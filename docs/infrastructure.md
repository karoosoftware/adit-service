### Infrastructure Overview

This directory contains the Terraform projects used to manage the AWS infrastructure for the `adit-service`.

#### Projects

| Directory | Description |
|-----------|-------------|
| `bootstrap` | Initial setup for Terraform remote state. Creates the S3 bucket and DynamoDB table used for state locking. |
| `bootstrap-oidc` | Sets up the OpenID Connect (OIDC) trust between GitLab and AWS. Defines the IAM roles used by Terraform in the CI/CD pipeline. |
| `preprod` | Pre-production environment. Manages the ECR repository for pre-production and the IAM roles for pushing images from the CI pipeline. |
| `prod` | Production environment. Manages the production ECR repository and the IAM roles for promoting images from pre-production to production. |
| `modules/ecr-repo` | A reusable Terraform module for creating ECR repositories with lifecycle policies and optional IAM roles. |

---

### Authentication & CI/CD Flow

The infrastructure uses **passwordless authentication** via AWS OIDC (OpenID Connect) to allow GitLab CI/CD pipelines to interact with AWS securely.

#### 1. Trust Relationship (OIDC)
The `bootstrap-oidc` project creates an IAM OIDC Identity Provider in AWS that trusts `https://gitlab.com`. This allows GitLab to provide a temporary JWT (JSON Web Token) to AWS to prove its identity.

#### 2. Terraform Execution Roles
Two primary roles are defined in `bootstrap-oidc` for running Terraform:
- **`gitlab-tf-preprod`**: Assumed by the pipeline when running on the `develop` branch. It has permissions to manage resources in the `preprod` directory.
- **`gitlab-tf-prod`**: Assumed by the pipeline when a tag matching `v*` is pushed. It has permissions to manage resources in the `prod` directory.

#### 3. Image Management Roles
The environment-specific projects (`preprod` and `prod`) create roles for the application build process:
- **`gitlab-ecr-preprod`**: (Created in `preprod`) Used by the `build` stage in GitLab CI to push images to the pre-production ECR repository. It is restricted to the `develop` branch.
- **`gitlab-ecr-promote-prod`**: (Created in `prod`) Used by the `promote` stage in GitLab CI. It has permissions to pull images from the `preprod` repository and push them to the `prod` repository. It is restricted to `v*` tags.

#### 4. GitLab CI Pipeline Flow (`.gitlab-ci.yml`)

1.  **Infrastructure Changes**:
    - When code is pushed to `develop`, the `tf_plan_preprod` and `tf_apply_preprod` jobs run using the `gitlab-tf-preprod` role.
    - When a tag `v*` is pushed, the `tf_plan_prod` and `tf_apply_prod` jobs run using the `gitlab-tf-prod` role.
2.  **App Build & Push**:
    - On the `develop` branch, the `build` stage assumes the `gitlab-ecr-preprod` role to build and push the Docker image to the preprod ECR repo.
3.  **App Promotion**:
    - On a `v*` tag, the `promote` stage assumes the `gitlab-ecr-promote-prod` role. It pulls the verified image from the preprod repo and pushes it to the production repo, ensuring that only what has been tested in pre-production reaches production.

This flow ensures a clear separation of concerns and follows the principle of least privilege by restricting AWS access based on the GitLab branch or tag.
