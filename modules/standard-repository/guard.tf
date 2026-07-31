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
# error names the offending pattern(s) but can't compare them. When the guard fails
# a plan, the CI `surface-classic-protection` job reads the plan artifact and fetches
# the full classic settings via GraphQL for the field-by-field comparison — see
# .github/workflows/terraform.yml and
# docs/runbooks/migrating-classic-protection-to-ruleset.md.
#
# It reads var.name, NOT module.repository.name, and that is load-bearing.
# Terraform defers a data source whose configuration depends on a resource with
# pending changes, and an *adoption* always leaves the repository resource
# pending — so sourcing the name from the resource deferred this read to apply,
# in exactly the case the guard exists for. Worse, a postcondition evaluated
# during apply runs after the resources it depends on, so the rulesets were
# already created by the time it failed: the guard reported double enforcement
# instead of preventing it. var.name is known at plan time, so the guard fails
# the plan before anything is applied.
#
# It also lives here rather than in the branch-protection primitive because the
# question it asks — does this repository carry classic protection at all? — is
# scoped to the repository, not to any one ruleset. The data source returns every
# classic rule the repo has in a single read, however many there are, so asking
# once per ruleset issues an identical query and gets an identical answer. In the
# primitive a repo with release branches ran the guard twice for no added cover.
#
# It is skipped entirely while repository_exists = false, the transient flag a
# brand-new repository carries for its creating change. The data source queries
# the live repository, so with nothing to query it fails the plan outright with
# "Could not resolve to a Repository" — verified, not assumed. Nothing is lost by
# skipping it: a repository that does not exist cannot carry classic protection.
data "github_branch_protection_rules" "classic" {
  count = var.repository_exists ? 1 : 0

  repository = var.name

  lifecycle {
    postcondition {
      condition     = length(self.rules) == 0
      error_message = "${var.name} has classic branch protection rule(s) matching [${join(", ", [for r in self.rules : r.pattern])}]; rulesets and classic protection double-enforce, so the classic rule must go. Compare its settings against the ruleset and migrate per docs/runbooks/migrating-classic-protection-to-ruleset.md, then remove it in the repository's Settings → Branches."
    }
  }
}
