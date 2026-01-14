variable "aws_region" {
  type    = string
  default = "eu-west-2"
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

# Prod promotion trigger: tags starting with v (v1.2.3 etc.)
# We’ll use wildcard matching in the trust policy: v*
variable "prod_tag_prefix" {
  type    = string
  default = "v"
}

variable "tf_state_bucket_name" {
  type        = string
  description = "S3 bucket name holding Terraform remote state"
  default     = "adit-service-tf-state"
}

variable "tf_lock_table_name" {
  type        = string
  description = "DynamoDB table name used for Terraform state locking"
  default     = "adit-service-terraform-locks"
}
