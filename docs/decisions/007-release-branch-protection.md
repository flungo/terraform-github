# ADR-007: Release-branch protection with an App push bypass

Date: 2026-07-29
Status: Accepted

## Context

`github-workflows` versions its reusable workflows with moving major branches
(its ADR-003): consumers pin `@vN`, and its `release.yml` fast-forwards the
current major branch (`v1`, later `v2`, …) to `main` on every merge.
Those branches must move **only** by that workflow's push or a merged PR —
never a direct human or agent push
(flungo/github-workflows#6; the driver for #13 here).

A require-PR ruleset blocks *all* direct pushes — including the release
workflow's fast-forward — unless its push identity is a bypass actor,
and the default `GITHUB_TOKEN` (`github-actions[bot]`) generally cannot be one.
github-workflows#6 therefore gave `release.yml` a dedicated GitHub App
(`flungo-release`, Contents read/write, installed on that repo only):
it mints a short-lived installation token per run and pushes with it,
so the App is the identity to exempt.

The standard `modules/branch-protection` ruleset (ADR-004) had no way to
express an App bypass, and the `standard-repository` composite applied it to
the default branch only.

## Decision

Extend the existing primitives rather than adding a new module:

- `modules/branch-protection` gains two inputs: `name` (a second ruleset on
  the same repository needs a distinct name) and `push_bypass_app_ids` —
  numeric GitHub App IDs granted an `"always"` bypass. Resolving a **slug**
  in-module via the `github_app` data source was tried first (self-describing,
  no magic number) and rejected by reality: `GET /apps/{slug}` returns 404 for
  a **private** App unless the caller authenticates as the App itself, so the
  owner's PAT cannot resolve it. App IDs are public, safe-to-commit
  information; callers annotate each ID with a comment naming the App. Unlike
  the admin bypass, the App bypass is **not** dropped by `strict`: it is the
  mechanism the ruleset exists to encode, not an escape hatch.
- The ruleset also encodes `non_fast_forward = true` (block force-pushes).
  Redundant while a pull request is required — that already blocks every
  direct push — but the guarantee becomes explicit and survives any future
  relaxation of the PR rule.
- `modules/standard-repository` gains a `release_branches` input
  (`{ pattern, push_bypass_app_ids }`, default `null`): when set, a second
  branch-protection instance creates a `"release"` ruleset for that pattern —
  the same standard rules, plus the App bypass. `required_status_checks` is
  deliberately not passed through: the caller's contexts are chosen for PRs
  into the default branch, and a context that never runs on a PR into a
  release branch would block its merges behind a perpetual "Expected" entry.
- First (and motivating) case: `github-workflows` declares
  `release_branches = { pattern = "refs/heads/v[0-9]*",
  push_bypass_app_ids = [4424737] }` — the `flungo-release` App.

## Consequences

**Positive:**

- `main` and `v*` on `github-workflows` move only via a merged PR or the
  release workflow's fast-forward; direct human/agent pushes are rejected.
  Any other repo can adopt the same model with one input.
- ID-based App references need no API lookup at plan time, work for private
  Apps, and are stable across App renames and key rotations.

**Negative / trade-offs:**

- The App ID is a magic number in config — mitigated by the required
  comment naming the App, and it never changes for the App's lifetime.
- An `"always"` bypass exempts the App from *every* rule in the ruleset,
  force-push and deletion blocks included. Accepted: `release.yml` itself
  refuses non-fast-forward moves, and the App is single-permission,
  single-repo.
- The classic-protection guard runs once per module instance, so a repo
  with release branches reads the live classic rules twice per plan —
  a harmless, read-only duplication.
