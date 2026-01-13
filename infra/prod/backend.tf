terraform {
  backend "s3" {
    bucket         = "adit-service-tf-state"
    key            = "prod/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "adit-service-terraform-locks"
    encrypt        = true
  }
}
