output "apply_role_arn" {
  value = aws_iam_role.apply.arn
}

output "boundary_policy_arn" {
  description = "Attach to every IAM role the repo creates (its applies can't create one without it)."
  value       = aws_iam_policy.boundary.arn
}
