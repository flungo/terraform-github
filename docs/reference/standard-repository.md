# Standard repository settings

The [`modules/standard-repository`](../../modules/standard-repository) composite
is the caller-facing surface for a managed repository: one module call creates
(or adopts) the repository with the standard settings, protects its default
branch, and attaches the fleet's shared Actions secrets. It composes three
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

Branch protection likewise applies its encoded defaults to every repo (require a
pull request, conversation resolution, linear history, block deletion; admin
bypass unless `strict`) — see [`branch-protection.md`](branch-protection.md).

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
| `required_status_checks` | `list(string)` | `[]` | Check contexts that must pass before merging, as they appear on the repo's PRs. Empty enforces no checks; a context the repo's CI never reports blocks merges behind a perpetual "Expected" entry, so list only contexts that actually run. |
| `release_branches` | `object` | `null` | Protect release branches with a second, `"release"` ruleset: `pattern` is the full ref pattern (fnmatch, e.g. `"refs/heads/v[0-9]*"`); `push_bypass_app_ids` the numeric IDs of the GitHub Apps allowed to push them directly (the release automation's identity — everyone else lands via a PR; annotate each ID with the App it names). `required_status_checks` is not applied to it — see [ADR-007](../decisions/007-release-branch-protection.md). |
| `terraform` | `bool` | `false` | The repo holds Terraform config → attach the HCP token secret (`TF_TOKEN_APP_TERRAFORM_IO`). Does **not** currently add a plan-check context to `required_status_checks` — see [ADR-006](../decisions/006-standard-repository-composite.md). |
| `manage_secrets` | `bool` | `true` | Opt-out of shared-secret management. Set `false` only where Terraform must not manage the repo's secrets — the self-referential case (`terraform-github` itself; see ADR-005's circularity note). |
| `shared_secrets` | `object` (sensitive) | `null` | The owner's shared secret values (`lychee_github_token`, optional `hcp_token`), composed once at owner level in a `locals` block and passed to every call as `shared_secrets = local.shared_secrets`. Required unless `manage_secrets = false`. |

The standard ruleset's `pattern` is deliberately not exposed: it stays at the
primitive's `~DEFAULT_BRANCH` default, so the composite protects the default
branch without knowing its name. Release branches are the exception — their
pattern is genuinely per-repo, so `release_branches` carries it explicitly.

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
