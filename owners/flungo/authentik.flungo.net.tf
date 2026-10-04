# authentik.flungo.net — adopted from the pre-existing repository; managed
# through the standard-repository composite: standard repository settings,
# default-branch protection, and the shared Actions secrets.

module "authentik_flungo_net" {
  source = "../../modules/standard-repository"

  name        = "authentik.flungo.net"
  description = "Terraform configuration, architecture documentation, and operational records for Fabrizio's Authentik server."

  # Not set: the repository does not report "terraform / terraform" yet, and the
  # flag requires it (ADR-010). Enable once it does.
  # terraform = true

  shared_secrets = local.shared_secrets
}
