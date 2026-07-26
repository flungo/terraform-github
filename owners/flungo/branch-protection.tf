# Standard branch protection for the flungo repositories, via the shared
# branch-protection module (../../modules/branch-protection). Applied first to
# authentik.flungo.net as the pilot; github-workflows and claude-plugins follow
# once it is proven (claude-plugins needs a default branch to exist first).
module "authentik_flungo_net_protection" {
  source     = "../../modules/branch-protection"
  repository = module.authentik_flungo_net.name
}
