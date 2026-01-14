variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "app_name" {
  type    = string
  default = "adit-service"
}

# Your GitLab project path (you confirmed this)
variable "gitlab_project_path" {
  type    = string
  default = "karoosoftware-group/adit-service"
}

# Preprod promotion source ref
variable "preprod_branch" {
  type    = string
  default = "develop"
}