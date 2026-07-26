# Plan: Initial build-out of `terraform-github`

Status: In progress — structure ratified (ADR-001/002/003/004); the `owners/flungo/` skeleton, plan/apply CI, `modules/repository`, and `modules/branch-protection` (piloted on authentik) have landed. §7 steps 1–3 done, step 4 in progress.
Related: [ADR-001](../decisions/001-dedicated-terraform-github-repo.md) (founding decisions)

## Goal

Turn the empty, documented repository into a working multi-owner GitHub-as-code
setup: shared modules that encode the standard project template and shared
secrets, one directory per owner (personal account + each organisation) consuming
those modules, an HCP Terraform backend matching `terraform-grafana-cloud`, and
GitHub Actions CI (plan on PR, apply on merge).

This plan works out the structural questions ADR-001 deliberately left open, and
proposes a build sequence. **Nothing here is applied yet** — HCL in this document
is illustrative pseudo-config, not committed Terraform. Each structural decision
that survives review graduates into its own ADR before the corresponding code
lands.

> **Illustrative snippets:** the `hcl` blocks below sketch intent (resource
> names, wiring). They are not the final config and deliberately omit detail that
> belongs in the implementation PRs.

---

## 1. Module structure

The shared modules live in `modules/` and are consumed by every owner directory
via a relative `source = "../../modules/<name>"`. They are **local** modules — no
registry publishing until cross-repo reuse actually demands it.

Proposed modules, smallest reusable primitive first, then a composite template:

### Primitive (resource-group) modules

Each wraps one GitHub provider resource type with the user's opinionated defaults,
so that a caller states *what* they want, not every attribute.

