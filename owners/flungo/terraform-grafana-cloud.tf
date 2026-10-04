# terraform-grafana-cloud — adopted from the pre-existing repository; managed
# through the standard-repository composite: standard repository settings,
# default-branch protection, and the shared Actions secrets.

module "terraform_grafana_cloud" {
  source = "../../modules/standard-repository"

  name        = "terraform-grafana-cloud"
  description = "Terraform configuration management for Grafana Cloud"

  terraform = true

  # Off: the repository does not report the Markdown checks yet, and the flag
  # requires them (ADR-012). Delete this line once it does.
  markdown = false

  shared_secrets = local.shared_secrets
}
