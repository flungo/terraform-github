# CLAUDE.md — terraform-github

This repository manages GitHub resources as code with Terraform, across the user's personal account and the organisations they administer — under the user's own credentials.

Its scope is **the GitHub provider's surface**, not a fixed feature list. It starts with a standard repository template and shared/common secrets, and grows to branch protection, webhooks, teams, and other resources exposed by [`integrations/github`](https://registry.terraform.io/providers/integrations/github/latest). It is named for the provider, not the initial use case, so that growth needs no rename. See [ADR-001](docs/decisions/001-dedicated-terraform-github-repo.md).

> **Status: build-out under way.** The `owners/flungo/` skeleton and the plan/apply CI have landed; repositories are managed directly in the owner directory (shared `modules/` are not extracted yet). The remaining build-out is scoped in [`docs/plans/initial-buildout.md`](docs/plans/initial-buildout.md). Keep this file, the README, and the ADR index current as resources land.

## Architecture

| Concern | Implementation |
|---|---|
| Terraform provider | `integrations/github ~> 6.0` (one provider configuration per owner) |
| State backend | HCP Terraform — org `flungo`, **one workspace per owner directory**, **Local execution mode** (inherited from `terraform-grafana-cloud`) |
| Structure | Directory per owner (`owners/<owner>/`) consuming shared modules (`modules/`) — **not** a single flat root module (see § Terraform conventions) |
| CI/CD | GitHub Actions — plan on PR, apply on merge (to be added with the first module code) |
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
modules/            Shared, opinionated modules — the standard template and preferences
                    (e.g. repository, repository-secrets, standard-repository). Consumed
                    by every owner directory via a relative source path.
owners/
  flungo/           The personal (user) account, by login — its own HCP workspace,
                    provider, and state. The only user account; named by login.
  <organisation>/   One directory per organisation account (every non-flungo owner
                    is an org). "owner" is GitHub's own term — the {owner} in
                    /repos/{owner}/{repo} and the provider's `owner` argument —
                    which is why the container is `owners/` (not the UI term
                    "accounts/"). "namespace"/"group" are GitLab terms, not GitHub's.
docs/
  decisions/        ADRs — numbered, never deleted or renumbered. README.md is the index.
  plans/            One-time build/onboarding procedures with status tracking; retired
                    (deleted) when complete. README.md is the index.
  runbooks/         Repeatable operational procedures (owner onboarding, token rotation,
                    importing repos). README.md is the index.
  reference/        Information-oriented lookup docs (standard-settings catalogue, shared-
                    secret names, provider coverage map). README.md is the index.
