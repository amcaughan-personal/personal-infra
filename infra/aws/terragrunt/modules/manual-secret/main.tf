# An encrypted parameter whose value is set by hand, never by Terraform:
#
#   read -rs VALUE && aws ssm put-parameter --name <name> --type SecureString --overwrite --value "$VALUE"
#
# Terraform creates it with a placeholder and ignores the value afterwards, so the secret
# never appears in configuration or state.

resource "aws_ssm_parameter" "this" {
  #checkov:skip=CKV_AWS_337:The AWS-managed key is enough here; a customer-managed key adds cost and key management for one parameter
  name        = var.name
  description = var.description
  type        = "SecureString"
  value       = "set-by-hand"

  lifecycle {
    ignore_changes = [value]
  }
}
