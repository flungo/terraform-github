# Runbook: Adopt an existing repository into Terraform

Bring a repository that already exists on GitHub under Terraform management, with the divergence from the live repo reviewed on the PR **before** anything is applied.

Repositories are managed through the standard-repository composite ([`modules/standard-repository`](../../modules/standard-repository)); an adoption pairs a module call with an `import {}` block that targets the composite's internal repository resource.
Only the repository itself is imported — the branch-protection ruleset (two, where the repo declares `release_branches`) and shared secrets are **created** by the same apply (they are additions, not adoptions; a pre-existing *classic* protection rule fails the plan via the guard — see [`migrating-classic-protection-to-ruleset.md`](migrating-classic-protection-to-ruleset.md)).

## Prerequisites

- The owner directory (`owners/<login>/`) exists with its backend, provider, and `github_token` variable.
- The owner's GitHub token secret (`<OWNER>_GITHUB_TOKEN`, e.g. `FLUNGO_GITHUB_TOKEN`) and `TF_TOKEN_APP_TERRAFORM_IO` are set for the `Terraform` workflow.

## Procedure

1. **Add config in a PR.** In the repo's own file `owners/<login>/<repo>.tf` (each repo's config lives in one by-subject file named for it — create it if new), add a module call and an `import {}` block targeting its internal resource address:

   ```hcl
   import {
     to = module.<name>.module.repository.github_repository.this
     id = "<repo-name>" # import ID is the repo name; owner comes from the provider
   }

   module "<name>" {
     source = "../../modules/standard-repository"

     name        = "<repo-name>"
     description = "<live description>"
     visibility  = "<public|private>" # match the live repo
     # topics as needed; the module supplies the standard toggles and merge strategy
     # terraform = true for a repo holding Terraform config
     # release_branches = {…} ONLY for a repo publishing a moving branch consumers
     #   pin — see creating-repositories.md question 9 (ADR-007/ADR-008)
     # manage_secrets = false ONLY for the self-referential case (terraform-github
     # itself — its CI-gating tokens stay manually managed; ADR-005)

     shared_secrets = local.shared_secrets
   }
   ```

2. **Let CI post the plan.** The `Terraform` workflow runs `terraform plan` against the live repo and posts it as a PR comment — showing the adoption plus every attribute where the config (module baseline + inputs) diverges from the live repository, and the composite's additions (the protection ruleset — two with `release_branches` — and shared secret(s)).

3. **Iterate to a clean import.** Adjust the inputs from the posted plan until the only remaining changes are *intended* ones.
   Match identity attributes (`visibility`, `description`, `topics`) to the **live** values.
   Where the live repo deviates from the module's encoded baseline (e.g. Projects enabled), decide per repo: **standardise** it (accept the module baseline — the plan will show that change) or **preserve** the deviation (which requires adding a module input, on the user's explicit confirmation; see [`../reference/standard-repository.md`](../reference/standard-repository.md)).
   The target is **no unexpected difference** — the adoption itself plus only the changes you meant to make.

   > **🤖 Agent** — Keep the repository's existing topics by default.
   > If it has none, or they are sparse, propose a few well-chosen topics from the [topics glossary](../reference/topics.md) for the user to confirm — adoption is a good moment to improve topic consistency across the fleet.

4. **Merge → apply.** Merging runs `terraform apply`: the resource is imported into state under the module address and any intended changes are made.

5. **Remove the import block.** In a follow-up PR, delete the `import {}` block once the adopting apply has run — the module call stays managing the repository.
   (The import-block convention; see [Terraform conventions](../reference/terraform-conventions.md).)

## Why not generate the config blind

Do not hand-write the inputs from guessed settings and apply them — a wrong attribute (e.g. `visibility`) would mutate the live repo.
The PR-posted plan is the safe feedback loop: it surfaces the true divergence so it can be reconciled before any apply.
