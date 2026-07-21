# terraform-github

Terraform configuration for managing GitHub resources across the personal account and organisations — a standard project template, shared/common secrets, and (over time) branch protection, webhooks, teams, and other resources exposed by the [`integrations/github`](https://registry.terraform.io/providers/integrations/github/latest) provider.

The repository is named for the **provider**, not its initial use case: scope is expected to grow to the full GitHub-manageable surface without a rename. See [ADR-001](docs/decisions/001-dedicated-terraform-github-repo.md) for the founding rationale.

> **Status: build-out under way.** The first owner directory (`owners/flungo/`) and the plan-on-PR / apply-on-merge CI workflow have landed; the `flungo` account's repositories are being brought under management. Shared `modules/` are not extracted yet — resources currently live directly in the owner directory. The remaining build-out is scoped in [`docs/plans/initial-buildout.md`](docs/plans/initial-buildout.md).

## What this manages

Terraform manages these GitHub resources for the `flungo` account (in `owners/flungo/`); apply runs on merge to `main` via CI.

- **Repositories** — a standard set of settings, merge strategy, and feature toggles applied per repo. Under management:
  - `authentik.flungo.net` — adopted (imported) from the pre-existing repo
  - `github-workflows` — created by this config to host the fleet's shared reusable workflows and CI standards
- **Growth** — a shared repository module, common Actions secrets/variables, branch protection / rulesets, webhooks, teams and membership, and other `integrations/github` resources

## Structure

Configuration is organised as **one directory per owner** (the personal account and each organisation), each consuming **shared modules** that encode the standard template and preferences:

```
modules/            # shared, opinionated modules (repository, secrets, standard-repository, …)
owners/
  flungo/           # the personal (user) account, by login
  <organisation>/   # one per organisation account (every non-flungo owner is an org)
docs/
  decisions/        # Architecture Decision Records (ADRs)
  plans/            # One-time build/onboarding procedures, tracked then retired
  runbooks/         # Repeatable operational procedures
  reference/        # Information-oriented lookup docs (standard settings, secret catalogue)
```

See [`docs/plans/initial-buildout.md`](docs/plans/initial-buildout.md) for the module design, the directory-per-owner layout, and the HCP workspace-topology analysis.

## Backend & CI

Inherited from [`terraform-grafana-cloud`](https://github.com/flungo/terraform-grafana-cloud):

- **State:** HCP Terraform (org `flungo`), **Local execution mode** — GitHub Actions / local CLI is the runner; HCP provides state, locking, and run history only. One workspace per owner directory (see the build-out plan).
- **Secrets:** GitHub Actions secrets, not HCP workspace variables.
- **CI:** GitHub Actions — plan on PR, apply on merge to `main`, `workflow_dispatch` for on-demand runs (to be added with the first module code).

## Authentication

Terraform authenticates to GitHub with a token supplied per owner directory as `TF_VAR_github_token` (from a per-owner GitHub Actions secret). The HCP Terraform backend is authenticated via `TF_TOKEN_APP_TERRAFORM_IO`. The credential model (single PAT vs per-owner PAT / GitHub App) is being decided in the build-out plan.

## Decision records

See [`docs/decisions/`](docs/decisions/) for the reasoning behind key architectural choices, and [CLAUDE.md](CLAUDE.md) for agent-oriented conventions.
