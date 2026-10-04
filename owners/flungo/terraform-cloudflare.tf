# terraform-cloudflare — adopted from the pre-existing repository; managed
# through the standard-repository composite: standard repository settings,
# default-branch protection, and the shared Actions secrets.

module "terraform_cloudflare" {
  source = "../../modules/standard-repository"

  name        = "terraform-cloudflare"
  description = "Terraform configuration management for Cloudflare"

  # Not set: the repository does not report "terraform / terraform" yet, and the
  # flag requires it (ADR-010). Enable once it does.
  # terraform = true

  # Off: the repository does not report the Markdown checks yet, and the flag
  # requires them (ADR-012). Delete this line once it does.
  markdown = false

  shared_secrets = local.shared_secrets
}
