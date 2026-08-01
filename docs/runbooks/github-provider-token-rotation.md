# Runbook: Rotate the GitHub provider token

Rotate the fine-grained PAT the `github` provider uses to manage the `flungo` account, before it expires.

This PAT is the **bootstrap** credential.
The intended end state is a **GitHub App** (its own future ADR), which would supersede this token and remove the need to rotate a PAT at all.
Until the App is in place, rotate the PAT on or before expiry.

## Token

| Field | Value |
| --- | --- |
| Token name | `terraform-github-flungo` |
| Type | Fine-grained PAT — `flungo` account, **all repositories** |
| Permissions | Repository → **Administration: Read and write**, **Secrets: Read and write**, **Metadata: Read-only** |
| Actions secret | `FLUNGO_GITHUB_TOKEN` (repo secret) → env `TF_VAR_github_token` |
| Expiry | 90 days |

> **Permissions grow with scope.** The current set covers everything managed today: **Administration** for repository settings and rulesets (`github_repository`, `github_repository_ruleset` — branch protection included), **Secrets** for the shared Actions secrets written to managed repos (`github_actions_secret`), and **Metadata**, which is always required.
> Additional resources need additional fine-grained permissions, added to the token when they land:
>
> - **Dependabot secrets:** Repository → **Dependabot secrets** (the `Secrets` permission covers Actions secrets only).
> - **Webhooks:** Repository → **Webhooks**.
> - **Teams / membership** (organisation owners): the corresponding **Organization** permissions.
>
> Re-record the permission set here whenever it changes.

## Rotation procedure

1. Create a new fine-grained PAT named `terraform-github-flungo` for the `flungo` account, **all repositories**, with the permissions above and a 90-day expiry (regenerate the existing token, or create-and-swap).
2. Update the **`FLUNGO_GITHUB_TOKEN`** repository secret (**Settings → Secrets and variables → Actions**) with the new value.
3. Verify: trigger the `Terraform` workflow via `workflow_dispatch` (`plan`) and confirm it authenticates and plans without error.
4. Revoke / delete the old token.
5. Record the rotation in the table below.

## Rotation record

| Date | Expires | Note |
| --- | --- | --- |
| 2026-07-21 | 2026-10-19 | Initial issue (bootstrap) |
