# claude-code-sandbox — adopted from the pre-existing repository; managed
# through the standard-repository composite: standard repository settings,
# default-branch protection, and the shared Actions secrets.

module "claude_code_sandbox" {
  source = "../../modules/standard-repository"

  name        = "claude-code-sandbox"
  description = "Personal Claude Code container image — pre-installed dev tooling, hardened and network-isolated for sandboxed local use."

  # Off: the repository does not report the Markdown checks yet, and the flag
  # requires them (ADR-012). Delete this line once it does.
  markdown = false

  shared_secrets = local.shared_secrets
}
