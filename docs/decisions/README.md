# Architecture Decision Records

Decisions are numbered sequentially and never deleted or renumbered. Each file documents the context, decision, and consequences for a key architectural choice. Superseded decisions keep their file and get a note at the top pointing to the newer ADR.

| # | Title | Status | Summary |
|---|---|---|---|
| [001](001-dedicated-terraform-github-repo.md) | Dedicated `terraform-github` repository for GitHub resources | Accepted | Manage GitHub resources across the personal account and organisations as code in a dedicated, provider-scoped repository, structured as one directory per owner consuming shared modules. HCP Terraform backend and CI conventions are inherited from `terraform-grafana-cloud`. |
| [002](002-workspace-per-owner-topology.md) | Workspace-per-owner backend topology | Accepted | One HCP workspace per owner directory (`github-<login>`) in a dedicated `terraform-github` project, Local execution. Chosen for credential scoping and blast-radius isolation; per-owner overhead stays low because the HCP token and GitHub App key are shared and workspaces auto-create on first `init`. |

## Adding a new ADR

1. Create `docs/decisions/<NNN>-<kebab-case-title>.md` using the template below
2. Update this index with a one-sentence summary
3. If the new decision supersedes an existing one, update the older ADR's status to `Superseded by ADR-NNN`

### ADR template

```markdown
# ADR-NNN: Title

Date: YYYY-MM-DD
Status: Accepted

## Context

Why does this decision need to be made?

## Decision

What was decided?

## Consequences

**Positive:**
- ...

**Negative / trade-offs:**
- ...
```
