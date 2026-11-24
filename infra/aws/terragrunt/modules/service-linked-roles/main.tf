# Service-linked roles that AWS services need before they'll do something for this account,
# and that AWS doesn't create on its own. Each is defined by AWS; this only creates it.

resource "aws_iam_service_linked_role" "this" {
  for_each = toset(var.services)

  aws_service_name = each.key
}
