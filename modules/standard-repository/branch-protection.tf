# Standard protection for the repository's default branch — applied to every
# repo, not gated on any flag. The pattern is left at the primitive's
# "~DEFAULT_BRANCH" default, so the composite never needs to know the branch
# name.
#
# The terraform flag deliberately does NOT add a Terraform plan check context
# here (the plan's original intent): a required context that a repo's CI never
# reports blocks its merges behind a perpetual "Expected" entry, and the fleet's
# Terraform repos do not yet uniformly run a plan check (authentik.flungo.net
# has no Terraform workflow at all). Callers list contexts their CI actually
# reports via required_status_checks; wiring the flag to append the
# conventional context is revisited once Terraform CI is standardised across
# the fleet. See docs/decisions/006-standard-repository-composite.md.
module "branch_protection" {
  source = "../branch-protection"

  repository             = module.repository.name
  strict                 = var.strict
  required_status_checks = var.required_status_checks
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
