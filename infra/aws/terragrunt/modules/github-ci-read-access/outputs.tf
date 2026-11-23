output "managed_policy_arns" {
  description = "AWS managed policies to attach: configuration reads of every resource."
  value       = ["arn:${data.aws_partition.current.partition}:iam::aws:policy/ReadOnlyAccess"]
}

output "deny_data_reads_json" {
  description = "Inline policy: denies reading data contents other than the repo's own."
  value       = data.aws_iam_policy_document.deny_data_reads.json
}

output "plan_reads_json" {
  description = "Inline policy: reads that plans need beyond ReadOnlyAccess."
  value       = data.aws_iam_policy_document.plan_reads.json
}
