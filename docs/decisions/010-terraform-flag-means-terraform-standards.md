# ADR-010: The `terraform` flag means "follows Fabrizio's Terraform standards"

Date: 2026-07-31 Status: Accepted

## Context

[ADR-006](006-standard-repository-composite.md) deliberately left the `terraform` flag doing only half of its intended job.
The flag was always meant to both attach the HCP Terraform token *and* add the Terraform plan check to the required status checks; the composite attached the token and stopped there.

The stated reason was that a required context a repo's CI never reports blocks that repo's merges behind a perpetual "Expected" entry, and the fleet's Terraform repos did not uniformly run a plan check — `authentik.flungo.net` was named as the exception.

Surveying every `terraform = true` repository showed the exception was in fact the majority.
Only two of five run the shared workflow:

| Repository | `.github/workflows/terraform.yml` |
| --- | --- |
| `terraform-github` | shared reusable, caller job `terraform` |
| `terraform-grafana-cloud` | shared reusable, caller job `terraform` |
| `stalwart.flungo.net` | **bespoke** — not the shared workflow |
| `authentik.flungo.net` | **none** — markdown lint/links and version-check only |
| `terraform-cloudflare` | **no workflows at all** — the repository is empty |

The flag had been read as "holds Terraform config".
That is a different property from "follows Fabrizio's Terraform standards", and the fleet proves they diverge: `stalwart.flungo.net` holds config and runs a workflow that is not the shared one; `terraform-cloudflare` holds nothing yet.
Only the second property implies both of the things the flag is meant to drive — the repo needs the HCP token *because* the workflow plans and applies, and reports the check *because* that workflow runs.

