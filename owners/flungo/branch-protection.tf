# Standard branch protection for the flungo repositories, via the shared
# branch-protection module (../../modules/branch-protection). Piloted on
# authentik.flungo.net, then rolled out to the remaining managed repos
# (github-workflows, claude-plugins).
module "authentik_flungo_net_protection" {
  source     = "../../modules/branch-protection"
  repository = module.authentik_flungo_net.name
}

module "github_workflows_protection" {
  source     = "../../modules/branch-protection"
  repository = module.github_workflows.name
}

module "claude_plugins_protection" {
  source     = "../../modules/branch-protection"
  repository = module.claude_plugins.name
}
