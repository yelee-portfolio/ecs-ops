resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]

  tags = {
    Name = "github"
  }
}

data "aws_iam_policy_document" "gh_trust" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:yelee-portfolio@296016621/ecs-ops@1359876553:ref:refs/heads/main"
      ]
    }
  }
}

resource "aws_iam_role" "gh" {
  name               = "ecs-ops-gh"
  assume_role_policy = data.aws_iam_policy_document.gh_trust.json

  tags = {
    Name = "ecs-ops-gh"
  }
}

resource "aws_iam_role_policy" "gh" {
  name = "deploy"
  role = aws_iam_role.gh.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "EcrLogin"
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      },
      {
        Sid    = "EcrPush"
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:DescribeImages"
        ]

        Resource = aws_ecr_repository.app.arn
      },
      {
        Sid    = "EcsRead"
        Effect = "Allow"

        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]

        Resource = "*"
      },
      {
        Sid    = "EcsDeploy"
        Effect = "Allow"

        Action = [
          "ecs:UpdateService"
        ]

        Resource = aws_ecs_service.app.id
      },
      {
        Sid    = "PassRoles"
        Effect = "Allow"

        Action = [
          "iam:PassRole"
        ]

        Resource = [
          aws_iam_role.exec.arn,
          aws_iam_role.task.arn
        ]

        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}

output "deploy_role" {
  value = aws_iam_role.gh.arn
}