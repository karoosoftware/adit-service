output "gitlab_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.gitlab.arn
}

output "preprod_role_arn" {
  value = aws_iam_role.gitlab_tf_preprod.arn
}

output "prod_role_arn" {
  value = aws_iam_role.gitlab_tf_prod.arn
}