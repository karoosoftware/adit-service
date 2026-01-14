variable "name" {
  description = "ECR repository name"
  type        = string
}

variable "image_tag_mutability" {
  description = "MUTABLE or IMMUTABLE"
  type        = string
  default     = "MUTABLE"
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Enable basic image scan on push"
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "AES256 or KMS"
  type        = string
  default     = "AES256"
  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "encryption_type must be AES256 or KMS."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN if encryption_type is KMS"
  type        = string
  default     = null
}

variable "create_gitlab_push_role" {
  type        = bool
  default     = false
  description = "Whether to create a GitLab OIDC role allowed to push to this repo"
}

variable "gitlab_oidc_provider_arn" {
  type        = string
  default     = null
  description = "ARN of the aws_iam_openid_connect_provider for GitLab"
}

variable "gitlab_audience" {
  type        = string
  default     = "https://gitlab.com"
  description = "OIDC audience for GitLab"
}

variable "gitlab_sub" {
  type        = string
  default     = null
  description = "Exact GitLab OIDC sub claim to allow (e.g. project_path:...:ref_type:branch:ref:develop)"
}

variable "gitlab_role_name" {
  type        = string
  default     = null
  description = "Name for the GitLab push role"
}


variable "max_image_count" {
  description = "Expire images beyond this count. Set to 0 to disable lifecycle policy."
  type        = number
  default     = 30
}

variable "repository_policy_json" {
  description = "Optional repository policy JSON. If null, no repo policy is attached."
  type        = string
  default     = null
}
