# ADR-001: Dedicated `terraform-github` repository for GitHub resources

Date: 2026-07-20
Status: Accepted

## Context

GitHub configuration — repository settings, a standard project template, shared/common secrets, and (over time) branch protection, rulesets, webhooks, teams, and membership — is currently managed by hand through the GitHub UI. This is applied across two kinds of owner: the personal account and one or more organisations the user belongs to. Manual management is error-prone, leaves no audit trail, drifts silently, and makes a consistent baseline across many repositories impossible to guarantee or reproduce.

Two sibling repositories already manage other infrastructure this way and have established conventions worth reusing:

- [`terraform-grafana-cloud`](https://github.com/flungo/terraform-grafana-cloud) — Grafana Cloud org config as code, HCP Terraform backend, GitHub Actions CI (plan on PR / apply on merge), ADR + plan + runbook documentation model.
- [`stalwart.flungo.net`](https://github.com/flungo/stalwart.flungo.net) — Stalwart mail server config as code, same documentation model.

Several founding questions had to be settled before any Terraform is written:

1. Should GitHub config live in its own repository, or be folded into an existing one?
2. Should it be managed with Terraform at all, or with a lighter-weight tool (scripts, `gh` CLI, Probot/Settings app)?
3. What should the repository be scoped to — and named for?
4. Which owners are in scope?
5. How should the configuration be structured to serve multiple owners without duplicating the opinionated baseline?

## Decision

### 1. A dedicated repository

GitHub resources are managed in their own repository, `terraform-github`, rather than folded into an existing infra repo. The GitHub provider, its credentials, its state, and its blast radius are distinct from Grafana Cloud or the mail server; co-locating them would entangle unrelated credentials and apply cycles. A dedicated repo keeps each concern's state, CI, and review gate independent — consistent with the one-platform-per-repo pattern the sibling repos already follow.

### 2. Terraform

Manage all GitHub configuration as code using the [`integrations/github`](https://registry.terraform.io/providers/integrations/github/latest) Terraform provider (`~> 6.0`; latest at time of writing is v6.13.0).

Terraform is chosen over the GitHub UI, ad-hoc `gh` CLI scripts, or the GitHub Settings Probot app for the same reasons ADR-001 of `terraform-grafana-cloud` chose it for Grafana Cloud: changes are version-controlled with a clear history, reviewed before they are applied (plan → review → apply), and reproducible for disaster recovery. It also lets a single opinionated baseline be expressed once as a module and applied uniformly across every repository and owner — the core requirement here — which a pile of imperative scripts cannot guarantee idempotently.

### 3. Provider-scoped naming, not use-case-scoped

The repository is named `terraform-github` — for the **provider / platform** it manages, not for its initial use case. It is deliberately *not* named `github-repo-settings`, `github-templates`, or `github-secrets`.

The first work is repository settings, a project template, and shared secrets, but the intent from day one is that scope grows to the full surface the GitHub provider covers (branch protection and rulesets, webhooks, teams and membership, org settings, environments, deploy keys, and so on). Naming for the initial slice would make the repo's name a lie within weeks and invite a disruptive rename. Naming for the provider keeps the repository's identity stable as scope expands — no rename, no broken links, no confusion about where a new GitHub-manageable resource belongs. This mirrors `terraform-grafana-cloud`, which is named for its platform rather than for "grafana-dashboards" or "grafana-alerts".

### 4. Multi-owner scope: personal account + organisations

The repository manages GitHub resources for **all owners the user administers** under their own credentials: the personal account, and each organisation the user belongs to with sufficient rights. Owners are treated uniformly — the personal account is simply one more owner alongside the organisations — while acknowledging that some resource types differ between the two (e.g. organisation-level Actions secrets and teams have no personal-account equivalent).

### 5. Directory-per-owner with shared modules

The configuration is structured as **one directory per owner**, each consuming **shared modules** that encode the actual templating and the user's preferences (standard repository settings, shared secrets, and later branch protection, etc.). Each owner directory is a thin consumer: it wires the GitHub provider for that owner, declares which repositories/resources that owner has, and delegates the opinionated detail to the shared modules.

This keeps the baseline defined once (in `modules/`) and applied consistently, while giving each owner an isolated configuration surface. Because HCP Terraform maps one workspace to one state file, a directory-per-owner layout implies a workspace-per-owner backend topology; the trade-offs of that mapping (blast radius, apply isolation, state size, per-owner credential scoping) are analysed in the initial build-out plan and will be ratified in a follow-up ADR (ADR-002) once confirmed. The HCP Terraform backend itself, its Local execution mode, and the GitHub Actions plan/apply CI model are **inherited wholesale from `terraform-grafana-cloud`** rather than reinvented.

## Consequences

**Positive:**
- All GitHub configuration changes are version-controlled, reviewed before apply, and reproducible.
- A single opinionated baseline (repo settings, shared secrets, project template) is defined once and applied uniformly across owners and repositories.
- The provider-scoped name and the modular structure both anticipate growth: new GitHub resource types and new owners are additive, requiring no restructuring or rename.
- Per-owner directories give natural isolation of credentials, state, and apply cycles between the personal account and each organisation.
- Conventions, backend, and CI are consistent with the sibling infra repos, so the repo is immediately familiar to work in.

**Negative / trade-offs:**
- Resources that already exist on GitHub must be imported before Terraform can manage them; ad-hoc UI changes will drift and be overwritten on the next apply.
- A directory-per-owner layout means cross-owner changes (e.g. rolling a new default out to every owner) are N applies rather than one — a deliberate trade of atomicity for isolation (see the build-out plan).
- The GitHub provider does not yet cover every GitHub feature; some settings will remain manual until provider support exists, and must be recorded as such.
- Managing GitHub *with* GitHub-hosted CI introduces a mild bootstrapping/circularity concern (the credentials and workflows that manage the org live in a repo within it) that the build-out plan must address.

## Notes

- The `integrations/github` provider version will be pinned in each owner directory's `terraform` block and locked via `.terraform.lock.hcl` at first `terraform init`.
- This ADR records the *founding* decisions only. The concrete module layout, workspace topology, provider/credential model, and CI shape are worked out in [`docs/plans/initial-buildout.md`](../plans/initial-buildout.md) and will graduate into their own ADRs as they are settled.
