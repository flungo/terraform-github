# terraform-provider-stalwart — adopted from the pre-existing repository;
# managed through the standard-repository composite: standard repository
# settings, default-branch protection, and the shared Actions secrets.

module "terraform_provider_stalwart" {
  source = "../../modules/standard-repository"

  name        = "terraform-provider-stalwart"
  description = "A terraform provider for the Stalwart mail server."

  # Public so the provider can be consumed from outside the fleet.
  visibility = "public"

  # terraform is deliberately unset: the repository does not run the Terraform
  # jobs the flag asserts (ADR-010), so the HCP token would be an unused
  # credential.

  shared_secrets = local.shared_secrets
}
