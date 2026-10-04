# github-workflows — created by this config; managed through the
# standard-repository composite: standard repository settings, default-branch
# and release-branch protection, and the shared Actions secrets.
#
# The `terraform` topic is deliberate, not a mis-tag to tidy away: the
# repository provides CI for Terraform repos, and being findable for that
# outweighs topics.md's "configuration codebase" definition.

module "github_workflows" {
  source = "../../modules/standard-repository"

  name        = "github-workflows"
  description = "Reusable GitHub Actions workflows and composite actions for linting, testing, compilation, packaging and release, with the shared CI standards behind them."
  topics      = ["terraform", "github-actions", "actions", "reusable-workflows", "ci", "cicd", "code-quality"]

  # Public so the private consumer repos can call its reusable workflows without
  # extra Actions-sharing config.
  visibility = "public"

  # Release branches (v1, v2, …): only the release App may push or create them
  # directly; everything else lands as a pull request (ADR-007).
  # The pattern is fnmatch, not regex, so it also reaches names like v2-test.
  # That is deliberate: creation is restricted to the same App, so nobody can
  # make those branches anyway, and a broad glob cannot silently miss a real
  # major the way an enumerated one could (v100). See ADR-008.
  release_branches = {
    pattern             = "refs/heads/v[0-9]*"
    push_bypass_app_ids = [4424737] # the flungo-release App
  }

  shared_secrets = local.shared_secrets
}
