locals {
  gitlab_issuer_url = "https://gitlab.com"
  gitlab_audience   = "https://gitlab.com"

  preprod_sub   = "project_path:${var.gitlab_project_path}:ref_type:branch:ref:${var.preprod_branch}"
  prod_sub_like = "project_path:${var.gitlab_project_path}:ref_type:tag:ref:${var.prod_tag_prefix}*"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "terraform_backend" {
  statement {
    sid     = "TerraformStateBucketList"
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${var.tf_state_bucket_name}"
    ]
  }

  statement {
    sid    = "TerraformStateObjectRW"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::${var.tf_state_bucket_name}/*"
    ]
  }

  statement {
    sid    = "TerraformLockTableRW"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem",
      "dynamodb:DescribeTable"
    ]
    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.tf_lock_table_name}"
    ]
  }
}

# Minimal ECR permissions to create/manage repos + lifecycle + policy
data "aws_iam_policy_document" "ecr_manage" {
  # Needed to create repositories and set policy/lifecycle
  statement {
    sid    = "ECRManageRepo"
    effect = "Allow"
    actions = [
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:DescribeRepositories",
      "ecr:TagResource",
      "ecr:UntagResource",
      "ecr:ListTagsForResource",
      "ecr:PutLifecyclePolicy",
      "ecr:GetLifecyclePolicy",
      "ecr:DeleteLifecyclePolicy",
      "ecr:SetRepositoryPolicy",
      "ecr:GetRepositoryPolicy",
      "ecr:DeleteRepositoryPolicy",
      "ecr:PutImageScanningConfiguration"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "gitlab_tf_backend" {
  name   = "gitlab-tf-backend"
  policy = data.aws_iam_policy_document.terraform_backend.json
}

resource "aws_iam_policy" "gitlab_tf_ecr_manage" {
  name   = "gitlab-tf-ecr-manage"
  policy = data.aws_iam_policy_document.ecr_manage.json
}

# Attach policies to both roles
resource "aws_iam_role_policy_attachment" "preprod_backend" {
  role       = aws_iam_role.gitlab_tf_preprod.name
  policy_arn = aws_iam_policy.gitlab_tf_backend.arn
}

resource "aws_iam_role_policy_attachment" "preprod_ecr" {
  role       = aws_iam_role.gitlab_tf_preprod.name
  policy_arn = aws_iam_policy.gitlab_tf_ecr_manage.arn
}

resource "aws_iam_role_policy_attachment" "prod_backend" {
  role       = aws_iam_role.gitlab_tf_prod.name
  policy_arn = aws_iam_policy.gitlab_tf_backend.arn
}

resource "aws_iam_role_policy_attachment" "prod_ecr" {
  role       = aws_iam_role.gitlab_tf_prod.name
  policy_arn = aws_iam_policy.gitlab_tf_ecr_manage.arn
}


# Terraform needs thumbprint_list for this resource; we can fetch the cert chain and compute it.
data "tls_certificate" "gitlab" {
  url = local.gitlab_issuer_url
}

resource "aws_iam_openid_connect_provider" "gitlab" {
  url            = local.gitlab_issuer_url
  client_id_list = [local.gitlab_audience]

  # Use the last cert in the chain (root/intermediate depending on chain) as the thumbprint.
  # This is a common Terraform pattern for OIDC providers.
  thumbprint_list = [data.tls_certificate.gitlab.certificates[length(data.tls_certificate.gitlab.certificates) - 1].sha1_fingerprint]
}

# -------------------------
# Role 1: Preprod Terraform role (develop branch only)
# -------------------------
resource "aws_iam_role" "gitlab_tf_preprod" {
  name = "gitlab-tf-preprod"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = aws_iam_openid_connect_provider.gitlab.arn
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

# -------------------------
# Role 2: Prod Terraform role (tags only, v*)
# -------------------------
resource "aws_iam_role" "gitlab_tf_prod" {
  name = "gitlab-tf-prod"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = aws_iam_openid_connect_provider.gitlab.arn
      }
      Condition = {
        StringEquals = {
          "gitlab.com:aud" = local.gitlab_audience
        }
        # Wildcards supported for GitLab sub filtering patterns (use StringLike). :contentReference[oaicite:2]{index=2}
        StringLike = {
          "gitlab.com:sub" = local.prod_sub_like
        }
      }
    }]
  })
}

# ---------------------------------------------
# Allow TF runner roles to manage gitlab-ecr-* IAM
# (needed because app/IAM resources are created by Terraform runs)
# ---------------------------------------------
data "aws_iam_policy_document" "tf_manage_gitlab_ecr_iam" {
  statement {
    sid    = "ManageGitlabEcrRolesPolicies"
    effect = "Allow"
    actions = [
      # Required for terraform plan/refresh
      "iam:GetRole",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:GetRolePolicy",

      # Required for apply (create/update/delete)
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",

      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",

      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/gitlab-ecr-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/gitlab-ecr-*"
    ]
  }
}

resource "aws_iam_policy" "gitlab_tf_manage_gitlab_ecr_iam" {
  name   = "gitlab-tf-manage-gitlab-ecr-iam"
  policy = data.aws_iam_policy_document.tf_manage_gitlab_ecr_iam.json
}

resource "aws_iam_role_policy_attachment" "preprod_manage_gitlab_ecr_iam" {
  role       = aws_iam_role.gitlab_tf_preprod.name
  policy_arn = aws_iam_policy.gitlab_tf_manage_gitlab_ecr_iam.arn
}

resource "aws_iam_role_policy_attachment" "prod_manage_gitlab_ecr_iam" {
  role       = aws_iam_role.gitlab_tf_prod.name
  policy_arn = aws_iam_policy.gitlab_tf_manage_gitlab_ecr_iam.arn
}
