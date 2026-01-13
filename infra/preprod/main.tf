module "ecr" {
  source = "../modules/ecr-repo/0.1.0"

  name                = "${var.app_name}-preprod"
  max_image_count     = 30
  scan_on_push        = true
  image_tag_mutability = "MUTABLE"

  repository_policy_json = null
}
