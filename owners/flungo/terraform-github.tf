# terraform-github — this repository: the Terraform config managing the fleet's
# GitHub resources. Adopted last, deliberately: its apply touches this repo's own
# branch protection, so the pipeline was proven on every other repo first (see
# the §5 circularity note in docs/plans/initial-buildout.md).

module "terraform_github" {
  source = "../../modules/standard-repository"

  name        = "terraform-github"
  description = "Terraform configuration for managing my GitHub account and organizations — repository settings, project templates, shared secrets, and other resources managed via the GitHub provider."

  # Public: the repo is a worked reference for managing GitHub with Terraform,
  # and holds no secrets — only their names.
  visibility = "public"

  # Follows Fabrizio's Terraform standards, so the flag requires the check those
  # jobs report. Its other effect, attaching the HCP token, is skipped here:
  # manage_secrets = false takes the whole secrets primitive out. That split is
  # deliberate — this repo supplies the token to itself by hand, but its CI
  # reports the check like any other, so the check half still applies.
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
