variable "repository" {
  description = "Name of the repository to protect (e.g. \"authentik.flungo.net\")."
  type        = string
}

variable "name" {
  description = "Name of the ruleset, as shown in the repository's rules settings. The default suits the single standard ruleset; a second ruleset on the same repository needs a distinct name (e.g. \"release\")."
  type        = string
  default     = "standard"
}

variable "pattern" {
  description = "Which ref the ruleset targets. Defaults to the repository's default branch (\"~DEFAULT_BRANCH\"); the module protects any branch, so it takes the pattern rather than assuming main."
  type        = string
  default     = "~DEFAULT_BRANCH"
}

variable "strict" {
  description = "When true, no one may bypass the rules. When false (the default), repository admins keep a deliberate bypass option — they can merge a pull request that doesn't meet the rules — but the rules still apply by default and admins cannot push straight to the branch. Set true on repos that must bind everyone."
  type        = bool
  default     = false
}

variable "push_bypass_app_ids" {
  description = "IDs of GitHub Apps that may push directly to the protected branch — an \"always\" bypass, exempting them from every rule in this ruleset. Reserved for narrowly-scoped automation identities (e.g. a release workflow's App that fast-forwards a release branch); humans and all other tokens stay bound. Numeric App IDs (public, safe-to-commit information), not slugs: a private App cannot be resolved by slug (GET /apps/{slug} 404s unless the App is public or the caller authenticates as the App itself), so callers pass the ID with a comment naming the App."
  type        = list(number)
  default     = []
}

variable "required_status_checks" {
  description = "Check contexts that must pass before merging. Empty enforces no required checks — GitHub has no \"require all checks\" option, and a context is only selectable once it has run on the protected branch."
  type        = list(string)
  default     = []
}
