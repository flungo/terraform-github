# claude-code-sandbox — the personal Claude Code container image. Adopted from
# the pre-existing repository; managed through the standard-repository
# composite: standard repository settings, default-branch protection, and the
# shared Actions secrets.

import {
  to = module.claude_code_sandbox.module.repository.github_repository.this
  id = "claude-code-sandbox" # import ID is the repo name; owner comes from the provider
}

module "claude_code_sandbox" {
  source = "../../modules/standard-repository"

  name        = "claude-code-sandbox"
  description = "Personal Claude Code container image — pre-installed dev tooling, hardened and network-isolated for sandboxed local use."

  shared_secrets = local.shared_secrets
}
