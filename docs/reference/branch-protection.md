# Standard branch protection

The [`modules/branch-protection`](../../modules/branch-protection) module protects a
repository branch — by default, the default branch — with a `github_repository_ruleset` (see
[ADR-004](../decisions/004-branch-protection-rulesets.md) for the ruleset-over-branch-protection
choice). This page catalogues the rules it encodes and the inputs it exposes.
A repository can carry several instances (distinct `name`s): the composite adds a
second, `"release"` ruleset where a repo declares release branches
([ADR-007](../decisions/007-release-branch-protection.md)).

To change the standard fleet-wide, edit the module in one place — not each owner
directory — then re-apply each owner to roll the change out.

## Encoded rules (not configurable)

The ruleset is `target = "branch"`, `enforcement = "active"`, and applies these rules:

| Rule | Value | Why |
|---|---|---|
| Pull request required | yes, `required_approving_review_count = 0` | Changes go through a PR, but no approval is required — the owner works solo, so requiring one would block their own PRs. |
| Conversation resolution | `required_review_thread_resolution = true` | Review threads must be resolved before merge. |
| Linear history | `required_linear_history = true` | No merge commits. |
| Block force-pushes | `non_fast_forward = true` | Redundant while a pull request is required — that already blocks every direct push — but encoded so the guarantee is explicit and survives any future relaxation of the PR rule. |
| Restrict deletion | `deletion = true` | A protected branch must not be deletable (only `always`-bypass actors may). GitHub blocks deleting the default branch anyway, but the module protects any branch, so this doesn't rely on that. |
| Branches up to date before merging (only where checks are required) | `strict_required_status_checks_policy = true` | A check that passed against a stale base says nothing about the merge — two pull requests can each be green against an older `main` and break it together. Encoded rather than exposed: it is what makes a required check mean anything. The block it lives in is emitted only when contexts are supplied, so it is absent entirely where `required_status_checks` is empty — including on release rulesets, which are passed none. See [ADR-011](../decisions/011-strict-required-status-checks.md). |

One further rule is **switchable** rather than encoded: `creation` — restricting
who may create a matching ref — is off by default and driven by the
`restrict_creation` input below.

## Per-repo inputs (configurable)

| Input | Type | Default | Notes |
|---|---|---|---|
| `repository` | `string` | — (required) | Repository name to protect. |
| `name` | `string` | `"standard"` | The ruleset's name in the repository's rules settings. A second ruleset on the same repository needs a distinct name (the composite's release-branch instance uses `"release"`). |
| `pattern` | `string` | `"~DEFAULT_BRANCH"` | Ref the ruleset targets; the module protects any branch, so it takes a pattern rather than assuming `main`. **fnmatch, not regex** — see [Pattern syntax](#pattern-syntax). |
| `restrict_creation` | `bool` | `false` | Only `always`-bypass actors may create matching refs — the PR-scoped admin bypass does not cover creation, so admins cannot either. For refs created by automation; no effect on a branch that already exists, and what makes a deliberately broad `pattern` safe. See [ADR-008](../decisions/008-restrict-release-branch-creation.md). |
| `strict` | `bool` | `false` | When `true`, removes the admin bypass entirely so the rules bind everyone. When `false`, admins keep a deliberate, PR-scoped bypass (override within a pull request); the rules still apply by default and admins cannot push straight to the branch. |
| `push_bypass_app_ids` | `list(number)` | `[]` | Numeric IDs of GitHub Apps that may push directly to the protected branch — an `"always"` bypass exempting them from every rule. For narrowly-scoped automation identities only (e.g. a release workflow's App); annotate each ID with the App it names. See [Bypass](#bypass). |
| `required_status_checks` | `list(string)` | `[]` | Check contexts that must pass before merging. Empty enforces none — GitHub has no "require all checks" option, and a context is only selectable once it has run on the protected branch. Supplying any context also activates the up-to-date-branch rule above, which is absent entirely while the list is empty. |

## Pattern syntax

Ruleset ref targeting is **fnmatch**, not regex. There is no anchoring and no `+`
quantifier: `[0-9]` matches exactly one digit and `*` then matches *any* remaining
characters. So `refs/heads/v[0-9]*` does **not** mean "v followed by digits" — it
also matches `v1x`, `v2-test` and `v9-scratch`.

That matters more than it looks: `deletion` is blocked for everything a pattern
matches, and the admin bypass is pull-request-scoped and does not cover deletion,
so an over-reaching pattern could leave a stray branch that **no human can delete**.

The fix is `restrict_creation`, **not** a narrower pattern. Restricting creation
means nobody can make the extra refs an over-reaching glob covers, so the
over-reach costs nothing — while narrowing invites the opposite and worse failure:
an enumerated pattern (`v[0-9]`, `v[0-9][0-9]`) silently misses `v100`, leaving a
real release branch unprotected with nothing to surface it. Prefer a glob that
cannot under-reach, and pair it with `restrict_creation`. See
[ADR-008](../decisions/008-restrict-release-branch-creation.md).

## Bypass

While `strict = false`, the built-in **Admin** repository role (`actor_id = 5`,
`actor_type = "RepositoryRole"`) gets a **`pull_request`** bypass — an admin may
merge a pull request that doesn't meet the rules, but the rules still apply by
default and direct pushes to the branch stay blocked even for admins. The bypass is
a deliberate action, never automatic. Setting `strict = true` drops the bypass block
entirely, binding everyone.

Each App in `push_bypass_app_ids` gets an **`always`** bypass
(`actor_type = "Integration"`), exempting it from every rule in the ruleset —
direct pushes included. That is the mechanism for release automation (an App whose
short-lived token a workflow mints in-run, e.g. `flungo-release` fast-forwarding
`github-workflows`' `v*` branches), so unlike the admin bypass it is **not**
dropped by `strict`. Apps are referenced by their numeric ID — public,
safe-to-commit information, annotated with a comment naming the App — because a
private App cannot be resolved by slug (`GET /apps/{slug}` 404s unless the App is
public or the caller authenticates as the App itself).
See [ADR-007](../decisions/007-release-branch-protection.md).

## Classic-protection guard

GitHub applies rulesets and classic branch protection (`github_branch_protection`,
the repo's Settings → Branches) *both at once* — a repo can carry both and they
double-enforce. The guard against that does **not** live in this module: it is in
the [`standard-repository`](standard-repository.md) composite, which reads the
repo's classic rules with the `github_branch_protection_rules` data source and
fails the plan via a `postcondition` if any exist.

It sits there for two reasons ([ADR-009](../decisions/009-plan-time-classic-protection-guard.md)).
It must read a repository name that is **known at plan time**: sourcing the name
from the repository resource made Terraform defer the read to apply whenever that
resource had pending changes — which an adoption always does — so the guard
evaluated too late to stop anything. And its scope is the *repository*, not the
ruleset — it asks whether the repo carries classic protection at all, and the data
source returns every classic rule in one read, so running it per ruleset repeats
an identical query for no extra cover. It is also where the repo-wide baseline
lives, and "rulesets, not classic protection" is a repo-wide policy.

A direct caller of this module is therefore unguarded, and should check for
classic rules itself. Every managed repository goes through the composite, so in
practice the guard is unconditional across the fleet.
