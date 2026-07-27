# github-workflows — reusable GitHub Actions workflows and shared CI standards
# (public so the private consumer repos can call it). Managed through the shared
# modules: standard repository settings and default-branch protection.

module "github_workflows" {
  source = "../../modules/repository"

  name        = "github-workflows"
  description = "Reusable GitHub Actions workflows and shared CI standards for the flungo Terraform repositories (Terraform plan/apply, drift remediation, Markdown validation)."
  topics      = ["terraform", "github-actions", "actions", "reusable-workflows", "ci", "cicd", "code-quality"]

  # Public so the private consumer repos can call its reusable workflows without
  # extra Actions-sharing config.
  visibility = "public"
}

module "github_workflows_protection" {
  source     = "../../modules/branch-protection"
  repository = module.github_workflows.name
}
