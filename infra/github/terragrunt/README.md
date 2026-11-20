# GitHub Control Plane

This subtree manages GitHub as infrastructure for the `amcaughan-personal` org.

The current AWS control plane still lives under [`infra/terragrunt`](../../terragrunt). We are keeping that tree in place for now so we can bootstrap GitHub management without coupling it to a larger AWS-path refactor.

## Structure

- `config/repositories.yaml`: every managed repository and what it gets (rulesets,
  required checks, a production environment). Adding a repo means adding an entry here.
- `modules/repositories/`: everything managed about each repository, for each entry
- `live/repositories/`: applies it (one stack, one state, one plan for the whole org)

## Authentication

- Terraform state still uses the shared AWS S3 backend, so AWS credentials are required for backend access.
- The GitHub provider itself expects runtime credentials from the environment, typically `GITHUB_TOKEN` or GitHub App credentials.

## Current Slices

Per repository, as listed in `config/repositories.yaml`:

- the repository itself (imported; Terraform never deletes one: destroy is blocked, and
  removing it from the config would archive it). Org standard, set as module defaults:
  - squash or rebase merges only; branches deleted after merging
  - issues on; wiki and projects off (docs live in each repo)
  - vulnerability alerts, secret scanning and push protection on (free for public repos)
  - description, homepage and topics per repo; GitHub Pages left to each repo's workflow

- `protected-main`
  - pull requests required
  - each repo's `required_checks` (in `config/repositories.yaml`) must pass, reported by GitHub Actions
  - no approvals required (solo org), but every change still goes through a PR
  - review threads must be resolved
  - linear history required
  - force pushes blocked
  - branch deletion blocked
  - repository admins can bypass through pull requests so the setup still works for a solo org
- `release-tags`
  - targets release tags matching `v*`
  - allows creating new release tags
  - blocks deleting or retargeting an existing release tag
  - repository admins can bypass directly for break-glass cleanup or repair
- `production` environment (repos with `production_environment: true`)
  - deploys only from `main`
  - a reviewer from `production_reviewers` must approve each deploy; admins can't bypass
  - a repo's AWS deploy role trusts only jobs in this environment (OIDC subject
    `repo:amcaughan-personal/<repo>:environment:production`), so the approval can't be skipped
    by editing a workflow

## Next Slices

- repository baseline settings
- shared labels / variables / repository defaults
- managed cross-repo file updates via PR fan-out automation
