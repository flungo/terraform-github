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
  description = "Which ref the ruleset targets. Defaults to the repository's default branch (\"~DEFAULT_BRANCH\"); the module protects any branch, so it takes the pattern rather than assuming main. This is **fnmatch**, not regex — no anchoring and no + quantifier, so \"v[0-9]*\" means \"v, one digit, then anything\" and also captures v1x or v2-test. Prefer a glob that cannot under-reach and pair it with restrict_creation, rather than narrowing it: over-reach that nobody can create is harmless, whereas a pattern that misses a real ref fails silently (ADR-008)."
  type        = string
  default     = "~DEFAULT_BRANCH"
}

variable "restrict_creation" {
  description = "When true, only actors with an *always* bypass may create refs matching the pattern (the PR-scoped admin bypass does not cover creation, just as it does not cover deletion). Use where the refs are created by automation rather than by hand: it turns an accidental creation into a clean rejection instead of a branch that the deletion rule then makes undeletable — which is also what makes a deliberately broad pattern safe. Leave false for a ruleset targeting a branch that already exists (the default branch), where it has no effect."
  type        = bool
  default     = false
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
