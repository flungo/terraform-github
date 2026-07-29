# authentik.flungo.net — Terraform config/docs repo for Fabrizio's Authentik
# server. Managed through the standard-repository composite: standard repository
# settings, default-branch protection, and the shared Actions secrets.

module "authentik_flungo_net" {
  source = "../../modules/standard-repository"

  name        = "authentik.flungo.net"
  description = "Terraform configuration, architecture documentation, and operational records for Fabrizio's Authentik server."

  terraform = true # authentik.flungo.net holds Terraform config

  shared_secrets = local.shared_secrets
}
