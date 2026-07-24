# Migrating a repository from classic branch protection to a ruleset

Some repositories carry **classic branch protection** (repo → Settings → Branches,
the `github_branch_protection` resource) from before they were onboarded to
Terraform. The [`branch-protection`](../../modules/branch-protection) module
protects default branches with a **ruleset** instead (see
[ADR-004](../decisions/004-branch-protection-rulesets.md)), and the two
**double-enforce** if both are present. The module's guard therefore fails the plan
while any classic rule exists, so onboarding a repo means *migrating* it off classic
protection — not just adding the module call.

This runbook is that migration: **compare the classic rule against the ruleset, then
remove the classic rule.** The comparison is the important part — never remove a
classic rule before confirming the ruleset is equivalent-or-stronger, or you silently
weaken the branch's protection.

## Procedure

1. **Add the module call** for the repo in `owners/<owner>/branch-protection.tf`:

   ```hcl
   module "<repo>_protection" {
     source     = "../../modules/branch-protection"
     repository = module.<repo>.name
   }
   ```

2. **Open the PR / run the plan.** The plan fails on the guard with
   `<repo> has classic branch protection rule(s) matching [<pattern>]`.

3. **Read the classic rule's settings.** The plan job's **Surface blocking classic
   protection** step prints the repo's full classic settings (GraphQL) to the run
   summary and the job log — the guard's data source only exposes the pattern, so
   this step is how the settings reach you.

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

6. **Re-run the plan.** With the classic rule gone the guard passes and the plan
   shows the ruleset as `1 to add`.

7. **Merge.** The apply on merge creates the ruleset; the branch is protected again.

## Ruleset baseline (what you're migrating *to*)

The full catalogue is [`docs/reference/branch-protection.md`](../reference/branch-protection.md).
In brief, the ruleset enforces on the default branch: pull request required
(0 approvals), conversation resolution, linear history, and any named status checks;
admins get a `pull_request`-scoped bypass unless `strict`.

## Classic → ruleset field mapping

Classic protection and rulesets expose overlapping but differently-named settings.
Use this to map each classic setting to its ruleset equivalent when comparing:

| Classic setting (GraphQL field) | Ruleset equivalent | Notes |
|---|---|---|
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
| `allowsForcePushes` | PR required (no direct pushes) | A required pull request blocks all direct pushes to the branch, force-pushes included. |
| `allowsDeletions` | `deletion = true` | The module restricts deletion of the protected branch (only bypass actors may delete it). |
| `lockBranch` | *(not encoded)* | The module doesn't lock branches. |

A blank "ruleset equivalent" means the module doesn't encode that protection —
so if the classic rule sets it `true`/non-empty, dropping the classic rule *loses*
it. Decide whether to extend the module or accept the loss.

## Worked example: authentik.flungo.net

`authentik.flungo.net` was the pilot. Its classic rule on `main`, as surfaced by the
plan job:

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
|---|---|---|---|
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
| Force pushes | `allowsForcePushes = false` | PR required (no direct pushes) | **Same** |
| Deletions | `allowsDeletions = false` | `deletion = true` | **Same** |
| Lock branch | `false` | not encoded | No loss (classic doesn't set it) |

**Verdict: the ruleset is equivalent-or-stronger on every setting authentik's classic
rule enforces** — matching PR, conversation-resolution, linear-history, and deletion
protection, and stronger on admin handling (a PR-scoped bypass rather than a full admin
exemption). Removing the classic rule is therefore safe — no protection is lost.
