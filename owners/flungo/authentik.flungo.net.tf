# authentik.flungo.net — Terraform config/docs repo for Fabrizio's Authentik
# server. Managed through the standard-repository composite: standard repository
# settings, default-branch protection, and the shared Actions secrets.

module "authentik_flungo_net" {
  source = "../../modules/standard-repository"

  name        = "authentik.flungo.net"
  description = "Terraform configuration, architecture documentation, and operational records for Fabrizio's Authentik server."

  # Holds Terraform config, but does not yet follow Fabrizio's Terraform
  # standards — its CI is markdown lint/links and version-check only, with no
  # github-workflows Terraform jobs. The flag asserts the standards are
  # followed (ADR-010), so setting it would require a check nothing reports and
  # block every merge. Enable when those jobs are adopted; that is also when
  # the HCP token starts being read.
  # terraform = true


  shared_secrets = local.shared_secrets
}
