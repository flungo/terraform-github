# terraform-grafana-cloud — Terraform config for Grafana Cloud, and the repo the
# structure and CI of this one were inherited from. Adopted from the
# pre-existing repository; managed through the standard-repository composite:
# standard repository settings, default-branch protection, and the shared
# Actions secrets.

module "terraform_grafana_cloud" {
  source = "../../modules/standard-repository"

  name        = "terraform-grafana-cloud"
  description = "Terraform configuration management for Grafana Cloud"

  terraform = true # terraform-grafana-cloud holds Terraform config

  shared_secrets = local.shared_secrets
}
