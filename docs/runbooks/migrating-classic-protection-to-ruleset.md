# Migrating a repository from classic branch protection to a ruleset

Some repositories carry **classic branch protection** (repo → Settings → Branches,
the `github_branch_protection` resource) from before they were onboarded to
Terraform. The [`branch-protection`](../../modules/branch-protection) module
protects default branches with a **ruleset** instead (see
[ADR-004](../decisions/004-branch-protection-rulesets.md)), and the two
**double-enforce** if both are present. The composite's guard therefore fails the plan
while any classic rule exists, so onboarding a repo means *migrating* it off classic
protection — not just adding the module call.

This runbook is that migration: **compare the classic rule against the ruleset, then
remove the classic rule.** The comparison is the important part — never remove a
classic rule before confirming the ruleset is equivalent-or-stronger, or you silently
weaken the branch's protection.

## Procedure

1. **Adopt the repository into Terraform.** A repo carrying a classic rule exists on
   GitHub but is not yet managed here, so this step is an *adoption*: a
   `standard-repository` call in the repo's own by-subject file
   `owners/<owner>/<repo>.tf`, paired with an `import {}` block for the repository
   resource. Follow [`importing-repositories.md`](importing-repositories.md) for the
   call, the import block, and the settings to reconcile.

   Do **not** add a standalone [`branch-protection`](../../modules/branch-protection)
   call: the composite already creates the ruleset, and a second one would apply
   alongside it. The primitive is for a genuine partial case only.

   Already-managed repo? Then there is nothing to add — skip to step 2, where the
   guard is already failing every plan.

2. **Open the PR / run the plan.** The plan fails on the guard with
   `<repo> has classic branch protection rule(s) matching [<pattern>]`.

3. **Read the classic rule's settings.** The plan comment surfaces the blocking
   *pattern*; the full settings come from the **`surface-classic-protection`** CI job,
   which runs whenever the plan fails on the guard and prints the repo's complete
   classic settings (GraphQL) to its run summary. Read them there — no manual step.

   <details><summary>To fetch them yourself outside CI</summary>

   ```bash
   gh api graphql -f owner=flungo -f name=<repo> -f query='
     query($owner: String!, $name: String!) {
       repository(owner: $owner, name: $name) {
         branchProtectionRules(first: 100) {
           nodes {
             pattern requiresApprovingReviews requiredApprovingReviewCount
             requiresCodeOwnerReviews dismissesStaleReviews
             requiresConversationResolution requiresLinearHistory
             requiresStatusChecks requiresStrictStatusChecks requiredStatusCheckContexts
             requiresCommitSignatures isAdminEnforced restrictsPushes
             allowsForcePushes allowsDeletions lockBranch
           }
         }
       }
     }'
   ```

   Needs a token with admin read on the repo (`FLUNGO_GITHUB_TOKEN` via `GH_TOKEN`).
   </details>

4. **Compare field-by-field** against the ruleset baseline (below). Confirm every
   protection the classic rule enforces is matched-or-exceeded by the ruleset.

   > **🤖 Agent** — do not recommend removing the classic rule until the comparison
   > shows no protection is lost; if the classic rule enforces something the ruleset
   > doesn't, surface it and ask whether to add it to the module (fleet-wide) or
   > accept the change.

   If the classic rule enforces something the module omits, decide deliberately:
   add it to [`modules/branch-protection`](../../modules/branch-protection) (so the
   whole fleet gains it) or accept dropping it. If the ruleset already covers
   everything, continue.

5. **Remove the classic rule** in the repo → Settings → Branches. Terraform can't do
   this — it doesn't manage the classic rule — so it's a manual step. The branch is
   briefly unprotected between removal and the ruleset applying (step 7); negligible
   for a solo repo, but sequence it so the window is short.

6. **Re-run the plan.** With the classic rule gone the guard passes. For an
   already-managed repo the plan shows just the ruleset as `1 to add` (two, where the
   repo also declares `release_branches`); for an adoption it shows the composite's
   full set — the imported repository plus the ruleset(s) and shared secret(s) — as
   [`importing-repositories.md`](importing-repositories.md) describes.

7. **Merge.** The apply on merge creates the ruleset; the branch is protected again.

## Ruleset baseline (what you're migrating *to*)

The full catalogue is [`docs/reference/branch-protection.md`](../reference/branch-protection.md).
In brief, the ruleset enforces on the default branch: pull request required
(0 approvals), conversation resolution, linear history, blocked force-pushes,
restricted deletion, and any named status checks; admins get a
`pull_request`-scoped bypass unless `strict`. Creation restriction (`creation`) is
available but off for default-branch rulesets, where it has no effect —
see [ADR-008](../decisions/008-restrict-release-branch-creation.md).

## Classic → ruleset field mapping

Classic protection and rulesets expose overlapping but differently-named settings.
Use this to map each classic setting to its ruleset equivalent when comparing:

