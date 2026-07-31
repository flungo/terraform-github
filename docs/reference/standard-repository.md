# Standard repository settings

The [`modules/standard-repository`](../../modules/standard-repository) composite
is the caller-facing surface for a managed repository: one module call creates
(or adopts) the repository with the standard settings, protects its default
branch — and its release branches, where the repo declares them — and attaches
the fleet's shared Actions secrets. It composes three
primitive modules, each of which stays independently usable where a genuine
partial case appears:

| Primitive | Concern | Catalogue |
|---|---|---|
| [`modules/repository`](../../modules/repository) | Repository settings, feature toggles, merge strategy | this page |
| [`modules/branch-protection`](../../modules/branch-protection) | Branch-protection rulesets — the default branch always; release branches where declared | [`branch-protection.md`](branch-protection.md) |
| [`modules/repository-secrets`](../../modules/repository-secrets) | Shared Actions secrets | [`secrets.md`](secrets.md) |

The composite adds no opinion of its own — the baselines are encoded in the
primitives. To change the standard fleet-wide, edit it in one place — the
relevant module, not each owner directory — then re-apply each owner to roll the
change out.

## Encoded baseline (not configurable)

These are set in `modules/repository` and are the same for every repository.
Changing one here rolls it out to all repositories on the next apply.

| Setting | Value | Why |
|---|---|---|
| `has_issues` | `true` | Issues are the default tracker; on everywhere. |
| `has_wiki` | `false` | Documentation lives in-repo (`docs/`), not a wiki. |
| `has_projects` | `false` | Project boards are not used at the repo level. |
| `has_downloads` | `false` | GitHub deprecated the Downloads feature; `true` does not persist (the API reports it back as `false`), so the baseline is off to avoid a perpetual plan diff. |
| `allow_merge_commit` | `false` | Linear history — no merge commits. |
| `allow_squash_merge` | `true` | Squash for single logical changes. |
| `allow_rebase_merge` | `true` | Rebase for several distinct changes worth preserving. |
| `delete_branch_on_merge` | `true` | Keeps the branch list tidy after merge. |
| `squash_merge_commit_title` | `PR_TITLE` | With Conventional Commits on PR titles, the PR title *is* the commit subject. |
| `squash_merge_commit_message` | `PR_BODY` | The PR description becomes the commit body, rather than the branch's working commit messages. |
| `allow_update_branch` | `false` | Branches are brought up to date by rebasing, which keeps the linear history the ruleset requires. |

Leaving a setting out of the baseline is not a way to leave it alone: the provider
resets an unset attribute to its own default on every apply, so an omission is
just a silent vote for that default. Anything the standard has a view on belongs
in the table above, stated explicitly.

Branch protection likewise applies its encoded defaults to every repo (require a
pull request, conversation resolution, linear history, block force-pushes, block
deletion; admin bypass unless `strict`) — see [`branch-protection.md`](branch-protection.md).

## Per-repo inputs (configurable)

The composite's full input surface:

