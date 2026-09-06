resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/ecs-ops"
  retention_in_days = 3

  tags = {
    Name = "ecs-ops"
  }
}