#############################
# iam_gitlab_ecr.tf (PREPROD)
#############################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  gitlab_audience   = "https://gitlab.com"
  preprod_ecr_repo_arn = "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/adit-service-preprod"
  preprod_sub     = "project_path:${var.gitlab_project_path}:ref_type:branch:ref:${var.preprod_branch}"

}

data "aws_iam_openid_connect_provider" "gitlab" {
  url = "https://gitlab.com"
}

data "aws_iam_policy_document" "gitlab_ecr_push_preprod" {
  # Needed for: aws ecr get-login-password
  statement {
    sid       = "ECRAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Needed for pushing images (Kaniko) to the preprod repo ONLY
  statement {
    sid    = "ECRPushToPreprodRepo"
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
      "ecr:DescribeImages"
    ]
    resources = [local.preprod_ecr_repo_arn]
  }
}

resource "aws_iam_policy" "gitlab_ecr_push_preprod" {
  name   = "gitlab-ecr-push-preprod"
  policy = data.aws_iam_policy_document.gitlab_ecr_push_preprod.json
}

resource "aws_iam_role" "gitlab_ecr_preprod" {
  name = "gitlab-ecr-preprod"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.gitlab.arn
      }
      Condition = {
        StringEquals = {
          "gitlab.com:aud" = local.gitlab_audience
          "gitlab.com:sub" = local.preprod_sub
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "gitlab_ecr_preprod_attach" {
  role       = aws_iam_role.gitlab_ecr_preprod.name
  policy_arn = aws_iam_policy.gitlab_ecr_push_preprod.arn
}

output "aws_role_arn_ecr_preprod" {
  value       = aws_iam_role.gitlab_ecr_preprod.arn
  description = "Assume-role ARN for GitLab develop/preprod pipeline to push to preprod ECR"
}
