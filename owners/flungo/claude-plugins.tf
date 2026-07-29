# claude-plugins — the personal Claude Code / claude.ai plugin marketplace
# (public so it can be installed). Managed through the standard-repository
# composite: standard repository settings, default-branch protection, and the
# shared Actions secrets.

module "claude_plugins" {
  source = "../../modules/standard-repository"

  name        = "claude-plugins"
  description = "Personal Claude Code / Claude.ai plugin marketplace"
  topics      = ["claude", "claude-code", "anthropic", "plugin", "marketplace"]

  # Public so the marketplace can be installed from Claude Code / claude.ai.
  visibility = "public"

  shared_secrets = local.shared_secrets
}
