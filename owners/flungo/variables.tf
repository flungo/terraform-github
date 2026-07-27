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
