resource "aws_ecs_cluster" "main" {
  name = "ecs-ops"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "ecs-ops"
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "ecs-ops"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.exec.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:v1"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "APP_VERSION"
          value = "v1"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = "ap-northeast-2"
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])

  tags = {
    Name = "ecs-ops"
  }
}

resource "aws_ecs_service" "app" {
  name            = "ecs-ops"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  alarms {
    alarm_names = [
      aws_cloudwatch_metric_alarm.unhealthy.alarm_name
    ]

    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.http,
    aws_route.private_nat,
    aws_iam_role_policy_attachment.exec
  ]

  tags = {
    Name = "ecs-ops"
  }
}