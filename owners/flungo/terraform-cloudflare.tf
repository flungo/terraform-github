# terraform-cloudflare — Terraform config for Cloudflare. Adopted from the
# pre-existing repository; managed through the standard-repository composite:
# standard repository settings, default-branch protection, and the shared
# Actions secrets.

module "terraform_cloudflare" {
  source = "../../modules/standard-repository"

  name        = "terraform-cloudflare"
  description = "Terraform configuration management for Cloudflare"

  # Still empty — no config and no workflows, so it cannot yet follow
  # Fabrizio's Terraform standards, which is what the flag asserts (ADR-010);
  # setting it would require a check nothing reports and block every merge.
  # Enable when the repo gains its config and the github-workflows Terraform
  # jobs.
  # terraform = true

  # Off: still empty, so it has no Markdown and no workflows to validate it
  # with — the same reason the terraform flag is off, and it clears the same
  # way. Delete this line alongside the repo's first documentation; the lychee
  # token it has been carrying unread is removed by this apply.
  markdown = false

  shared_secrets = local.shared_secrets
}
