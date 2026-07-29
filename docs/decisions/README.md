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
