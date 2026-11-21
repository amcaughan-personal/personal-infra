# personal_infra

Personal infrastructure managed with Terragrunt and Terraform:
- **AWS**: my personal AWS account, under `infra/aws/terragrunt`
- **GitHub**: the `amcaughan-personal` org's repositories, rulesets and environments, under [`infra/github/terragrunt`](infra/github/terragrunt/README.md)

Both trees share the same S3 state backend, local Docker tooling, and manual apply process.

Tool versions (Terraform, Terragrunt) are set once in [`.tool-versions`](.tool-versions). The dev image (`local-dev/dev-shell.sh`, which rebuilds when the file changes), CI's format check and `root.hcl`'s version constraints all read it, so local runs and CI always use the same versions.
The AWS side defines a small, opinionated baseline focused on:
- account-level security visibility
- high-signal alerts
- cost guardrails
- low-friction automation for disposable resources
- a shared low-cost dev network foundation for private service testing

This is just for me personally to manage my AWS account.

What’s in here

- CloudTrail with targeted CloudWatch alarms (root login, IAM changes, trail tampering)
- GuardDuty with optional automated response for EC2 cryptomining
- Account-wide S3 public access block
- Cost controls (Budgets, Cost Anomaly Detection)
- Scheduled automation for cleaning up opted-in disposable resources
- Secure S3 patterns for logs and state
- Shared dev VPC and shared endpoint stacks for private API/service experiments
- Terragrunt-based layout for clarity and dependency management
- Every resource tagged with `Repo` and `Stack`, so anything in the console points back to the code that manages it

What’s intentionally not in here

- Automated apply from CI (this core infra repo would need basically full admin, that's too unsafe)
  Changes are applied manually to keep a clear human approval boundary
- Multi-account / Organizations setup (Not trying to create a pile of spaghetti, this is for small use cases)

Usage

This repo is applied manually via Terragrunt. CI is limited to static analysis and security scanning.

Local tooling lives under `local-dev/`.

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
