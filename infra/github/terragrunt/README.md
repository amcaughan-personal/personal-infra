# GitHub Control Plane

This subtree manages GitHub as infrastructure for the `amcaughan-personal` org.

The current AWS control plane still lives under [`infra/aws/terragrunt`](../../aws/terragrunt). We are keeping that tree in place for now so we can bootstrap GitHub management without coupling it to a larger AWS-path refactor.

## Structure

- `config/repositories.yaml`: every managed repository and what it gets (rulesets,
  required checks, a production environment). Adding a repo means adding an entry here.
- `modules/repositories/`: everything managed about each repository, for each entry
- `live/repositories/`: applies it (one stack, one state, one plan for the whole org)

## Authentication

- Terraform state still uses the shared AWS S3 backend, so AWS credentials are required for backend access.
- The GitHub provider itself expects runtime credentials from the environment, typically `GITHUB_TOKEN` or GitHub App credentials.

## What each repository gets

Per entry in `config/repositories.yaml` (set only what differs from the defaults):

- **The repository itself.** Terraform never deletes one: destroy is blocked, and removing an
  entry would archive the repo. Org standard, set as module defaults:
  - squash or rebase merges only; branches deleted after merging
  - issues on; wiki and projects off (docs live in each repo)
  - vulnerability alerts, secret scanning and push protection on (free for public repos)
  - description, homepage and topics per repo; GitHub Pages left to each repo's workflow
- **Protected Main** (on unless `protected_main: false`)
  - every change goes through a PR (no approval needed in a solo org); threads resolved
  - the repo's `required_checks` must pass, reported by GitHub Actions
  - linear history; no force pushes or branch deletion
  - admins can bypass, but only through a PR
- **Deployment environments** (e.g. `environments: { staging: {}, production: { approval: true } }`)
  - deploy only from `main`
  - with `approval: true`, a reviewer from `deploy_reviewers` must approve each deploy;
    admins can't bypass (set `approval: false` for pure CI/CD; main-only still applies)
  - a repo's AWS deploy role for an environment trusts only jobs in it (OIDC subject
    `repo:amcaughan-personal/<repo>:environment:<name>`), so neither rule can be skipped by
    editing a workflow

## Creating a repository

1. Add an entry, usually starting from the template:

   ```yaml
     my-project:
       description: "What it is"
       template: repo-template
   ```

2. Plan and apply `live/repositories`. The repo is created with the standard settings and
   Protected Main, and its first commit has the shared security scan.
3. Add `required_checks` once its workflows have run on a PR (the template's three scans:
   `security / trivy / trivy`, `security / gitleaks / gitleaks`, `security / actionlint / actionlint`).

Without `template`, the repo starts with an empty README so `main` exists.
