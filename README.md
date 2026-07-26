# terraform-github

Terraform configuration for managing GitHub resources across the personal account and organisations — a standard project template, shared/common secrets, and (over time) branch protection, webhooks, teams, and other resources exposed by the [`integrations/github`](https://registry.terraform.io/providers/integrations/github/latest) provider.

The repository is named for the **provider**, not its initial use case: scope is expected to grow to the full GitHub-manageable surface without a rename. See [ADR-001](docs/decisions/001-dedicated-terraform-github-repo.md) for the founding rationale.

> **Status: build-out under way.** The first owner directory (`owners/flungo/`), the plan-on-PR / apply-on-merge CI workflow, and the standard repository module (`modules/repository`) have landed; the `flungo` account's repositories are managed through the module. The remaining build-out is scoped in [`docs/plans/initial-buildout.md`](docs/plans/initial-buildout.md).

## What this manages

Terraform manages these GitHub resources for the `flungo` account (in `owners/flungo/`); apply runs on merge to `main` via CI.

- **Repositories** — each managed through the shared standard repository module (`modules/repository`), which applies the standard settings, merge strategy, and feature toggles. Under management:
  - `authentik.flungo.net` — adopted (imported) from the pre-existing repo
  - `github-workflows` — created by this config to host the fleet's shared reusable workflows and CI standards
  - `claude-plugins` — created by this config; the personal Claude Code / claude.ai plugin marketplace
- **Branch protection** — each managed repo's default branch is protected via the shared branch-protection module (`modules/branch-protection`, a repository ruleset): require a pull request, conversation resolution, and linear history. Piloted on `authentik.flungo.net`.
- **Growth** — common Actions secrets/variables, webhooks, teams and membership, and other `integrations/github` resources

## Structure

Configuration is organised as **one directory per owner** (the personal account and each organisation), each consuming **shared modules** that encode the standard template and preferences:

```
modules/            # shared, opinionated modules — repository (the standard repo) today; more to come
owners/
  flungo/           # the personal (user) account, by login
  <organisation>/   # one per organisation account (every non-flungo owner is an org)
docs/
  decisions/        # Architecture Decision Records (ADRs)
  plans/            # One-time build/onboarding procedures, tracked then retired
  runbooks/         # Repeatable operational procedures
  reference/        # Information-oriented lookup docs (standard settings, secret catalogue)
```

See the [decision records](docs/decisions/) for the directory-per-owner layout (ADR-001), the workspace-per-owner topology (ADR-002), and the standard repository module (ADR-003); the module's settings are catalogued in [`docs/reference/standard-repository.md`](docs/reference/standard-repository.md).

## Backend & CI

Inherited from [`terraform-grafana-cloud`](https://github.com/flungo/terraform-grafana-cloud):

- **State:** HCP Terraform (org `flungo`), **Local execution mode** — GitHub Actions / local CLI is the runner; HCP provides state, locking, and run history only. One workspace per owner directory (see the build-out plan).
- **Secrets:** GitHub Actions secrets, not HCP workspace variables.
- **CI:** GitHub Actions — plan on PR, apply on merge to `main`, `workflow_dispatch` for on-demand runs.

## Authentication

Terraform authenticates to GitHub with a token supplied per owner directory as `TF_VAR_github_token` (from a per-owner GitHub Actions secret). The HCP Terraform backend is authenticated via `TF_TOKEN_APP_TERRAFORM_IO`. The interim credential is a per-owner fine-grained PAT; consolidating onto a shared GitHub App is a tracked follow-up.

## Decision records

See [`docs/decisions/`](docs/decisions/) for the reasoning behind key architectural choices, and [CLAUDE.md](CLAUDE.md) for agent-oriented conventions.
