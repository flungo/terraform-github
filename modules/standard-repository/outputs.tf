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

# No default_branch output — see the note in modules/repository/outputs.tf.

output "ruleset_id" {
  description = "ID of the standard branch-protection ruleset."
  value       = module.branch_protection.id
}
