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

output "default_branch" {
  description = "The repository's default branch."
  value       = github_repository.this.default_branch
}
