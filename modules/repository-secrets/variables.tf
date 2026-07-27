variable "repository" {
  description = "Name of the repository the shared secrets are attached to (e.g. \"authentik.flungo.net\")."
  type        = string
}

variable "lychee_github_token" {
  description = "Value for the LYCHEE_GITHUB_TOKEN Actions secret — the GitHub token the lychee Markdown link-checker uses in CI to avoid rate-limiting. Attached to every managed repository. Supplied from the owner directory (via CI); sensitive and never committed."
  type        = string
  sensitive   = true
}

variable "terraform" {
  description = "Whether this repository holds Terraform config. When true, the org-wide HCP Terraform token (TF_TOKEN_APP_TERRAFORM_IO) is also attached so the repo can plan/apply in its own CI. Its primary effect at this stage; branch protection etc. are not gated on it."
  type        = bool
  default     = false
}

variable "hcp_token" {
  description = "Value for the TF_TOKEN_APP_TERRAFORM_IO Actions secret — the org-wide HCP Terraform Owners-team token. A single shared value; required only when terraform = true. Sensitive and never committed."
  type        = string
  sensitive   = true
  default     = ""
}
