# The standard repository composite — the one-call "my standard repo". It
# composes the three primitives (repository, branch-protection,
# repository-secrets) so an owner directory instantiates a fully-standardised
# repository with a single module call. Per-repo variation comes in through the
# small caller-facing input set in variables.tf; the opinionated baselines stay
# encoded in the primitives. See docs/reference/standard-repository.md and
# docs/decisions/006-standard-repository-composite.md.

module "repository" {
  source = "../repository"

  name        = var.name
  description = var.description
  visibility  = var.visibility
  topics      = var.topics
  auto_init   = var.auto_init
}