GitHub offers no way to sidestep the naming problem.
Required status checks are individually named contexts: there is no "require all checks" option, no wildcard, and no exclusion list ([community request](https://github.com/orgs/community/discussions/12377)).
So a context can only be required where it is known to report.

## Decision

**`terraform = true` asserts that the repository follows Fabrizio's Terraform standards** — which means it uses the `flungo/github-workflows` Terraform jobs, called under the conventional job name (`terraform`) and reading the conventional secret names.
It is not a statement about whether the repository contains `.tf` files.

The standards are Fabrizio's own, not an industry convention — the possessive is deliberate, because what the flag asserts is conformance to *this fleet's* way of doing Terraform, which is defined in `flungo/github-workflows` and nowhere else.

Framing it as the standards rather than as one specific workflow is likewise deliberate.
The flag's job is to say "this repository is built to that standard", and everything the composite does for it follows: the jobs read a known secret, so attach it; the jobs report a known context, so require it.
A future standard that adds another job or another secret extends the same flag rather than needing a new one.

The composite therefore does both halves together:

- attaches the org-wide HCP Terraform token, so the workflow can plan and apply;
- requires the workflow's `terraform / terraform` check before merge.

They arrive together because they are the same fact: the workflow needs the credential and reports the check.

`required_status_checks` becomes **additive** — the repository's *extra* contexts, appended to the baseline the flag supplies, rather than the complete list.

A repository that holds Terraform config but does not follow the standards leaves the flag off, with a comment saying what adopting them needs.
Two do today — `authentik.flungo.net` and `terraform-cloudflare` — neither having the jobs yet.

`stalwart.flungo.net` is the third case and a different one: it *does* follow the standards and use HCP for state, so it keeps the flag and its token, and drops only the context it cannot report.
See below.

### Conflicts are resolved by excluding the context, not by opting out of the flag

A repository can legitimately follow the standards — needing the secrets, wanting the settings — and still be unable to report the check they imply.
`stalwart.flungo.net` is the case: it uses HCP for state, so it wants the token, but its management host is LAN-only and the shared baseline cannot run on a GitHub-hosted runner.

`excluded_status_checks` removes named contexts after the implied and additional ones are combined.
That is preferred to a per-flag opt-out (`terraform_check = false` or similar) because the conflict is general: any future flag that implies a check can meet a repository that cannot report it, and the exclusion list absorbs each case without growing a matching boolean.
It also keeps the flag meaning one thing — the repo follows the standards — rather than splitting into a lattice of partial adoptions.

The list is scoped to contexts a *flag* implies, and a variable validation enforces that: a context named in both `required_status_checks` and `excluded_status_checks` is rejected.
Adding a context and then removing it leaves it not required, which is exactly what omitting it from `required_status_checks` does — so the pair is always a mistake rather than an intent, and is worth catching at plan time rather than silently honouring.
A caller that wants to keep such an entry visible but inactive comments it out.

The cost is that an exclusion is easy to leave behind after the reason for it lapses, so each one is commented at the call site with what would let it go.

### Adopting the standards does not deadlock a repository

Enabling the flag before a repository has the CI would, read naively, be a trap: the check becomes required before anything reports it.
It is not, because a `pull_request` workflow run uses the workflow file from the **pull request's own head**.
So the pull request that introduces the jobs also runs them, reports the context, and can satisfy its own requirement.

That makes the safe order: enable the flag here first, so the secrets exist when those jobs first run, then open the pull request in the target repository that adds them.
Other pull requests already open against that repository *are* blocked until it merges — they predate the workflow, so nothing reports their check — but they unblock by rebasing once it lands.
That is a queue, not a deadlock.

### The context string carries a naming requirement

`terraform / terraform` is `<caller job id> / <reusable job id>`.
The reusable half is fixed by `flungo/github-workflows`; the caller half is whatever each repository names its job.
Hardcoding the string in the composite therefore makes "name the caller job `terraform`" a condition of the flag.
Both current users already do.

This was preferred to deriving or configuring the string.
A per-repo input would reintroduce exactly the boilerplate the flag exists to remove, and a repository that has adopted the shared workflow has already accepted its conventions — the job name is one more.

## Consequences

**Positive:**

- The flag is coherent: one declaration, both effects, and it is true or false about a single checkable fact rather than an approximate one.
- Repositories that run the shared workflow now actually gate merges on it.
  That gap existed since ADR-006 and was invisible.
- Resolves ADR-006's explicit deferral rather than leaving it open indefinitely.
- The absence of the flag becomes informative: a commented-out `terraform = true` with a reason records that a repository is *waiting* on the standards, and what for.
- `excluded_status_checks` generalises beyond this flag, so the next standards flag that implies a check needs no new opt-out of its own.

**Negative / trade-offs:**

- **Two repositories lose their HCP token** — `authentik.flungo.net` and `terraform-cloudflare`.
  Neither runs a workflow that consumes it, so the credential was unused, but this is the fleet's first apply with a non-zero destroy count.
- **The naming requirement is implicit at the call site.** A repository that runs the shared workflow from a differently-named job, and sets the flag, blocks its own merges.
  Mitigated by documenting it on the input and here, but nothing enforces it.
- **The contract is now documented in two repositories.** The naming constraints the flag depends on — the caller job named `terraform`, the conventional secret names — bind a repository *adopting* the standards, so they are also written in `flungo/github-workflows`' adoption runbook, where that reader is looking.
  Nothing in this repo's CI reads that copy, so it goes stale silently.
  Mitigated by the cross-repo table in CLAUDE.md § "Docs in other repos that mirror this one", which names it as part of any change to this contract.
- **An exclusion can outlive its reason.** `excluded_status_checks` is not transient in the sense `import {}` blocks are — it stays for as long as the conflict does — so nothing prompts its removal once the repository can report the check.
  Mitigated only by the call-site comment naming what would clear it.
- **The flag now says less than it used to.** "Holds Terraform config" is still a useful fact and is no longer recorded anywhere in this repo's config.
  Accepted: it drove nothing, and the comment left on each opted-out repository carries it.
