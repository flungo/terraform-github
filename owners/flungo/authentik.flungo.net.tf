# authentik.flungo.net — Terraform config/docs repo for Fabrizio's Authentik
# server. Managed through the shared modules: standard repository settings and
# default-branch protection. The moved block relocates the repository from its
# previous top-level address into the module without destroy/recreate — it can
# be dropped in a follow-up once the migrating apply has run.

moved {
  from = github_repository.authentik_flungo_net
  to   = module.authentik_flungo_net.github_repository.this
}

module "authentik_flungo_net" {
  source = "../../modules/repository"

  name        = "authentik.flungo.net"
  description = "Terraform configuration, architecture documentation, and operational records for Fabrizio's Authentik server."
}

module "authentik_flungo_net_protection" {
  source     = "../../modules/branch-protection"
  repository = module.authentik_flungo_net.name
}
