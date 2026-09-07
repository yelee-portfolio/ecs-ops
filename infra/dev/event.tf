data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_event_rule" "deploy_fail" {
  name        = "ecs-ops-deploy-fail"
  description = "ECS deployment failure"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Deployment State Change"]

    resources = [
      aws_ecs_service.app.id
    ]

    detail = {
      eventName = ["SERVICE_DEPLOYMENT_FAILED"]
    }
  })

  tags = {
    Name = "ecs-ops-deploy-fail"
  }
}

resource "aws_cloudwatch_event_target" "deploy_fail" {
  rule = aws_cloudwatch_event_rule.deploy_fail.name
  arn  = aws_sns_topic.alerts.arn
}

data "aws_iam_policy_document" "alerts" {
  statement {
    sid    = "Owner"
    effect = "Allow"

    principals {
      type = "AWS"

      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }

    actions = [
      "SNS:GetTopicAttributes",
      "SNS:SetTopicAttributes",
      "SNS:AddPermission",
      "SNS:RemovePermission",
      "SNS:DeleteTopic",
      "SNS:Subscribe",
      "SNS:ListSubscriptionsByTopic",
      "SNS:Publish"
    ]
    resources = [
      aws_sns_topic.alerts.arn
    ]
  }

  statement {
    sid    = "Events"
    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "events.amazonaws.com"
      ]
    }

    actions = [
      "sns:Publish"
    ]

    resources = [
      aws_sns_topic.alerts.arn
    ]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"

      values = [
        aws_cloudwatch_event_rule.deploy_fail.arn
      ]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.alerts.json
}