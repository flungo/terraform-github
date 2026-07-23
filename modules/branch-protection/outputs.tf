output "id" {
  description = "The repository ruleset ID."
  value       = github_repository_ruleset.this.id
}

output "node_id" {
  description = "GraphQL node ID of the ruleset."
  value       = github_repository_ruleset.this.node_id
}
