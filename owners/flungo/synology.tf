# synology — created by this config; managed through the standard-repository
# composite: standard repository settings, default-branch protection, and the
# shared Actions secrets.

module "synology" {
  source = "../../modules/standard-repository"

  name        = "synology"
  description = "Documentation and configuration for Synology NAS servers."
  topics      = ["synology", "nas", "homelab"]

  shared_secrets = local.shared_secrets
}
