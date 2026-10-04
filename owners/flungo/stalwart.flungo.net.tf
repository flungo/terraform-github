# stalwart.flungo.net — adopted from the pre-existing repository; managed
# through the standard-repository composite: standard repository settings,
# default-branch protection, and the shared Actions secrets.

module "stalwart_flungo_net" {
  source = "../../modules/standard-repository"

  name        = "stalwart.flungo.net"
  description = "Terraform configuration for flungo's stalwart server."

  # Follows the Terraform standards (ADR-010) but does not report
  # "terraform / terraform", so that context is excluded rather than the flag
  # withheld. Drop the exclusion once it reports the check.
  terraform = true

  # Scoped to the Terraform check only: the Markdown checks still apply.
  excluded_status_checks = ["terraform / terraform"]

  shared_secrets = local.shared_secrets
}
