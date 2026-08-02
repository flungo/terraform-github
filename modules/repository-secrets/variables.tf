variable "repository" {
  description = "Name of the repository the shared secrets are attached to (e.g. \"authentik.flungo.net\")."
  type        = string
}

variable "markdown" {
  description = "Whether this repository follows Fabrizio's Markdown standards. When true, the lychee link-checker's GitHub token (LYCHEE_GITHUB_TOKEN) is attached so the external URL sweep can reach other private repos and avoid rate-limiting. Its only effect here; the required checks the standards imply are the composite's business."
  type        = bool
  default     = false
}

variable "lychee_github_token" {
  description = "Value for the LYCHEE_GITHUB_TOKEN Actions secret — the GitHub token the lychee Markdown link-checker uses in CI to reach other private repos and avoid rate-limiting. Required only when markdown = true. Supplied from the owner directory (via CI); sensitive and never committed."
  type        = string
  sensitive   = true
  default     = ""
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
