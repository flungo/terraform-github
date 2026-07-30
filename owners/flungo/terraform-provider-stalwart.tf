# terraform-provider-stalwart — the Terraform provider for the Stalwart mail
# server (public, so it can be consumed). Adopted from the pre-existing
# repository; managed through the standard-repository composite: standard
# repository settings, default-branch protection, and the shared Actions
# secrets.

module "terraform_provider_stalwart" {
  source = "../../modules/standard-repository"

  name        = "terraform-provider-stalwart"
  description = "A terraform provider for the Stalwart mail server."

  # Public so the provider can be consumed from outside the fleet.
  visibility = "public"

  # terraform is deliberately false: the flag attaches the HCP Terraform token
  # to repos that plan/apply real infrastructure in their own CI. This repo
  # *implements* a provider — it holds Go source, not Terraform config with an
  # HCP backend, so the token would be an unused credential on a public repo.

  shared_secrets = local.shared_secrets
}
