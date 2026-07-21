# Secrets

The credentials CI uses. All are **GitHub Actions secrets** — never HCP workspace variables, and never Terraform-managed (a broken apply must not be able to lock the repo out of its own credentials; see `CLAUDE.md` § Terraform conventions → bootstrapping / circularity).

| Secret | Purpose | Rotation |
|---|---|---|
| `TF_TOKEN_APP_TERRAFORM_IO` | HCP Terraform Owners-team token for the state backend — org-wide, shared across all owner workspaces | Manual (rotate in HCP) |
| `FLUNGO_GITHUB_TOKEN` | `github` provider token for the `flungo` owner (fine-grained PAT, bootstrap) → `TF_VAR_github_token` | [`../runbooks/github-provider-token-rotation.md`](../runbooks/github-provider-token-rotation.md) |

Per-owner GitHub tokens move to **GitHub Environments** (environment-scoped secrets) as more owners are onboarded, so one owner's CI job cannot read another owner's token — a follow-up with its own ADR.
