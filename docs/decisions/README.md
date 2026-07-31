# Architecture Decision Records

Decisions are numbered sequentially and never deleted or renumbered. Each file documents the context, decision, and consequences for a key architectural choice. Superseded decisions keep their file and get a note at the top pointing to the newer ADR.

| # | Title | Status | Summary |
|---|---|---|---|
| [001](001-dedicated-terraform-github-repo.md) | Dedicated `terraform-github` repository for GitHub resources | Accepted | Manage GitHub resources across the personal account and organisations as code in a dedicated, provider-scoped repository, structured as one directory per owner consuming shared modules. HCP Terraform backend and CI conventions are inherited from `terraform-grafana-cloud`. |
| [002](002-workspace-per-owner-topology.md) | Workspace-per-owner backend topology | Accepted | One HCP workspace per owner directory (`github-<login>`) in a dedicated `terraform-github` project, Local execution. Chosen for credential scoping and blast-radius isolation; per-owner overhead stays low because the HCP token and GitHub App key are shared and workspaces auto-create on first `init`. |
| [003](003-standard-repository-module.md) | Standard repository module | Accepted | Extract `modules/repository` encoding the opinionated baseline (feature toggles, merge strategy) with a small per-repo input set; route every owner-directory repository through it, migrating existing resources via `moved {}` blocks (no destroy/recreate). Standard first; deviation inputs added only on explicit confirmation. |
| [004](004-branch-protection-rulesets.md) | Branch protection via repository rulesets | Accepted | Protect default branches with a shared `modules/branch-protection` — a `github_repository_ruleset` (chosen over `github_branch_protection`): require PR (0 approvals) + conversation resolution + linear history, admin bypass unless `strict`, targeting `~DEFAULT_BRANCH`. Piloted on `authentik.flungo.net`. |
| [005](005-shared-secrets-module.md) | Shared secrets via the repository-secrets module | Accepted | A `modules/repository-secrets` wraps `github_actions_secret` to attach the common set — `LYCHEE_GITHUB_TOKEN` on every repo, `TF_TOKEN_APP_TERRAFORM_IO` gated on a `terraform` flag; values arrive via the reusable workflow's new `tf_secret_vars` secret (composed from the owner's own secrets; `sensitive`). Per-repo only — org-level secrets are a future `org-secrets` module. Piloted on `authentik.flungo.net`. |
| [006](006-standard-repository-composite.md) | Standard-repository composite module | Accepted | A `modules/standard-repository` composes the three primitives (repository + branch-protection + repository-secrets) so an owner directory declares one module call per repo; migrated via `moved {}` blocks. Secret values come from one owner-level `shared_secrets` local passed uniformly to every call; a `manage_secrets` opt-out covers the self-referential case. The `terraform` flag attaches the HCP secret but does not yet add a required plan-check context (fleet CI isn't uniform; a never-reported context would block merges). |
| [007](007-release-branch-protection.md) | Release-branch protection with an App push bypass | Accepted | Extend `modules/branch-protection` with `name` and `push_bypass_app_ids` (numeric App IDs — a private App cannot be resolved by slug — granted an `"always"` bypass, kept under `strict`) and encode `non_fast_forward`; a `release_branches` composite input creates a second `"release"` ruleset. First case: `github-workflows`' moving-major `v*` branches, pushed only by its `flungo-release` App or a merged PR. |
| [008](008-restrict-release-branch-creation.md) | Restrict release-branch creation to the release automation | Accepted | Ruleset ref targeting is fnmatch, not regex, so `v[0-9]*` also reaches `v1x`/`v2-test` — and with `deletion` blocked and the admin bypass being PR-scoped, such a branch could not be deleted by anyone. Add `restrict_creation`, set by the composite for release rulesets, so only the release App can create a matching ref: the trap becomes a clean rejection. The broad glob is then kept deliberately — narrowing to enumerated shapes would leave a silent under-reach (`v100`), whereas over-reach nobody can create costs nothing. `update` stays unrestricted (it would block backport PRs). Refines ADR-007. |
| [009](009-plan-time-classic-protection-guard.md) | Evaluate the classic-protection guard at plan time, in the composite | Accepted | Terraform defers a data source that depends on a resource with pending changes, and an adoption always leaves the repository resource pending — so ADR-004's guard was never evaluated at plan time for the case it exists for, and fired only during apply, *after* the rulesets it should have blocked were created. The guard moves to `modules/standard-repository` and reads `var.name` (plan-time known) instead of `module.repository.name`. Creation then needs the guard skipped — the data source cannot query a repository that does not exist — so a transient `repository_exists` input (default `true`) gates it. Also removes ADR-007's duplicate read: one guard per repository, not per ruleset. Refines ADR-004. |

## Adding a new ADR

1. Create `docs/decisions/<NNN>-<kebab-case-title>.md` using the template below
2. Update this index with a one-sentence summary
3. If the new decision supersedes an existing one, update the older ADR's status to `Superseded by ADR-NNN`

### ADR template

```markdown
# ADR-NNN: Title

Date: YYYY-MM-DD
Status: Accepted

## Context

Why does this decision need to be made?

## Decision

What was decided?

## Consequences

**Positive:**
- ...

**Negative / trade-offs:**
- ...
```
