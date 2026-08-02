# claude-code-sandbox — the personal Claude Code container image. Adopted from
# the pre-existing repository; managed through the standard-repository
# composite: standard repository settings, default-branch protection, and the
# shared Actions secrets.

module "claude_code_sandbox" {
  source = "../../modules/standard-repository"

  name        = "claude-code-sandbox"
  description = "Personal Claude Code container image — pre-installed dev tooling, hardened and network-isolated for sandboxed local use."

  # Off: has documentation but runs neither Markdown workflow, so it does not
  # follow the standards the flag asserts (ADR-012). Leaving it at the default
  # would require two checks nothing reports and block every merge. Delete this
  # line when the workflows are adopted — that is also when the lychee token
  # starts being read, and this apply removes it in the meantime.
  markdown = false

  shared_secrets = local.shared_secrets
}
