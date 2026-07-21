variable "github_token" {
  description = "GitHub token for the flungo provider. Supplied via TF_VAR_github_token; sensitive and never committed."
  type        = string
  sensitive   = true
}
