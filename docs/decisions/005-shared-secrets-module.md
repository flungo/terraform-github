# ADR-005: Shared secrets via the repository-secrets module

Date: 2026-07-27 Status: Accepted

## Context

Managed repositories need a common set of GitHub Actions secrets — starting with `LYCHEE_GITHUB_TOKEN` (the token the lychee Markdown link-checker uses in CI on every repo) and, for repos that hold Terraform config, `TF_TOKEN_APP_TERRAFORM_IO` (the org-wide HCP token so they can plan/apply in their own CI).
Two problems shape the design:

- **Personal/org asymmetry.** An organisation has `github_actions_organization_secret` (`visibility = all|private|selected`) — one resource covers many repos.
  A personal account has no org-level secret; a shared secret must be set per repository via `github_actions_secret`.
  The personal and org cases need different resources.
- **The values must reach CI.** `github_actions_secret` requires the plaintext value at plan/apply time.
  But the secrets that gate *this* repo's own CI (the provider token, the HCP backend token) are deliberately kept as manually-managed Actions secrets, not Terraform-managed, so a broken apply can't lock the repo out of its own credentials.
  The reusable `terraform.yml` (this repo's CI) previously passed only the single provider token, so there was no way to feed additional values in.

## Decision

- **A dedicated `modules/repository-secrets`** wraps `github_actions_secret` and applies the common set to one repository: `LYCHEE_GITHUB_TOKEN` on every repo, and `TF_TOKEN_APP_TERRAFORM_IO` gated on a `terraform` flag (its primary effect).
  The org-level case (`github_actions_organization_secret`) is a separate future `org-secrets` module — capturing the asymmetry is exactly why shared secrets are their own module rather than folded into `repository`.
- **Values arrive via `tf_secret_vars`.** The reusable `terraform.yml` gained an optional `tf_secret_vars` secret ([flungo/github-workflows#16](https://github.com/flungo/github-workflows/pull/16)) — a JSON map of *secret* values it explodes into masked `TF_VAR_*` env vars.
  The owner's caller composes that map from its own Actions secrets with `toJSON` (escape-safe), so each secret stays independently managed and no specific value is hard-coded in the shared workflow.
  The consuming variables are `sensitive`, so plan output and the plan artifact redact them.
- **Terraform-managing these is safe** because they are written to *other* repos — the circularity concern applies only to the tokens gating this repo's own CI, which stay manual **for now**.
  Managing this repo's *own* secrets is a planned later step and is not inherently unsafe: those values are defined from the repo's own secrets, so an apply is a same-value noop and self-stable.
  When secret management is standardised across the fleet, this repo will either lean on that noop self-stability or take an explicit opt-out from managing its own CI-gating tokens; until then they remain manually managed.
- **Piloted on `authentik.flungo.net`** (`terraform = true`), following the same one-repo-first sequence as the repository and branch-protection modules.

## Consequences

**Positive:**

- The common secret set is defined once and rolled out by re-applying each owner; onboarding a repo attaches the shared secrets through one module call.
- `tf_secret_vars` is a generic seam — any future shared secret is another key in the owner-composed JSON and another input on the module, with no workflow change.
- The personal/org split is explicit, so the org case can be added cleanly later.

**Negative / trade-offs:**

- The secret values are exported as masked `TF_VAR_*` environment variables on the CI runner.
  They are kept out of logs (each `::add-mask::`ed) and out of plan output and the plan artifact (`sensitive` variables + the provider marking `plaintext_value` sensitive) — the standard exposure for Terraform variables in CI.
- Two modules will exist for one concept (`repository-secrets` + a future `org-secrets`) because GitHub models per-repo and org secrets differently.
