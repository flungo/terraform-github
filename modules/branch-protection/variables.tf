variable "repository" {
  description = "Name of the repository to protect (e.g. \"authentik.flungo.net\")."
  type        = string
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

variable "required_status_checks" {
  description = "Check contexts that must pass before merging. Empty enforces no required checks — GitHub has no \"require all checks\" option, and a context is only selectable once it has run on the protected branch."
  type        = list(string)
  default     = []
}
