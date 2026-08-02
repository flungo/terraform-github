# stalwart.flungo.net — Terraform config for Fabrizio's Stalwart mail server.
# Adopted from the pre-existing repository; managed through the
# standard-repository composite: standard repository settings, default-branch
# protection, and the shared Actions secrets.

module "stalwart_flungo_net" {
  source = "../../modules/standard-repository"

  name        = "stalwart.flungo.net"
  description = "Terraform configuration for flungo's stalwart server."

  # Follows Fabrizio's Terraform standards and uses HCP for state, so it takes
  # the HCP token — but it cannot report the shared workflow's check, so that
  # context is excluded rather than the flag withheld. Its management host is
  # LAN-only, so the shared baseline (plan against real infrastructure) cannot
  # run on a GitHub-hosted runner; its own CI works around this by planning
  # against an ephemeral container, and its production apply is disabled
  # outright. Aligning it needs a self-hosted runner (on hold) and probably
  # support for one in flungo/github-workflows — tracked in that repository's
  # own docs (docs/plans/terraform-ci.md § Phase 3). Drop the exclusion once it
  # reports "terraform / terraform".
  terraform = true

  # Scoped to the Terraform baseline, for the reason above — it does not reach
  # the Markdown checks, which run on GitHub-hosted runners like anywhere else.
  excluded_status_checks = ["terraform / terraform"]

  shared_secrets = local.shared_secrets
}