| Module | Wraps | Purpose |
|---|---|---|
| `modules/repository` | `github_repository` (+ `github_branch_default`) | A repository created/managed with the standard settings: visibility, feature toggles (issues/wiki/projects), merge strategy (merge commits off, squash + rebase on — rebase preferred; delete-branch-on-merge), default branch, topics, `.gitignore`/license templates. This is the "project template". |
| `modules/repository-secrets` | `github_actions_secret`, `github_actions_variable`, `github_dependabot_secret` | Apply a set of shared/common Actions secrets + variables to a repository. |
| `modules/branch-protection` | `github_repository_ruleset` (preferred) **or** `github_branch_protection` | Standard protection for the default branch. **One of the motivators for this repo** — applied *early* (§7), not deferred. Defaults and inputs are specified in [§1.1 Branch protection defaults](#11-branch-protection-defaults) below. |
| `modules/webhook` | `github_repository_webhook` / `github_organization_webhook` | Standard webhook wiring. *Growth — not first slice.* |
| `modules/team` | `github_team`, `github_team_membership` | Org teams and membership. *Growth, org-only — not first slice.* |

### Composite (template) module

| Module | Composes | Purpose |
|---|---|---|
| `modules/standard-repository` | `repository` + `branch-protection` + `repository-secrets` | The one-call "my standard repo": creates the repo with standard settings, applies standard branch protection, attaches the shared secrets. An owner directory instantiates this once per repository (or over a map of repositories) and gets a fully-standardised repo. Intentional per-repo variation is expressed through **simple module inputs** (e.g. `visibility`, `topics`, and intent flags like `terraform`), scoped as we onboard repositories and discover the variations that actually recur — not by forking the module. |

### Module inputs & variable naming

- **Customise through simple inputs, not forks.** A caller expresses common variations via a small set of inputs. The set is grown deliberately as onboarding surfaces genuine, recurring variation — start minimal.
- **Prefer intent flags over micromanagement.** A flag should describe *why*, not restate what the module does, so one input can drive several control-flow decisions from a single declaration. Example: a `terraform = true` flag on a repo's module call means "this repo holds Terraform config" and — at this stage — primarily gates whether the **HCP token secret** is attached (and can add the Terraform plan check to the required status checks). Branch protection itself is *not* gated on this flag; it applies to every repo regardless (see below).
- **Variable naming convention.** Where an input corresponds to a GitHub provider argument, **match the provider's variable name** (e.g. `visibility`, `default_branch`). Where there is no direct correspondent, use best judgement and name for the *intent* of the flag (e.g. `terraform`, `strict`).

### 1.1 Branch protection defaults

Protecting `main` is one of the repo's motivators, so `modules/branch-protection`
ships an opinionated default that every managed repo gets. Preferred
implementation is a **`github_repository_ruleset`** (the modern, more expressive
resource) over the older `github_branch_protection`. The module presents a stable
input surface, but the two resources are **not semantically identical**, so pick
one and commit to it.

> **Migration caveat (ruleset ⇄ branch_protection).** The two enforce via
> different mechanisms and field shapes — e.g. bypass is `bypass_actors` on a
> ruleset vs `enforce_admins` on branch protection; branch targeting is a
> `conditions.ref_name` pattern vs a single `pattern`; and both can even apply to
> the same branch at once (double enforcement). If we ever migrate the module from
> one to the other, **call out the per-field semantic differences and confirm
> whether any per-repo overrides are needed before switching** — a silent swap is
> likely to produce unintended drift or a quietly weaker rule. **The migration must
> also delete the legacy `github_branch_protection`** in the same change — leaving
> both resources applied double-enforces and defeats the purpose of the move.

**Default rules:**

- Require a pull request before merging
- Require status checks to pass before merging — **only enforces the check
  contexts you name** (see `required_status_checks` below)
- Require conversation resolution before merging
- Require linear history

**Inputs:**

- **`pattern`** (string, required) — the branch (or glob) to protect, matching the
  provider's `pattern` field. The module protects *any* branch, so it takes the
  pattern rather than assuming `main`. The `standard-repository` composite defaults
  this to the **repo's default branch**, so a caller normally never sets it — but
  the primitive itself does not hard-code `main`.
- **`strict`** (bool, default `false`) — when `true`, **do not allow bypassing**
  the above (no bypass actors / no admin override). Left `false` by default so the
  owner can still act directly during bootstrap and incident response; flip to
  `true` on repos that should be strictly enforced.
- **`required_status_checks`** (list(string), default `[]`) — the check contexts
  that must pass. **Important GitHub semantics:** an empty list enforces *nothing*
  — there is no "require all checks" option, and a check context is only selectable
  after it has actually run on the protected branch. So "require status checks" has
  teeth only once contexts are listed; for a repo with CI these are its check names
  (the `terraform` flag adds the Terraform plan check — see §"standard-repository").
- Individual rules are overridable per repo where a genuine exception exists, but
  the intent is that the defaults apply unchanged to almost every repo (customise
  through the small input set, per §1 "Module inputs & variable naming" — don't
  fork the module).

**Module built early; applied to the rest later.** The `branch-protection` *module*
is built and proven at §7 step 4 — right after repository management and **before**
secrets — against the first repo (`authentik.flungo.net`). Protecting the remaining
repos, `terraform-github` itself included, happens when they are onboarded after CI
is proven (§7 step 8). `terraform-github` is deliberately **not** the first repo
onboarded (see the circularity note in §5).

### Shared secrets — a note on the personal/org asymmetry

Shared secrets are **not** symmetric across owner types, and the modules must
reflect that:

- **Organisations** have `github_actions_organization_secret` with
  `visibility = "all" | "private" | "selected"` — one resource covers many repos.
  For an org, a common secret is best set **once at the org level**.
- **Personal accounts** have no org-level secret; a shared secret must be set
  **per repository** via `github_actions_secret`.

So `modules/repository-secrets` handles the personal (per-repo) case, and a
separate `modules/org-secrets` (or a variant) handles the org-level case. Owner
directories use whichever fits. Capturing this asymmetry is exactly why the
"shared secrets" concern is its own module rather than folded into the repository
module.

**Initial common secret set:**

- **`LYCHEE_GITHUB_TOKEN`** — the starting point. The [lychee](https://github.com/lycheeverse/lychee) Markdown link-checker used in CI across these repos needs a GitHub token to avoid rate-limiting; it is the first shared secret every managed repo should carry.
- **HCP token — optional, gated on the `terraform` intent flag.** A repo that holds Terraform config (its module call sets `terraform = true`) also needs the HCP Terraform token to run `plan`/`apply` in CI. Because an Owners-team HCP token reaches every workspace in the org (it is org-wide, not per-workspace — see §4), this is a *single shared value* attached only where `terraform = true`, not a per-repo secret to manage. **Verify at implementation** whether the available HCP token scope is indeed org/team-wide (expected yes) before relying on one shared value.

### Build order for modules

`repository` → `branch-protection` → `repository-secrets` / `org-secrets` →
`standard-repository` composite → (later) `webhook`, `team`. Build and prove the
primitives against one repo before composing them. Branch protection comes early
(right after `repository`) because protecting `main` is one of the repo's
motivators, not a later nicety — see the build sequence in §7.

### Proposed starting inputs (for review)

A deliberately minimal surface, named per the convention above (match the provider
argument where one exists, else name for intent), grown as onboarding surfaces real
variation. **This is a proposal — review / adjust; open questions are flagged below.**

**`modules/repository`**

| Input | Type | Default | Maps to / intent |
|---|---|---|---|
| `name` | string | — (required) | provider `name` |
| `description` | string | — (required) | provider `description` — required so every managed repo is described |
| `visibility` | string | `"private"` | provider `visibility` |
| `topics` | list(string) | `[]` | provider `topics` |
| `default_branch` | string | `"main"` | `github_branch_default` |
| _(baked defaults)_ | — | — | **merge commits disabled; squash + rebase both allowed** (rebase preferred); delete-branch-on-merge; issues on, wiki/projects off — exposed as inputs only if a repo actually needs to differ |

**`modules/branch-protection`**

| Input | Type | Default | Maps to / intent |
|---|---|---|---|
| `repository` | string | — (required) | target repo |
| `pattern` | string | — (required) | protected branch/glob — matches the provider's `pattern` field (the module protects *any* branch; the composite defaults it to the repo's default branch) |
| `strict` | bool | `false` | forbid bypass (no bypass actors / no admin override) |
| `required_status_checks` | list(string) | `[]` | check contexts that must pass. **Empty ⇒ enforces nothing** (GitHub has no "require all"; a context is selectable only after it has run on the protected branch) |
| _(baked defaults)_ | — | — | require PR · conversation resolution · linear history · require-status-checks (teeth only via `required_status_checks`) |

**`modules/repository-secrets` (per-repo) · `modules/org-secrets` (org-level)**

| Input | Type | Default | Maps to / intent |
|---|---|---|---|
| `repository` _(repo)_ / `visibility` + `selected_repository_ids` _(org)_ | — | — | where the secret lands |
| `terraform` | bool | `false` | attach the HCP token secret (the flag's primary effect) |
| secret values | string (sensitive) | — | passed from owner-dir variables (`TF_VAR_…`), never hard-coded; names e.g. `LYCHEE_GITHUB_TOKEN`, HCP token |

**`modules/standard-repository` (composite — the caller-facing surface)**

| Input | Type | Default | Drives |
|---|---|---|---|
| `name`, `description`, `visibility`, `topics`, `default_branch` | (as `repository`) | | the repository |
| `terraform` | bool | `false` | **the HCP token secret** (primary), and adds the Terraform plan check to `required_status_checks`. Branch protection itself applies regardless of this flag. |
| `strict` | bool | `false` | branch-protection bypass enforcement |
| _(branch protection)_ | — | — | applied to every repo; `pattern` defaults to the repo's `default_branch` |

**Resolved in review (2026-07-20):**

1. **Feature toggles** (issues / wiki / projects / discussions) — **baked** as fixed
   defaults; expose inputs only on the first real exception.
2. **`required_status_checks`** — **explicit contexts**, because an empty list
   enforces nothing (GitHub has no "require all checks", and a context must have run
   on the protected branch to be selectable — [GitHub Docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)). The `terraform` flag adds the Terraform
   plan check by convention; additional contexts are listed per repo. (This corrects
   the earlier draft, which implied an empty list still gated merges.)
3. **Merge strategy** — **disable merge commits; allow squash + rebase** (rebase
   preferred). Note: GitHub's per-repo *default* merge button tends to become
   "last used", so a configured default has limited effect — the meaningful control
   is which strategies are *allowed*.

---

## 2. Directory-per-owner layout

```
.
├── modules/                       # shared, opinionated modules (see §1)
│   ├── repository/
│   ├── repository-secrets/
│   ├── org-secrets/
│   └── standard-repository/
├── owners/
│   ├── flungo/                    # a login — here the personal (user) account `flungo`
│   │   ├── terraform.tf           #   cloud{} backend → its own workspace + provider req
│   │   ├── providers.tf           #   provider "github" { owner = "flungo" }
│   │   ├── variables.tf
│   │   ├── repositories.tf        #   module "..." { source = "../../modules/standard-repository" ... }
│   │   └── secrets.tf
│   └── <organisation>/            # one per organisation account (every non-flungo owner is an org)
│       ├── terraform.tf
│       ├── providers.tf
│       ├── variables.tf
│       ├── repositories.tf
│       └── secrets.tf
└── docs/
```

**A note on GitHub nomenclature (why `owners/`, and what the leaf is).** GitHub
calls both a personal account and an organisation an **account** — a *user account*
and an *organisation account*. Both **own** repositories: `owner` is the first path
segment of every repo (`/repos/{owner}/{repo}` in the REST API), it is the
`integrations/github` provider's argument, and a repo's `owner.type` is `User` or
`Organization`. So **owner** is the precise, provider-aligned word that spans a user
and an org — which is why the container is `owners/`, not the softer UI term
`accounts/`. (GitHub has no "namespace"/"group" concept — those are GitLab's.)

Each directory is one owner. In this setup there is exactly **one user account —
`flungo`** (the personal account) — and every other owner is an **organisation**, so
the practical shape is `owners/flungo/` plus one `owners/<organisation>/` per org.
`flungo` is not a special *naming* case: it is just the login that happens to be the
`User` account; an org directory is that org's login, same shape. A user and an org
account differ only where GitHub itself differs (no org-level secrets/teams on a user
account — see §1), never in how the directory is named.

Each owner directory is a **thin consumer**:

```hcl
# owners/flungo/repositories.tf  (illustrative)
module "dotfiles" {
  source     = "../../modules/standard-repository"
  name       = "dotfiles"
  visibility = "public"
  # shared secrets, topics, protection all defaulted by the module
}
```

The opinionated detail (merge settings, feature toggles, protection rules, the
common secret set) lives in the module. Changing the standard once in `modules/`
and re-applying each owner rolls it out everywhere — the central point of the
shared-module design.

> **Terraform root modules are flat** (they load every `*.tf` in the directory
> and do not recurse). "Directory per owner" therefore means each owner directory
> is its own **root module** that is `terraform init`/`plan`/`apply`'d
> independently — not subdirectories of a single root. This is a deliberate
> divergence from the sibling repos' "root module only, flat" convention, which
> is documented in [Terraform conventions](../reference/terraform-conventions.md).

---

## 3. Workspace topology — the key decision

**Question:** should each owner directory be its own HCP Terraform workspace
(separate state), or should directories share one workspace with different var
files / backend keys?

### The HCP constraint that frames it

HCP Terraform (the `cloud {}` block) maps **one workspace = one state file**.
Two different root configurations cannot point at the same workspace and coexist
— they would clobber each other's state. HCP's CLI-workspace mechanism
(`workspaces { tags = [...] }` + `terraform workspace select`) does let one
config switch between several workspaces, but each remains a *separate* state. So
"share one workspace across owner directories" is not actually available the way
it would be with, say, an S3 backend keyed by prefix. The realistic options are:

- **Option A — workspace per owner directory.** Each `owners/<owner>/` has its
  own `cloud{}` block → its own HCP workspace → its own state.
- **Option B — single root module, all owners in one workspace.** Collapse the
  directory-per-owner layout into one root that declares an aliased provider per
  owner (`github.personal`, `github.org_foo`) and calls the modules once per
  owner. One workspace, one state.
- **Option C — one config, many workspaces via `tags`/CLI workspaces.** One
  directory, selected into a per-owner workspace at run time. Still one state per
  owner, so it inherits A's isolation but loses the per-owner *directory* the user
  wants and complicates local ergonomics.

### Trade-off analysis

| Dimension | A: workspace per owner | B: single shared workspace |
|---|---|---|
| **Blast radius** | Small — a bad apply touches only that owner's resources/state. | Large — one apply spans every owner; one mistake can affect all. |
| **Apply isolation** | Full — plan/apply each owner independently; a broken plan in one owner never blocks the others. | None — one plan/apply for everything; a single resource error blocks the whole run. |
| **State size** | Small per workspace; grows only with that owner. | Single state grows with the sum of all owners; slower plans. |
| **Credential scoping** | Each workspace/run carries **only that owner's** GitHub token. Smallest credential blast radius; supports per-owner PATs or GitHub App installs. | One run must hold **every** owner's credentials simultaneously; any resource can use any token. |
| **Cross-owner rollout** | N applies (one per owner) — staged, individually reviewable. | One apply rolls a change to all owners atomically. |
| **CI shape** | A matrix over owner directories (each is init/plan/apply'd on its own path). | One straightforward job. |
| **Terraform provider wiring** | Natural — each directory declares one provider. | Awkward — multiple aliased providers **cannot** be `for_each`'d; you must hand-write an explicit aliased provider + module block per owner anyway, so the "loop over owners" simplicity is largely illusory. |
| **Matches stated preference** | Yes — directory per owner. | No — collapses to a single directory. |

### Recommendation: **Option A — workspace per owner**

Reasons, in priority order:

1. **Credential scoping is the decisive factor.** Managing multiple owners means
   multiple GitHub tokens (a personal PAT, org admin tokens, or per-owner GitHub
   App installations). Option A keeps each owner's credential in its own
   workspace and its own CI run — a mistake or a leak is contained to one owner.
   Option B forces every credential into a single run where any resource can use
   any token; that is a materially worse security posture for the multi-owner
   goal.
2. **Blast radius and apply isolation** matter more here than atomic cross-owner
   rollout. Staging a change owner-by-owner (review the personal plan, then each
   org) is a *feature*, not a cost, for opinionated-baseline changes.
3. **It aligns with the stated directory-per-owner preference and the HCP
   one-workspace-per-state reality** — the constraint pushes the same way the
   preference does, so there is no need to fight it.
4. **The "single apply is simpler" appeal of B is undercut** by Terraform's
   provider model: dynamic `for_each` over multiple provider configs is not
   supported, so B still needs one explicit block per owner. The duplication A is
   accused of is exactly what the shared modules eliminate.

The one real cost — cross-owner rollouts are N applies — is acceptable given the
low change frequency of an org baseline, and is mitigated by CI running the
owner matrix automatically.

Option C is noted and rejected: it keeps per-owner state (so it doesn't simplify
the backend) but gives up the per-owner directory the user wants.

> **Confirmed in review (2026-07-20); ratified as [ADR-002](../decisions/002-workspace-per-owner-topology.md)
> (2026-07-21).** Option A is accepted.

---

## 4. HCP backend mapping

Inheriting `terraform-grafana-cloud`'s setup (ADR-002 there), adapted for
multiple workspaces:

- **Organisation:** `flungo` (the existing HCP Terraform org).
- **Project:** a dedicated HCP project, e.g. `terraform-github`, grouping all the
  owner workspaces so they are listed and permissioned together.
- **Workspaces:** one per owner directory, named `github-<login>` —
  `github-flungo` for the personal account, `github-<organisation>` per org. Each
  owner directory's `terraform.tf`
  pins its own workspace:

  ```hcl
  # owners/flungo/terraform.tf  (illustrative)
  terraform {
    cloud {
      organization = "flungo"
      workspaces { name = "github-flungo" }   # project: terraform-github
    }
    required_providers {
      github = { source = "integrations/github", version = "~> 6.0" }
    }
    required_version = ">= 1.9"
  }
  ```

- **Workspaces are auto-created, not a manual chore per owner.** With the `cloud`
  block, if the named workspace does not exist HCP **creates it on first
  `terraform init`**. Execution mode cannot be set in the `cloud` block (it is a
  workspace setting), and an auto-created workspace **inherits the project's
  default execution mode**. So the one manual step is a *project-level* setting:
  create the `terraform-github` project once and set its **default execution mode
  to Local**; every owner workspace then comes into being Local on first init. Net
  answer to "manual each time vs dynamic": **dynamic** — onboarding an owner is
  adding a directory and running init, not clicking through HCP. (Optionally the
  workspaces could instead be declared as code via the `tfe` provider for full
  reproducibility; deferred — auto-create + a project default is simpler to start.)
- **Execution mode:** **Local**, exactly as the Grafana repo — GitHub Actions (or
  a local CLI) is the runner; HCP provides state storage + locking + run history
  only. Set as the project default so workspaces inherit it (above). No workspace
  variables in HCP; secrets come from GitHub Actions.
- **Secrets:** GitHub Actions secrets, not HCP workspace variables — matching the
  Grafana repo. The **HCP token (`TF_TOKEN_APP_TERRAFORM_IO`) is a single shared
  secret, not per-owner:** an Owners-team token reaches every workspace in the org,
  so one value authenticates all owner workspaces. The *GitHub* provider token is
  the only credential that is per-owner (see §5).

**Alternative considered:** `workspaces { tags = ["github"] }` + CLI workspaces
instead of a fixed `name` per directory. Rejected for the same reason as Option C
— it adds a `terraform workspace select` step and run-time ambiguity for no gain
over an explicit `name` per directory. Explicit names are clearest and match the
Grafana repo.

---

## 5. Provider & credential model

Each owner directory configures the `github` provider for its owner:

```hcl
# owners/<organisation>/providers.tf  (illustrative; owner = "flungo" for the personal account)
provider "github" {
  owner = "<organisation>"        # the account login — an organisation, or "flungo"
  token = var.github_token        # sensitive; from TF_VAR_github_token in CI
}
```

### Does this mean managing a GitHub secret per owner? — the overhead question

Only partly, and it collapses to near-zero. Two of the three credentials a run
needs are **shared, not per-owner**: the HCP token is one org-wide value (§4), and
— with a GitHub App (below) — the GitHub credential is one App private key too. So
the per-owner secret sprawl the workspace-per-owner model seems to imply does not
actually materialise.

Credential options, to decide before writing owner directories:

- **Single classic/fine-grained PAT** with admin on the personal account + each
  org. Simplest bootstrap; matches "under my own credentials". Downside: one token
  is a single point of compromise across all owners, and per-owner PATs would mean
  one Actions secret to mint and rotate per owner — the overhead the owner flagged.
- **GitHub App installed per owner — the low-overhead, self-bootstrapping path.**
  The provider authenticates as an App via `app_auth {}` (App ID + installation ID
  + private key). One App, one **private key** (a single Actions secret), installed
  on the personal account and each org; the provider mints a **short-lived,
  per-owner installation token at run time**. This is also the answer to "can the
  repo create the scoped token itself?": GitHub has **no API to mint a user PAT**,
  but a GitHub App *is* the supported way to issue scoped, auto-expiring per-owner
  tokens from one key — and `terraform-github` can manage the App's installations
  and repository access itself once bootstrapped. Per-owner isolation with a single
  managed secret.

**Recommendation:** bootstrap the **personal account (`flungo`) first with a
fine-grained PAT** (fewest moving parts to prove the pipeline end-to-end), then
stand up the **GitHub App** and cut owners over to App auth — onboarding the
personal account first is what unlocks self-bootstrapping the App and the remaining
owners' access (see §7). Wire the GitHub credential as a per-directory variable
(`TF_VAR_github_token` / App inputs) from day one so the PAT→App migration is a
config swap, not a refactor. Record the model in an ADR when settled.

> **Bootstrapping / circularity:** this repo manages GitHub using credentials and
> workflows stored in GitHub. Keep the provider token a manually-managed Actions
> secret (not a Terraform-managed resource) so a broken apply can never lock the
> repo out of its own credentials. The build-out must avoid Terraform managing the
> very secret/branch-protection that gates its own CI on this repo until the setup
> is proven.

---

## 6. CI

Adopt the Grafana repo's `terraform.yml` model — **plan on PR, apply on merge to
`main`, `workflow_dispatch` for on-demand** — with two adaptations for the
multi-owner layout:

- **Matrix over owner directories.** Each job runs `terraform -chdir=owners/<owner>`
  for its owner, so plans/applies are per-workspace. A change touching only one
  owner directory need only run that owner (path filtering is a later
  optimisation; start by running the full matrix).
- **Plan comment per owner.** The PR comment upsert keys off the owner so each
  owner's plan is a distinct, updated comment.

**Drift remediation — deferred / lighter than Grafana.** The Grafana repo applies
daily because it manages *auto-rotating tokens* that must stay authoritative.
`terraform-github` manages mostly static configuration with no self-rotating
resource, so a daily **auto-apply** is not warranted. Recommendation: ship
plan/apply CI first; if drift becomes a real problem, add **plan-only drift
*detection*** (open an issue on drift, do not auto-apply) across the owner matrix,
rather than the Grafana repo's auto-remediation. Decide when we get there.

CI workflow YAML is intentionally **not** written in this documentation PR — its
shape depends on the workspace decision above and belongs with the first module
code.

---

## 7. Build sequence

Each step is its own PR (own plan, own review gate), in order:

> **Progress.** Steps 1–3 are done: structure ratified (ADR-001/002/003); the
> `owners/flungo/` skeleton and plan/apply CI landed; and `modules/repository` is
> extracted with the flungo repositories migrated onto it. Two deviations from the
> original sequence: **CI (step 7) landed early**, with the skeleton at step 2; and
> `github-workflows` and `claude-plugins` were added ahead of step 8, so step 3
> migrated **all three** existing repositories, not `authentik.flungo.net` alone.
> Step 4 (`modules/branch-protection`) is in progress — the module and its
> `authentik.flungo.net` pilot; rolling it out to `github-workflows` and
> `claude-plugins` follows.

1. **Ratify structure** — merge this repo's docs (this PR). Confirm the workspace
   recommendation (§3) and credential model (§5); write **ADR-002** (workspace
   topology) and, if the credential model is settled, an ADR for it.
2. **HCP + personal-account skeleton** — create the HCP `terraform-github` project
   (default execution mode **Local**); add `owners/flungo/` with backend + provider
   + variables and a single imported repository — **`authentik.flungo.net`**, a
   fairly fresh repo that exercises most of the features discussed (it has Terraform
   config, so `terraform = true`) — no modules yet. First `terraform init`
   auto-creates the `github-flungo` workspace (§4). Prove init/plan/apply end-to-end
   with the bootstrap **personal PAT**. *(Personal first: it also unlocks
   self-bootstrapping the GitHub App and the remaining owners' access at step 9.)*
   **Steps 3–7 are proven against `authentik.flungo.net` alone.** Do not bring in
   any other repo or owner until the full pipeline (module → protection → secrets →
   composite → CI) is green for that one repo — see step 8.
3. **`modules/repository`** — extract the standard repo settings into the module and
   convert `authentik.flungo.net` to consume it. No other repos yet.
4. **`modules/branch-protection`** — build the module and protect
   `authentik.flungo.net`'s default branch with the agreed defaults (§1) — right
   after repository management and **before** secrets.
5. **Shared secrets** — `modules/repository-secrets`; apply the common set to
   `authentik.flungo.net` — `LYCHEE_GITHUB_TOKEN`, and the HCP token (it has
   `terraform = true`, §1). (`modules/org-secrets` is not needed until the first org,
   step 10.)
6. **`modules/standard-repository` composite** — compose repository + branch
   protection + secrets; migrate `authentik.flungo.net` to one module call.
7. **CI** — add `terraform.yml` (§6). Prove plan-on-PR / apply-on-merge for the
   single-repo `flungo` workspace.
8. **Onboard the rest of the initial `flungo` set** — only now, with the pipeline
   proven end-to-end on one repo, import and onboard the others in order:
   **`stalwart.flungo.net`, `claude-code-sandbox`, `terraform-grafana-cloud`,
   `terraform-provider-stalwart`, `terraform-cloudflare`**, then **`terraform-github`
   itself** (its self-referential branch protection lands here — it is deliberately
   not among the first onboarded; see the §5 circularity note). Each gets the
   standard module call (protection + secrets). Remaining `flungo` repos are left to
   the MCP/API discovery pass (final step).
9. **GitHub App** — stand up the App, install it on the personal account, and cut
   `flungo` over from the PAT to App auth (§5). This is the self-bootstrapping
   pivot: from here, onboarding a new owner is installing the App and adding a
   directory, not minting and storing a new PAT.
10. **First organisation account — `flungo-docker`** — add `owners/flungo-docker/`,
    its auto-created workspace, its App installation, and its org-level shared
    secrets, starting with the **`avahi`** repo. This is the first non-user account,
    so it is where the user/org account asymmetry (§1) is exercised for real.
11. **Growth modules** — webhooks, teams, and other resources as needed, each with
    its own ADR. (Branch protection is already built at step 4, not deferred here.)
12. **Discover & scope the rest via MCP/API** — with the pattern proven, enumerate
    the remaining `flungo` repos and every other organisation and its repos through
    the GitHub MCP/API, and bring them under management in batches. Left to the end
    deliberately: hand-enumerating them now would be guesswork and churn.

---

## Decisions & open items

Resolved in review (2026-07-20) — carried into the sections above:

- ✅ **Credential model** — bootstrap the personal account with a PAT, then a
  **GitHub App** for per-owner tokens from one key (self-bootstrapping); wire the
  credential per-directory from day one (§5). → ADR when settled.
- ✅ **First owner to onboard** — the **personal account (`flungo`)**; it unlocks
  self-bootstrapping the App and further owners (§7 step 2/9).
- ✅ **Owner directory naming** — by actual GitHub login; personal is
  `owners/flungo/`, noted as the personal account (§2).
- ✅ **Drift** — plan/apply CI first, drift *detection* later, no daily auto-apply
  (§6).
- ✅ **Initial shared secrets** — start with `LYCHEE_GITHUB_TOKEN`; attach the HCP
  token where a repo's module call sets `terraform = true` (§1). Verify HCP token
  scope is org/team-wide at implementation.
- ✅ **Branch protection** — a motivator; the module is built early (§7 step 4,
  before secrets) and proven on `authentik.flungo.net`. Agreed default rules with a
  `strict` bypass toggle; the protected branch is the `pattern` input (composite
  defaults it to the repo's default branch). `terraform-github` is protected when it
  is onboarded (§7 step 8), and is **not** among the first repos onboarded.
- ✅ **Workspace topology** — **Option A (workspace per owner)**, ratified as
  [ADR-002](../decisions/002-workspace-per-owner-topology.md). The per-owner
  overhead concern is addressed (one org-wide HCP token + auto-created workspaces +
  a single GitHub App key).
- ✅ **Initial managed set** — onboarding order fixed (§7): `flungo` starts with
  `authentik.flungo.net`, then `stalwart.flungo.net`, `claude-code-sandbox`,
  `terraform-grafana-cloud`, `terraform-provider-stalwart`, `terraform-cloudflare`,
  then `terraform-github` itself; first organisation is `flungo-docker` (starting
  with `avahi`). Every remaining `flungo` repo and all other orgs/repos are scoped
  via an MCP/API discovery pass at the end (§7 step 12).

- ✅ **Module input surface** — proposal reviewed (§1 "Proposed starting inputs").
  Settled: `description` required; branch-protection input is `pattern` (composite
  defaults it to the repo's default branch); feature toggles baked; merge commits
  off with squash + rebase on (rebase preferred); `required_status_checks` are
  explicit contexts (an empty list enforces nothing) with the `terraform` flag
  adding the Terraform plan check; `terraform`'s primary effect is the HCP token
  secret, while branch protection applies to every repo regardless.

Still to confirm: nothing outstanding. The plan is fully reconciled with review —
next action is to **merge this PR**, then step 1 writes **ADR-002** and step 2
begins the `authentik.flungo.net` skeleton.
