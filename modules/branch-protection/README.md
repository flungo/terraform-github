# Module: `branch-protection`

Standard branch protection for a repository's default branch, implemented as a
`github_repository_ruleset` (see [ADR-004](../../docs/decisions/004-branch-protection-rulesets.md)
for why a ruleset over the older `github_branch_protection`).

It applies the fleet's default rules — require a pull request, require conversation
resolution, require linear history, and require any named status checks — with a
deliberate admin bypass (an override *within a pull request*, not a direct-push
exemption) unless `strict` is set. The full catalogue of defaults and inputs is
in [`docs/reference/branch-protection.md`](../../docs/reference/branch-protection.md).

The module also **guards against classic branch protection**: it reads the
repository's classic rules and fails the plan if any exist, so a legacy rule can't
silently double-enforce alongside the ruleset. The guard is read-only — Terraform
can't delete an unmanaged classic rule, so it surfaces the drift for removal by
hand (repo Settings → Branches).

## Usage

```hcl
module "authentik_flungo_net_protection" {
  source     = "../../modules/branch-protection"
  repository = module.authentik_flungo_net.name
}
```

Referencing the repository module's `name` output makes the ruleset depend on the
repository — the repo is created/managed before it is protected.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `repository` | `string` | — (required) | Repository name to protect. |
| `pattern` | `string` | `"~DEFAULT_BRANCH"` | Ref the ruleset targets; defaults to the repo's default branch. |
| `strict` | `bool` | `false` | When `true`, remove the admin bypass so the rules bind everyone. |
| `required_status_checks` | `list(string)` | `[]` | Check contexts that must pass; empty enforces none. |

## Outputs

| Name | Description |
|---|---|
| `id` | The repository ruleset ID. |
| `node_id` | GraphQL node ID of the ruleset. |
