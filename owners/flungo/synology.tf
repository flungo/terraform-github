# synology — created by this config; managed through the standard-repository
# composite: standard repository settings, default-branch protection, and the
# shared Actions secrets.

module "synology" {
  source = "../../modules/standard-repository"

  name        = "synology"
  description = "Documentation and configuration for Synology NAS servers."
  topics      = ["synology", "nas", "homelab"]

  # Transient: markdown defaults to true, but a new repo has not adopted the
  # workflows yet, so the checks it would require never report. Removed by
  # the PR that adopts them.
  markdown = false

  # Transient: removed in a follow-up PR once the creating apply has run.
  repository_exists = false

  shared_secrets = local.shared_secrets
}
