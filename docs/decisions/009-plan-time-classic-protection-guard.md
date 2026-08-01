# ADR-009: Evaluate the classic-protection guard at plan time, in the composite

Date: 2026-07-31 Status: Accepted

## Context

[ADR-004](004-branch-protection-rulesets.md) added a guard against classic branch protection: a `github_branch_protection_rules` data source with a `postcondition` that fails when the repository carries any classic rule, because a ruleset and a classic rule double-enforce.
It claimed the guard "makes double enforcement a plan-time error".
Adopting five repositories proved that claim false in the one case the guard exists for.

The guard lived in `modules/branch-protection` and read `var.repository`, which the composite supplied as `module.repository.name` — an attribute of the `github_repository` resource.
**Terraform defers reading a data source whose configuration depends on a resource with pending changes**, and an adoption always leaves the repository resource pending: the `import` plus the settings reconciliation are the entire point.
So on the adoption plan every instance reported

```text
will be read during apply (depends on a resource or a module with changes pending)
```

and the postcondition was never evaluated.
The plan passed, the merge applied, and only then did the guard fire — on three of the five repositories.

That timing is not merely late, it inverts the guard's purpose.
A postcondition evaluated during apply runs *after* the resources it depends on, so all five rulesets had already been created when it failed.
The guard reported double enforcement instead of preventing it, leaving three repositories double-enforced until the classic rules were removed by hand.

The failure compounded: the `surface-classic-protection` CI job parses the plan artifact for guard diagnostics, so with the plan green it printed "nothing to surface" rather than the field-by-field settings the migration runbook depends on.
Both halves of the safety net missed the adoption case simultaneously.

The guard had only ever been exercised against `authentik.flungo.net`, which was already managed and *unchanged* — no pending changes, so its data source read at plan time and the guard behaved as designed.
The adoption path was never tested.

## Decision

**The guard reads a plan-time-known repository name, and lives in the composite.**

- It moves from `modules/branch-protection/guard.tf` to `modules/standard-repository/guard.tf`.
- It reads `var.name` — the caller's own input, a literal string — instead of `module.repository.name`.
  This is the substance of the fix: with no dependency on a pending resource, Terraform reads the data source at plan time in every case, including an adoption, and the postcondition fails the plan before anything is applied.
- The `branch-protection` primitive keeps `var.repository` sourced from `module.repository.name`.
  That dependency is still wanted *there*: it orders ruleset creation after the repository exists, which matters when the composite creates a new repository rather than adopting one.

Placing it in the composite rather than adding a second input to the primitive was chosen over two alternatives — splitting the primitive's input into a static name plus a resource-derived one, and extracting a dedicated `branch-protection-guard` module.
The composite already has `var.name` to hand, so the primitive's input surface is untouched.

**One new composite input is unavoidable: `repository_exists` (default `true`).** Removing the dependency on the repository resource is what fixes adoption, but that dependency was also doing real work for *creation*: it deferred the read until the resource existed.
Read at plan time against a repository GitHub has never heard of, the data source does not return an empty list — it fails the plan outright:

```text
Error: Could not resolve to a Repository with the name 'flungo/<name>'.
```

That was verified on a throwaway branch, not assumed.
So the two cases pull in opposite directions, and Terraform cannot tell them apart:

| | Adoption | Creation |
| --- | --- | --- |
| name from the repository resource | deferred to apply — too late | works |
| name from `var.name` | works | plan fails, `NOT_FOUND` |

`repository_exists` is how the caller says which case it is.
It gates the data source with `count`, and it is **transient** — set `false` only in the change that creates a brand-new repository, then removed once that apply has run, exactly like the `import {}` block an adoption carries and then drops.
Skipping the guard for a create costs nothing: a repository that does not exist cannot carry classic protection.

It defaults to `true`, which is also the safer error.
Someone who wrongly follows the *creation* runbook for a repository that already exists still gets the guard, so if that repository carries classic protection the plan fails and points them at the migration runbook — the mistake surfaces a step earlier than it otherwise would.
(The create would fail regardless: with no state entry and no `import {}` block Terraform plans a *create*, and GitHub rejects a duplicate name at apply.
It cannot silently adopt or overwrite an existing repository — taking over an existing resource always requires an explicit import.)

It also fixes a duplication [ADR-007](007-release-branch-protection.md) recorded as harmless: the guard ran once per *module instance*, so a repository declaring release branches read its classic rules twice per plan.
The repository is the correct scope because that is what the guard actually asks about — *does this repository carry classic protection at all?* — rather than anything about a particular ruleset.
A repository may well have many classic rules, just as it may have many rulesets; the point is that the data source returns all of them in one read, so a second instance issues an identical query and gets an identical answer.
Per-ruleset evaluation bought no extra cover.

Placing it in the composite also matches what the composite *is*.
It encodes the repository-wide baseline, and "this fleet protects branches with rulesets, not classic protection" is precisely such a repo-wide policy — so the check that enforces it belongs alongside the rest of the baseline rather than inside one of the primitives that implements it.

The `branch-protection` primitive is consequently no longer self-guarding when used standalone.
Accepted: the primitive is documented as being for a genuine partial case only, and every managed repository goes through the composite.

## Consequences

**Positive:**

- The guard fails the plan for an adoption, which is the case it was written for — double enforcement is prevented rather than reported after the fact.
- `surface-classic-protection` works again as designed without being changed: it parses the plan artifact, and the guard's diagnostics are now in it.
  The plan artifact is uploaded before the plan-failure check, so a failed plan still produces one.
- One guard evaluation per repository instead of one per ruleset.
- The `branch-protection` primitive's input surface is unchanged.

**Negative / trade-offs:**

- **A new composite input, `repository_exists`, and a two-step dance to create a repository**: set it `false` in the creating change, remove it afterwards.
  The cost is real — a caller can forget to remove it and silently lose the guard on that repository from then on.
  Mitigated by the default (`true`), by the creation runbook making removal an explicit step, and by the flag being conspicuous in a repo file that otherwise carries none.
- `modules/branch-protection` used standalone no longer guards against classic protection.
  Any future direct caller must supply its own guard, or accept the risk.
- The guard is now keyed on the *requested* name (`var.name`) rather than the live resource's name.
  These are the same value in every current call, and a rename would change both together, but they are no longer tied by Terraform.
- The general trap remains latent elsewhere: any future data source whose configuration references a managed resource will defer to apply, and a `postcondition` on it silently becomes a post-hoc report rather than a gate.
  This ADR records the pattern; it does not prevent its recurrence.
