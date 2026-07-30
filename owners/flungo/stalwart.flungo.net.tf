# stalwart.flungo.net — Terraform config for Fabrizio's Stalwart mail server.
# Adopted from the pre-existing repository; managed through the
# standard-repository composite: standard repository settings, default-branch
# protection, and the shared Actions secrets.

import {
  to = module.stalwart_flungo_net.module.repository.github_repository.this
  id = "stalwart.flungo.net" # import ID is the repo name; owner comes from the provider
}

module "stalwart_flungo_net" {
  source = "../../modules/standard-repository"

  name        = "stalwart.flungo.net"
  description = "Terraform configuration for flungo's stalwart server."

  terraform = true # stalwart.flungo.net holds Terraform config

  shared_secrets = local.shared_secrets
}
