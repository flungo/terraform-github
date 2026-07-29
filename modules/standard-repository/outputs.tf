output "name" {
  description = "The repository name."
  value       = module.repository.name
}

output "full_name" {
  description = "The full repository name in \"owner/name\" form."
  value       = module.repository.full_name
}

output "node_id" {
  description = "GraphQL node ID of the repository."
  value       = module.repository.node_id
}

output "repo_id" {
  description = "Numeric repository ID."
  value       = module.repository.repo_id
}

output "default_branch" {
  description = "The repository's default branch."
  value       = module.repository.default_branch
}

output "ruleset_id" {
  description = "ID of the standard branch-protection ruleset."
  value       = module.branch_protection.id
}
