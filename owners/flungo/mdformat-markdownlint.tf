# mdformat-markdownlint — an mdformat plugin and a markdownlint preset that keep
# the two tools in agreement, so a formatted file lints clean from one config
# (public, so the package can be published and installed). Created by this
# config; managed through the standard-repository composite: standard
# repository settings, default-branch protection, and the shared Actions
# secrets.

module "mdformat_markdownlint" {
  source = "../../modules/standard-repository"

  name        = "mdformat-markdownlint"
  description = "mdformat plugin and markdownlint preset that keep the two in agreement: one config, and formatter output that lints clean."
  topics      = ["markdown", "mdformat", "markdownlint", "code-quality", "plugin"]

  # Public so the plugin can be published to and installed from PyPI, and the
  # preset extended by other repositories.
  visibility = "public"

  shared_secrets = local.shared_secrets
}
