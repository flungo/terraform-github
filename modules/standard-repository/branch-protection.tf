# Standard protection for the repository's default branch — applied to every
# repo, not gated on any flag. The pattern is left at the primitive's
# "~DEFAULT_BRANCH" default, so the composite never needs to know the branch
# name.
#
# Required checks are assembled in three parts: the contexts implied by the
# standards flags, plus the caller's additional ones, minus any the caller
# excludes. Flags imply checks because adopting a standard means adopting the
# workflow that reports it — see
# docs/decisions/010-terraform-flag-means-terraform-standards.md.
#
# excluded_status_checks is the escape hatch for a repo that legitimately takes
# a flag's other effects but cannot report its check. Removing the context is
# preferable to a per-flag opt-out: it generalises to any future flag/check
# conflict without growing a matching boolean each time. It only ever applies to
# a context a flag implies — a variable validation rejects one that also appears
# in required_status_checks, since adding and then removing a context is the
# same as never adding it.
#
# "terraform / terraform" is <caller job id> / <reusable job id>. The reusable
# half is fixed by flungo/github-workflows; the caller half is whatever the repo
# names its job — which is why the standards require that name. A repo that
# adopts the workflow under a different job name reports a different context and
# would block its own merges behind a perpetual "Expected" entry.
module "branch_protection" {
  source = "../branch-protection"

  repository = module.repository.name
  strict     = var.strict

  required_status_checks = tolist(setsubtract(
    concat(
      var.terraform ? ["terraform / terraform"] : [],
      var.required_status_checks,
    ),
    var.excluded_status_checks,
  ))
}

# Release-branch protection — a second ruleset, created only where the repo
# declares release branches. Same standard rules as the default branch, plus
# an "always" bypass for the release automation's GitHub App(s): the branches
# move only by that automation's push (a release workflow's fast-forward) or a
# merged PR — never a direct human/agent push. Required status checks are not
# passed: the caller's contexts are chosen for PRs into the default branch,
# and a context that never runs on a PR into a release branch would block its
# merges behind a perpetual "Expected" entry. First case: github-workflows'
# moving-major v* branches. See docs/decisions/007-release-branch-protection.md.
#
# Creation is restricted to the same Apps, not exposed as a knob: release
# branches are cut by the release automation, never by hand, so a stray or
# mistyped one is a mistake worth rejecting outright. Without it the deletion
# rule would hold that mistake permanently — a human cannot delete a matching
# ref, since the admin bypass is pull-request-scoped and does not cover
# deletion. It is also what lets the caller's pattern be a deliberately broad
# glob: nobody can create the extra refs it reaches onto, so over-reach costs
# nothing, while a narrower pattern risks silently missing a real release
# branch. See docs/decisions/008-restrict-release-branch-creation.md.
module "release_branch_protection" {
  count  = var.release_branches == null ? 0 : 1
  source = "../branch-protection"

  repository          = module.repository.name
  name                = "release"
  pattern             = var.release_branches.pattern
  strict              = var.strict
  push_bypass_app_ids = var.release_branches.push_bypass_app_ids
  restrict_creation   = true
}
