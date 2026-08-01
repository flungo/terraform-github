output "name" {
  description = "The repository name."
  value       = github_repository.this.name
}

output "full_name" {
  description = "The full repository name in \"owner/name\" form."
  value       = github_repository.this.full_name
}

output "node_id" {
  description = "GraphQL node ID — the identifier downstream resources such as branch protection reference."
  value       = github_repository.this.node_id
}

output "repo_id" {
  description = "Numeric repository ID."
  value       = github_repository.this.repo_id
}

# There is deliberately no default_branch output. The provider deprecated
# github_repository.default_branch (setting a default branch is what
# github_branch_default is for), so exposing it emitted a deprecation warning on
# every validate for an output nothing consumed — branch protection targets the
# default branch by the ruleset's own ~DEFAULT_BRANCH condition, not by name.
# If a caller ever needs the name, read data.github_repository, whose
# default_branch attribute is not deprecated; do not restore the resource
# attribute.