```

`modules/` does not exist yet — modules are extracted later in the build-out; until then resources live directly in each owner directory. `owners/flungo/` is the first owner directory.

## Terraform conventions

> **Key divergence from the sibling repos.** `terraform-grafana-cloud` and `stalwart.flungo.net` use a **single flat root module** ("root module only — no child modules unless complexity clearly warrants it"). This repo deliberately does **not**: the multi-owner requirement makes shared modules + a directory (and HCP workspace) per owner the right structure from the start. The "one flat root" rule does not apply here. What *is* carried over: one `.tf` file per logical concern *within* each directory or module, sensitive values as variables, and durations as arithmetic.

- **Directory per owner is a root module per owner.** Terraform root modules are flat — they load every `*.tf` in a directory and do not recurse. So each `owners/<owner>/` is its own root module, `init`/`plan`/`apply`'d independently against its own HCP workspace. Owner directories are thin: provider config, backend, variables, and module calls — the opinionated detail lives in `modules/`.
- **Shared modules encode the preferences.** Change the standard once in `modules/` and re-apply each owner to roll it out. Owner directories should not re-express settings the module already owns.
- **Customise modules through simple inputs, named for intent.** Express per-repo variation with a small, deliberately grown set of module inputs — not by forking a module. Where an input maps to a GitHub provider argument, **match the provider's variable name** (e.g. `visibility`, `default_branch`); where it does not, name it for the *intent* so one flag can drive several decisions (e.g. `terraform = true` marks a repo as holding Terraform config and can gate both required status checks and whether the HCP token secret is attached).
- **Standard first; add inputs for deviations only on explicit confirmation.** When adopting a repo into the standard module, bringing it to the standard (disabling a feature, changing a setting) is confirmed by the user *per repo*. Add a module input to support a deviation **only when the user explicitly confirms** the deviation must be supported in the workflow — never speculatively — and name it per the convention above.
- **Resource names mirror the real object name.** A resource's local name matches the repository (or team, secret, …) name, with any character not valid in a Terraform identifier replaced by `_` — e.g. repository `authentik.flungo.net` → `github_repository.authentik_flungo_net`. (Terraform identifiers allow letters, digits, `_`, and `-` and must start with a letter or `_`; `.` is the usual offender.)
- **One `.tf` file per logical group** within a directory/module (`repositories.tf`, `secrets.tf`, `providers.tf`, `terraform.tf`).
- **One provider configuration per owner** — `provider "github" { owner = "<owner>" token = var.github_token }`. Provider configurations are static; you cannot `for_each` a module across a dynamic set of provider aliases, so each owner is wired explicitly.
- **All sensitive values are variables**, declared `sensitive = true`; never hard-code tokens or secret values.
- **Express durations as arithmetic** for readability: `30 * 86400 # 30 days`, not `2592000`.
- **Adopt existing resources via `import {}` blocks** (Terraform ≥ 1.5) in the `.tf` file, atomic with the config that manages them and reviewed in the same PR — every repo, secret, or team that already exists on GitHub must be imported before it can be managed. (Same convention as `terraform-grafana-cloud` ADR-012.)
- **Pin the provider** in each directory's `terraform` block and commit `.terraform.lock.hcl`.
- **Bootstrapping / circularity:** this repo manages GitHub using credentials and workflows stored in GitHub. Keep the provider token a manually-managed Actions secret (not a Terraform-managed resource), and be cautious about letting Terraform manage the branch protection / secrets that gate this repo's own CI until the setup is proven. A broken apply must never lock the repo out of its own credentials.

## Working with this repo in Claude Code

Sessions use the **GitHub MCP** for all GitHub interactions (PRs, CI status, comments) — there is no `gh` CLI. Use `mcp__github__*` tools.

Once CI exists, on-demand runs are triggered with `mcp__github__actions_run_trigger` (`workflow_id: "terraform.yml"`, `ref: "<branch>"`); after triggering, give the user a direct link (`https://github.com/flungo/terraform-github/actions/runs/<run_id>`) and report the outcome. (Pattern inherited from `terraform-grafana-cloud`.)

## Branch management

Claude sessions must **never commit directly to `main`**. All work happens on a feature branch.

**At the start of every session:**
- If `main` is checked out: pull to ensure it is up to date, then create a new feature branch before making any changes.
- If a non-`main` branch is already checked out: confirm with the user whether to continue on it or start fresh before proceeding.

**After each user prompt:** fetch from upstream and, if there are new commits on `main`, rebase the current feature branch onto it (`git fetch origin main` then `git rebase origin/main` only if fetch produced new commits). Review what changed; if upstream changes affect work on the branch, adjust (via rebase amend). If anything is unclear or conflicts with a decision already made on the branch, **stop and ask** rather than silently picking an interpretation.

