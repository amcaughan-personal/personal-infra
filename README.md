# personal_infra

Personal AWS and GitHub infrastructure managed with Terragrunt and Terraform.

This repository defines a small, opinionated personal control plane focused on:
- account-level security visibility
- high-signal alerts
- cost guardrails
- low-friction automation for disposable resources
- a shared low-cost dev network foundation for private service testing
- standardized GitHub governance for managed repositories

This is just for me personally to manage the infrastructure and repository standards I use for experiments and demos.

What’s in here

- GitHub repository standards managed as infrastructure
- CloudTrail with targeted CloudWatch alarms (root login, IAM changes, trail tampering)
- GuardDuty with optional automated response for EC2 cryptomining
- Account-wide S3 public access block
- Cost controls (Budgets, Cost Anomaly Detection)
- Scheduled automation for cleaning up opted-in disposable resources
- Secure S3 patterns for logs and state
- Shared dev VPC and shared endpoint stacks for private API/service experiments
- Terragrunt-based layout for clarity and dependency management across both AWS and GitHub control-plane code

What’s intentionally not in here

- Automated apply from CI (this core infra repo would need basically full admin, that's too unsafe)
  Changes are applied manually to keep a clear human approval boundary
- Multi-account / Organizations setup (Not trying to create a pile of spaghetti, this is for small use cases)

Usage

This repo is applied manually via Terragrunt. CI is limited to static analysis and security scanning.

Local tooling lives under `local-dev/`.

AWS control-plane stacks live under `infra/aws/terragrunt`.

GitHub control-plane stacks live under `infra/github/terragrunt`.

Shared dev network stacks live under `infra/aws/terragrunt/live/network/dev`:
- `vpc`
  cheap shared foundation intended to stay up
- `endpoints`
  hourly-cost private connectivity layer intended to be easy to create/destroy

That split is deliberate. The VPC itself is cheap; the interface endpoints are the part I may tear down when I'm not actively testing private connectivity.

Scheduled automation stacks live under `infra/aws/terragrunt/live/automation`:
- `cleanup-janitor`
  daily account janitor for explicitly tagged disposable resources

If you copy pieces from this repo, do so deliberately. Most modules are tightly scoped to a single-account context.

License

MIT
