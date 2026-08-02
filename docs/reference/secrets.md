# Secrets

The credentials CI uses.
All are **GitHub Actions secrets** — never HCP workspace variables.
The tokens that gate this repo's *own* CI are never Terraform-managed (a broken apply must not be able to lock the repo out of its own credentials; see [Terraform conventions](terraform-conventions.md) → bootstrapping / circularity).
Secrets written to *other* repos (below) carry no such circularity and are Terraform-managed.

| Secret | Purpose | Rotation |
| --- | --- | --- |
| `TF_TOKEN_APP_TERRAFORM_IO` | HCP Terraform Owners-team token for the state backend — org-wide, shared across all owner workspaces. Also propagated to `terraform = true` managed repos (below). | Manual (rotate in HCP) |
| `FLUNGO_GITHUB_TOKEN` | `github` provider token for the `flungo` owner (fine-grained PAT, bootstrap) → `TF_VAR_github_token` | [`../runbooks/github-provider-token-rotation.md`](../runbooks/github-provider-token-rotation.md) |
| `LYCHEE_GITHUB_TOKEN` | The lychee Markdown link-checker's GitHub token — read by the external URL sweep, to reach other private repos and avoid rate limits. Composed into the reusable workflow's `tf_secret_vars` and propagated to `markdown = true` managed repos (below). Also read by this repo's own sweep. | Manual |

`TF_TOKEN_APP_TERRAFORM_IO` and `LYCHEE_GITHUB_TOKEN` are additionally composed into the reusable workflow's `tf_secret_vars` secret so the [`repository-secrets`](../../modules/repository-secrets) module can write them into managed repos.

## Shared secrets written to managed repos

`modules/repository-secrets` attaches the fleet's common Actions secrets to each managed repository ([ADR-005](../decisions/005-shared-secrets-module.md)).
Neither is universal: each is gated on the flag asserting that the repo follows the standard whose workflows read it, so a credential is never attached where nothing consumes it ([ADR-010](../decisions/010-terraform-flag-means-terraform-standards.md), [ADR-012](../decisions/012-markdown-flag-means-markdown-standards.md)).

| Secret written | Where | Source value |
| --- | --- | --- |
| `LYCHEE_GITHUB_TOKEN` | repos with `markdown = true` | `LYCHEE_GITHUB_TOKEN` (above) |
| `TF_TOKEN_APP_TERRAFORM_IO` | repos with `terraform = true` | `TF_TOKEN_APP_TERRAFORM_IO` (above) |

The values reach Terraform via the reusable workflow's `tf_secret_vars` (exported as masked `TF_VAR_*` env vars); the owner-directory variables are `sensitive`, so plan output and the plan artifact redact them.

Per-owner GitHub tokens move to **GitHub Environments** (environment-scoped secrets) as more owners are onboarded, so one owner's CI job cannot read another owner's token — a follow-up with its own ADR.
