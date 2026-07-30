# terraform-cloudflare — Terraform config for Cloudflare. Adopted from the
# pre-existing repository; managed through the standard-repository composite:
# standard repository settings, default-branch protection, and the shared
# Actions secrets.

module "terraform_cloudflare" {
  source = "../../modules/standard-repository"

  name        = "terraform-cloudflare"
  description = "Terraform configuration management for Cloudflare"

  terraform = true # terraform-cloudflare holds Terraform config

  shared_secrets = local.shared_secrets
}
