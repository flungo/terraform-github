# The fleet's shared Actions secrets — LYCHEE_GITHUB_TOKEN on every repo, plus
# the HCP token where the repo holds Terraform config (terraform = true). Values
# come from the owner-level shared_secrets object, so repo calls never wire
# individual secret values. Skipped entirely when manage_secrets = false — the
# self-referential opt-out for repos whose secrets must stay manually managed
# (see ADR-005's circularity note).
module "secrets" {
  count  = var.manage_secrets ? 1 : 0
  source = "../repository-secrets"

  repository = module.repository.name

  lychee_github_token = var.shared_secrets.lychee_github_token
  terraform           = var.terraform
  hcp_token           = var.shared_secrets.hcp_token
}
