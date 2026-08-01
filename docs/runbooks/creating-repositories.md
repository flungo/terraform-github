# Runbook: Create a new repository with Terraform

Bring a **new** repository into existence by declaring it in Terraform — the apply creates it.
Contrast [`importing-repositories.md`](importing-repositories.md), which *adopts* a repository that already exists on GitHub.
A create needs **no `import {}` block**: there is no live repository to reconcile against, so the module call is written directly and the plan is a pure addition.

Repositories are managed through the standard-repository composite ([`modules/standard-repository`](../../modules/standard-repository)); a create is a new call to it.
The module supplies the standard feature toggles and merge strategy, protects the default branch (and release branches, where the repo declares them), and attaches the shared Actions secrets — you provide only the per-repo inputs.

## Questions to answer first

Settle these before writing the module call — most map straight onto a module input.

> **🤖 Agent** — Don't ask these cold.
> Where the task gives you enough context to propose a sensible answer — or where a standard default applies (`visibility` defaults to private, `auto_init` to true) — suggest it and ask the human to confirm; ask open-endedly only where you genuinely can't infer.
> Work down the list, then confirm the full set before writing the module call.

1. **Owner** — which account owns it, i.e. which `owners/<login>/` directory?
   (Personal `flungo`, or an organisation.)
2. **Name** — the exact repository name.
   It becomes the `name` input, and the module call's local name with any character invalid in a Terraform identifier replaced by `_` (e.g. `my.repo` → `module "my_repo"`; see [Terraform conventions](../reference/terraform-conventions.md)).
3. **Visibility** — `public` or `private`?
   Standard is private; go public only when it must be readable/callable by others (e.g. hosting reusable workflows that private repos call).
4. **Description** — the one-line repository description.
5. **Topics** — any topics to set (optional; safe to include).
   Prefer topics from the [topics glossary](../reference/topics.md) so they stay consistent across the fleet.
6. **Initialise now?** — `auto_init` (default `true`) seeds an initial commit with a placeholder `README.md` (the repo name and description) so a default branch (`main`) exists up front — suits populating via the usual branch + PR flow.
   Set it `false` for an empty repo whose first bulk push establishes `main`.
7. **Terraform repo?** — `terraform = true` marks a repo that holds Terraform config, which attaches the HCP token secret so it can plan/apply in its own CI (the value comes from the owner-level `shared_secrets`).
8. **Required status checks** — check contexts that must pass before merging, if the repo's CI is already known (they can be added later once the checks run; a context that never runs blocks merges behind a perpetual "Expected" entry).
9. **Release branches?** — `release_branches` protects a repo's release branches with a second ruleset.
   Only for repos that publish a moving branch consumers pin (today: `github-workflows` and its `v*` majors); leave it unset otherwise.
   It needs the ref `pattern` (fnmatch, e.g. `"refs/heads/v[0-9]*"`) and `push_bypass_app_ids`, the numeric IDs of the GitHub Apps allowed to push a matching branch **directly** — annotate each with a comment naming the App.
   Those Apps become the only actors that may push directly or **create** one; everyone else still lands changes via a PR, which stays open by design.
   So this suits a repo whose release branches are cut by a workflow rather than by hand.
   Note `required_status_checks` is deliberately *not* applied to the release ruleset — the contexts you list are chosen for PRs into the default branch.
   See [ADR-007](../decisions/007-release-branch-protection.md) and [ADR-008](../decisions/008-restrict-release-branch-creation.md).
10. **Standard deviations** — the module encodes the baseline (issues on; wiki/projects/downloads off; merge commits off, squash + rebase on, delete-branch-on-merge on; the standard protection rules).
    You do **not** set these per repo.
    If the repo genuinely needs to deviate, that requires adding a module input and the human's explicit confirmation that the deviation must be supported (see [`../reference/standard-repository.md`](../reference/standard-repository.md)).

## Prerequisites

