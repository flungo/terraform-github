# authentik.flungo.net — Terraform config/docs repo for Fabrizio's Authentik
# server. Managed through the shared modules: standard repository settings and
# default-branch protection.

module "authentik_flungo_net" {
  source = "../../modules/repository"

  name        = "authentik.flungo.net"
  description = "Terraform configuration, architecture documentation, and operational records for Fabrizio's Authentik server."
}

module "authentik_flungo_net_protection" {
  source     = "../../modules/branch-protection"
  repository = module.authentik_flungo_net.name
}

module "authentik_flungo_net_secrets" {
  source     = "../../modules/repository-secrets"
  repository = module.authentik_flungo_net.name

  lychee_github_token = var.lychee_github_token
  terraform           = true # authentik.flungo.net holds Terraform config
  hcp_token           = var.hcp_token
}
