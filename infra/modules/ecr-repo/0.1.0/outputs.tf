data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

output "repository_name" {
  value = aws_ecr_repository.this.name
}

output "repository_arn" {
  value = aws_ecr_repository.this.arn
}

output "repository_url" {
  value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${aws_ecr_repository.this.name}"
}

output "gitlab_push_role_arn" {
  value       = var.create_gitlab_push_role ? aws_iam_role.gitlab_push[0].arn : null
  description = "ARN of the GitLab role allowed to push to this repo"
}
