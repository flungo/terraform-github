variable "name" {
  description = "Repository name (e.g. \"github-workflows\"). Passed to the repository module; the caller's module local name should mirror it with invalid identifier characters replaced by \"_\" (see docs/reference/terraform-conventions.md)."
  type        = string
}

variable "description" {
  description = "One-line repository description."
  type        = string
}

variable "visibility" {
  description = "Repository visibility. The standard is \"private\"; set \"public\" only where the repo must be readable or callable by others (e.g. hosting reusable workflows that private repos call)."
  type        = string
  default     = "private"
}

variable "topics" {
  description = "Repository topics (optional)."
  type        = list(string)
  default     = []
}

variable "auto_init" {
  description = "Seed an initial commit so the default branch exists at creation. Applies only when the repository is created; the repository module ignores later drift on it. Set false to create an empty repo whose first bulk push establishes main."
  type        = bool
  default     = true
}

variable "strict" {
  description = "When true, no one may bypass the branch-protection rules. When false (the default), repository admins keep a deliberate bypass option — they can merge a pull request that doesn't meet the rules — but cannot push straight to the protected branch. Set true on repos that must bind everyone."
  type        = bool
  default     = false
}

variable "required_status_checks" {
  description = "Check contexts that must pass before merging, as they appear on the repo's pull requests (e.g. \"terraform / terraform\"). Empty enforces no required checks — GitHub has no \"require all checks\" option, and a context that never runs on a PR blocks its merge behind a perpetual \"Expected\" entry, so list only contexts the repo's CI actually reports."
  type        = list(string)
  default     = []
}

variable "release_branches" {
  description = "Protect the repo's release branches with a second (\"release\") ruleset: pattern is the full ref pattern the branches match, **fnmatch** as rulesets interpret it (e.g. \"refs/heads/v[0-9]*\") — prefer a glob that cannot under-reach, since the ruleset also restricts creation to the same Apps, so nobody can create the extra refs it over-reaches onto. push_bypass_app_ids are the numeric IDs of the GitHub Apps allowed to push and create those branches (annotate each with the App it names) — the release automation's identity, everyone else lands via a PR. Default null: no release-branch ruleset. See docs/reference/branch-protection.md."
  type = object({
    pattern             = string
    push_bypass_app_ids = list(number)
  })
  default = null
}

variable "terraform" {
  description = "Whether this repository holds Terraform config. When true, the org-wide HCP Terraform token (TF_TOKEN_APP_TERRAFORM_IO) is attached as an Actions secret so the repo can plan/apply in its own CI — the flag's primary effect. Branch protection applies to every repo regardless of this flag."
  type        = bool
  default     = false
}

variable "manage_secrets" {
  description = "Whether the composite manages the repo's shared Actions secrets. Default true — every managed repo carries them. Set false only where Terraform must not manage the repo's secrets: the self-referential case (terraform-github itself, whose CI-gating tokens stay manually managed so a broken apply can't lock the repo out of its own credentials — see ADR-005's circularity note)."
  type        = bool
  default     = true
}

variable "shared_secrets" {
  description = "The owner's shared secret values, composed once at owner level (local.shared_secrets, from the owner directory's sensitive variables) and passed to every composite call as one uniform reference — repo files never wire individual values. lychee_github_token feeds LYCHEE_GITHUB_TOKEN (every repo); hcp_token feeds TF_TOKEN_APP_TERRAFORM_IO (repos with terraform = true). Required unless manage_secrets = false."
  type = object({
    lychee_github_token = string
    hcp_token           = optional(string, "")
  })
  sensitive = true
  default   = null

  validation {
    condition     = !var.manage_secrets || var.shared_secrets != null
    error_message = "shared_secrets must be set when manage_secrets = true (pass the owner-level local.shared_secrets)."
  }
}
