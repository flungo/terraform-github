# ADR-002: Workspace-per-owner backend topology

Date: 2026-07-21
Status: Accepted

## Context

ADR-001 established a directory-per-owner structure (`owners/<owner>/`, each a thin consumer of shared modules). That structure needs a concrete mapping onto the HCP Terraform backend inherited from `terraform-grafana-cloud`: does each owner directory get its own workspace (and state), or do the directories share one workspace?

HCP Terraform (the `cloud {}` block) maps **one workspace to one state file**. Two different root configurations cannot point at the same workspace and coexist — they would clobber each other's state. HCP's CLI-workspace mechanism (`workspaces { tags = [...] }` + `terraform workspace select`) lets one configuration switch between several workspaces, but each remains a *separate* state. So "share one workspace across owner directories" is not actually available the way it would be with, e.g., an S3 backend keyed by prefix.

Three options were weighed:

- **Option A — workspace per owner directory.** Each `owners/<owner>/` has its own `cloud{}` block → its own HCP workspace → its own state.
- **Option B — single root module, all owners in one workspace** via an aliased provider per owner.
- **Option C — one config, many workspaces via `tags`/CLI workspaces.** Still one state per owner, so it inherits A's isolation but loses the per-owner directory.

Comparing A (the chosen option) against B, the single-workspace alternative:

| Dimension | A: workspace per owner | B: single shared workspace |
|---|---|---|
| Blast radius | Small — a bad apply touches only that owner's state. | Large — one apply spans every owner. |
| Apply isolation | Full — plan/apply each owner independently. | None — one resource error blocks the whole run. |
| State size | Small per workspace. | Grows with the sum of all owners. |
| Credential scoping | Each run carries only that owner's GitHub token. | One run holds every owner's credentials; any resource can use any token. |
| Cross-owner rollout | N applies (staged, individually reviewable). | One atomic apply. |
| CI shape | A matrix over owner directories. | One job. |
| Provider wiring | One provider per directory. | Multiple aliased providers, which cannot be `for_each`'d — so an explicit block per owner anyway. |

## Decision

Adopt **Option A: one HCP workspace per owner directory**.

- **Organisation:** `flungo` (the existing HCP Terraform org).
- **Project:** a dedicated HCP project `terraform-github` grouping all owner workspaces, with its **default execution mode set to Local** (matching `terraform-grafana-cloud`). Each owner directory's `cloud` block names this project explicitly (`workspaces { project = "terraform-github" }`) so its auto-created workspace lands here and inherits the Local default. The `project` argument is **required, not cosmetic**: omit it and the workspace is auto-created in the organisation's *default* project — which uses Remote execution — silently breaking the Local-execution design.
- **Workspaces:** one per owner directory, named `github-<login>` — `github-flungo` for the personal account, `github-<organisation>` per organisation. Each owner directory's `terraform.tf` `cloud` block pins both the workspace `name` and the `project`; the workspace is auto-created in that project on first `terraform init`.

**Why the `github-` prefix.** HCP workspace names are unique per *organisation*, not per project ([HCP docs](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/create) — "must be unique within the organization"). These workspaces therefore share the `flungo` org's namespace with `grafana-cloud`, `stalwart-flungo-net`, and any future workspaces. The prefix keeps the GitHub-management workspaces recognisable and grouped in the org-wide contexts that do *not* surface the project — the CLI workspace selector, the API, and the flat workspace list — and avoids a bare `flungo` workspace that would be ambiguous next to the org of the same name. (The dedicated `terraform-github` project groups them in the UI, but the prefix is what disambiguates everywhere else.)

## Consequences

**Positive:**
- **Credential scoping** — the decisive factor. Each workspace/run carries only that owner's GitHub token, so a mistake or a leak is contained to one owner. (Option B would force every owner's credential into a single run where any resource could use any token.)
- **Blast radius and apply isolation** — a bad apply touches only that owner's resources and state; a broken plan in one owner never blocks the others.
- **Smaller per-workspace state** and faster plans than a single combined state.
- Aligns with the directory-per-owner structure and the HCP one-workspace-per-state reality — the constraint and the preference point the same way.

**Negative / trade-offs:**
- **Cross-owner rollouts are N applies** (one per owner) rather than one atomic apply. This is an accepted cost — for an opinionated baseline that changes infrequently, staging owner-by-owner is a feature, not a burden — and CI runs each owner automatically.
- **CI is a matrix** over owner directories rather than a single job. It starts as a single-owner job (`owners/flungo`) and generalises to the matrix when a second owner is onboarded.
- Terraform cannot `for_each` a module over a dynamic set of provider aliases, so Option B would still require an explicit block per owner anyway; the duplication Option A is charged with is exactly what the shared modules eliminate.

### The per-owner overhead is smaller than it looks

Workspace-per-owner appears to imply per-owner secret sprawl, but a run's credentials are **shared, not per-owner** (or on a path to it), and the workspace itself is **automated away**:

- The **HCP token** (`TF_TOKEN_APP_TERRAFORM_IO`) is a single org-wide Owners-team token that reaches every workspace in the org — one secret authenticates all owner workspaces.
- With a **GitHub App** (the intended credential model), the GitHub credential is a single App private key that mints short-lived, per-owner installation tokens at run time. The interim bootstrap uses a per-owner fine-grained PAT instead (`FLUNGO_GITHUB_TOKEN` for the first owner), so that one saving is not yet realised — consolidating onto a shared App key, and isolating each owner's secret via GitHub Environments, is a tracked follow-up.
- **Workspaces are auto-created**, not a manual chore per owner: the `cloud` block creates the named workspace — in the `terraform-github` project, via the `project` argument — on first `terraform init`, inheriting that project's Local execution default.

So onboarding an owner is adding a directory and running `init`, backed by one shared HCP token — and, once the App model lands, one shared App key — rather than a growing pile of manually-managed per-owner secrets.
