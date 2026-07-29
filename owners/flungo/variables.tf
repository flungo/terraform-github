variable "github_token" {
  description = "GitHub token for the flungo provider. Supplied via TF_VAR_github_token; sensitive and never committed."
  type        = string
  sensitive   = true
}

variable "lychee_github_token" {
  description = "Value written to each managed repo's LYCHEE_GITHUB_TOKEN Actions secret (the lychee link-checker's GitHub token). Supplied via the reusable workflow's tf_secret_vars in CI; sensitive and never committed."
  type        = string
  sensitive   = true
}

variable "hcp_token" {
  description = "Value written to Terraform repos' TF_TOKEN_APP_TERRAFORM_IO Actions secret (the org-wide HCP Terraform token). Supplied via the reusable workflow's tf_secret_vars in CI; sensitive and never committed."
  type        = string
  sensitive   = true
}

# The owner's shared secret values, composed once and passed to every
# standard-repository call as `shared_secrets = local.shared_secrets` — repo
# files never wire individual secret values. A new shared secret is a new
# variable above, a new key here, and a new input on the modules; the repo files
# don't change.
locals {
  shared_secrets = {
    lychee_github_token = var.lychee_github_token
    hcp_token           = var.hcp_token
  }
}
