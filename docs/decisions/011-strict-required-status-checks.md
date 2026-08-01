# ADR-011: Require branches to be up to date before merging

Date: 2026-07-31
Status: Accepted

Refines [ADR-004](004-branch-protection-rulesets.md), which stands.

## Context

A required status check proves that CI passed on the pull request's head.
It does not prove that CI passed on anything resembling what will land.
If the base branch has moved since the check ran, the merge combines two trees that were never tested together — each pull request green in isolation, `main` broken by their combination.
Nothing in the pull request surfaces this; the check is a tick against a base that no longer exists.

This is not hypothetical for `terraform-github` in particular.
Two pull requests touching different owner files both plan cleanly on their own, and the second one's plan is computed against state that the first one's apply has already changed.

GitHub exposes exactly the setting for this — `strict_required_status_checks_policy` on a ruleset's status-check rule, "require branches to be up to date before merging" in the UI.
The module has carried it, hardcoded `false`, since [ADR-004](004-branch-protection-rulesets.md).

### Merge queue is not available to this fleet, on any plan it would buy

The obvious richer answer is GitHub's merge queue — the equivalent of GitLab's merge trains, which speculatively test the queued combination rather than blocking on it.
It is unavailable here, and the constraint is **account type, not plan tier**:

| Owner | Public repository | Private repository |
|---|---|---|
| Personal account (this fleet today) | ✗ | ✗ |
| Organisation, any plan | ✓ | ✗ |
| Organisation on Enterprise Cloud | ✓ | ✓ |

The `flungo` account is a personal account, so merge queue is out entirely.
Onboarding a first organisation would reach only the public repositories; the private ones would need Enterprise Cloud, which is not a proportionate spend for a single-maintainer fleet.

That turns out not to be the binding constraint, because merge queue's two halves have very different value here:

- **Correctness** — never merge something whose CI passed against a stale base.
  Strict checks deliver this.
- **Throughput** — avoid serialising manual rebases when many pull requests are in flight.
  This is what merge queue adds, and it is worth close to nothing when one maintainer works one pull request at a time.

So strict checks are not a downgrade accepted under a licensing constraint.
They are the appropriate mechanism at this fleet's volume, and merge queue would mostly remove a rebase cost that is already being absorbed anyway.

## Decision

**`strict_required_status_checks_policy = true` is encoded in `modules/branch-protection`** — not exposed as an input.
Unlike linear history or the force-push block, which are unconditional rule attributes, this one sits inside the status-check block and so exists only where contexts do.

Encoding rather than configuring follows from what the setting does: it is what makes a required check mean anything.
A repository that has decided to require a check has already decided it wants that check to be true of the merge, not merely of some earlier state of the branch.
There is no coherent position that wants the check but not its strictness, so there is nothing for an input to express.

Not adding an input also avoids a naming collision that would have been actively misleading.
The module already has `strict`, meaning *remove the admin bypass*.
A second input about strict *checks* beside it would invite exactly the wrong reading of both.

### It rolls out with the checks, not on its own

The module emits the whole `required_status_checks` block only when contexts are supplied, so where none are the setting is never sent at all.
That — not any claim about how GitHub treats it — is why the change is inert on every repository that requires no checks, which today is most of the fleet.

It therefore does not need its own rollout.
Each repository gains the behaviour at the moment it gains a required check, as it adopts the shared Terraform jobs.
The two repositories that already require `terraform / terraform` — `terraform-github` and `terraform-grafana-cloud` — get it immediately.

### What it does and does not guarantee

Being precise here matters, because the setting is easy to over-read.

It guarantees the head contained every commit on the base at the moment the check passed.
It does **not** guarantee that CI ran on the commit that lands: this fleet keeps a linear history, so a squash or rebase merge always produces a *new* commit that no check ever saw.
What is preserved is the **tree**, not the SHA — for a branch merged while its base has not moved since the check, the resulting tree is identical to the tested one.
That is the meaningful guarantee, and it is the same one a GitLab semi-linear merge gives.

## Consequences

**Positive:**

- A required check now constrains the merge rather than a snapshot of the branch that may predate it — the property the check was assumed to have, subject to the admin bypass noted below.
- Applies to `terraform-github` itself, where the failure mode is worst: a stale plan is not merely untested, it is computed against superseded state.
- No new input, so the standard stays the standard, and `strict` keeps its single meaning.
- Rides each repository's CI adoption rather than needing a rollout of its own — a repository cannot end up with required checks that are not strict.
- **It makes GitHub's "Update branch" button appear**, which is the opposite of what it first looks like.
  The standard sets `allow_update_branch = false`, and that setting only governs whether the button is *always* suggested; GitHub shows it regardless once the base requires branches to be up to date.
  Its dropdown offers **Update with rebase**, so the branch can be brought up to date server-side without a local rebase and force-push, and without the merge commit that would break linear history.

**Negative / trade-offs:**

- **A merge now invalidates every other open pull request** against that branch: each must rebase and re-run CI before it can merge.
  At one-pull-request-at-a-time volume this costs nothing, but it scales badly.
  Three mitigations cover different parts of it.
  **Stacked pull requests** ([public preview since 2026-07-30](https://github.blog/changelog/2026-07-30-stacked-pull-requests-are-now-in-public-preview/)) cover *dependent* work: a stack merges bottom-up and GitHub rebases and retargets the pull requests above, which is precisely the manual step strict checks impose.
  That is automatic on a bottom merge; when the trunk moves independently — the case strict checks actually create — it is a **Rebase stack** click rather than a local rebase and force-push.
  They need no organisation and no plan change, they enforce branch protection on every pull request in the stack rather than only the bottom, and they require the linear history this fleet already mandates — so nothing here has to change to use them.
  **Merge queue** covers the other half, *independent* concurrent pull requests, which are not a stack and so gain nothing from the above; that remains organisation-gated, per the table above.
  **Delegating the loop** needs neither: an agent given permission to merge can watch a pull request and rebase, push and retry until it lands, which is the whole of the cost strict checks add.
  Reach for that first, use stacked pull requests where the work is genuinely dependent, and treat merge queue as the escalation.
- **Redundant on a repository with a single active contributor and no concurrent pull requests** — which is most of the fleet, most of the time.
  Accepted: the cost is zero in exactly the case where the benefit is zero, and it is the concurrent case that this exists for.
- **It binds nobody while `strict = false`.** The module grants repository admins a pull-request-scoped bypass unless `strict` is set, and no repository sets it — so for the sole admin the requirement is advisory, overridable at the point of merge.
  That is the same trade-off ADR-004 accepted for every other rule in the ruleset and is not made worse here, but it means the guarantee is "the branch was up to date, or someone chose otherwise deliberately" rather than an invariant.
  `strict = true` is what would make it binding.