| Input | Type | Default | Notes |
|---|---|---|---|
| `name` | `string` | — (required) | The repository name. |
| `description` | `string` | — (required) | One-line description. |
| `visibility` | `string` | `"private"` | `"public"` only where the repo must be readable/callable by others (e.g. hosting reusable workflows). |
| `topics` | `list(string)` | `[]` | Repository topics — prefer the [topics glossary](topics.md). |
| `auto_init` | `bool` | `true` | Seed an initial commit so `main` exists at creation. Applies only at creation; later drift is ignored. Set `false` for an empty repo populated by a bulk push. |
| `strict` | `bool` | `false` | Remove the admin bypass from branch protection so the rules bind everyone. |
| `required_status_checks` | `list(string)` | `[]` | **Additional** required check contexts, beyond any implied by the standards flags. Named as they appear on the repo's PRs. GitHub has no "require all checks" option and no wildcard — contexts are named individually, and one the repo's CI never reports blocks merges behind a perpetual "Expected" entry — so list only contexts that actually run, and do not repeat an implied one. |
| `excluded_status_checks` | `list(string)` | `[]` | Contexts to **remove** from the required set, applied after the implied and additional ones are combined. The escape hatch where a repo legitimately takes a flag's other effects but cannot report the check that flag implies. Preferred to a per-flag opt-out because it generalises to any flag/check conflict. It is only ever for a context a *flag* implies: a validation rejects one that also appears in `required_status_checks`, since adding a context and then removing it leaves it not required — exactly what omitting it does — so listing it twice is a mistake, not an intent. To keep such an entry in the code but disabled, comment it out in `required_status_checks`. Name what is excluded and why at the call site. |
| `release_branches` | `object` | `null` | Protect release branches with a second, `"release"` ruleset: `pattern` is the full ref pattern (fnmatch, e.g. `"refs/heads/v[0-9]*"` — prefer a glob that cannot under-reach); `push_bypass_app_ids` the numeric IDs of the GitHub Apps allowed to push them directly (the release automation's identity — everyone else lands via a PR; annotate each ID with the App it names). Those Apps are also the **only** actors that may create a matching branch, which is what makes the broad pattern safe. `required_status_checks` is not applied to it — see [ADR-007](../decisions/007-release-branch-protection.md) and [ADR-008](../decisions/008-restrict-release-branch-creation.md). |
| `terraform` | `bool` | `false` | The repo **follows Fabrizio's Terraform standards** — it uses the `flungo/github-workflows` Terraform jobs, under the conventional job name (`terraform`) and reading the conventional secret names. Not merely "holds Terraform config": that is a different property and the fleet diverges. Both effects follow from adopting the standards — the HCP token (`TF_TOKEN_APP_TERRAFORM_IO`) those jobs read is attached, and the `terraform / terraform` check they report is required. Leave `false`, with a comment saying what adopting them needs, on a repo that holds config but does not yet follow them; where a repo follows them but cannot report the check, keep the flag and drop the context via `excluded_status_checks`. See [ADR-010](../decisions/010-terraform-flag-means-terraform-standards.md). |
| `manage_secrets` | `bool` | `true` | Opt-out of shared-secret management. Set `false` only where Terraform must not manage the repo's secrets — the self-referential case (`terraform-github` itself; see ADR-005's circularity note). |
| `shared_secrets` | `object` (sensitive) | `null` | The owner's shared secret values (`lychee_github_token`, optional `hcp_token`), composed once at owner level in a `locals` block and passed to every call as `shared_secrets = local.shared_secrets`. Required unless `manage_secrets = false`. |
| `repository_exists` | `bool` | `true` | Whether the repository already exists on GitHub. Gates the classic-protection guard. **Transient** — set `false` only in the change that creates a brand-new repository, and remove it once that apply has run (the guard's data source cannot query a repository that does not exist yet, and fails the plan if asked to). See [ADR-009](../decisions/009-plan-time-classic-protection-guard.md). |

The standard ruleset's `pattern` is deliberately not exposed: it stays at the
primitive's `~DEFAULT_BRANCH` default, so the composite protects the default
branch without knowing its name. Release branches are the exception — their
pattern is genuinely per-repo, so `release_branches` carries it explicitly.

## Classic-protection guard

The composite reads each repository's *classic* branch protection rules
(`github_branch_protection_rules`) and a `postcondition` fails the plan if any
exist. GitHub applies rulesets and classic protection both at once, so a legacy
rule left over from before onboarding would double-enforce against the ruleset.
The guard is read-only — Terraform cannot delete a rule it does not manage — so it
surfaces the drift for removal by hand, per
[`../runbooks/migrating-classic-protection-to-ruleset.md`](../runbooks/migrating-classic-protection-to-ruleset.md).

Two details are deliberate and load-bearing
([ADR-009](../decisions/009-plan-time-classic-protection-guard.md)):

- **It reads `var.name`, not the repository resource's name.** Terraform defers a
  data source whose configuration depends on a resource with pending changes, and
  an adoption always leaves the repository pending — so reading the resource's
  name deferred the guard to apply, where a postcondition runs *after* the
  resources it depends on and the ruleset it should have blocked already exists.
  A literal name keeps the check at plan time.
- **It lives in the composite, not the branch-protection primitive**, so it runs
  once per repository rather than once per ruleset.
- **It is skipped while `repository_exists = false`.** Reading a literal name is
  what fixes adoption, but it breaks creation: asked about a repository GitHub has
  never heard of, the data source fails the plan with `Could not resolve to a
  Repository` rather than returning nothing. The flag is how the caller says which
  case it is, and it is transient — see [creating a repository](../runbooks/creating-repositories.md).
  Nothing is lost by skipping it: a repository that does not exist cannot carry
  classic protection.

The data source exposes only each rule's `pattern`, not its settings. When a plan
fails on the guard, the CI `surface-classic-protection` job reads the plan
artifact and fetches the full classic settings via GraphQL, printing them to its
run summary — the comparison that confirms the ruleset is equivalent-or-stronger
before the classic rule is removed.

## Growing the input surface

The input set is kept small and grown deliberately. A repository is brought to
the **standard by default**; a per-repo deviation from the encoded baseline is
supported by adding an input **only when the user has explicitly confirmed** the
deviation must be supported (see [Terraform conventions](terraform-conventions.md)). When an
input maps to a GitHub provider argument it takes the provider's own name (e.g.
`visibility`); otherwise it is named for the *intent* so one flag can drive
several decisions. An input added to a primitive is invisible to composite
callers until the composite re-exposes it — add it in both places in the same
change.

> **🤖 Agent** — When a repository's live setting differs from the encoded
> baseline, propose bringing it to the standard and ask the user to confirm per
> repo; add an input to preserve the deviation only if they say it must be
> supported. Do not add a deviation input speculatively.

## Using the module

- Create a new repository: [`../runbooks/creating-repositories.md`](../runbooks/creating-repositories.md).
- Adopt an existing repository: [`../runbooks/importing-repositories.md`](../runbooks/importing-repositories.md).
