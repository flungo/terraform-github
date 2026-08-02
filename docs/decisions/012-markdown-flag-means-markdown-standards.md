# ADR-012: The `markdown` flag means "follows Fabrizio's Markdown standards"

Date: 2026-08-01
Status: Accepted

## Context

`LYCHEE_GITHUB_TOKEN` has been attached to **every** managed repository since [ADR-005](005-shared-secrets-module.md), which described it as the secret "every managed repo should carry".
That was written before the fleet was actually surveyed, and before [ADR-010](010-terraform-flag-means-terraform-standards.md) established the principle that corrects it: a shared secret belongs where the workflow that reads it runs.

Surveying which repositories call the [`flungo/github-workflows`](https://github.com/flungo/github-workflows) Markdown workflows shows the token sitting unread on nearly half the fleet:

| Repository | `markdown-lint.yml` + `markdown-links.yml` | Caller job ids |
| --- | --- | --- |
| `authentik.flungo.net` | both, `@v1` | `lint`, `links` — realigned |
| `stalwart.flungo.net` | both, `@v1` | `lint`, `links` — realigned |
| `terraform-provider-stalwart` | both, `@v1` | `lint`, `links` — realigned |
| `claude-plugins` | both, `@v1` | `lint`, `links` — realigned |
| `github-workflows` | both, dogfooded from `./` | `markdown-lint`, `markdown-links` — already conforming |
| `terraform-github` | both, `@v1` — adopted in the pull request this one follows | `markdown-lint`, `markdown-links` |
| `terraform-grafana-cloud` | **neither** | — |
| `claude-code-sandbox` | **neither** | — |
| `terraform-cloudflare` | **neither** — the repository is empty | — |

The token is only ever read by the **external** URL sweep, which needs it to resolve links into other private repositories and to avoid public-GitHub rate limits.
A repository that runs neither workflow has no reader for it.

The symmetric gap is on the other side: the four repositories that *do* run the workflows gate nothing on them.
Their Markdown could break on `main` without a required check noticing, which is the same invisible gap [ADR-010](010-terraform-flag-means-terraform-standards.md) found for the Terraform plan check.

## Decision

**`markdown = true` asserts that the repository follows Fabrizio's Markdown standards** — it calls the `flungo/github-workflows` Markdown workflows under the conventional job names.
It is not a statement about whether the repository contains Markdown; every repository does, and the flag is about the CI, not the content.

This is [ADR-010](010-terraform-flag-means-terraform-standards.md)'s shape applied to a second standard, which is the point: that ADR deliberately framed the `terraform` flag as conformance to a *standard* rather than to one workflow, so that another standard would extend the same pattern rather than need a new one.
This is the first test of that, and the pattern held — the composite grew one variable, one implied-context branch, and one `count`.

The composite therefore does both halves together:

- attaches `LYCHEE_GITHUB_TOKEN`, so the external sweep can reach other private repositories;
- requires `markdown-lint / lint` and `markdown-links / internal`, the checks the two workflows report on every pull request.

They arrive together because they are the same fact: the repository runs those workflows.

### Two workflows, two checks — but not three

The Markdown standard is two workflows, so the flag implies two contexts where `terraform` implies one.
Nothing about the design assumed one check per flag, and the assembly in `modules/standard-repository/branch-protection.tf` concatenates lists rather than appending strings.

The third job is deliberately **not** required.
`markdown-links.yml` carries an `external` job alongside `internal`, and it self-skips on `pull_request` — the sweep runs on a schedule and on dispatch, reporting breakage through a single auto-updated issue rather than failing a run, precisely so that a third-party outage cannot block a merge.
Requiring `markdown-links / external` would name a context that never runs on a pull request for the very reason the job exists.

### The context strings carry a naming requirement, and it is now a published convention

A context is `<caller job id> / <reusable job id>`.

Both halves are now fixed by convention in `github-workflows`, and this ADR is part of why.
The first draft hardcoded the reusable halves as **display names** — `markdown-lint.yml`'s job is `lint` but was named `markdownlint`, and `markdown-links.yml`'s `internal` job was named `Internal links & anchors` — so reading the ids out of those files produced two wrong strings, and the values had to be copied from an actual check run.

Writing that down was the argument that a display name is a poor contract, and it produced [`github-workflows` ADR-011](https://github.com/flungo/github-workflows/blob/main/docs/decisions/011-reusable-job-ids-are-the-check-name.md): a reusable job sets no `name:`, so its id *is* the check name.
That cut `v2` there, and the contexts became `markdown-lint / lint` and `markdown-links / internal` — lowercase, space-free, and derivable without running anything.

The caller half is whatever each repository names its job, so hardcoding the contexts makes the caller job names a condition of the flag — the same way `terraform / terraform` does.

Reviewing that requirement is what produced [`github-workflows` ADR-010](https://github.com/flungo/github-workflows/blob/main/docs/decisions/010-caller-job-ids-match-the-workflow-filename.md), and it changed the answer here.
The first draft of this ADR hardcoded `lint` and `links`, because those were the names the adoption runbook's snippets used and the names all four existing adopters had copied.
They are poor names: a caller job id is a **repository-wide namespace**, and `lint` is exactly what a repository is most likely to want for something else — this repository runs Terraform `fmt`/`validate` and could plausibly gain `actionlint`.

That convention makes the rule mechanical fleet-wide: **a caller's job id is the reusable workflow's filename without `.yml`.**
So the contexts here are `markdown-lint / lint` and `markdown-links / internal`, and — more usefully — *both* halves of any future standard's context are derivable from a filename and a job id rather than needing to be negotiated or transcribed.
`terraform / terraform` already satisfied the rule, which is some evidence it is the one that was being reached for anyway.

### The flag defaults to `true`

`terraform` defaults to `false`, and the obvious move was to mirror it. That is wrong here, and the asymmetry is the point rather than an inconsistency.

The two flags describe different base rates. Holding Terraform config is a property of a minority of repositories and always will be; following the Markdown standards is something **every** repository should end up doing — every repository has documentation, and the aspiration is fleet-wide adoption. A default should be the case you expect, so that the configuration records deviations rather than restating the norm nine times.

It also matches [ADR-003](003-standard-repository-module.md)'s standard-first principle: the composite encodes the standard, and a repository states where it *differs*. Under a `false` default, six of nine repositories had to assert conformance, and the three that did not were silent — indistinguishable from an oversight. Inverted, silence means conforming and every exception carries a written reason.

**A repository being created is the one case that needs care.** It has no caller workflows yet, so the two checks the flag requires would never report and its first pull request would be unmergeable. The [creation runbook](../runbooks/creating-repositories.md) therefore sets `markdown = false` on the create, with the line deleted by the pull request that adopts the workflows — the same shape as `repository_exists`, and for the same reason: a value that is only correct during a transition.

This is not free. A `false` default fails safe (a repository never acquires a required check it cannot report), while a `true` default fails *closed* (a repository that has not adopted the workflows blocks its own merges until someone sets the flag). That trade is accepted because the failure is loud, immediate, and fixed by one line — whereas the failure the old default produced was silent: a repository quietly gating nothing, which is what this ADR exists to correct.

### No repository is exempt, and `github-workflows` least of all

An earlier draft treated `github-workflows` as a sanctioned exception.
It cannot pin itself `@v1`, so it dogfoods both workflows from `./` inside its combined `ci.yml`, where the caller jobs sit beside `actionlint` — and it had therefore named them `markdown-lint` and `markdown-links` rather than `lint` and `links`.
The plan was to keep the flag and reconcile with `excluded_status_checks` plus a matching `required_status_checks`.

That was backwards.
`ci.yml` was not deviating from the standard; it was the only caller in the fleet already doing the right thing, and the runbook's examples were what needed fixing.
Under [`github-workflows` ADR-010](https://github.com/flungo/github-workflows/blob/main/docs/decisions/010-caller-job-ids-match-the-workflow-filename.md) it conforms with no reconciliation at all, and the exclusion route is no longer offered for a naming mismatch — a repository that reports a different context should be renamed, not excused.

`excluded_status_checks` keeps its real case: a repository that follows a standard but genuinely **cannot run** the check, as `stalwart.flungo.net` cannot run the Terraform baseline from a GitHub-hosted runner.
That is a fact about the infrastructure; a job name is a choice, and choices get aligned.

### Realigning the four existing adopters is part of this change

`authentik.flungo.net`, `stalwart.flungo.net`, `terraform-provider-stalwart` and `claude-plugins` all carry the old `lint` / `links` names.
Requiring the new contexts before they are renamed would block their merges behind two contexts nothing reports, so the renames land first and this flag follows.

## Consequences

**Positive:**

- The token stops being attached where nothing reads it. Three repositories shed an unused credential.
- Four repositories gain merge gating on their Markdown checks — a gap that, like [ADR-010](010-terraform-flag-means-terraform-standards.md)'s, existed silently.
- [ADR-010](010-terraform-flag-means-terraform-standards.md)'s framing is validated: a second standard extended the same flag pattern with no new mechanism, and the absence of a flag is again informative rather than an oversight.
- The `terraform` and `markdown` flags now compose. `authentik.flungo.net` shows why keeping them separate matters — it follows the Markdown standards and not the Terraform ones, so one flag on and one off is the accurate description.

**Negative / trade-offs:**

- **Three repositories lose `LYCHEE_GITHUB_TOKEN`** — `terraform-grafana-cloud`, `claude-code-sandbox` and `terraform-cloudflare`. None runs a workflow that reads it, so nothing breaks, but this is a destroy in the plan and it is worth reading rather than waving through.
- **Repositories gaining their first required check also gain strictness.** [ADR-011](011-strict-required-status-checks.md) encodes `strict_required_status_checks_policy` in the block the module emits only where a context is required, so `claude-plugins`, `terraform-provider-stalwart` and `authentik.flungo.net` acquire "branches must be up to date before merging" as a side effect of this flag rather than of a decision about strictness. That is the intended coupling, but it arrives here rather than being chosen here.
- **A repository whose Markdown CI is currently red will find its merges blocked.** That is the flag working as intended, and there is no way to require a check conditionally, but it is a behaviour change landing on four repositories at once.
- **The naming requirement is implicit at the call site**, as with `terraform`, and nothing validates it. A repository that adopts the workflows under other job names and sets the flag blocks its own merges. [`github-workflows` ADR-010](https://github.com/flungo/github-workflows/blob/main/docs/decisions/010-caller-job-ids-match-the-workflow-filename.md) makes the rule mechanical rather than remembered, which is the mitigation, but it is still a convention.
- **Four repositories needed a rename before this could apply**, and each rename momentarily changed the context that repository reported. That is done: it landed with each repository's `@v2` migration, since [`github-workflows` ADR-011](https://github.com/flungo/github-workflows/blob/main/docs/decisions/011-reusable-job-ids-are-the-check-name.md) renamed the reusable halves at the same time and one pull request per repository avoided a window where a caller reported a context nothing expected. It was the cost of having published poor example names in the first place.
- **The contract is now documented in two repositories.** The caller job names the flag depends on bind a repository *adopting* the standards, so they are also written in [`github-workflows`' `adopting-markdown-workflows.md`](https://github.com/flungo/github-workflows/blob/main/docs/runbooks/adopting-markdown-workflows.md), where that reader is looking. Nothing here reads that copy, so it is named in [`CLAUDE.md` § Docs in other repos that mirror this one](../../CLAUDE.md#docs-in-other-repos-that-mirror-this-one).
