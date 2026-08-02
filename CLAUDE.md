# CLAUDE.md — terraform-github

This repository manages GitHub resources as code with Terraform, across the user's personal account and the organisations they administer — under the user's own credentials.

Its scope is **the GitHub provider's surface**, not a fixed feature list.
It starts with a standard repository template and shared/common secrets, and grows to branch protection, webhooks, teams, and other resources exposed by [`integrations/github`](https://registry.terraform.io/providers/integrations/github/latest).
It is named for the provider, not the initial use case, so that growth needs no rename.
See [ADR-001](docs/decisions/001-dedicated-terraform-github-repo.md).

> **Status: build-out under way.** The `owners/flungo/` skeleton, the plan/apply CI, the primitive modules (`repository`, `branch-protection`, `repository-secrets`), and the `standard-repository` composite have landed; each managed flungo repository is a single composite call.
> The remaining build-out is scoped in [`docs/plans/initial-buildout.md`](docs/plans/initial-buildout.md).
> Keep this file, the README, and the ADR index current as resources land.

## Architecture

| Concern | Implementation |
| --- | --- |
| Terraform provider | `integrations/github ~> 6.0` (one provider configuration per owner) |
| State backend | HCP Terraform — org `flungo`, **one workspace per owner directory**, **Local execution mode** (inherited from `terraform-grafana-cloud`) |
| Structure | Directory per owner (`owners/<owner>/`) consuming shared modules (`modules/`) — **not** a single flat root module (see [Terraform conventions](docs/reference/terraform-conventions.md)) |
| CI/CD | GitHub Actions — thin callers of the reusable [`flungo/github-workflows`](https://github.com/flungo/github-workflows) workflows (`@v2`): `terraform.yml` (plan on PR, apply on merge; `working-directory: owners/flungo`, owner-scoped `concurrency-group: terraform-flungo` and `plan-comment-marker`), `markdown-lint.yml` and `markdown-links.yml` (see § Validating Markdown locally), and `flungo-workflows.yml` for the version check. Each caller job is named for the workflow it calls, which is what fixes the check context it reports |
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

When a sensitive value is needed in docs or config, use a placeholder (e.g. `<github-token>`) and note where the real value lives (a GitHub Actions secret, a secrets manager, or an environment variable).
Provider tokens are supplied via `TF_VAR_github_token` from a per-owner Actions secret; they are declared `sensitive = true` and never hard-coded.
The secrets CI uses, and their rotation, are catalogued in [`docs/reference/secrets.md`](docs/reference/secrets.md).

## Repo layout

```text
modules/                Shared, opinionated modules, consumed by owner directories
                        via a relative source path; more are added as the build-out
                        proceeds.
  standard-repository/  The caller-facing composite — one call per managed repo —
                        composing the three primitives below.
  repository/           Baseline repository settings — the standard project template
                        (feature toggles, merge strategy).
  branch-protection/    Branch protection as a repository ruleset — the default
                        branch, plus release branches where a repo declares them.
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

`modules/standard-repository/` is the composite every owner directory consumes — one call per managed repo.
`owners/flungo/` is the first owner directory.

## Terraform conventions

Generic HCL authoring conventions (resource naming, sensitive values, durations, provider pinning + lockfile, `import {}` / `moved {}` blocks) come from the **`terraform-standards`** plugin (`flungo-plugins`, enabled in `.claude/settings.json`).
This repo's structure-specific conventions — directory-per-owner root modules, shared modules encoding the standard, intent-named inputs, by-subject `.tf` grouping, and the key divergence from the sibling repos' single-flat-root pattern — are catalogued in [`docs/reference/terraform-conventions.md`](docs/reference/terraform-conventions.md).
That reference doc is canonical for this repo; consult it, and the plugin, before adding or changing Terraform config here.

**Transient config — things that should never be found at rest.** `import {}` and `moved {}` blocks come out in a follow-up PR once their apply has run (the plugin's convention), and `repository_exists = false` on a `standard-repository` call is the same shape: it exists only for the change that *creates* a repository, and the [creation runbook](docs/runbooks/creating-repositories.md) removes it in the next PR.
Finding any of them on `main` means a runbook was left half-finished — and for `repository_exists` that is not cosmetic, it silently disables the classic-protection guard on that repository ([ADR-009](docs/decisions/009-plan-time-classic-protection-guard.md)).

> **🤖 Agent** — Treat `repository_exists` in an owner directory as a defect, not configuration.
> The repository almost certainly exists by then, so deleting the line is the fix and its plan should be *no changes*.
> Never add it for a repository that already exists, and never carry it over when using an existing repo file as a template.

## Working with this repo in Claude Code

Sessions use the **GitHub MCP** for all GitHub interactions (PRs, CI status, comments) — there is no `gh` CLI.
Use `mcp__github__*` tools.

Once CI exists, on-demand runs are triggered with `mcp__github__actions_run_trigger` (`workflow_id: "terraform.yml"`, `ref: "<branch>"`); after triggering, give the user a direct link (`https://github.com/flungo/terraform-github/actions/runs/<run_id>`) and report the outcome.
(Pattern inherited from `terraform-grafana-cloud`.)

### Validating Terraform locally

CI is the authority — the `terraform.yml` plan on the PR is what proves a change.
But `fmt`/`validate` locally first catches syntax and type errors without burning a CI round-trip.

**How to get a `terraform` binary in a cloud session, the egress allowlist, and why `CHECKPOINT_DISABLE=1` is worth setting come from the `claude-code-web` plugin** (`cloud-sessions` → `references/egress-and-tooling.md`), which carries that recipe for every Terraform repo rather than each repo restating it.
Only this repo's own arguments belong here:

```bash
$S/terraform fmt -check -recursive          # from the repo root; needs no provider
cd owners/flungo                            # the owner directory is the root module
$S/terraform init -backend=false            # -backend=false: no HCP token needed
$S/terraform validate
```

**Afterwards:** delete `owners/<owner>/.terraform/` (gitignored, and large).
**Keep `.terraform.lock.hcl` — it is committed** (see [Terraform conventions](docs/reference/terraform-conventions.md)).
If `init` modified it, that is a real change: review and commit it deliberately rather than discarding it.

`validate` is clean — no warnings.
Treat any it does emit as caused by your change, not as background noise.
Local `plan` is not possible: it needs both the HCP backend token and a GitHub token.

### Validating Markdown locally

Both commands, where to read the linter version from (a CI run — never a number written down here), how to install `lychee` in this sandbox, and why the external URL sweep cannot be verified locally all come from the **`markdown-standards`** plugin's `validating-locally.md`.
There is nothing repo-specific to add: this repo runs the fleet's two checks with the fleet's globs.

## Branch management

Branch and PR hygiene comes from the **`git-conventions`** plugin (`flungo-plugins`, enabled in `.claude/settings.json`): never commit to `main` — a feature branch per change; at session start pull `main` and branch (confirm before continuing on an existing non-`main` branch); fetch and rebase onto `main` before finishing; [Conventional Commits](https://www.conventionalcommits.org/); linear history — squash a single logical change, rebase (no squash) to preserve several distinct ones; rebase hygiene — amend rather than leaving fix-up commits; force-push feature branches only, never `main`; land via PR and delete the branch after merge; and monitor PRs via activity subscriptions, not `send_later`.
The plugin complements this file; where this repo differs, this file wins.

## Documentation standards

Documentation conventions come from the **`docs-standards`** plugin (`flungo-plugins`, enabled in `.claude/settings.json`): the Diátaxis `docs/` split (`decisions/`, `plans/`, `runbooks/`, `reference/`, each with a `README.md` index kept current in the same commit), the Nygard ADR format, the ephemeral two-PR plan lifecycle, the 🤖 Agent / Verify callouts, semantic line breaks, and the end-of-session staleness scan — for which the plugin ships the `Stop` hook that prints the doc-maintenance checklist.
The plugin complements this file; where this repo differs, this file wins.

Markdown authoring conventions come from the **`markdown-standards`** plugin (`flungo-plugins`, enabled in `.claude/settings.json`): semantic line breaks (one sentence per source line, `MD013` off), unique names for cross-referenced headings (`MD024` `siblings_only`), compact tables including their delimiter rows (`MD060`), and how to fix an adjacent-blockquote finding rather than suppress it (`MD028`).
The rules those conventions pair with live in `.markdownlint-cli2.jsonc`, and CI enforces them — see § Validating Markdown locally.
The plugin complements this file; where this repo differs, this file wins.

This repo's specific doc hooks, on top of the plugin's generic ones:

- **New resource type** → update `README.md` → "What this manages".
- **New provider config or variable** → update the relevant directory's `providers.tf` / `variables.tf` docs.
- **New credential** → add a rotation runbook in `docs/runbooks/` and note it in the § Sensitive information list and [`docs/reference/secrets.md`](docs/reference/secrets.md).

### Docs in other repos that mirror this one

Some of this repo's contracts are also documented in the repos that have to *meet* them, because that is where the reader adopting them is looking.
Those copies go stale silently — nothing in this repo's CI reads them — so changing a contract below means opening a PR against the named repo in the same change:

| Contract here | Mirrored in | What goes stale |
| --- | --- | --- |
| The `terraform` flag ([ADR-010](docs/decisions/010-terraform-flag-means-terraform-standards.md)) — the `terraform / terraform` context it requires, the `terraform` caller-job name that context depends on, and the conventional secret names | [`flungo/github-workflows`](https://github.com/flungo/github-workflows) → `docs/runbooks/adopting-terraform-workflows.md` § "Adopting in a repository managed by `terraform-github`" | The naming constraints an adopter must follow, the flag-first ordering, and the fact that the flag now also requires an up-to-date branch (ADR-011) |
| `excluded_status_checks` and the `terraform` flag as they apply to `stalwart.flungo.net` | [`flungo/stalwart.flungo.net`](https://github.com/flungo/stalwart.flungo.net) → `docs/plans/terraform-ci.md` § Phase 3 | What that repo must do to drop its exclusion |

> **🤖 Agent** — Treat the mirrored docs as part of the change, not follow-up work.
> If you lack push access to the repo in question, say so and ask for it (`add_repo`) rather than landing a half-change; the copy that goes stale is the one an adopter reads.

## Active work

| Plan | Status |
| --- | --- |
| [Initial build-out](docs/plans/initial-buildout.md) | In progress — owner skeleton, plan/apply CI, the three primitives (`repository`, `branch-protection`, `repository-secrets`), and the `standard-repository` composite have landed; each managed flungo repo is one composite call (§7 steps 1–7 done). Next: step 8 — onboard the rest of the flungo repos, then App auth and the first org |

## Key decisions

See [`docs/decisions/README.md`](docs/decisions/README.md) for the full index.
Short version:

- Dedicated, provider-scoped `terraform-github` repo; Terraform over UI/scripts; multi-owner (personal + orgs); directory-per-owner consuming shared modules (ADR-001)
- HCP backend, Local execution mode, and GitHub Actions plan/apply CI inherited from `terraform-grafana-cloud` (ADR-002 there); **workspace-per-owner topology** — one HCP workspace per owner directory (`github-<login>`) in a dedicated `terraform-github` project (ADR-002)
- **Standard repository module** (`modules/repository`) encodes the opinionated baseline; owner directories route each repo through it, migrated via `moved {}` blocks; standard first, deviation inputs added only on explicit confirmation (ADR-003)
- **Branch protection via repository rulesets** — a shared `modules/branch-protection` (a `github_repository_ruleset`, not the older `github_branch_protection`) protects default branches: require PR, conversation resolution, linear history, and block deletion; PR-scoped admin bypass unless `strict`; piloted on authentik (ADR-004)
- **Classic-protection guard in the composite, evaluated at plan time** — a pre-existing classic branch protection rule double-enforces against the ruleset, so a `postcondition` fails the plan while one exists.
  It reads the caller's `name` input, not the repository resource's name: Terraform defers a data source that depends on a pending resource, and an adoption always leaves one pending, so the original placement in `modules/branch-protection` evaluated only during apply — after the rulesets it should have blocked were created.
  Living in the composite also means one guard per repository rather than one per ruleset (ADR-009)
- **Standard-repository composite** (`modules/standard-repository`) — the caller-facing surface: one call composes the three primitives per repo.
  Secret values come from one owner-level `local.shared_secrets` source (never wired per repo file); a `manage_secrets` opt-out exists for the self-referential case (terraform-github itself).
  The `terraform` flag's second half — a required plan-check context — was deferred here and resolved by ADR-010 (ADR-006)
- **Release-branch protection with an App push bypass** — the branch-protection primitive takes `name` and `push_bypass_app_ids` (numeric App IDs — private Apps cannot be resolved by slug — `"always"` bypass, kept under `strict`) and encodes `non_fast_forward`; a `release_branches` composite input adds a `"release"` ruleset.
  First case: `github-workflows`' `v*` branches, pushed only by its `flungo-release` App or a merged PR (ADR-007)
- **Release-branch creation restricted to the automation** — ruleset ref targeting is fnmatch, *not* regex, so `v[0-9]*` also reaches `v1x`/`v2-test`; combined with the deletion block (and a PR-scoped admin bypass that does not cover deletion) such a branch was undeletable.
  `restrict_creation` — set by the composite for release rulesets — means only the release App can create a matching ref, turning the trap into a clean rejection.
  The broad glob is then kept on purpose: narrowing to enumerated shapes would silently miss `v100`, and under-reach fails quietly where over-reach nobody can create costs nothing.
  `update` stays unrestricted deliberately: it would block backport PRs (ADR-008)
- **The `terraform` flag means "follows Fabrizio's Terraform standards"** — not "holds Terraform config"; the fleet proved those diverge (only two of five `terraform = true` repos used the shared jobs).
  Both effects follow from the one fact: the HCP token those jobs read is attached, and the `terraform / terraform` check they report is required.
  `required_status_checks` becomes additional-only, and `excluded_status_checks` drops an implied context where a repo follows the standards but cannot report the check (`stalwart.flungo.net`) — a validation rejects a context named in both lists (ADR-010)
- **Branches must be up to date before merging** — `strict_required_status_checks_policy` is encoded in the branch-protection module, not exposed: there is no coherent position that wants a required check but not its strictness, and a second "strict" input beside the existing `strict` (which removes the admin bypass) would misread both.
  The module emits the block it lives in only where contexts are supplied, so it is inert where none are required and arrives with each repository's CI adoption.
  Merge queue — the richer answer — is gated on **organisation** ownership, not plan tier, so no upgrade reaches a personal account (ADR-011)
