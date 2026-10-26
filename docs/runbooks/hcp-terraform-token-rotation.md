# Runbook: Rotate the HCP Terraform token

Rotate the HCP Terraform Owners-team token that authenticates every owner workspace's state backend, before it expires.

This repo is the **source of truth** for the token's value.
It lives in this repo's `TF_TOKEN_APP_TERRAFORM_IO` Actions secret, and the [`repository-secrets`](../../modules/repository-secrets) module writes the same value into the `TF_TOKEN_APP_TERRAFORM_IO` secret of every managed repository with `terraform = true`.
So a rotation updates **only this repo's secret**, and an apply copies it out.
Updating a managed repository's copy by hand is overwritten by the next apply here.

## Token

| Field | Value |
| --- | --- |
| Type | HCP Terraform **team token**, team `owners`, organisation `flungo` |
| Description | `github` |
| Actions secret | `TF_TOKEN_APP_TERRAFORM_IO` (repo secret) → the backend credential, and `TF_VAR_hcp_token` via `tf_secret_vars` |
| Expiry | 90 days |
| Expiry notices | HCP Terraform emails 30 and 7 days before expiry |

## Rotation procedure

1. In [app.terraform.io](https://app.terraform.io) → `flungo` → **Settings → API Tokens → [Team tokens](https://app.terraform.io/app/flungo/settings/authentication-tokens?tabIndex=1)**, click **Create a team token** with **Team** `owners`, **Description** `github`, **Expiration** 90 days.
   Copy the value immediately; it is not shown again.
2. Update this repo's **`TF_TOKEN_APP_TERRAFORM_IO`** repository secret (**Settings → Secrets and variables → [Actions](https://github.com/flungo/terraform-github/settings/secrets/actions)**) with the new value.
3. Trigger the [`Terraform`](https://github.com/flungo/terraform-github/actions/workflows/terraform.yml) workflow (**Actions → Terraform → Run workflow**) with `plan`.
   It must initialise against HCP, and its only planned changes should be the `github_actions_secret.hcp_token` updates for the managed `terraform = true` repositories.
4. Trigger it again with `apply`, so the managed repositories receive the new value.
5. Delete the old token in HCP, on the same **[Team tokens](https://app.terraform.io/app/flungo/settings/authentication-tokens?tabIndex=1)** page.
6. Record the rotation in the table below.

## Recovery: token already expired

The fix is the same procedure.
Until it runs, every workspace that uses the token fails at `terraform init` with `Failed to read organization "flungo" … unauthorized`, this repo's included, so the apply in step 4 is what restores the managed repositories' CI as well.

## Rotation record

| Date | Expires | Note |
| --- | --- | --- |
| 2026-10-25 | 2027-01-23 | Rotated after expiry (2026-10-20); replaced the previous `github` and `grafana-cloud` tokens, both deleted, with one token |
