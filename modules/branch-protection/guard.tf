# Assert the repository carries no *classic* branch protection rules
# (github_branch_protection / the repo's "Branches" settings). This fleet
# protects default branches with rulesets (see ADR-004); a lingering classic
# rule would double-enforce against the ruleset and is almost always an
# unmanaged left-over from before the repo was onboarded.
#
# This is a read-only guard: Terraform cannot delete a resource it does not
# manage, so the data source reads the live classic rules and the postcondition
# fails the plan if any exist — surfacing the drift so it can be removed by hand
# (repo Settings → Branches) rather than silently coexisting with the ruleset.
data "github_branch_protection_rules" "this" {
  repository = var.repository

  lifecycle {
    postcondition {
      condition     = length(self.rules) == 0
      error_message = "${var.repository} has classic branch protection rule(s); this fleet protects branches with rulesets. Remove the classic rule(s) in the repository's Settings → Branches."
    }
  }
}
