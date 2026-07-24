# ADR-004: Branch protection via repository rulesets

Date: 2026-07-22
Status: Accepted

## Context

Protecting the default branch is one of the motivators for managing GitHub as
code, so the fleet needs a standard, opinionated protection applied to every repo.
The GitHub provider offers two mechanisms:

- **`github_branch_protection`** — the older resource, a single branch's protection
  settings.
- **`github_repository_ruleset`** — the newer, more expressive resource (a repo can
  hold several rulesets; conditions target refs by pattern, including the special
  `~DEFAULT_BRANCH`; bypass is modelled as explicit actors).

The two are **not semantically identical** — bypass is `bypass_actors` on a ruleset
vs `enforce_admins` on branch protection; branch targeting is a `conditions.ref_name`
pattern vs a single `pattern`; and both can even apply to the same branch at once
(double enforcement). Whichever is chosen must be committed to, because migrating
between them later is an error-prone, per-field exercise.

## Decision

Adopt **`github_repository_ruleset`** and encode the standard in a shared
[`modules/branch-protection`](../../modules/branch-protection) module.

- **Default rules** (the catalogue is [`docs/reference/branch-protection.md`](../reference/branch-protection.md)):
  require a pull request before merging (no required approvals — the owner works
  solo — but conversation threads must be resolved), require linear history, restrict
  deletion of the protected branch, and require any named status checks.
- **Target** the repository's default branch via `~DEFAULT_BRANCH`; the module takes
  a `pattern` input rather than hard-coding `main`, so it can protect any branch.
- **Bypass** — a `strict` input (default `false`) controls the admin bypass.
  Non-strict gives admins a **deliberate, `pull_request`-scoped** bypass: they can
  merge a PR that doesn't meet the rules (bootstrap / incident response), but the
  rules still apply by default and admins cannot push straight to the branch —
  `bypass_mode` is `"pull_request"`, not `"always"`. `strict = true` removes the
  bypass so the rules bind everyone.
- **Rolled out per repo** through a module call, starting with `authentik.flungo.net`
  as the pilot; the other managed repos follow once it is proven.
- **Guard against classic branch protection** — the module reads the repo's classic
  rules via the `github_branch_protection_rules` data source and a `postcondition`
  fails the plan if any exist. Rulesets and classic `github_branch_protection` both
  apply at once (double enforcement), so an unmanaged legacy rule must not be left
  in place. The guard is read-only — Terraform can't delete a resource it doesn't
  manage — so it surfaces the drift for manual removal rather than reconciling it.
  The data source exposes only each rule's `pattern`, so the CI plan job fetches the
  full classic settings (GraphQL) when the guard fails, feeding the compare-before-remove
  migration in [`docs/runbooks/migrating-classic-protection-to-ruleset.md`](../runbooks/migrating-classic-protection-to-ruleset.md).

## Consequences

**Positive:**
- The modern resource: ref-pattern targeting, `~DEFAULT_BRANCH` (no need to name the
  branch), and room to grow (multiple rulesets, richer rules).
- The standard is defined once in the module and rolled out by re-applying each owner.
- The classic-protection guard makes double enforcement a plan-time error, so a repo
  can't quietly carry both a legacy rule and the ruleset.

**Negative / trade-offs:**
- Rulesets and `github_branch_protection` are not interchangeable; if we ever migrate
  to the other resource we must translate each field deliberately and delete the
  legacy resource in the same change (leaving both double-enforces).
- The admin-bypass actor is referenced by a built-in role ID (`5` = Admin), a magic
  number the provider requires — documented in the module.
