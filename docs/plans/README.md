# Plans

> **Lifecycle:** Plans track one-time procedures to completion, then are retired. When a plan is complete, delete it in a follow-up PR — do not archive or leave it in place. Extract decisions to ADRs, final state to the README/architecture docs, and repeatable procedures to `docs/runbooks/`. See `CLAUDE.md` § Documentation standards → "Plan lifecycle" for the full pre-deletion checklist.

| File | Description | Status |
|---|---|---|
| [initial-buildout.md](initial-buildout.md) | Bootstrap the repo: module structure, directory-per-owner layout, HCP workspace topology, provider/credential model, CI, and build sequence | In progress — §7 steps 1–7 landed (the `repository`, `branch-protection`, `repository-secrets` primitives and the `standard-repository` composite on the `flungo` owner); step 8 (onboard the rest of the `flungo` set) under way — the first five repos are adopted, `terraform-github` itself follows |
