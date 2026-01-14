resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.encryption_type == "KMS" ? var.kms_key_arn : null
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  count      = var.max_image_count > 0 ? 1 : 0
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire images beyond last ${var.max_image_count}"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.max_image_count
        }
        action = { type = "expire" }
      }
    ]
  })
}

resource "aws_ecr_repository_policy" "this" {
  count      = var.repository_policy_json != null ? 1 : 0
  repository = aws_ecr_repository.this.name
  policy     = var.repository_policy_json
}

data "aws_iam_policy_document" "gitlab_ecr_push" {
  count = var.create_gitlab_push_role ? 1 : 0

  statement {
    sid       = "ECRAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPushToRepo"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:BatchGetImage",
      "ecr:DescribeImages"
    ]
    resources = [aws_ecr_repository.this.arn]
  }
}

resource "aws_iam_policy" "gitlab_ecr_push" {
  count  = var.create_gitlab_push_role ? 1 : 0
  name   = "${var.gitlab_role_name}-policy"
  policy = data.aws_iam_policy_document.gitlab_ecr_push[0].json
}

resource "aws_iam_role" "gitlab_push" {
  count = var.create_gitlab_push_role ? 1 : 0
  name  = var.gitlab_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = var.gitlab_oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "gitlab.com:aud" = var.gitlab_audience
          "gitlab.com:sub" = var.gitlab_sub
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "gitlab_push_attach" {
  count      = var.create_gitlab_push_role ? 1 : 0
  role       = aws_iam_role.gitlab_push[0].name
  policy_arn = aws_iam_policy.gitlab_ecr_push[0].arn
}

