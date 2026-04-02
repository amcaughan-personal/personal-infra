# GitHub Control Plane

This subtree manages GitHub as infrastructure for the `amcaughan-personal` org.

The current AWS control plane still lives under [`infra/terragrunt`](/home/aaron/repos/personal_infra/infra/terragrunt). We are keeping that tree in place for now so we can bootstrap GitHub management without coupling it to a larger AWS-path refactor.

## Structure

- `data/`
  - shared inventory data such as managed repositories and GitHub Apps
- `modules/`
  - reusable Terraform modules for GitHub standards
- `stacks/`
  - Terragrunt stacks that apply those standards to the org

## Authentication

- Terraform state still uses the shared AWS S3 backend, so AWS credentials are required for backend access.
- The GitHub provider itself expects runtime credentials from the environment, typically `GITHUB_TOKEN` or GitHub App credentials.

## Current Slices

The first GitHub slices standardize two repository rulesets across the managed repos:

- `protected-main`
  - pull requests required
  - one approval required
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

## Next Slices

- repository baseline settings
- GitHub App installation access
- shared labels / variables / repository defaults
- managed cross-repo file updates via PR fan-out automation

## First App

The first app definition is `platform_sync`, a GitHub App intended to open standardized pull requests across the managed repositories for things like:

- shared workflow SHA bumps
- managed config updates
- repo-wide file rollouts

The app definition lives in `data/apps.yaml`. The installation-management stack lives under `stacks/app-installations/platform-sync`.

Important: the GitHub provider here manages installation repository access, not app registration itself. The app still needs to be created once in GitHub and then wired in with an installation ID under `apps.<name>.installation.id`.

Bootstrap the app registration with:

```bash
scripts/github/app-registration-url.py platform_sync
```
