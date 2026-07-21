# Runbook: Create a new repository with Terraform

Bring a **new** repository into existence by declaring it in Terraform — the apply creates it. Contrast [`importing-repositories.md`](importing-repositories.md), which *adopts* a repository that already exists on GitHub. A create needs **no `import {}` block**: there is no live repository to reconcile against, so the resource is written directly and the plan is a pure addition.

## Questions to answer first

Settle these before writing the resource — the answers map straight onto `github_repository` arguments.

> **🤖 Agent** — Don't ask these cold. Where the task gives you enough context to propose a sensible answer — or where a standard default applies (visibility, `auto_init`, feature toggles, merge strategy) — suggest it and ask the human to confirm; ask open-endedly only where you genuinely can't infer. Work down the list, then confirm the full set before writing the resource.

1. **Owner** — which account owns it, i.e. which `owners/<login>/` directory? (Personal `flungo`, or an organisation.)
2. **Name** — the exact repository name. It becomes `name`, and the resource's local name with any character invalid in a Terraform identifier replaced by `_` (e.g. `my.repo` → `github_repository.my_repo`; see `CLAUDE.md` § Terraform conventions).
3. **Visibility** — `public` or `private`? (Public when it must be readable/callable by others — e.g. hosting reusable workflows that private repos call — otherwise private.)
4. **Description** — the one-line repository description.
5. **Topics** — any topics to set (optional; safe to include).
6. **Initialise now?** — with `auto_init = true`, GitHub seeds an initial commit containing a `README.md` (the repo name as a heading and the description as body — plus a `.gitignore`/licence only if `gitignore_template`/`license_template` are set, which the standard does not) so a default branch (`main`) exists up front. Leave it `false` for an empty repo whose first push establishes `main`. `auto_init = true` suits populating via the usual branch + PR flow (the seeded README is a placeholder to replace); an empty repo suits an initial bulk push.
7. **Feature toggles** — issues, wiki, projects, downloads. The standard baseline is issues on, wiki and projects off, downloads on. Confirm any deviation.
8. **Merge strategy / standard deviations** — the standard is merge commits off, squash + rebase on, delete-branch-on-merge on. Per `CLAUDE.md` § Terraform conventions, a repo is brought to the standard by default; support a deviation only when the human explicitly confirms it must be supported.

## Prerequisites

- The owner directory (`owners/<login>/`) exists with its backend, provider, and `github_token` variable.
- The owner's GitHub token secret (`<OWNER>_GITHUB_TOKEN`, e.g. `FLUNGO_GITHUB_TOKEN`) and `TF_TOKEN_APP_TERRAFORM_IO` are set for the `Terraform` workflow, and the token can create repositories (Administration: read/write) for the owner.

## Procedure

1. **Add config in a PR.** In `owners/<login>/repositories.tf`, add a `github_repository` resource with the answers above — and **no `import {}` block**:

   ```hcl
   resource "github_repository" "<name>" {
     name        = "<repo-name>"
     description = "<one-line description>"
     topics      = ["<topic>", …]

     visibility = "<public|private>"
     auto_init  = true # GitHub seeds a README (repo name + description) so main exists; false = empty repo

     has_issues             = true
     has_wiki               = false
     has_projects           = false
     has_downloads          = true
     allow_merge_commit     = false
     allow_squash_merge     = true
     allow_rebase_merge     = true
     delete_branch_on_merge = true
   }
   ```

2. **Let CI post the plan.** The `Terraform` workflow runs `terraform plan` and posts it as a PR comment. Confirm it reads **`1 to add, 0 to change, 0 to destroy`** and that the only resource is the one you are creating — a create must not change or destroy anything else. Check the attributes (`visibility`, `auto_init`, feature toggles, topics) match the answers.

3. **Merge → apply.** Merging runs `terraform apply`, which creates the repository. There is no import block to remove afterwards.

4. **Populate the repository.** Add its content (workflows, docs, code) via the usual branch + PR flow. With `auto_init = true` the default branch already exists to branch from (replace the seeded placeholder README in that first change); with an empty repo, the first push establishes `main`.

## Why a create is safe without a plan-reconcile loop

Importing carries the risk that a wrong attribute (e.g. `visibility`) *mutates* a live repository, which is why that runbook iterates on the posted plan before applying. A create has no live repository to mutate, so the only checks that matter are that the plan is a **pure addition** (`0 to change, 0 to destroy`) and that the attributes are what you intend — both visible on the PR-posted plan before merge.
