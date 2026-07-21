# Runbook: Adopt an existing repository into Terraform

Bring a repository that already exists on GitHub under Terraform management, with the divergence from the live repo reviewed on the PR **before** anything is applied.

## Prerequisites

- The owner directory (`owners/<login>/`) exists with its backend, provider, and `github_token` variable.
- The owner's GitHub token secret (`<OWNER>_GITHUB_TOKEN`, e.g. `FLUNGO_GITHUB_TOKEN`) and `TF_TOKEN_APP_TERRAFORM_IO` are set for the `Terraform` workflow.

## Procedure

1. **Add config in a PR.** In `owners/<login>/repositories.tf`, add an `import {}` block and a first-pass `github_repository` resource with the standard settings:

   ```hcl
   import {
     to = github_repository.<name>
     id = "<repo-name>" # import ID is the repo name; owner comes from the provider
   }

   resource "github_repository" "<name>" {
     name = "<repo-name>"
     # standard settings — visibility, merge strategy, feature toggles, …
   }
   ```

2. **Let CI post the plan.** The `Terraform` workflow runs `terraform plan` against the live repo and posts it as a PR comment — showing the adoption plus every attribute where the config diverges from the live repository.

3. **Iterate to a clean import.** Adjust the resource from the posted plan until the only remaining changes are *intended* ones. Match identity attributes (`visibility`, `description`, `topics`) to the **live** values; apply the opinionated standard settings deliberately. The target is **no substantive or unexpected difference** — the adoption itself plus only the changes you meant to make.

4. **Merge → apply.** Merging runs `terraform apply`: the resource is imported into state and any intended changes are made.

5. **Remove the import block.** In a follow-up PR, delete the `import {}` block once the adopting apply has run — the resource stays managed by its config. (The import-block convention; see `CLAUDE.md` § Terraform conventions.)

## Why not generate the config blind

Do not hand-write the resource from guessed settings and apply it — a wrong attribute (e.g. `visibility`) would mutate the live repo. The PR-posted plan is the safe feedback loop: it surfaces the true divergence so it can be reconciled before any apply.
