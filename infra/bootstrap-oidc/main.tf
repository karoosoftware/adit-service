locals {
  gitlab_issuer_url = "https://gitlab.com"
  gitlab_audience   = "https://gitlab.com"

  preprod_sub = "project_path:${var.gitlab_project_path}:ref_type:branch:ref:${var.preprod_branch}"
  prod_sub_like = "project_path:${var.gitlab_project_path}:ref_type:tag:ref:${var.prod_tag_prefix}*"
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

# NOTE: Intentionally no permissions attached yet.
# OIDC smoke test only needs sts:GetCallerIdentity, which works without extra IAM permissions.