- **The repository does not already exist on GitHub.** Check before you start (`https://github.com/<owner>/<repo>`).
  If it does, stop — this is an *adoption*, and the procedure is [`importing-repositories.md`](importing-repositories.md), which pairs the module call with an `import {}` block so Terraform takes over the live repository instead of trying to make a new one.

  > **What happens if you get this wrong?** It fails, and fails safely.
  > With no state entry and no `import {}` block Terraform plans a **create**, and GitHub rejects a duplicate name when the apply runs — so the apply errors having changed nothing.
  > Terraform cannot silently adopt or overwrite an existing repository: taking over an existing resource always requires an explicit import.
  > The cost is a wasted merge-and-apply cycle, not damage.
  > And if the existing repository carries classic branch protection, leaving `repository_exists` at its default catches the mistake one step earlier still — the guard fails the *plan*.

- The owner directory (`owners/<login>/`) exists with its backend, provider, and `github_token` variable.
- The owner's GitHub token secret (`<OWNER>_GITHUB_TOKEN`, e.g. `FLUNGO_GITHUB_TOKEN`) and `TF_TOKEN_APP_TERRAFORM_IO` are set for the `Terraform` workflow, and the token can create repositories (Administration: read/write) for the owner.

## Procedure

1. **Add config in a PR.** In a new file `owners/<login>/<repo>.tf` (each repo's config lives in one by-subject file named for it), add a module call with the answers above — and **no `import {}` block**:

   ```hcl
   module "<name>" {
     source = "../../modules/standard-repository"

     name        = "<repo-name>"
     description = "<one-line description>"
     topics      = ["<topic>", …]

     visibility = "<public|private>"
     # auto_init defaults to true (seeds main); add auto_init = false for an empty repo
     # terraform = true for a repo holding Terraform config
     # release_branches = { pattern = "refs/heads/v[0-9]*", push_bypass_app_ids = [<id>] }
     #   ONLY for a repo publishing a moving branch consumers pin (ADR-007/ADR-008)

     # Transient: removed in step 4, once the creating apply has run.
     repository_exists = false

     shared_secrets = local.shared_secrets
   }
   ```

   `repository_exists = false` skips the classic-protection guard, which queries the live repository and would otherwise fail the plan with `Could not resolve to a Repository` — there is nothing to query yet.
   Nothing is lost: a repository that does not exist cannot carry classic protection.
   It is transient, exactly like the `import {}` block an adoption carries and then drops ([ADR-009](../decisions/009-plan-time-classic-protection-guard.md)).

2. **Let CI post the plan.** The `Terraform` workflow runs `terraform plan` and posts it as a PR comment.
   Confirm the additions are exactly the composite's resources for this repo — `module.<name>.module.repository.github_repository.this`, the `module.<name>.module.branch_protection` ruleset, the `module.<name>.module.secrets[0]` secret(s) (`LYCHEE_GITHUB_TOKEN`, plus the HCP token when `terraform = true`), and — only when `release_branches` is set — a second ruleset at `module.<name>.module.release_branch_protection[0]` — with **`0 to change, 0 to destroy`**; a create must not touch anything else.
   Check the attributes (`visibility`, `auto_init`, feature toggles, topics) match the answers.

3. **Merge → apply.** Merging runs `terraform apply`, which creates the repository.

4. **Remove `repository_exists = false`.** In a follow-up PR, once the creating apply has run — the repository now exists, so the guard can and should run against it.
   Its plan should be **no changes**, which also confirms the create landed cleanly.
   Leaving the flag in place silently disables the classic-protection guard for that repository from then on, so this step is not optional.
   (This mirrors the adoption runbook's removal of the applied `import {}` block.)

5. **Populate the repository.** Add its content (workflows, docs, code) via the usual branch + PR flow.
   With `auto_init = true` the default branch already exists to branch from (replace the seeded placeholder README in that first change); with an empty repo, the first push establishes `main`.

## Why a create is safe without a plan-reconcile loop

Importing carries the risk that a wrong attribute (e.g. `visibility`) *mutates* a live repository, which is why that runbook iterates on the posted plan before applying.
A create has no live repository to mutate, so the only checks that matter are that the plan is a **pure addition** (`0 to change, 0 to destroy`) and that the attributes are what you intend — both visible on the PR-posted plan before merge.
