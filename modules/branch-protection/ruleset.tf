# Standard branch protection, implemented as a repository ruleset (the modern,
# more expressive resource — see docs/decisions/004-branch-protection-rulesets.md).
# Default rules: require a pull request, require conversation resolution, require
# linear history, restrict deletion, and require any named status checks. Repository
# admins may bypass unless var.strict is set. The catalogue of defaults and inputs
# lives in docs/reference/branch-protection.md.
resource "github_repository_ruleset" "this" {
  name        = "standard"
  repository  = var.repository
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = [var.pattern]
      exclude = []
    }
  }

  # Non-strict rulesets give repository admins a deliberate bypass *option*: they
  # may merge a pull request that doesn't meet the rules (bootstrap / incident
  # response), but the rules still apply by default and admins cannot push straight
  # to the branch — bypass_mode is "pull_request", not "always". A strict ruleset
  # removes the bypass entirely so the rules bind everyone.
  dynamic "bypass_actors" {
    for_each = var.strict ? [] : [1]
    content {
      actor_id    = 5 # the built-in Admin repository role
      actor_type  = "RepositoryRole"
      bypass_mode = "pull_request"
    }
  }

  rules {
    # Restrict deletion — a protected branch must not be deletable (only actors with
    # bypass may delete it). GitHub already refuses to delete the *default* branch,
    # but this module protects any branch by pattern, so encode it rather than lean
    # on that incidental protection.
    deletion = true

    # Require linear history — no merge commits.
    required_linear_history = true

    # Require a pull request before merging; no required approvals (the owner works
    # solo, so requiring an approval would block their own PRs), but conversation
    # threads must be resolved.
    pull_request {
      required_approving_review_count   = 0
      required_review_thread_resolution = true
    }

    # Require named status checks only when contexts are supplied — an empty set
    # would enforce nothing, so the block is omitted entirely in that case.
    dynamic "required_status_checks" {
      for_each = length(var.required_status_checks) > 0 ? [1] : []
      content {
        dynamic "required_check" {
          for_each = var.required_status_checks
          content {
            context = required_check.value
          }
        }
        strict_required_status_checks_policy = false
      }
    }
  }
}
