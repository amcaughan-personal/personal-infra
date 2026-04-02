# GitHub Control Plane

This subtree manages GitHub as infrastructure for the `amcaughan-personal` org.

The AWS control plane lives under [`infra/aws/terragrunt`](/home/aaron/repos/personal_infra/infra/aws/terragrunt), and the GitHub control plane lives here under `infra/github/terragrunt`.

## Structure

- `catalog/`
  - shared desired-state data, starting with the managed repository catalog
- `modules/`
  - reusable Terraform modules for GitHub standards
- `stacks/`
  - Terragrunt stacks that apply those standards to the org

## Authentication

- Terraform state still uses the shared AWS S3 backend, so AWS credentials are required for backend access.
- The GitHub provider itself expects runtime credentials from the environment, typically `GITHUB_TOKEN` or GitHub App credentials.

## First Slice

The initial slice standardizes a protected `main` ruleset across the managed repos:

- pull requests required
- one approval required
- review threads must be resolved
- linear history required
- force pushes blocked
- branch deletion blocked
- repository admins can bypass through pull requests so the setup still works for a solo org

## Next Slices

- repository baseline settings
- GitHub App installation access
- shared labels / variables / repository defaults
- managed cross-repo file updates via PR fan-out automation
