# Repository topics

A shared vocabulary of GitHub repository topics, so the same concept is tagged
the same way across the fleet. Topics are set through the `topics` input on the
standard repository module (see [`standard-repository.md`](standard-repository.md));
this page catalogues the topics the fleet uses — what each one signals and when to
apply it — and the conventions for choosing them.

## Glossary

### Terraform

| Topic | Signals — and when to apply it |
|---|---|
| `terraform` | The repository is a Terraform *configuration* codebase — `.tf` files managing real resources (e.g. `terraform-grafana-cloud`, `terraform-github`). |
| `terraform-provider` | The repository *implements* a Terraform provider (e.g. `terraform-provider-stalwart`) — provider source code, not configuration that consumes one. |
| `infrastructure-as-code` | The repository defines infrastructure as code — the canonical companion to `terraform`; apply it alongside on any Terraform configuration repo. |

### GitHub Actions, CI, and quality

| Topic | Signals — and when to apply it |
|---|---|
| `github-actions` | GitHub Actions is a defining feature of the repository — it hosts or centres on Actions workflows, not just an incidental CI job. |
| `actions` | The widely-used shorthand paired with `github-actions`; part of the ecosystem tags Actions content as `actions` specifically, so carry both for reach. |
| `reusable-workflows` | The repository publishes reusable workflows (`workflow_call`) that other repositories call. Apply to repos whose purpose is hosting shared, callable workflow definitions. |
| `ci` | The repository provides continuous-integration tooling or standards used by other repositories (shared pipelines, checks, conventions) — CI *is* the subject, rather than the repo merely having a pipeline of its own. |
| `cicd` | The repository spans CI *and* delivery — it builds/tests *and* deploys/applies (e.g. Terraform plan on PR, apply on merge). |
| `code-quality` | The repository provides code-quality tooling or standards — linting, formatting, validation, static analysis — for itself or the wider fleet. |

### Claude

| Topic | Signals — and when to apply it |
|---|---|
| `claude` | Content built for Anthropic's Claude — agents, skills, plugins, or prompts. Apply where Claude tooling is the repository's subject. |
| `claude-code` | Content specific to Claude Code (the CLI/agent) as opposed to Claude in general — e.g. plugins, skills, or hooks aimed at Claude Code. |
| `anthropic` | The vendor tag for Anthropic's tools; the Claude ecosystem pairs it with `claude` / `claude-code` for discoverability. |

### Plugins and distribution

These are **ecosystem-agnostic** — they describe the *kind* of artefact, for any
software, not a particular platform. A Claude-specific set is narrowed by pairing
them with `claude` / `claude-code`, not by redefining these.

| Topic | Signals — and when to apply it |
|---|---|
| `plugin` | The repository is, or contains, a plugin — for any software or ecosystem. Use the singular `plugin`: it is the widely-used form, far more common than `plugins`. |
| `marketplace` | The repository is an installable marketplace or registry others install from, rather than a single artefact. |

## Conventions for choosing topics

- **Keep a repo's existing topics by default.** Adoption imports the live topics
  (see [`../runbooks/importing-repositories.md`](../runbooks/importing-repositories.md));
  don't churn them without reason.
- **Prefer a topic already in this glossary** over coining a near-synonym, so one
  concept is tagged identically fleet-wide.
- **Prefer a widely-used topic over a niche one.** When a concept isn't in the
  glossary yet, reach for an established topic already common across GitHub — weigh
  its repo count and follow the **Related Topics** on `github.com/topics/<name>` to
  find the established neighbours — rather than a bespoke tag. Widely-used topics
  aid discoverability for people, search engines, and bots, and keep the fleet
  aligned with each ecosystem's conventions. Then record it here.
- **Skip topics that don't narrow anything.** Avoid tags too broad to be meaningful
  (e.g. `ai`, `devops`) and vendor tags that merely restate a more specific one
  (e.g. `hashicorp` on a `terraform` repo). A vendor tag earns its place only where
  the ecosystem actively uses it for discovery (e.g. `anthropic` in the Claude
  ecosystem).
- **Add a new topic to this glossary only when a genuinely new category is needed**
  that no existing entry covers — in the *same* change that first applies it,
  never speculatively.
- **Follow GitHub's topic rules.** Topics are lowercase; words are separated by
  hyphens (no spaces or underscores); digits are allowed and a topic may start
  with one. A topic is at most 50 characters, and a repository may carry up to 20.
- **Topics are always public** — a topic set on a private repository is still
  visible publicly, so never encode anything sensitive in one.

## Finding a new topic

When a repository needs a topic that isn't in the glossary yet, vet the candidate
against how GitHub actually uses it. The signals are all on
`github.com/topics/<name>` or a `topic:<name>` repository search:

- **Popularity** — the repository count; prefer the form with the most repos.
- **Variants** — compare singular vs plural and near-synonyms; the popular form is
  not always the obvious one (`plugin` far outweighs `plugins`; `ci` beats
  `continuous-integration`).
- **Curated description** — GitHub's featured-topic blurb, to confirm the meaning
  matches your intended use.
- **Related Topics** — the neighbours listed on the topic page, to surface other
  established topics worth adopting.
- **Real usage** — the topic sets on the top-starred repos in the space, for the
  community's working vocabulary.

> **🤖 Agent** — Vet a candidate against those signals, apply the conventions above
> (prefer a listed topic; prefer widely-used; skip anything too broad or
> vendor-noise), then add the chosen topic to this glossary in the same change that
> first applies it.