**Commit messages — [Conventional Commits](https://www.conventionalcommits.org/):** `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, etc. Imperative subject, no trailing period. The body is for the *why*, not a restatement of the diff.

**Landing branches — always via PR.** Claude never pushes to `main`; open a PR and let the user merge. Delete the remote branch after merge.

**Linear history — no merge commits.** Land via squash or rebase, never `git merge`. **Squash** when the branch is a single logical change (regardless of working-commit count); **rebase** (fast-forward, no squash) when it holds several distinct logical changes worth preserving. When in doubt, squash. Force-pushing is allowed on feature branches (after `--amend`/rebase), never on `main`.

**Rebase hygiene — no "fix-up" commits.** When correcting a minor inaccuracy on a branch, amend/fixup the relevant commit rather than appending a corrective commit. History should read as though the work was always correct.

**PR monitoring — prefer subscriptions, avoid `send_later`.** When watching a PR via activity subscriptions, do not schedule `send_later` self check-ins: either review comments arrive as events that wake the session, or the user returns. Only propose `send_later` when polling a CI job's outcome is critical *and* that outcome may complete without emitting an event.

## Documentation standards

Documentation is a first-class deliverable. Stale docs are actively harmful — they mislead future sessions into re-deriving settled decisions or acting on wrong assumptions. These rules apply after every change.

### Agent-directed callouts

Docs here are read by both humans and AI agents. When a passage is an instruction to an **agent** following the doc — what to *do*, not a fact everyone needs — mark it with an agent callout so it is unmistakable, and so a human can see what the agent was told:

> **🤖 Agent** — \<what the agent should do\>

Reserve it for agent behaviour (e.g. "propose a value from context and ask the human to confirm, rather than asking cold"); shared facts and steps stay as normal prose. Keep each callout to the action — one instruction per callout.

### Plans vs runbooks vs reference vs ADRs

Following the [Divio/Diátaxis](https://diataxis.fr/) split — docs are task-oriented (how-to) or information-oriented (reference); ADRs add a decision-oriented kind.

- **Plans** (`docs/plans/`) — one-time procedures tracked to completion then **retired** (deleted). Numbered checkboxes; status in `docs/plans/README.md`. The permanent record lives in ADRs and reference docs, not the plan.
- **Runbooks** (`docs/runbooks/`) — repeatable *how-to* guides referenced indefinitely (owner onboarding, token rotation). No completion checkboxes.
- **Reference** (`docs/reference/`) — *information-oriented*, descriptive not procedural (standard-settings catalogue, shared-secret names). If it has no steps and exists to be looked up, it goes here.
- **ADRs** (`docs/decisions/`) — decision-oriented; numbered sequentially, never deleted or renumbered. Superseded ADRs keep their file with a note pointing to the newer one.

### After making an architectural decision
1. Create a new ADR in `docs/decisions/` using the template in `docs/decisions/README.md` (format: `# ADR-NNN: Title`, Date, Status, Context, Decision, Consequences).
2. Update `docs/decisions/README.md` with a one-sentence summary.
3. If it supersedes an existing ADR, update the old ADR's status to `Superseded by ADR-NNN`.

### After implementing new resources or features
1. Update `README.md` → "What this manages" if a new resource type is introduced.
2. Update the relevant directory's `providers.tf` / `variables.tf` docs if new provider configs or variables are added.
3. If the feature introduces a new credential, add a runbook in `docs/runbooks/` for rotating it and note it in the § Sensitive information list / any secrets table.

### After any change to `docs/`
- **Always refresh the relevant `README.md` index** (decisions, plans, runbooks, reference) in the same commit. Stale index rows are actively misleading — update the status field whenever the underlying document changes.

### Plan lifecycle (two-PR retirement)
1. **Active** — plan doc exists, README row shows "In progress" / "Planning". Mark steps `[x]` as they complete.
2. **Complete** — when all steps are done, set the README row to `Complete (YYYY-MM-DD)`, update § Active work here, and open a PR. Verify every structural decision has an ADR before marking complete.
3. **Retired** — once the completion PR is merged and the user confirms, open a second PR to delete the plan file and remove its README row. Git history preserves it.

**Plans are ephemeral — never reference them from permanent docs or code.** Architecture, decisions, and repeatable procedures belong in their permanent home (README, ADRs, runbooks, Terraform comments), expressed as outcomes — not as links to the plan that produced them. The one exception is the § Active work section below, which may link a plan while it is in progress.

### End-of-session staleness scan
Search for anything that may have changed (owner names, workspace names, provider version, module names, secret names), close any resolved open decisions in the docs, verify § Active work still reflects reality, and audit every README row whose document was touched. If something is probably stale but unverifiable without live access, add a `> **Verify:** …` callout rather than leaving silent uncertainty.

## Active work

| Plan | Status |
|---|---|
| [Initial build-out](docs/plans/initial-buildout.md) | Planning — module structure, directory-per-owner layout, HCP workspace topology, and build sequence proposed; awaiting review before any Terraform is written |

## Key decisions

See [`docs/decisions/README.md`](docs/decisions/README.md) for the full index. Short version:

- Dedicated, provider-scoped `terraform-github` repo; Terraform over UI/scripts; multi-owner (personal + orgs); directory-per-owner consuming shared modules (ADR-001)
- HCP backend, Local execution mode, and GitHub Actions plan/apply CI inherited from `terraform-grafana-cloud` (ADR-002 there); **workspace-per-owner topology** — one HCP workspace per owner directory (`github-<login>`) in a dedicated `terraform-github` project (ADR-002)
