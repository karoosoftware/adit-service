#############################
# iam_gitlab_ecr_promote.tf (PROD)
#############################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  federated       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/gitlab.com"
  gitlab_audience = "https://gitlab.com"

  prod_sub = "project_path:${var.gitlab_project_path}:ref_type:tag:ref:${var.prod_tag_prefix}*"

  # Source repo (preprod) and destination repo (prod)
  preprod_ecr_repo_arn = "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.app_name}-preprod"
  prod_ecr_repo_arn    = "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.app_name}-prod"
}

data "aws_iam_policy_document" "gitlab_ecr_promote_prod" {
  statement {
    sid       = "ECRAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ReadManifestFromPreprod"
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:ListImages",
      "ecr:DescribeRepositories"
    ]
    resources = [local.preprod_ecr_repo_arn]
  }

  statement {
    sid    = "WriteManifestToProd"
    effect = "Allow"
    actions = [
      "ecr:PutImage",
      "ecr:DescribeImages",
      "ecr:ListImages",
      "ecr:DescribeRepositories"
    ]
    resources = [local.prod_ecr_repo_arn]
  }
}

resource "aws_iam_policy" "gitlab_ecr_promote_prod" {
  name   = "gitlab-ecr-promote-prod"
  policy = data.aws_iam_policy_document.gitlab_ecr_promote_prod.json
}

resource "aws_iam_role" "gitlab_ecr_promote_prod" {
  name = "gitlab-ecr-promote-prod"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = local.federated
      }
      Condition = {
        StringEquals = {
          "gitlab.com:aud" = local.gitlab_audience
        }
        # IMPORTANT: wildcard => StringLike
        StringLike = {
          "gitlab.com:sub" = local.prod_sub
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "gitlab_ecr_promote_prod_attach" {
  role       = aws_iam_role.gitlab_ecr_promote_prod.name
  policy_arn = aws_iam_policy.gitlab_ecr_promote_prod.arn
}