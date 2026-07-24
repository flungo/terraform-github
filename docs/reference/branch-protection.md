# Standard branch protection

The [`modules/branch-protection`](../../modules/branch-protection) module protects a
repository's default branch with a `github_repository_ruleset` (see
[ADR-004](../decisions/004-branch-protection-rulesets.md) for the ruleset-over-branch-protection
choice). This page catalogues the rules it encodes and the inputs it exposes.

To change the standard fleet-wide, edit the module in one place — not each owner
directory — then re-apply each owner to roll the change out.

## Encoded rules (not configurable)

The ruleset is `target = "branch"`, `enforcement = "active"`, and applies these rules:

| Rule | Value | Why |
|---|---|---|
| Pull request required | yes, `required_approving_review_count = 0` | Changes go through a PR, but no approval is required — the owner works solo, so requiring one would block their own PRs. |
| Conversation resolution | `required_review_thread_resolution = true` | Review threads must be resolved before merge. |
| Linear history | `required_linear_history = true` | No merge commits. |
| Restrict deletion | `deletion = true` | A protected branch must not be deletable (only bypass actors may). GitHub blocks deleting the default branch anyway, but the module protects any branch, so this doesn't rely on that. |

## Per-repo inputs (configurable)

| Input | Type | Default | Notes |
|---|---|---|---|
| `repository` | `string` | — (required) | Repository name to protect. |
| `pattern` | `string` | `"~DEFAULT_BRANCH"` | Ref the ruleset targets; the module protects any branch, so it takes a pattern rather than assuming `main`. |
| `strict` | `bool` | `false` | When `true`, removes the admin bypass entirely so the rules bind everyone. When `false`, admins keep a deliberate, PR-scoped bypass (override within a pull request); the rules still apply by default and admins cannot push straight to the branch. |
| `required_status_checks` | `list(string)` | `[]` | Check contexts that must pass before merging. Empty enforces none — GitHub has no "require all checks" option, and a context is only selectable once it has run on the protected branch. |

## Bypass

While `strict = false`, the built-in **Admin** repository role (`actor_id = 5`,
`actor_type = "RepositoryRole"`) gets a **`pull_request`** bypass — an admin may
merge a pull request that doesn't meet the rules, but the rules still apply by
default and direct pushes to the branch stay blocked even for admins. The bypass is
a deliberate action, never automatic. Setting `strict = true` drops the bypass block
entirely, binding everyone.

## Classic-protection guard

GitHub applies rulesets and classic branch protection (`github_branch_protection`,
the repo's Settings → Branches) *both at once* — a repo can carry both and they
double-enforce. To stop a legacy classic rule silently coexisting with the ruleset,
the module reads the repo's classic rules with the `github_branch_protection_rules`
data source and a `postcondition` fails the plan if any exist.

The guard is **read-only and unconditional** — it runs on every repo the module
protects, regardless of `strict`. Terraform can't delete a resource it doesn't
manage, so the guard surfaces the drift rather than reconciling it: clear the classic
rule by hand in the repository's Settings → Branches, then re-plan.

The data source exposes only each rule's `pattern`, not its settings — so on a guard
failure the CI plan job (`.github/workflows/terraform.yml`) fetches the repo's full
classic settings via GraphQL and prints them to the run summary and log. That is the
read side of the migration: compare the classic settings against the ruleset before
removing the classic rule. The full procedure is
[`docs/runbooks/migrating-classic-protection-to-ruleset.md`](../runbooks/migrating-classic-protection-to-ruleset.md).
