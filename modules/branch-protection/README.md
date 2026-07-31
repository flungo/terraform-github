# Module: `branch-protection`

Standard branch protection for a repository branch — the default branch unless
`pattern` says otherwise — implemented as a
`github_repository_ruleset` (see [ADR-004](../../docs/decisions/004-branch-protection-rulesets.md)
for why a ruleset over the older `github_branch_protection`).

It applies the fleet's default rules — require a pull request, require conversation
resolution, require linear history, block force-pushes, restrict deletion (and
optionally creation), and require any named status checks — with a deliberate admin
bypass (an override *within a pull request*, not a direct-push exemption) unless
`strict` is set. The full catalogue of defaults and inputs is in
[`docs/reference/branch-protection.md`](../../docs/reference/branch-protection.md).

A repository can carry more than one instance under distinct `name`s: the
[`standard-repository`](../standard-repository) composite adds a second, `"release"`
ruleset where a repo declares release branches
([ADR-007](../../docs/decisions/007-release-branch-protection.md)).

> Owner directories normally consume this via the
> [`standard-repository`](../standard-repository) composite rather than calling it
> directly; call it directly only for a genuine partial case.

This module does **not** guard against classic branch protection — a repo carrying
both a classic rule and a ruleset double-enforces, and the guard for that lives in
the [`standard-repository`](../standard-repository) composite, which runs it once
per repository rather than once per ruleset. It must read a repository name known
at plan time, which the composite has and this module does not
([ADR-009](../../docs/decisions/009-plan-time-classic-protection-guard.md)). A
direct caller of this module is therefore unguarded and must check for classic
rules itself — one more reason to go through the composite. The migration
procedure is
[`docs/runbooks/migrating-classic-protection-to-ruleset.md`](../../docs/runbooks/migrating-classic-protection-to-ruleset.md).

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
| `name` | `string` | `"standard"` | The ruleset's name. A second ruleset on the same repository needs a distinct one (the composite's release instance uses `"release"`). |
| `pattern` | `string` | `"~DEFAULT_BRANCH"` | Ref the ruleset targets; defaults to the repo's default branch. **fnmatch, not regex** — `v[0-9]*` also matches `v1x`. Prefer a glob that cannot under-reach and pair it with `restrict_creation`. |
| `restrict_creation` | `bool` | `false` | Only `always`-bypass actors may create matching refs (not admins — their bypass is PR-scoped). For refs created by automation; also what makes a broad `pattern` safe. |
| `strict` | `bool` | `false` | When `true`, remove the admin bypass so the rules bind everyone. |
| `push_bypass_app_ids` | `list(number)` | `[]` | Numeric IDs of GitHub Apps granted an `"always"` bypass, so they may push the branch directly (release automation); annotate each ID with the App it names. Not dropped by `strict`. |
| `required_status_checks` | `list(string)` | `[]` | Check contexts that must pass; empty enforces none. |

## Outputs

| Name | Description |
|---|---|
| `id` | The repository ruleset ID. |
| `node_id` | GraphQL node ID of the ruleset. |
