# Module: `repository-secrets`

Attaches the fleet's shared/common **GitHub Actions secrets** to a repository
(see [ADR-005](../../docs/decisions/005-shared-secrets-module.md)). This is the
per-repository case; org-level shared secrets
(`github_actions_organization_secret`) will be a separate `org-secrets` module
when the first organisation is onboarded — the two are not symmetric (a personal
account has no org-level secret), which is why shared secrets are their own
module rather than folded into `repository`.

> Owner directories normally consume this via the
> [`standard-repository`](../standard-repository) composite rather than calling it
> directly; call it directly only for a genuine partial case.

The common set today:

- **`LYCHEE_GITHUB_TOKEN`** — attached to **every** managed repository; the token
  the lychee Markdown link-checker uses in CI to avoid rate-limiting.
- **`TF_TOKEN_APP_TERRAFORM_IO`** — attached only where `terraform = true`; the
  org-wide HCP Terraform token, so a repo that holds Terraform config can
  plan/apply in its own CI.

Values are supplied by the owner directory and never hard-coded. In CI they arrive
via the reusable workflow's `tf_secret_vars` secret (composed from the owner's own
Actions secrets with `toJSON`), exported as masked `TF_VAR_*` env vars; the
variables are `sensitive`, so plan output and the plan artifact redact them. Terraform-managing
these secrets is safe because they are written to *other* repos — unlike the
provider/HCP tokens that gate this repo's own CI, which stay manual (see
[`docs/reference/secrets.md`](../../docs/reference/secrets.md)).

## Usage

```hcl
module "authentik_flungo_net_secrets" {
  source     = "../../modules/repository-secrets"
  repository = module.authentik_flungo_net.name

  lychee_github_token = var.lychee_github_token
  terraform           = true
  hcp_token           = var.hcp_token
}
```

Referencing the repository module's `name` output makes the secrets depend on the
repository — the repo is managed before its secrets are attached.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `repository` | `string` | — (required) | Repository name to attach the secrets to. |
| `lychee_github_token` | `string` (sensitive) | — (required) | Value for `LYCHEE_GITHUB_TOKEN`; attached to every repo. |
| `terraform` | `bool` | `false` | When `true`, also attach the HCP token so the repo can run Terraform in its own CI. |
| `hcp_token` | `string` (sensitive) | `""` | Value for `TF_TOKEN_APP_TERRAFORM_IO`; required when `terraform = true`. |
