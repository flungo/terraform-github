# Standard repository settings

The [`modules/repository`](../../modules/repository) module is the standard
repository for the fleet. It hard-codes the opinionated baseline below so every
repository is uniform, and exposes only the genuinely per-repo attributes as
inputs. This page catalogues what the module encodes, what it leaves to the
caller, and the rule for growing the input surface.

To change the standard fleet-wide, edit it in one place — the module, not each
owner directory — then re-apply each owner to roll the change out.

## Encoded baseline (not configurable)

These are set in the module and are the same for every repository. Changing one
here rolls it out to all repositories on the next apply.

| Setting | Value | Why |
|---|---|---|
| `has_issues` | `true` | Issues are the default tracker; on everywhere. |
| `has_wiki` | `false` | Documentation lives in-repo (`docs/`), not a wiki. |
| `has_projects` | `false` | Project boards are not used at the repo level. |
| `has_downloads` | `false` | GitHub deprecated the Downloads feature; `true` does not persist (the API reports it back as `false`), so the baseline is off to avoid a perpetual plan diff. |
| `allow_merge_commit` | `false` | Linear history — no merge commits. |
| `allow_squash_merge` | `true` | Squash for single logical changes. |
| `allow_rebase_merge` | `true` | Rebase for several distinct changes worth preserving. |
| `delete_branch_on_merge` | `true` | Keeps the branch list tidy after merge. |

## Per-repo inputs (configurable)

| Input | Type | Default | Notes |
|---|---|---|---|
| `name` | `string` | — (required) | The repository name. |
| `description` | `string` | — (required) | One-line description. |
| `visibility` | `string` | `"private"` | `"public"` only where the repo must be readable/callable by others (e.g. hosting reusable workflows). |
| `topics` | `list(string)` | `[]` | Repository topics. |
| `auto_init` | `bool` | `true` | Seed an initial commit so `main` exists at creation. Applies only at creation; the module ignores later drift on it. Set `false` for an empty repo populated by a bulk push. |

## Growing the input surface

The input set is kept small and grown deliberately. A repository is brought to
the **standard by default**; a per-repo deviation from the encoded baseline is
supported by adding an input **only when the user has explicitly confirmed** the
deviation must be supported (see [Terraform conventions](terraform-conventions.md)). When an
input maps to a GitHub provider argument it takes the provider's own name (e.g.
`visibility`); otherwise it is named for the *intent* so one flag can drive
several decisions.

> **🤖 Agent** — When a repository's live setting differs from the encoded
> baseline, propose bringing it to the standard and ask the user to confirm per
> repo; add an input to preserve the deviation only if they say it must be
> supported. Do not add a deviation input speculatively.

## Using the module

- Create a new repository: [`../runbooks/creating-repositories.md`](../runbooks/creating-repositories.md).
- Adopt an existing repository: [`../runbooks/importing-repositories.md`](../runbooks/importing-repositories.md).
