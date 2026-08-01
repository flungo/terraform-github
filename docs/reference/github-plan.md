# GitHub plan and what depends on it

The `flungo` owner is a **personal (user) account on GitHub Pro**.

That is not a billing detail — it is a load-bearing precondition for what this repository manages.
Two properties of the account gate features the config depends on, and they are different properties:

- **The plan** (Free / Pro) decides whether protection can be applied to *private* repositories at all.
- **The account type** (personal vs organisation) decides whether merge queue exists, independently of plan.

This page records what rests on each, so that a surprising `403` or a rejected rule is recognisable rather than mysterious.

## What GitHub Pro is load-bearing for

| Capability | On GitHub Free | On GitHub Pro |
| --- | --- | --- |
| Rulesets / branch protection on **public** repositories | ✓ | ✓ |
| Rulesets / branch protection on **private** repositories | ✗ | ✓ |

Rulesets are available in public repositories on every plan, and in private repositories on Pro, Team and Enterprise Cloud ([About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)).

A ruleset is part of the standard repository, so every managed repository has one — and the fleet includes private repositories.
Their protection therefore exists only because the account is on Pro.
On Free those `github_repository_ruleset` resources would fail rather than silently do nothing, but the error would not say "your plan lapsed", which is the reason this page exists.

## What no plan unlocks on a personal account

**Merge queue** is gated on the repository being owned by an *organisation*, not on plan tier — a personal account cannot use it on a public repository either, and upgrading to Team would not change that ([Managing a merge queue](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue)).

| Owner | Public repository | Private repository |
| --- | --- | --- |
| Personal account (today) | ✗ | ✗ |
| Organisation, any plan | ✓ | ✗ |
| Organisation on Enterprise Cloud | ✓ | ✓ |

This is why [ADR-011](../decisions/011-strict-required-status-checks.md) reaches for strict required status checks instead.
Onboarding a first organisation would make merge queue available to its public repositories only; private ones would need Enterprise Cloud.

**Stacked pull requests are the counter-example** — worth naming so this page is not read as "a personal account gets nothing".
They are [in public preview for all repositories](https://github.blog/changelog/2026-07-30-stacked-pull-requests-are-now-in-public-preview/) with no plan or account-type gate stated, and they rebase and retarget the pull requests above one that merges — automatically on a bottom merge, and behind a **Rebase stack** click when the trunk moves independently.
That covers *dependent* work; independent concurrent pull requests are not a stack and still want merge queue.

**Push rulesets** (as distinct from the branch rulesets this repo uses) need Team or above.
Not currently used — every ruleset here is `target = "branch"`.

## Why this is not asserted in Terraform

It would be better to have the config fail loudly on a plan downgrade than to have a reference page about it.
The provider cannot express that for a personal account.

Checking the pinned provider's schema (`integrations/github` 6.13.0) rather than its docs:

| Data source | Exposes the plan? |
| --- | --- |
| `github_organization` | **Yes** — has a `plan` attribute |
| `github_user` | **No** — `login`, `name`, `public_repos`, `followers`, keys and timestamps only |

So the assertion becomes possible for an *organisation* owner, and a `precondition` on `data.github_organization` is worth adding once one exists.
For the personal account there is no provider-native route; the only option is an `http` data source against `GET /user`, which means a new provider dependency and the token in a request header for a check whose failure is not silent anyway.

> **🤖 Agent** — Do not add the `http` workaround.
> The judgement recorded here is that documenting the dependency beats asserting it for the personal account.
> If an owner directory is ever an organisation, add the `precondition` on `data.github_organization` instead.

**The detection gap worth knowing about:** `terraform-github` runs no drift workflow (plan on PR, apply on merge, nothing scheduled — see the CI section of the README).
A plan downgrade would therefore surface at the next apply, not within a day.
If that ever matters, adding `terraform-drift.yml` is the fix, not a plan assertion.
