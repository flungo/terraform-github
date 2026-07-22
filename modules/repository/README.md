# Module: `repository`

The standard repository for the `terraform-github` fleet. It wraps a single
`github_repository` and hard-codes the opinionated baseline (feature toggles and
merge strategy) so every repo is uniform; only the genuinely per-repo attributes
are inputs. Change the standard once here and re-apply each owner to roll it out.

The encoded baseline and the rule for growing the input surface are catalogued in
[`docs/reference/standard-repository.md`](../../docs/reference/standard-repository.md).

## Usage

```hcl
module "github_workflows" {
  source = "../../modules/repository"

  name        = "github-workflows"
  description = "Reusable GitHub Actions workflows and shared CI standards."
  topics      = ["terraform", "github-actions", "reusable-workflows", "ci"]
  visibility  = "public"
}
```

The module local name should mirror the repository name with any character invalid
in a Terraform identifier replaced by `_` (e.g. `authentik.flungo.net` →
`module "authentik_flungo_net"`), per [Terraform conventions](../../docs/reference/terraform-conventions.md).

Adopting a repository that already exists on GitHub? Pair the module call with an
`import {}` block targeting the module's internal resource address —
`import { to = module.<name>.github_repository.this, id = "<repo-name>" }` — and
follow [`docs/runbooks/importing-repositories.md`](../../docs/runbooks/importing-repositories.md).

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | — (required) | Repository name; becomes `github_repository.name`. |
| `description` | `string` | — (required) | One-line repository description. |
| `visibility` | `string` | `"private"` | `"public"` or `"private"`. Standard is private; go public only where the repo must be readable/callable by others. |
| `topics` | `list(string)` | `[]` | Repository topics. |
| `auto_init` | `bool` | `true` | Seed an initial commit so `main` exists at creation. Applies only at creation (later drift ignored). Set `false` for an empty repo populated by a bulk push. |

## Outputs

| Name | Description |
|---|---|
| `name` | The repository name. |
| `full_name` | Full name in `owner/name` form. |
| `node_id` | GraphQL node ID (referenced by downstream resources such as branch protection). |
| `repo_id` | Numeric repository ID. |
| `default_branch` | The repository's default branch. |
