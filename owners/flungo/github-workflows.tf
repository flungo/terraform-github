# github-workflows — reusable GitHub Actions workflows and shared CI standards
# (public so the private consumer repos can call it). Managed through the
# standard-repository composite: standard repository settings, default-branch
# and release-branch protection, and the shared Actions secrets.

module "github_workflows" {
  source = "../../modules/standard-repository"

  name        = "github-workflows"
  description = "Reusable GitHub Actions workflows and shared CI standards for the flungo Terraform repositories (Terraform plan/apply, drift remediation, Markdown validation)."
  topics      = ["terraform", "github-actions", "actions", "reusable-workflows", "ci", "cicd", "code-quality"]

  # Public so the private consumer repos can call its reusable workflows without
  # extra Actions-sharing config.
  visibility = "public"

  # The moving-major release branches (v1, later v2, …): consumers pin @vN and
  # the repo's release.yml fast-forwards the current major to main on every
  # merge (its ADR-003). Only that workflow's App identity may push them
  # directly; reverts and backports land as PRs (base v*). See the repo's
  # releasing.md § Branch protection, github-workflows#6, and #13 here.
  release_branches = {
    pattern             = "refs/heads/v[0-9]*"
    push_bypass_app_ids = [4424737] # the flungo-release App
  }

  shared_secrets = local.shared_secrets
}
