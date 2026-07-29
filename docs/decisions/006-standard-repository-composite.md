# ADR-006: Standard-repository composite module

Date: 2026-07-29
Status: Accepted

## Context

The three primitive modules — `repository`
([ADR-003](003-standard-repository-module.md)), `branch-protection`
([ADR-004](004-branch-protection-rulesets.md)), and `repository-secrets`
([ADR-005](005-shared-secrets-module.md)) — each landed and were proven on
`authentik.flungo.net`. Every managed repository is meant to get all three, so an
owner directory currently writes three module calls per repo, wiring the
repository name and the shared-secret variables into each by hand. The intended
end state has always been a composite over the primitives — one call that yields
a fully-standardised repository, so an owner directory stays the thin consumer
[ADR-001](001-dedicated-terraform-github-repo.md) envisioned.

Four design points needed settling at implementation:

- **The caller-facing input surface** — which of the primitives' inputs the
  composite re-exposes.
- **How the shared secret values reach each call** — the primitives take them as
  per-call inputs, which would have every repo file wiring the same owner-wide
  values.
- **Whether a repo can opt out of secret management** — `terraform-github`
  itself (deliberately onboarded last) must not have Terraform manage the very
  tokens that gate its own CI ([ADR-005](005-shared-secrets-module.md)'s
  circularity note).
- **Whether the `terraform` flag adds the Terraform plan check to
  `required_status_checks`** — the intent settled in the build-out review
  (2026-07-20) was that it should, by convention.

## Decision

Add [`modules/standard-repository`](../../modules/standard-repository), a
composite of the three primitives, and route every owner-directory repository
through it as a single module call per repo (one per by-subject file).

- **Thin composition, no resources of its own.** The composite only wires the
  primitives together: `repository` feeds its `name` output to
  `branch_protection` and `secrets`. Baselines stay encoded in the primitives;
  the composite adds no new opinion.
- **Input surface**: the repository inputs (`name`, `description`, `visibility`,
  `topics`, `auto_init`), the protection inputs (`strict`,
  `required_status_checks`), and the secrets inputs (`terraform`,
  `manage_secrets`, `shared_secrets`). The branch-protection `pattern` is *not*
  exposed — it stays at the primitive's `~DEFAULT_BRANCH` default, so the
  composite protects the default branch without knowing its name. The catalogue
  lives in
  [`docs/reference/standard-repository.md`](../reference/standard-repository.md).
- **Shared secret values are sourced once at owner level.** Instead of
  individual per-call value inputs, the composite takes a single sensitive
  `shared_secrets` object (`lychee_github_token`, optional `hcp_token`). The
  owner directory composes it **once** in a `locals` block from its sensitive
  variables, and every call passes the same `local.shared_secrets` reference.
  Terraform has no implicit variable inheritance into child modules, so one
  uniform reference is the closest available expression of "define once": adding
  a shared secret touches the owner's variables/local and the modules — never
  the repo files.
- **A `manage_secrets` opt-out, default `true`.** When `false`, the composite
  skips the `repository-secrets` primitive entirely (`shared_secrets` may then
  be omitted — validated). This exists for the self-referential case:
  `terraform-github`'s own CI-gating tokens stay manually managed
  ([ADR-005](005-shared-secrets-module.md)), so its onboarding can take the
  standard settings and protection without Terraform managing its secrets.
- **The `terraform` flag does not (yet) add a plan check context.** The settled
  intent was for `terraform = true` to append the Terraform plan check to
  `required_status_checks` by convention. Implementation showed the fleet is not
  ready: a ruleset's required context that a repo's CI never reports blocks its
  merges behind a perpetual "Expected" entry, the context string is
  caller-job-dependent (`terraform / terraform` on this repo), and
  `authentik.flungo.net` — the pilot, `terraform = true` — has **no Terraform
  workflow at all** yet. So the flag's effect remains the HCP token secret only;
  callers list contexts their CI actually reports via `required_status_checks`.
  Wiring the flag to append the conventional context is revisited once Terraform
  CI is standardised across the fleet.
- **Migrate with `moved {}` blocks; the standard applies in full.** Each repo's
  three (or two) module calls collapse to one composite call, with `moved`
  blocks relocating the existing state (resource-level for the repository, which
  keeps its module-call name; module-level for the protection and secrets calls)
  — removed in a follow-up once the migrating apply has run, per
  [Terraform conventions](../reference/terraform-conventions.md). Because the
  composite always attaches the shared secrets, migrating `github-workflows` and
  `claude-plugins` — which had none — *adds* their `LYCHEE_GITHUB_TOKEN` secret:
  the intended fleet-wide standard, landing as a side effect of the migration
  rather than a separate rollout.

## Consequences

**Positive:**

- Onboarding a repository is one module call with a handful of intent-named
  inputs — the thin-consumer shape the directory-per-owner structure was
  designed around.
- The full standard is indivisible by default: a repo cannot pick up the standard
  settings while silently skipping protection, and skipping the shared secrets is
  an explicit, intent-named opt-out reserved for the self-referential case — not
  something a caller does by omission.
- Adding a shared secret never touches the repo files — only the owner's
  variables/local and the modules.
- The primitives remain independently usable where a genuine partial case
  appears.

**Negative / trade-offs:**

- Two levels of module nesting (`owner → composite → primitive`); state addresses
  lengthen accordingly (`module.<repo>.module.repository.github_repository.this`).
- The composite's input surface must track the primitives' — an input added to a
  primitive is invisible to composite callers until re-exposed.
- The `terraform` flag's required-check effect diverges from the settled intent
  until fleet CI standardises — recorded here rather than silently dropped.
