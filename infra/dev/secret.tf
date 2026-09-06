resource "aws_secretsmanager_secret" "app" {
  name                    = "ecs-ops-app"
  recovery_window_in_days = 7

  tags = {
    Name = "ecs-ops-app"
  }
}

resource "aws_iam_role_policy" "secret" {
  name = "secret-read"
  role = aws_iam_role.exec.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue"
        ]

        Resource = aws_secretsmanager_secret.app.arn
      }
    ]
  })
}