| Classic setting (GraphQL field) | Ruleset equivalent | Notes |
| --- | --- | --- |
| `requiresApprovingReviews` / `requiredApprovingReviewCount` | `pull_request.required_approving_review_count` | Module default `0` — a solo owner can't approve their own PR. A classic rule requiring ≥1 is *stronger*; decide before dropping. |
| `requiresConversationResolution` | `pull_request.required_review_thread_resolution` | Both `true` in the module. |
| `requiresLinearHistory` | `required_linear_history` | Both `true` in the module. |
| `requiresStatusChecks` / `requiredStatusCheckContexts` | `required_status_checks.required_check[*].context` | Module default: none. Named contexts must be re-listed via the module's `required_status_checks` input. |
| `requiresStrictStatusChecks` | `strict_required_status_checks_policy` | Module sets `false`. |
| `isAdminEnforced` | `bypass_actors` (Admin, `pull_request`) | Classic `isAdminEnforced = true` ≈ ruleset `strict = true` (no bypass). Module default gives admins a PR-scoped bypass. |
| `requiresCodeOwnerReviews` | *(not encoded)* | No CODEOWNERS requirement in the module — flag if the classic rule sets it. |
| `dismissesStaleReviews` | *(not encoded)* | Not modelled (0 required approvals makes it moot). |
| `requiresCommitSignatures` | *(not encoded)* | Flag if set — the module doesn't require signed commits. |
| `restrictsPushes` / push allowances | conditions / `bypass_actors` | The ruleset restricts pushes to PRs implicitly (PR required). Explicit push allowlists aren't modelled. |
| `allowsForcePushes` | `non_fast_forward = true` | The module encodes the force-push block directly. (A required pull request already blocks every direct push, so this is belt-and-braces — but it is a real rule, not an implication.) |
| `allowsDeletions` | `deletion = true` | The module restricts deletion of the protected branch (only `always`-bypass actors may — a PR-scoped admin bypass does not cover deletion). |
| *(no classic equivalent)* | `creation` | Rulesets can restrict who may *create* a matching ref; classic protection has no counterpart, so migration neither gains nor loses it. Off for default-branch rulesets; used for release branches (ADR-008). |
| `lockBranch` | *(not encoded)* | The module doesn't lock branches. |

A blank "ruleset equivalent" means the module doesn't encode that protection —
so if the classic rule sets it `true`/non-empty, dropping the classic rule *loses*
it. Decide whether to extend the module or accept the loss.

## Worked example: authentik.flungo.net

`authentik.flungo.net` was the pilot. Its classic rule on `main`, as fetched with the
query above:

```json
{"pattern":"main","requiresApprovingReviews":true,"requiredApprovingReviewCount":0,
 "requiresCodeOwnerReviews":false,"dismissesStaleReviews":false,
 "requiresConversationResolution":true,"requiresLinearHistory":true,
 "requiresStatusChecks":true,"requiresStrictStatusChecks":false,
 "requiredStatusCheckContexts":[],"requiresCommitSignatures":false,
 "isAdminEnforced":false,"restrictsPushes":false,"allowsForcePushes":false,
 "allowsDeletions":false,"lockBranch":false}
```

Field-by-field against the ruleset:

| Classic setting | authentik value | Ruleset | Verdict |
| --- | --- | --- | --- |
| PR required / approvals | `true` / `0` | PR required, 0 approvals | **Same** |
| Conversation resolution | `true` | `true` | **Same** |
| Linear history | `true` | `true` | **Same** |
| Status checks / contexts | `true` / `[]` | none | **Same** — "require checks" with zero contexts requires nothing, as does an omitted block |
| Strict status checks | `false` | `false` | **Same** |
| Admin enforcement | `isAdminEnforced = false` | Admin `pull_request` bypass | **Ruleset stronger** — classic lets admins bypass entirely (incl. direct push); the ruleset only lets them override *within a PR* |
| Code-owner reviews | `false` | not encoded | No loss (classic doesn't set it) |
| Stale-review dismissal | `false` | not encoded | No loss (moot at 0 approvals) |
| Commit signatures | `false` | not encoded | No loss (classic doesn't set it) |
| Restrict pushes | `false` | PR required (implicit) | **Ruleset ≥** |
| Force pushes | `allowsForcePushes = false` | `non_fast_forward = true` | **Same** |
| Deletions | `allowsDeletions = false` | `deletion = true` | **Same** |
| Lock branch | `false` | not encoded | No loss (classic doesn't set it) |

**Verdict: the ruleset is equivalent-or-stronger on every setting authentik's classic
rule enforces** — matching PR, conversation-resolution, linear-history, force-push
and deletion protection, and stronger on admin handling (a PR-scoped bypass rather than a full admin
exemption). Removing the classic rule is therefore safe — no protection is lost.
