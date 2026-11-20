resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "GuardDutyFindingsToSNS"
  description = "Route selected GuardDuty findings to SNS"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [
        { numeric = [">=", var.min_severity] }
      ]
    }
  })
}


# Turn the raw finding JSON into a short plain-text email. GuardDuty's description already
# says who did what from where, so the message adds severity, timing and a console link.
locals {
  message_lines = [
    "GuardDuty finding (severity <severity>, 7+ is high): <title>",
    "",
    "Type:    <type>",
    "Account: <account> (<region>)",
    "Seen:    <first_seen> to <last_seen> (<count> events)",
    "",
    "What happened:",
    "<description>",
    "",
    "Review or archive it: https://<region>.console.aws.amazon.com/guardduty/home?region=<region>#/findings?fId=<id>",
  ]

  # A quoted JSON string tells EventBridge to deliver plain text. jsonencode escapes < and >,
  # which EventBridge needs literally to recognise <placeholders>, so put them back.
  message_template = replace(replace(jsonencode(join("\n", local.message_lines)), "\\u003c", "<"), "\\u003e", ">")
}

resource "aws_cloudwatch_event_target" "to_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "SendToSNS"
  arn       = var.sns_topic_arn

  input_transformer {
    input_paths = {
      title       = "$.detail.title"
      severity    = "$.detail.severity"
      type        = "$.detail.type"
      account     = "$.detail.accountId"
      region      = "$.detail.region"
      id          = "$.detail.id"
      first_seen  = "$.detail.service.eventFirstSeen"
      last_seen   = "$.detail.service.eventLastSeen"
      count       = "$.detail.service.count"
      description = "$.detail.description"
    }
    input_template = local.message_template
  }
}
