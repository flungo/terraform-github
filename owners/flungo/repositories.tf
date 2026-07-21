# Existing repositories are adopted via import blocks (ADR-012 pattern); drop
# each block in a follow-up once the adopting apply has run.

import {
  to = github_repository.authentik_flungo_net
  id = "authentik.flungo.net" # import ID is the repo name; owner comes from the provider
}

# Matched to the live repo so the import adopts it cleanly (no substantive changes).
# authentik already matches our merge/feature standard; Projects is left enabled as
# it is on the live repo — standardise deliberately later if desired.
resource "github_repository" "authentik_flungo_net" {
  name        = "authentik.flungo.net"
  description = "Terraform configuration, architecture documentation, and operational records for Fabrizio's Authentik server."

  visibility             = "private"
  has_issues             = true
  has_wiki               = false
  has_projects           = true
  has_downloads          = true
  allow_merge_commit     = false
  allow_squash_merge     = true
  allow_rebase_merge     = true
  delete_branch_on_merge = true
}
