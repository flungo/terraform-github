# The flungo account's repositories. Each is a call to the shared standard
# repository module (../../modules/repository); the module encodes the baseline
# (feature toggles, merge strategy) and each call passes only the per-repo inputs.
# The moved blocks relocate the resources from their previous top-level addresses
# into the module without destroy/recreate — they can be dropped in a follow-up
# once the migrating apply has run.

moved {
  from = github_repository.authentik_flungo_net
  to   = module.authentik_flungo_net.github_repository.this
}

module "authentik_flungo_net" {
  source = "../../modules/repository"

  name        = "authentik.flungo.net"
  description = "Terraform configuration, architecture documentation, and operational records for Fabrizio's Authentik server."
}

moved {
  from = github_repository.github_workflows
  to   = module.github_workflows.github_repository.this
}

module "github_workflows" {
  source = "../../modules/repository"

  name        = "github-workflows"
  description = "Reusable GitHub Actions workflows and shared CI standards for the flungo Terraform repositories (Terraform plan/apply, drift remediation, Markdown validation)."
  topics      = ["terraform", "github-actions", "actions", "reusable-workflows", "ci", "cicd", "code-quality"]

  # Public so the private consumer repos can call its reusable workflows without
  # extra Actions-sharing config.
  visibility = "public"
}

moved {
  from = github_repository.claude_plugins
  to   = module.claude_plugins.github_repository.this
}

module "claude_plugins" {
  source = "../../modules/repository"

  name        = "claude-plugins"
  description = "Personal Claude Code / Claude.ai plugin marketplace"
  topics      = ["claude", "claude-code", "anthropic", "plugin", "marketplace"]

  # Public so the marketplace can be installed from Claude Code / claude.ai.
  visibility = "public"
}
