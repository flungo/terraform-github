# Shared Actions secrets attached to a managed repository. Values are supplied by
# the owner directory (from CI via the reusable workflow's tf_secret_vars) and never
# hard-coded here. Terraform-managing these is deliberate and safe: unlike the
# provider/HCP tokens that gate *this* repo's own CI — kept manual so a broken
# apply can't lock this repo out of its credentials (see the reference/secrets
# catalogue) — the secrets written to OTHER repos carry no such circularity.

# LYCHEE_GITHUB_TOKEN — the GitHub token the lychee Markdown link-checker uses in
# CI to reach other private repos and avoid rate-limiting. Attached only where
# var.markdown is set: the workflow that reads it is the external URL sweep, so a
# repo that does not run it carries a credential nothing consumes.
resource "github_actions_secret" "lychee_github_token" {
  count = var.markdown ? 1 : 0

  repository      = var.repository
  secret_name     = "LYCHEE_GITHUB_TOKEN"
  plaintext_value = var.lychee_github_token

  lifecycle {
    precondition {
      condition     = var.lychee_github_token != ""
      error_message = "lychee_github_token must be set when markdown = true."
    }
  }
}

# TF_TOKEN_APP_TERRAFORM_IO — the org-wide HCP Terraform token, so a repo that holds
# Terraform config can plan/apply in its own CI. A single shared value, attached
# only where var.terraform is set.
resource "github_actions_secret" "hcp_token" {
  count = var.terraform ? 1 : 0

  repository      = var.repository
  secret_name     = "TF_TOKEN_APP_TERRAFORM_IO"
  plaintext_value = var.hcp_token

  lifecycle {
    precondition {
      condition     = var.hcp_token != ""
      error_message = "hcp_token must be set when terraform = true."
    }
  }
}
