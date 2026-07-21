# Runbooks

Step-by-step operational procedures for long-term, repeatable maintenance tasks — *task-oriented* how-to guides referenced indefinitely (no completion checkboxes). Examples this repo expects to grow: **onboarding a new owner** (personal account or organisation), **rotating the GitHub provider token**, **importing existing repositories** into Terraform management.

Contrast with [`../plans/`](../plans/) (one-time procedures, tracked to completion then deleted) and [`../reference/`](../reference/) (information-oriented lookup docs, not procedures).

| Document | Purpose |
|---|---|
| [`onboarding-an-owner.md`](onboarding-an-owner.md) | Onboard a new owner account (personal or organisation): create its directory, HCP workspace, and token, then adopt its repositories |
| [`importing-repositories.md`](importing-repositories.md) | Adopt an existing repository into Terraform via an import block, reviewing the divergence on the PR-posted plan before applying |
| [`github-provider-token-rotation.md`](github-provider-token-rotation.md) | Rotate the `github` provider's fine-grained PAT (`terraform-github-flungo` → `FLUNGO_GITHUB_TOKEN`) before expiry |
