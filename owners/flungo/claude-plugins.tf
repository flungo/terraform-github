# claude-plugins — the personal Claude Code / claude.ai plugin marketplace
# (public so it can be installed). Managed through the shared modules: standard
# repository settings and default-branch protection.

module "claude_plugins" {
  source = "../../modules/repository"

  name        = "claude-plugins"
  description = "Personal Claude Code / Claude.ai plugin marketplace"
  topics      = ["claude", "claude-code", "anthropic", "plugin", "marketplace"]

  # Public so the marketplace can be installed from Claude Code / claude.ai.
  visibility = "public"
}

module "claude_plugins_protection" {
  source     = "../../modules/branch-protection"
  repository = module.claude_plugins.name
}
