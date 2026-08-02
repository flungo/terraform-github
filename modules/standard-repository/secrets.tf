# The fleet's shared Actions secrets, each attached where the standard that
# reads it is followed — LYCHEE_GITHUB_TOKEN where markdown = true, the HCP
# token where terraform = true. Values come from the owner-level shared_secrets
# object, so repo calls never wire individual secret values. Skipped entirely
# when manage_secrets = false — the self-referential opt-out for repos whose
# secrets must stay manually managed (see ADR-005's circularity note). That
# takes the secret half of both flags out while leaving the check half in place;
# the two halves are independent, and a repo can report a check for a workflow
# whose credential it supplies to itself by hand.
module "secrets" {
  count  = var.manage_secrets ? 1 : 0
  source = "../repository-secrets"

  repository = module.repository.name

  markdown            = var.markdown
  lychee_github_token = var.shared_secrets.lychee_github_token
  terraform           = var.terraform
  hcp_token           = var.shared_secrets.hcp_token
}
