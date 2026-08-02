# terraform-grafana-cloud — Terraform config for Grafana Cloud, and the repo the
# structure and CI of this one were inherited from. Adopted from the
# pre-existing repository; managed through the standard-repository composite:
# standard repository settings, default-branch protection, and the shared
# Actions secrets.

module "terraform_grafana_cloud" {
  source = "../../modules/standard-repository"

  name        = "terraform-grafana-cloud"
  description = "Terraform configuration management for Grafana Cloud"

  terraform = true

  # Off: has documentation but runs neither Markdown workflow, so it does not
  # follow the standards the flag asserts (ADR-012). Leaving it at the default
  # would require two checks nothing reports and block every merge. Delete this
  # line when the workflows are adopted — that is also when the lychee token
  # starts being read, and this apply removes it in the meantime.
  markdown = false

  shared_secrets = local.shared_secrets
}
