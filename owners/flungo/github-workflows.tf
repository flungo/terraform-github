# github-workflows — reusable GitHub Actions workflows and shared CI standards
# (public so the private consumer repos can call it). Managed through the
# standard-repository composite: standard repository settings, default-branch
# protection, and the shared Actions secrets.

module "github_workflows" {
  source = "../../modules/standard-repository"

  name        = "github-workflows"
  description = "Reusable GitHub Actions workflows and shared CI standards for the flungo Terraform repositories (Terraform plan/apply, drift remediation, Markdown validation)."
  topics      = ["terraform", "github-actions", "actions", "reusable-workflows", "ci", "cicd", "code-quality"]

  # Public so the private consumer repos can call its reusable workflows without
  # extra Actions-sharing config.
  visibility = "public"

  shared_secrets = local.shared_secrets
}

# State moves from the previous per-primitive module calls into the composite;
# removed in a follow-up PR once the migrating apply has run.
moved {
  from = module.github_workflows.github_repository.this
  to   = module.github_workflows.module.repository.github_repository.this
}

moved {
  from = module.github_workflows_protection
  to   = module.github_workflows.module.branch_protection
}
