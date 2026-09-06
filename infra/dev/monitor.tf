variable "email" {
  type      = string
  sensitive = true
}

resource "aws_sns_topic" "alerts" {
  name = "ecs-ops-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.email
}

resource "aws_cloudwatch_metric_alarm" "unhealthy" {
  alarm_name          = "ecs-ops-unhealthy"
  alarm_description   = "ALB target is unhealthy"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "ecs-ops-5xx"
  alarm_description   = "Application returned 5xx responses"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "ecs-ops-cpu"
  alarm_description   = "ECS CPU utilization is high"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "memory" {
  alarm_name          = "ecs-ops-memory"
  alarm_description   = "ECS memory utilization is high"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "ecs-ops"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "Target health"
          region = "ap-northeast-2"
          period = 60
          stat   = "Average"

          metrics = [
            [
              "AWS/ApplicationELB",
              "HealthyHostCount",
              "TargetGroup",
              aws_lb_target_group.app.arn_suffix,
              "LoadBalancer",
              aws_lb.app.arn_suffix
            ],
            [
              "AWS/ApplicationELB",
              "UnHealthyHostCount",
              "TargetGroup",
              aws_lb_target_group.app.arn_suffix,
              "LoadBalancer",
              aws_lb.app.arn_suffix
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "ECS CPU and memory"
          region = "ap-northeast-2"
          period = 60
          stat   = "Average"

          metrics = [
            [
              "AWS/ECS",
              "CPUUtilization",
              "ClusterName",
              aws_ecs_cluster.main.name,
              "ServiceName",
              aws_ecs_service.app.name
            ],
            [
              "AWS/ECS",
              "MemoryUtilization",
              "ClusterName",
              aws_ecs_cluster.main.name,
              "ServiceName",
              aws_ecs_service.app.name
            ]
          ]
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          title  = "Application logs"
          region = "ap-northeast-2"
          view   = "table"
          query  = "SOURCE '/ecs/ecs-ops' | fields @timestamp, @message | sort @timestamp desc | limit 50"
        }
      }
    ]
  })
}