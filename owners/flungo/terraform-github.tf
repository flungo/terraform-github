# terraform-github — this repository: the Terraform config managing the fleet's
# GitHub resources. Adopted last, deliberately: its apply touches this repo's own
# branch protection, so the pipeline was proven on every other repo first (see
# the §5 circularity note in docs/plans/initial-buildout.md).

import {
  to = module.terraform_github.module.repository.github_repository.this
  id = "terraform-github" # import ID is the repo name; owner comes from the provider
}

module "terraform_github" {
  source = "../../modules/standard-repository"

  name        = "terraform-github"
  description = "Terraform configuration for managing my GitHub account and organizations — repository settings, project templates, shared secrets, and other resources managed via the GitHub provider."

  # Public: the repo is a worked reference for managing GitHub with Terraform,
  # and holds no secrets — only their names.
  visibility = "public"

  # Records that this repo holds Terraform config. Currently inert: the flag's
  # only effect today is attaching the HCP token, and manage_secrets = false
  # skips the secrets primitive entirely. Kept so the fact is stated where every
  # other Terraform repo states it. It becomes live by either route — flipping
  # manage_secrets, or widening what the flag itself drives (ADR-006 leaves a
  # required plan-check context on the table) — and neither should have to
  # rediscover that this repo holds Terraform config.
  terraform = true

  # The self-referential opt-out (ADR-005's circularity note). This repo's CI is
  # gated by the very secrets the composite would manage — FLUNGO_GITHUB_TOKEN
  # and TF_TOKEN_APP_TERRAFORM_IO — so a broken apply that rewrote them would
  # lock the repo out of the credentials it needs to fix itself. They stay
  # manually managed until self-management is deliberately taken on.
  #
  # shared_secrets is therefore not passed: the composite's validation requires
  # it only when manage_secrets is true.
  manage_secrets = false
}
