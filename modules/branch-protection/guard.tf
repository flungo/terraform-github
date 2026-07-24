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
#
# The data source exposes only each rule's `pattern` (not its settings), so the
# error names the offending pattern(s) but can't compare them. The CI plan job
# fills that gap: on this postcondition failing it fetches the repo's full classic
# settings via GraphQL and prints them, so the migration can compare before
# removing. See .github/workflows/terraform.yml and
# docs/runbooks/migrating-classic-protection-to-ruleset.md.
data "github_branch_protection_rules" "this" {
  repository = var.repository

  lifecycle {
    postcondition {
      condition     = length(self.rules) == 0
      error_message = "${var.repository} has classic branch protection rule(s) matching [${join(", ", [for r in self.rules : r.pattern])}]; rulesets and classic protection double-enforce, so the classic rule must go. The failed plan surfaces its settings — compare against the ruleset and migrate per docs/runbooks/migrating-classic-protection-to-ruleset.md, then remove it in the repository's Settings → Branches."
    }
  }
}
