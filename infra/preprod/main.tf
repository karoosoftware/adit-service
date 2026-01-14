locals {
  preprod_sub = "project_path:${var.gitlab_project_path}:ref_type:branch:ref:${var.preprod_branch}"
}

module "ecr" {
  source = "../modules/ecr-repo/0.1.0"

  name                 = "${var.app_name}-preprod"
  max_image_count      = 30
  scan_on_push         = true
  image_tag_mutability = "MUTABLE"
  encryption_type      = "AES256"

  create_gitlab_push_role  = true
  gitlab_role_name         = "gitlab-ecr-preprod"
  gitlab_oidc_provider_arn = "arn:aws:iam::992468223519:oidc-provider/gitlab.com"
  gitlab_sub               = local.preprod_sub
}