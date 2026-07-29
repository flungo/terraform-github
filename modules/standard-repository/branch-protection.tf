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
