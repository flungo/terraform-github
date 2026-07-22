# ADR-003: Standard repository module

Date: 2026-07-21
Status: Accepted

## Context

ADR-001 chose a directory-per-owner structure "consuming shared modules", but the
first repositories were written as inline `github_repository` resources directly in
`owners/flungo/repositories.tf` while the setup was proven — `authentik.flungo.net`
(adopted via import) plus `github-workflows` and `claude-plugins` (created by
config). With three repositories now managed, the opinionated settings were
duplicated across each resource: the point at which the shared module ADR-001
anticipated should be extracted, so the standard lives in one place.

Two things had to be decided: the module's shape (what it encodes vs exposes), and
how to move already-managed resources into it without Terraform destroying and
recreating live repositories.

## Decision

Extract [`modules/repository`](../../modules/repository) — the **standard
repository** — and route every owner-directory repository through it.

- **One `github_repository "this"` per module call.** The module's local resource
  name is the idiomatic `this`; the *module call's* local name mirrors the
  repository name (`module "authentik_flungo_net"`), keeping the naming convention
  at the owner-directory level.
- **Encode the baseline; expose only per-repo variation.** Feature toggles (issues
  on; wiki/projects/downloads off) and merge strategy (merge off; squash +
  rebase on; delete-branch-on-merge on) are hard-coded. Inputs are `name`,
  `description`, `visibility` (default `private`), `topics`, and `auto_init`. The
  catalogue lives in [`docs/reference/standard-repository.md`](../reference/standard-repository.md).
- **Standard first; grow inputs deliberately.** A repository is brought to the
  baseline by default; an input to preserve a deviation is added only on explicit
  user confirmation (per `CLAUDE.md` § Terraform conventions).
- **Migrate with `moved {}` blocks.** Each existing resource is relocated from its
  top-level address to `module.<name>.github_repository.this` via a `moved` block,
  so the refactor is a state move — not a destroy/recreate. The blocks are removed
  in a follow-up once the migrating apply has run (mirroring the import-block
  adopt-then-remove pattern).
- **`authentik.flungo.net` is standardised.** Its previously-enabled Projects
  (a deviation kept at adoption) is turned off to match the baseline rather than
  adding a `has_projects` input — the single behavioural change in the migration.

## Consequences

**Positive:**
- The standard is defined once; changing the module and re-applying rolls it out to
  every repository.
- Owner directories stay thin — a module call with a few intent-named inputs.
- The migration is safe: `moved` blocks preserve the live repositories and their
  state; the PR-posted plan shows `0 to destroy`.

**Negative / trade-offs:**
- A layer of module indirection between the owner directory and the resource.
- The encoded baseline cannot vary per repo without adding an input — intended, but
  it means a genuine deviation is a deliberate change to the module's surface, not a
  quick edit in the owner directory.
- `moved` blocks linger in the owner directory until the follow-up removes them.
