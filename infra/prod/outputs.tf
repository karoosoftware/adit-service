output "preprod_repo_url" {
  value = module.ecr.repository_url
}

output "aws_role_arn_ecr_promote_prod" {
  value       = aws_iam_role.gitlab_ecr_promote_prod.arn
  description = "Assume-role ARN for GitLab tag pipeline to promote image from preprod ECR to prod ECR without rebuilding"
}
