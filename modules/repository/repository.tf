# The standard repository. The opinionated baseline below is deliberately not
# exposed as inputs — change it here to roll the new standard out to every repo on
# the next apply. Per-repo variation comes in through the small input set in
# variables.tf. See docs/reference/standard-repository.md for the catalogue and the
# rule for growing the input surface (standard first; add an input for a deviation
# only when the user confirms it must be supported).
resource "github_repository" "this" {
  name        = var.name
  description = var.description
  topics      = var.topics

  visibility = var.visibility
  auto_init  = var.auto_init

  # Standard feature toggles: issues on; wiki, projects, and downloads off.
  # GitHub deprecated the Downloads feature — has_downloads = true does not persist
  # (the API reports it back as false), so the baseline is off to avoid a perpetual
  # plan diff.
  has_issues    = true
  has_wiki      = false
  has_projects  = false
  has_downloads = false

  # Standard merge strategy: merge commits off; squash and rebase on; branches
  # deleted on merge (keeps a linear history and a tidy branch list).
  allow_merge_commit     = false
  allow_squash_merge     = true
  allow_rebase_merge     = true
  delete_branch_on_merge = true

  # Squash commit message: take the subject from the pull request title and the
  # body from its description. With Conventional Commits enforced on PR titles,
  # the PR title *is* the commit subject, so the provider's defaults
  # (COMMIT_OR_PR_TITLE / COMMIT_MESSAGES) would splice the branch's working
  # commit messages into main's history instead.
  squash_merge_commit_title   = "PR_TITLE"
  squash_merge_commit_message = "PR_BODY"

  # Off: branches are brought up to date by rebasing, which keeps the linear
  # history the ruleset requires.
  allow_update_branch = false

  # auto_init only takes effect when the repository is created; ignore later drift
  # so an already-created repo never shows a spurious diff for it.
  lifecycle {
    ignore_changes = [auto_init]
  }
}
