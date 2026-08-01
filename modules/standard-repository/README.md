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

It does carry one check of its own: a **classic-protection guard** that fails the
plan if the repository still has a classic branch protection rule, which would
double-enforce against the ruleset. It reads `var.name` rather than the repository
resource's name so the check evaluates at plan time even during an adoption, and it
lives here rather than in the branch-protection primitive so it runs once per
repository instead of once per ruleset — see
[ADR-009](../../docs/decisions/009-plan-time-classic-protection-guard.md) and
[`docs/runbooks/migrating-classic-protection-to-ruleset.md`](../../docs/runbooks/migrating-classic-protection-to-ruleset.md).
Creating a brand-new repository is the one case where it must be skipped
(`repository_exists = false`), because the guard cannot query a repository that
does not exist yet — see
[`docs/runbooks/creating-repositories.md`](../../docs/runbooks/creating-repositories.md).

## Usage

```hcl
module "authentik_flungo_net" {
  source = "../../modules/standard-repository"

  name        = "authentik.flungo.net"
  description = "Terraform configuration and documentation for Fabrizio's Authentik server."

  terraform = true # follows Fabrizio's Terraform standards → HCP token + required check

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
| `required_status_checks` | `list(string)` | `[]` | **Additional** required check contexts, beyond any implied by the standards flags. No wildcards — GitHub names contexts individually, and one that never runs blocks merges behind a perpetual "Expected" entry. |
| `excluded_status_checks` | `list(string)` | `[]` | Contexts to **remove** from the required set, applied after the implied and additional ones are combined. For a repo that takes a flag's other effects but cannot report the check it implies. A context listed in `required_status_checks` too is rejected by a validation — adding then removing it is the same as never adding it; comment out the `required_status_checks` entry instead. |
| `release_branches` | `object` | `null` | Protect release branches with a second, `"release"` ruleset: `{ pattern, push_bypass_app_ids }` — the ref pattern the branches match (fnmatch, e.g. `"refs/heads/v[0-9]*"`) and the numeric IDs of the GitHub Apps allowed to push *and create* them. See [ADR-007](../../docs/decisions/007-release-branch-protection.md) and [ADR-008](../../docs/decisions/008-restrict-release-branch-creation.md). |
| `terraform` | `bool` | `false` | The repo **follows Fabrizio's Terraform standards** — the `flungo/github-workflows` Terraform jobs, under the conventional job and secret names — not merely "holds Terraform config". Attaches the HCP token those jobs read **and** requires the `terraform / terraform` check they report. See [ADR-010](../../docs/decisions/010-terraform-flag-means-terraform-standards.md). |
| `manage_secrets` | `bool` | `true` | Opt-out of shared-secret management; `false` only for the self-referential case (`terraform-github` itself — see [ADR-005](../../docs/decisions/005-shared-secrets-module.md)). |
| `shared_secrets` | `object` (sensitive) | `null` | The owner-level secret values (`lychee_github_token`, optional `hcp_token`). Required unless `manage_secrets = false`. |
| `repository_exists` | `bool` | `true` | Repository already exists on GitHub. Gates the classic-protection guard; **transient** — set `false` only in the change that creates the repository, then remove it (see [ADR-009](../../docs/decisions/009-plan-time-classic-protection-guard.md)). |

## Outputs

| Name | Description |
|---|---|
| `name` | The repository name. |
| `full_name` | Full name in `owner/name` form. |
| `node_id` | GraphQL node ID of the repository. |
| `repo_id` | Numeric repository ID. |
| `ruleset_id` | ID of the standard branch-protection ruleset. |
