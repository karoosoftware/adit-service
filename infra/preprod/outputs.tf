output "preprod_repo_url" {
  value = module.ecr.repository_url
}

output "aws_role_arn_ecr_preprod" {
  value       = aws_iam_role.gitlab_ecr_preprod.arn
  description = "Assume-role ARN for GitLab develop/preprod pipeline to push to preprod ECR"
}
