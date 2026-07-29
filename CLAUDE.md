# CLAUDE.md — terraform-github

This repository manages GitHub resources as code with Terraform, across the user's personal account and the organisations they administer — under the user's own credentials.

Its scope is **the GitHub provider's surface**, not a fixed feature list. It starts with a standard repository template and shared/common secrets, and grows to branch protection, webhooks, teams, and other resources exposed by [`integrations/github`](https://registry.terraform.io/providers/integrations/github/latest). It is named for the provider, not the initial use case, so that growth needs no rename. See [ADR-001](docs/decisions/001-dedicated-terraform-github-repo.md).

> **Status: build-out under way.** The `owners/flungo/` skeleton, the plan/apply CI, the primitive modules (`repository`, `branch-protection`, `repository-secrets`), and the `standard-repository` composite have landed; each managed flungo repository is a single composite call. The remaining build-out is scoped in [`docs/plans/initial-buildout.md`](docs/plans/initial-buildout.md). Keep this file, the README, and the ADR index current as resources land.

## Architecture

| Concern | Implementation |
|---|---|
| Terraform provider | `integrations/github ~> 6.0` (one provider configuration per owner) |
| State backend | HCP Terraform — org `flungo`, **one workspace per owner directory**, **Local execution mode** (inherited from `terraform-grafana-cloud`) |
| Structure | Directory per owner (`owners/<owner>/`) consuming shared modules (`modules/`) — **not** a single flat root module (see [Terraform conventions](docs/reference/terraform-conventions.md)) |
| CI/CD | GitHub Actions — a thin caller of the reusable [`flungo/github-workflows`](https://github.com/flungo/github-workflows) `terraform.yml` (`@v1`); plan on PR, apply on merge. `working-directory: owners/flungo`, owner-scoped `concurrency-group: terraform-flungo` and `plan-comment-marker` |
| Secrets | GitHub Actions secrets — not HCP workspace variables |

## Sensitive information — never commit or expose

**Never include in any file, commit, or output:**
- GitHub tokens — Personal Access Tokens (classic or fine-grained), `GITHUB_TOKEN`, OAuth tokens
- GitHub App private keys, client secrets, or installation tokens
- Webhook secrets
- The **values** of any Actions / Dependabot secret or variable
- HCP Terraform API tokens (`TF_TOKEN_APP_TERRAFORM_IO`)
- Any other password, private key, or bearer token

**Safe to include** (appears, or would appear, in plain-text Terraform config or public docs):
- GitHub usernames, organisation names, team names and slugs
- Repository names, topics, descriptions, visibility
- Actions secret / variable **names** (never their values)
- Webhook URLs (not their secrets), branch and ruleset names
- Public keys, GitHub App IDs and client IDs (not secrets)

When a sensitive value is needed in docs or config, use a placeholder (e.g. `<github-token>`) and note where the real value lives (a GitHub Actions secret, a secrets manager, or an environment variable). Provider tokens are supplied via `TF_VAR_github_token` from a per-owner Actions secret; they are declared `sensitive = true` and never hard-coded. The secrets CI uses, and their rotation, are catalogued in [`docs/reference/secrets.md`](docs/reference/secrets.md).

## Repo layout

```
modules/                Shared, opinionated modules, consumed by owner directories
                        via a relative source path; more are added as the build-out
                        proceeds.
  standard-repository/  The caller-facing composite — one call per managed repo —
                        composing the three primitives below.
  repository/           Baseline repository settings — the standard project template
                        (feature toggles, merge strategy).
  branch-protection/    Default-branch protection, as a repository ruleset.
  repository-secrets/   Shared Actions secrets — LYCHEE_GITHUB_TOKEN on every repo,
                        plus the HCP token where the repo holds Terraform config.
owners/
  flungo/               The personal (user) account, by login — its own HCP workspace,
                        provider, and state. The only user account; named by login.
  <organisation>/       One directory per organisation account (every non-flungo owner
                        is an org). "owner" is GitHub's own term — the {owner} in
                        /repos/{owner}/{repo} and the provider's `owner` argument —
                        which is why the container is `owners/` (not the UI term
                        "accounts/"). "namespace"/"group" are GitLab terms, not GitHub's.
docs/
  decisions/            ADRs — numbered, never deleted or renumbered. README.md is the index.
  plans/                One-time build/onboarding procedures with status tracking; retired
                        (deleted) when complete. README.md is the index.
  runbooks/             Repeatable operational procedures (owner onboarding, token rotation,
                        importing repos). README.md is the index.
  reference/            Information-oriented lookup docs (standard-settings catalogue, shared-
                        secret names, provider coverage map). README.md is the index.
```

`modules/standard-repository/` is the composite every owner directory consumes — one call per managed repo. `owners/flungo/` is the first owner directory.

## Terraform conventions

Generic HCL authoring conventions (resource naming, sensitive values, durations, provider pinning + lockfile, `import {}` / `moved {}` blocks) come from the **`terraform-standards`** plugin (`flungo-plugins`, enabled in `.claude/settings.json`). This repo's structure-specific conventions — directory-per-owner root modules, shared modules encoding the standard, intent-named inputs, by-subject `.tf` grouping, and the key divergence from the sibling repos' single-flat-root pattern — are catalogued in [`docs/reference/terraform-conventions.md`](docs/reference/terraform-conventions.md). That reference doc is canonical for this repo; consult it, and the plugin, before adding or changing Terraform config here.

## Working with this repo in Claude Code

Sessions use the **GitHub MCP** for all GitHub interactions (PRs, CI status, comments) — there is no `gh` CLI. Use `mcp__github__*` tools.

Once CI exists, on-demand runs are triggered with `mcp__github__actions_run_trigger` (`workflow_id: "terraform.yml"`, `ref: "<branch>"`); after triggering, give the user a direct link (`https://github.com/flungo/terraform-github/actions/runs/<run_id>`) and report the outcome. (Pattern inherited from `terraform-grafana-cloud`.)

## Branch management

Branch and PR hygiene comes from the **`git-conventions`** plugin (`flungo-plugins`, enabled in `.claude/settings.json`): never commit to `main` — a feature branch per change; at session start pull `main` and branch (confirm before continuing on an existing non-`main` branch); fetch and rebase onto `main` before finishing; [Conventional Commits](https://www.conventionalcommits.org/); linear history — squash a single logical change, rebase (no squash) to preserve several distinct ones; rebase hygiene — amend rather than leaving fix-up commits; force-push feature branches only, never `main`; land via PR and delete the branch after merge; and monitor PRs via activity subscriptions, not `send_later`. The plugin complements this file; where this repo differs, this file wins.

## Documentation standards

Documentation conventions come from the **`docs-standards`** plugin (`flungo-plugins`, enabled in `.claude/settings.json`): the Diátaxis `docs/` split (`decisions/`, `plans/`, `runbooks/`, `reference/`, each with a `README.md` index kept current in the same commit), the Nygard ADR format, the ephemeral two-PR plan lifecycle, the 🤖 Agent / Verify callouts, semantic line breaks, and the end-of-session staleness scan — for which the plugin ships the `Stop` hook that prints the doc-maintenance checklist. The plugin complements this file; where this repo differs, this file wins.

This repo's specific doc hooks, on top of the plugin's generic ones:

- **New resource type** → update `README.md` → "What this manages".
- **New provider config or variable** → update the relevant directory's `providers.tf` / `variables.tf` docs.
- **New credential** → add a rotation runbook in `docs/runbooks/` and note it in the § Sensitive information list and [`docs/reference/secrets.md`](docs/reference/secrets.md).

## Active work

| Plan | Status |
|---|---|
| [Initial build-out](docs/plans/initial-buildout.md) | In progress — owner skeleton, plan/apply CI, the three primitives (`repository`, `branch-protection`, `repository-secrets`), and the `standard-repository` composite have landed; each managed flungo repo is one composite call (§7 steps 1–7 done). Next: step 8 — onboard the rest of the flungo repos, then App auth and the first org |

## Key decisions

See [`docs/decisions/README.md`](docs/decisions/README.md) for the full index. Short version:

- Dedicated, provider-scoped `terraform-github` repo; Terraform over UI/scripts; multi-owner (personal + orgs); directory-per-owner consuming shared modules (ADR-001)
- HCP backend, Local execution mode, and GitHub Actions plan/apply CI inherited from `terraform-grafana-cloud` (ADR-002 there); **workspace-per-owner topology** — one HCP workspace per owner directory (`github-<login>`) in a dedicated `terraform-github` project (ADR-002)
- **Standard repository module** (`modules/repository`) encodes the opinionated baseline; owner directories route each repo through it, migrated via `moved {}` blocks; standard first, deviation inputs added only on explicit confirmation (ADR-003)
- **Branch protection via repository rulesets** — a shared `modules/branch-protection` (a `github_repository_ruleset`, not the older `github_branch_protection`) protects default branches: require PR, conversation resolution, linear history, and block deletion; PR-scoped admin bypass unless `strict`; guards against pre-existing classic protection; piloted on authentik (ADR-004)
- **Standard-repository composite** (`modules/standard-repository`) — the caller-facing surface: one call composes the three primitives per repo. Secret values come from one owner-level `local.shared_secrets` source (never wired per repo file); a `manage_secrets` opt-out exists for the self-referential case (terraform-github itself). The `terraform` flag attaches the HCP secret but does not yet add a required plan-check context (fleet CI isn't uniform) (ADR-006)
