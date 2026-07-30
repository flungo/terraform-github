# terraform-cloudflare — Terraform config for Cloudflare. Adopted from the
# pre-existing repository; managed through the standard-repository composite:
# standard repository settings, default-branch protection, and the shared
# Actions secrets.

import {
  to = module.terraform_cloudflare.module.repository.github_repository.this
  id = "terraform-cloudflare" # import ID is the repo name; owner comes from the provider
}

module "terraform_cloudflare" {
  source = "../../modules/standard-repository"

  name        = "terraform-cloudflare"
  description = "Terraform configuration management for Cloudflare"

  terraform = true # terraform-cloudflare holds Terraform config

  shared_secrets = local.shared_secrets
}
