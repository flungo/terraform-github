# ADR-008: Restrict release-branch creation to the release automation

Date: 2026-07-30
Status: Accepted

Refines [ADR-007](007-release-branch-protection.md), which stands.

## Context

ADR-007 gave release branches their own ruleset: require a pull request,
block force-pushes, restrict deletion, and grant the release App an
`always` push bypass. Two things surfaced once it was live.

**The ref pattern over-reaches.** `refs/heads/v[0-9]*` reads like the
regex "v followed by digits", and that is how it was intended. Ruleset
ref targeting is **fnmatch**, not regex: there is no anchoring and no `+`
quantifier, so `[0-9]` matches one digit and `*` then matches *anything*.
`v1x`, `v2-test` and `v9-scratch` are all governed by the release ruleset.

**Over-reach plus `deletion = true` was a trap.** A branch accidentally
created under a matching name could not be deleted by anyone: the admin
bypass is `pull_request`-scoped, which does not cover deletion. Only the
release App could remove it, and the App is driven by `release.yml`,
which never deletes. Recovery meant editing the ruleset — a
disproportionate response to a typo, where the obvious fix (delete the
branch) is exactly what the protection forbids.

## Decision

**Restrict creation to the bypass actors.** `modules/branch-protection`
takes `restrict_creation`, and the composite sets it `true` for the
release ruleset — not exposed as a caller knob, because release branches
are cut by the release workflow and never by hand. Only actors with an
`always` bypass may then create a matching ref — the PR-scoped admin bypass
does not cover creation, just as it does not cover deletion — so
`release.yml` still creates `v2` on a major bump via its App, while everyone
else, admins included, is rejected outright.

**Keep the broad glob; accept the over-reach.** The pattern stays
`refs/heads/v[0-9]*` rather than being narrowed to enumerated shapes
(`v[0-9]`, `v[0-9][0-9]`, …). Narrowing was considered and rejected: any
enumeration leaves a gap — `v100` matches none of the above — and that
gap is an *under-reach*, which fails **silently**. A real release branch
would simply be unprotected, with nothing to surface it. Over-reach fails
the other way: it is visible, and with creation restricted nobody can
create the extra refs it covers, so it costs nothing.

The two together are what make the broad glob safe. Restricting creation
turns the trap into a clean rejection at the cheapest possible point, and
that in turn removes the reason to narrow the pattern at all.

**`update` is deliberately not restricted.** It is the adjacent-looking
rule and would be wrong: restricting updates limits pushes to bypass
actors, which would block backport and revert PRs from merging into
`v*`. The require-pull-request rule already governs updates correctly.

## Consequences

**Positive:**

- No version ceiling: `v100` and beyond are covered by the same pattern,
  with no config change and no silent gap.
- An accidental release branch fails at creation with a clear rejection —
  the cheapest point to catch it — instead of being created and then held
  permanently by the deletion rule.
- Release branches are machine-*created*: `release.yml` cuts `v*` and
  nothing else can. Advancing them stays open to merged PRs by design, so
  backports and reverts still land (see the `update` note above).
- The module keeps a single `pattern` input. A list was drafted for the
  enumeration approach and dropped with it, rather than left as unused
  generality.

**Negative / trade-offs:**

- **No branch may be named `v` + digit + anything.** `v2-test`,
  `v1-wip` and similar are rejected at creation for everyone but the App.
  Accepted, and arguably desirable — it keeps the namespace consumers
  resolve `@vN` against unambiguous — but it is a real constraint on
  scratch branch names, and the rejection message will not explain why.
- A human can no longer hand-create a release branch. Bootstrapping a new
  major outside `release.yml`, or restoring a deleted one, requires
  temporarily relaxing the ruleset. Accepted: the same deliberate,
  visible act is already required to force-push or delete one.

## Verification

Both halves of this decision were confirmed against the live repository
on 2026-07-30, after the apply.

The Decision above rests on GitHub's fnmatch honouring `[0-9]` as a
character class. That was an **assumption** when this ADR was written:
it is standard fnmatch and documented as fnmatch, but it had not been
confirmed against the API, and no successful release push could confirm
it — the App bypasses the ruleset either way. Had character classes not
been supported, `refs/heads/v[0-9]*` would have matched nothing and the
release branches would have been unprotected while appearing protected.

Pushing an existing commit to `refs/heads/v0` — inside the pattern but
outside the release line, so a *success* would have been harmless and
easily undone — was rejected:

```text
remote: error: GH013: Repository rule violations found for refs/heads/v0.
remote: - Cannot create ref due to creations being restricted.
```

So the pattern does match real refs, and the creation restriction does
bind a non-bypass identity. The rejection also demonstrates the
trade-off recorded above: it names the rule, not the reason.

This exercises `creation` on a ref that does not yet exist. The
force-push and deletion rules on a *live* release branch were not
separately tested, since doing so would risk the branches consumers pin.
The push path is covered instead by the release App's fast-forwards
through the applied ruleset (github-workflows#20 and #21).
