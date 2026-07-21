# Runbook: Onboard an owner

Bring a new **owner account** (the personal account, or an organisation) under management: create its directory and credential, let CI create its workspace and post the plan, then adopt its repositories.

## Prerequisites

- The HCP **`terraform-github` project** exists with **default execution mode = Local**. This is a one-time setup, established when the first owner was onboarded; assume it is done for subsequent owners. (The `project` argument in the cloud block would create the project on first `init`, but the *execution-mode default* is a project setting configured once in HCP.)

## Procedure

1. **Create the owner directory** `owners/<login>/` (thin — no per-owner prose in the `.tf` comments):
   - `terraform.tf` — cloud backend bound to workspace `github-<login>` in the `terraform-github` project, `integrations/github ~> 6.0`, `required_version >= 1.9`.
   - `providers.tf` — `provider "github" { owner = "<login>" token = var.github_token }`.
   - `variables.tf` — `github_token` (sensitive).

   ```hcl
   # owners/<login>/terraform.tf
   terraform {
     cloud {
       organization = "flungo"
       workspaces {
         name    = "github-<login>"
         project = "terraform-github"
       }
     }
     required_providers {
       github = { source = "integrations/github", version = "~> 6.0" }
     }
     required_version = ">= 1.9"
   }
   ```

2. **Create the owner's token and wire it in.** A fine-grained PAT for `<login>`, **all repositories**, with **Administration: Read and write** + **Metadata: Read-only** (add more as scope grows — see [`github-provider-token-rotation.md`](github-provider-token-rotation.md)). Store it as the `<OWNER>_GITHUB_TOKEN` Actions secret and reference it as `TF_VAR_github_token` for this owner in `.github/workflows/terraform.yml`.

3. **Open the PR.** CI's plan job runs `terraform init`, which **auto-creates** the `github-<login>` workspace in the `terraform-github` project (inheriting Local execution), then posts the plan on the PR — no manual `init` or workspace creation.

4. **Adopt the owner's repositories** — follow [`importing-repositories.md`](importing-repositories.md) for each existing repo (import block reconciled against the PR-posted plan → clean import), in this PR or follow-ups.

## Notes

- **Organisation owners** additionally have org-level resources a user account does not (org Actions secrets, teams/membership). Those are onboarded as the corresponding modules/resources land.
- **CI** currently targets `owners/flungo` directly; add the new owner to `.github/workflows/terraform.yml` (step 2), and — once there is more than one — generalise it to a matrix over `owners/*` with per-owner secrets (the GitHub Environments follow-up).
- The **bootstrap** GitHub credential is a PAT; the intended end state is a GitHub App that mints per-owner tokens from one key (its own future ADR).
