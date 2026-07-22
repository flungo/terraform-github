# Runbook: Create a new repository with Terraform

Bring a **new** repository into existence by declaring it in Terraform — the apply creates it. Contrast [`importing-repositories.md`](importing-repositories.md), which *adopts* a repository that already exists on GitHub. A create needs **no `import {}` block**: there is no live repository to reconcile against, so the module call is written directly and the plan is a pure addition.

Repositories are managed through the shared standard repository module ([`modules/repository`](../../modules/repository)); a create is a new call to it. The module supplies the standard feature toggles and merge strategy — you provide only the per-repo inputs.

## Questions to answer first

Settle these before writing the module call — most map straight onto a module input.

> **🤖 Agent** — Don't ask these cold. Where the task gives you enough context to propose a sensible answer — or where a standard default applies (`visibility` defaults to private, `auto_init` to true) — suggest it and ask the human to confirm; ask open-endedly only where you genuinely can't infer. Work down the list, then confirm the full set before writing the module call.

1. **Owner** — which account owns it, i.e. which `owners/<login>/` directory? (Personal `flungo`, or an organisation.)
2. **Name** — the exact repository name. It becomes the `name` input, and the module call's local name with any character invalid in a Terraform identifier replaced by `_` (e.g. `my.repo` → `module "my_repo"`; see [Terraform conventions](../reference/terraform-conventions.md)).
3. **Visibility** — `public` or `private`? Standard is private; go public only when it must be readable/callable by others (e.g. hosting reusable workflows that private repos call).
4. **Description** — the one-line repository description.
5. **Topics** — any topics to set (optional; safe to include). Prefer topics from the [topics glossary](../reference/topics.md) so they stay consistent across the fleet.
6. **Initialise now?** — `auto_init` (default `true`) seeds an initial commit with a placeholder `README.md` (the repo name and description) so a default branch (`main`) exists up front — suits populating via the usual branch + PR flow. Set it `false` for an empty repo whose first bulk push establishes `main`.
7. **Standard deviations** — the module encodes the baseline (issues on; wiki/projects/downloads off; merge commits off, squash + rebase on, delete-branch-on-merge on). You do **not** set these per repo. If the repo genuinely needs to deviate, that requires adding a module input and the human's explicit confirmation that the deviation must be supported (see [`../reference/standard-repository.md`](../reference/standard-repository.md)).

## Prerequisites

- The owner directory (`owners/<login>/`) exists with its backend, provider, and `github_token` variable.
- The owner's GitHub token secret (`<OWNER>_GITHUB_TOKEN`, e.g. `FLUNGO_GITHUB_TOKEN`) and `TF_TOKEN_APP_TERRAFORM_IO` are set for the `Terraform` workflow, and the token can create repositories (Administration: read/write) for the owner.

## Procedure

1. **Add config in a PR.** In `owners/<login>/repositories.tf`, add a module call with the answers above — and **no `import {}` block**:

   ```hcl
   module "<name>" {
     source = "../../modules/repository"

     name        = "<repo-name>"
     description = "<one-line description>"
     topics      = ["<topic>", …]

     visibility = "<public|private>"
     # auto_init defaults to true (seeds main); add auto_init = false for an empty repo
   }
   ```

2. **Let CI post the plan.** The `Terraform` workflow runs `terraform plan` and posts it as a PR comment. Confirm it reads **`1 to add, 0 to change, 0 to destroy`** and that the only resource is `module.<name>.github_repository.this` — a create must not change or destroy anything else. Check the attributes (`visibility`, `auto_init`, feature toggles, topics) match the answers.

3. **Merge → apply.** Merging runs `terraform apply`, which creates the repository. There is no import block to remove afterwards.

4. **Populate the repository.** Add its content (workflows, docs, code) via the usual branch + PR flow. With `auto_init = true` the default branch already exists to branch from (replace the seeded placeholder README in that first change); with an empty repo, the first push establishes `main`.

## Why a create is safe without a plan-reconcile loop

Importing carries the risk that a wrong attribute (e.g. `visibility`) *mutates* a live repository, which is why that runbook iterates on the posted plan before applying. A create has no live repository to mutate, so the only checks that matter are that the plan is a **pure addition** (`0 to change, 0 to destroy`) and that the attributes are what you intend — both visible on the PR-posted plan before merge.
