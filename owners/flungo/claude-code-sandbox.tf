# claude-code-sandbox — the personal Claude Code container image. Adopted from
# the pre-existing repository; managed through the standard-repository
# composite: standard repository settings, default-branch protection, and the
# shared Actions secrets.

module "claude_code_sandbox" {
  source = "../../modules/standard-repository"

  name        = "claude-code-sandbox"
  description = "Personal Claude Code container image — pre-installed dev tooling, hardened and network-isolated for sandboxed local use."

  shared_secrets = local.shared_secrets
}
