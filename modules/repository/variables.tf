variable "name" {
  description = "Repository name (e.g. \"github-workflows\"). Becomes github_repository.name; the caller's module local name should mirror it with invalid identifier characters replaced by \"_\" (see CLAUDE.md § Terraform conventions)."
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

  validation {
    condition     = contains(["public", "private"], var.visibility)
    error_message = "visibility must be \"public\" or \"private\"."
  }
}

variable "topics" {
  description = "Repository topics (optional)."
  type        = list(string)
  default     = []
}

variable "auto_init" {
  description = "Seed an initial commit so the default branch exists at creation. Applies only when the repository is created and has no effect afterwards, so the module ignores later drift on it — a caller of an already-created repo can leave it at the default. Default true suits populating via the branch + PR flow; set false to create an empty repo whose first bulk push establishes main."
  type        = bool
  default     = true
}
