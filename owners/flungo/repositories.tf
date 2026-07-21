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
