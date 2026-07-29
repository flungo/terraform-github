# Module: `standard-repository`

The caller-facing composite for the `terraform-github` fleet — the one-call "my
standard repo" (see
[ADR-006](../../docs/decisions/006-standard-repository-composite.md)). One call
per managed repository composes the three primitives: [`repository`](../repository)
(baseline settings), [`branch-protection`](../branch-protection) (branch-protection
rulesets — the default branch always, release branches where declared), and
[`repository-secrets`](../repository-secrets) (shared Actions
secrets). The composite wires them together and adds no opinion of its own — the
baselines stay encoded in the primitives; the full catalogue is in
[`docs/reference/standard-repository.md`](../../docs/reference/standard-repository.md).

## Usage

```hcl
module "authentik_flungo_net" {
  source = "../../modules/standard-repository"

  name        = "authentik.flungo.net"
  description = "Terraform configuration and documentation for Fabrizio's Authentik server."

  terraform = true # holds Terraform config → HCP token secret attached

  shared_secrets = local.shared_secrets
}
```

The module local name mirrors the repository name with any character invalid in a
Terraform identifier replaced by `_`, per
[Terraform conventions](../../docs/reference/terraform-conventions.md).
`shared_secrets` is composed **once** at owner level (a `locals` block over the
owner directory's sensitive variables) and passed to every call as the same
uniform reference — repo files never wire individual secret values.

Adopting a repository that already exists on GitHub? Pair the call with an
`import {}` block targeting the composite's internal repository resource —
`import { to = module.<name>.module.repository.github_repository.this, id = "<repo-name>" }`
— and follow
[`docs/runbooks/importing-repositories.md`](../../docs/runbooks/importing-repositories.md);
the protection ruleset and secrets are created (not imported) by the same apply.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | — (required) | Repository name. |
| `description` | `string` | — (required) | One-line repository description. |
| `visibility` | `string` | `"private"` | `"public"` or `"private"`. Standard is private; go public only where the repo must be readable/callable by others. |
| `topics` | `list(string)` | `[]` | Repository topics. |
| `auto_init` | `bool` | `true` | Seed an initial commit so `main` exists at creation (creation-time only; later drift ignored). |
| `strict` | `bool` | `false` | Remove the branch-protection admin bypass so the rules bind everyone. |
| `required_status_checks` | `list(string)` | `[]` | Check contexts that must pass before merging, as reported on the repo's PRs. Empty enforces no checks; a context that never runs blocks merges behind a perpetual "Expected" entry. |
| `release_branches` | `object` | `null` | Protect release branches with a second, `"release"` ruleset: `{ pattern, push_bypass_app_ids }` — the ref pattern the branches match (e.g. `"refs/heads/v[0-9]*"`) and the numeric IDs of the GitHub Apps allowed to push them directly. See [ADR-007](../../docs/decisions/007-release-branch-protection.md). |
| `terraform` | `bool` | `false` | The repo holds Terraform config → attach the HCP token secret. Does **not** (yet) add a plan-check context — see [ADR-006](../../docs/decisions/006-standard-repository-composite.md). |
| `manage_secrets` | `bool` | `true` | Opt-out of shared-secret management; `false` only for the self-referential case (`terraform-github` itself — see [ADR-005](../../docs/decisions/005-shared-secrets-module.md)). |
| `shared_secrets` | `object` (sensitive) | `null` | The owner-level secret values (`lychee_github_token`, optional `hcp_token`). Required unless `manage_secrets = false`. |

## Outputs

| Name | Description |
|---|---|
| `name` | The repository name. |
| `full_name` | Full name in `owner/name` form. |
| `node_id` | GraphQL node ID of the repository. |
| `repo_id` | Numeric repository ID. |
| `default_branch` | The repository's default branch. |
| `ruleset_id` | ID of the standard branch-protection ruleset. |
