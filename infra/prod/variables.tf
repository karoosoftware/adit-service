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

variable "prod_tag_prefix" {
  type    = string
  default = "v"
}