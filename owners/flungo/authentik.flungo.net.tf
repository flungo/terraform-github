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

# State moves from the previous per-primitive module calls into the composite;
# removed in a follow-up PR once the migrating apply has run.
moved {
  from = module.authentik_flungo_net.github_repository.this
  to   = module.authentik_flungo_net.module.repository.github_repository.this
}

moved {
  from = module.authentik_flungo_net_protection
  to   = module.authentik_flungo_net.module.branch_protection
}

moved {
  from = module.authentik_flungo_net_secrets
  to   = module.authentik_flungo_net.module.secrets[0]
}
