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

# github-workflows does not exist yet, so it is CREATED by this config rather than
# adopted — hence no import block (contrast the authentik resource above). Applying
# this config brings the repo into existence; it is then populated with the shared
# reusable workflows (Terraform plan/apply, drift remediation, Markdown validation)
# and CI standards separately. Public so the private consumer repos can call its
# reusable workflows without extra Actions-sharing configuration.
resource "github_repository" "github_workflows" {
  name        = "github-workflows"
  description = "Reusable GitHub Actions workflows and shared CI standards for the flungo Terraform repositories (Terraform plan/apply, drift remediation, Markdown validation)."
  topics      = ["terraform", "github-actions", "reusable-workflows", "ci"]

  visibility = "public"

  # auto_init creates an initial commit on main so the default branch exists up
  # front — the repo can then be populated via the usual branch + PR flow rather
  # than a first push straight to a non-existent main.
  auto_init = true

  has_issues             = true # the repo's own Markdown-link sweep opens issues here
  has_wiki               = false
  has_projects           = false
  has_downloads          = true
  allow_merge_commit     = false
  allow_squash_merge     = true
  allow_rebase_merge     = true
  delete_branch_on_merge = true
}
