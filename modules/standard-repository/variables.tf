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
  description = "Additional check contexts that must pass before merging, beyond any implied by the standards flags (e.g. terraform). Named as they appear on the repo's pull requests. GitHub has no \"require all checks\" option and no wildcard — contexts are named individually, and one that never runs on a pull request blocks its merge behind a perpetual \"Expected\" entry — so list only contexts the repo's CI actually reports, and do not repeat an implied one."
  type        = list(string)
  default     = []
}

variable "excluded_status_checks" {
  description = "Check contexts to remove from the required set, applied after the implied and additional ones are combined. The escape hatch for a repo that legitimately takes a flag's other effects but cannot report the check that flag implies — e.g. one that follows Fabrizio's Terraform standards and needs the HCP token, but whose CI cannot run the shared workflow's baseline. Excluding the context is preferred to a per-flag opt-out because it generalises to any flag/check conflict without adding a matching boolean each time. It is for contexts a *flag* implies: a context the caller adds itself belongs in neither list, or commented out in required_status_checks if it is only temporarily disabled. Name what is excluded and why at the call site."
  type        = list(string)
  default     = []

  validation {
    condition     = length(setintersection(var.excluded_status_checks, var.required_status_checks)) == 0
    error_message = "A context must not appear in both required_status_checks and excluded_status_checks (${join(", ", sort(tolist(setintersection(var.excluded_status_checks, var.required_status_checks))))}). Adding a context and then removing it leaves it not required, which is what omitting it from required_status_checks already does — so listing it in both is a mistake rather than an intent. To keep the entry in code but disabled, comment it out in required_status_checks."
  }
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
  description = "Whether this repository follows Fabrizio's Terraform standards — which means it uses the flungo/github-workflows Terraform jobs, called under the conventional job name (`terraform`) and reading the conventional secret names. It is not merely \"holds Terraform config\": a repo can hold config without following the standards, and the two must not be conflated (see ADR-010). Adopting the standards is what makes both effects follow — the composite attaches the org-wide HCP Terraform token (TF_TOKEN_APP_TERRAFORM_IO) the jobs read, and requires the \"terraform / terraform\" check they report. Leave false, with a comment saying what adopting them needs, on a repo that holds Terraform config but does not yet follow them; where a repo follows them but genuinely cannot report the check, keep the flag and drop the context via excluded_status_checks. Branch protection itself applies regardless."
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

variable "repository_exists" {
  description = "Whether the repository already exists on GitHub. Default true — every managed repo does, once created. Set false ONLY in the change that creates a brand-new repository, and remove it in a follow-up once the creating apply has run: it is transient, exactly like the import block an adoption carries. It gates the classic-protection guard, whose data source queries the live repository and errors with \"Could not resolve to a Repository\" when there is nothing to query yet. A repository that does not exist cannot carry classic protection, so skipping the guard for a create loses no cover. See ADR-009."
  type        = bool
  default     = true
}
