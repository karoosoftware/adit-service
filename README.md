# Python HTTP adit-service (AWS DevOps Test)

A minimal Python HTTP server designed for local development, containerization, and CI/CD testing.

The service exposes:
- `GET /` → returns a greeting message
- `GET /health` → returns `ok` for health checks
- Any other route → returns `404 Not found`

The server listens on **port 8080**.

---

## Project Structure

```
adit-service/
├── pyproject.toml
├── README.md
├── Dockerfile
├── src/
│   └── adit_service/
│       ├── __init__.py
│       └── app.py
└── tests/
    └── test_smoke.py
```

---

## Requirements

To run locally:
- Python 3.x

To run in a container:
- Docker

---

## Running the Application Locally

### 1. (Optional) Create a virtual environment

```bash
python -m venv .venv
source .venv/bin/activate
```

### 2. Start the server

From the repository root:

```bash
python src/adit_service/app.py
```

The server will start listening on `http://0.0.0.0:8080`.

---

## Testing Locally (Without Docker)

Use `curl` or a browser.

```bash
curl http://localhost:8080/
curl http://localhost:8080/health
curl http://localhost:8080/unknown
```

Expected responses:

| Endpoint        | Status | Response                     |
|-----------------|--------|------------------------------|
| `/`             | 200    | Hello from AWS DevOps test   |
| `/health`       | 200    | ok                           |
| any other route | 404    | Not found                    |

---

## Building the Docker Image

From the repository root (where the `Dockerfile` is located):

```bash
VERSION=$(python -c "import tomllib; print(tomllib.load(open('pyproject.toml','rb'))['project']['version'])")
docker build -f docker/Dockerfile -t adit-service:$VERSION .

```

---

## Running the Application with Docker

```bash
docker run --rm -p 8080:8080 adit-service:$VERSION
```

The application will be accessible at:

```
http://localhost:8080
```

---

## Testing the Docker Container Locally

Once the container is running:

```bash
curl http://localhost:8080/
curl http://localhost:8080/health
```

You should see the same responses as when running locally.

---

## Notes

- The application runs as a non-root user inside the container.
- The server is multi-threaded and suitable for basic concurrency testing.
- The `/health` endpoint is suitable for container and load balancer health checks.

---

## CI/CD

This project is designed to be built and deployed using **GitLab CI/CD**.

### Infrastructure & AWS Setup
Detailed documentation for the infrastructure, including Terraform projects, AWS OIDC authentication, and CI/CD pipeline flow, can be found in [docs/infrastructure.md](docs/infrastructure.md).

For more details on the proposed future deployment model, see [docs/deployment-architecture.md](docs/deployment-architecture.md).

### Planned additions
- Automated container builds
- Smoke tests against the running container
- Deployment via GitLab CI pipelines (e.g. pushing images to Amazon ECR)
- **ECS Deployment**: Note that deployment to Amazon ECS (Elastic Container Service) has not been implemented yet and will be part of the next phase of the project.

---

## Local GitLab Access & Manual Sync

This repository is hosted primarily on GitHub.  
GitLab is currently used **only for CI/CD**.

> ⚠️ A GitHub → GitLab mirror has **not yet been configured**.  
> Until mirroring is in place, changes must be **manually synced** to GitLab to trigger CI pipelines.

---

### Prerequisites

- A **GitLab Personal Access Token** with:
    - `read_repository`
    - `write_repository`

### Add GitLab as a remote

From the root of the repository:

```bash
git remote add gitlab https://oauth2:<YOUR_GITLAB_TOKEN>@gitlab.com/karoosoftware-group/adit-service.git
git remote -v
```

### Manual sync workflow (until mirroring is enabled)

To ensure GitLab CI runs on the latest code:
```bash
git pull origin main
git push gitlab main
```

## Artifact Build & Promotion

This project follows the **"Build once, deploy many"** principle. The Docker image is built only once in the pre-production stage and then promoted to production without modification or rebuilding, ensuring that exactly what was tested is what gets deployed.

### 1. Build Stage (Pre-production)
Triggered on: **`develop` branch**

1.  **Unit Testing**: Runs pytest to ensure code quality.
2.  **Metadata Extraction**: Extracts the application version from `pyproject.toml`.
3.  **ECR Authentication**: Uses AWS OIDC to get a login token for the preprod ECR registry.
4.  **Kaniko Build**: Uses **Kaniko** to build the Docker image and push it to the pre-production ECR repository.
    - Images are tagged with both the Git commit SHA and `develop`.
    - Kaniko is used instead of `dind` (Docker-in-Docker) due to security/privilege constraints on GitLab runners.

### 2. Promotion Stage (Production)
Triggered on: **`v*` tags** (e.g., `v0.1.0`)

Currently, this stage is triggered by **manual tag creation**.

1.  **Verification**: Checks that the image corresponding to the Git commit SHA exists in the pre-production ECR repository.
2.  **Skopeo Promotion**: Uses **Skopeo** to copy the image directly from the pre-production ECR repository to the production ECR repository.
    - **No Rebuilding**: The image is copied at the layer level, ensuring bit-for-bit identity between environments.
    - **Tagging**: The production image is tagged with the Git tag (e.g., `v0.1.0`).

### 3. Promotion Failure Scenarios

The promotion process is designed to fail safely if the integrity of the "Build once, deploy many" flow is compromised. Common failure scenarios include:

1.  **Missing Source Image (Failed/Incomplete Build)**:
    - **Cause**: The previous build job on the `develop` branch failed or was interrupted before the image upload to the pre-production ECR was completed.
    - **Result**: The `promote_to_prod` job will fail with an error: `ERROR: Source image not found in PREPROD ECR`.
    - **Fix**: Re-run the build pipeline on the corresponding commit in the `develop` branch.

2.  **SHA Mismatch (Branch Lag)**:
    - **Cause**: A tag is created on a commit (e.g., on the `main` branch) that has not yet been built and pushed from the `develop` branch. Since the pipeline looks for an image tagged with the specific Git SHA, if that SHA was never processed by the `develop` build pipeline, the image won't exist.
    - **Result**: Similar to the missing image error, the promotion fails because the expected artifact is not found.
    - **Fix**: Ensure the `develop` branch is merged into `main` (or the target branch for tagging) and that the CI pipeline has successfully built that SHA before creating the tag.

---

## Audit & Traceability

This pipeline is built with a strong focus on auditability and security:

- **Immutable Artifacts**: Each artifact is built once, identified by a unique Git commit SHA and an immutable Docker digest.
- **Environment Parity**: The exact artifact tested in pre-production is promoted to production without rebuilding, eliminating "it works on my machine" or build-time environment differences.
- **Human Approval via Tags**: Promotion to production is triggered only by protected release tags, which serve as a record of human approval and release intent.
- **End-to-End Traceability**: Git history, tag history, and CI logs provide a complete trace from code change → artifact → production deployment.
- **IAM Role Separation**: Strict IAM role separation ensures that only approved workflows (and only on protected tags/branches) can affect production artifacts.

---

## Future: Decoupled Deployment with AWS Step Functions

To further enhance security and reliability, the deployment logic can be transitioned from GitLab CI into **AWS Step Functions**. In this model, the **existing `.gitlab-ci.yml` pipeline** remains the entry point and orchestrator of the developer workflow, but it delegates the heavy lifting of infrastructure changes and deployments to AWS-native services.

This removes the need for GitLab to hold broad infrastructure permissions and allows for more complex orchestration (e.g., blue/green deployments, manual approvals within AWS, and automated rollbacks).

### 1. Conceptual Architecture
The existing GitLab CI jobs (like `tf_apply` or `promote_to_prod`) will be refactored to simply trigger an AWS Step Function execution. GitLab passes the necessary context (target environment, commit SHA, version) as input, and AWS handles the secure execution.

### 2. Step-by-Step Implementation Flow

#### Phase 1: Infrastructure Preparation
1.  **Deployment State Machine**: Define a Step Function using Amazon States Language (ASL) that orchestrates:
    - **Validation**: Checks if the ECR image exists for the given SHA.
    - **Terraform Task**: Runs an AWS CodeBuild project to execute `terraform apply`.
    - **ECS Update**: Updates the ECS Service with the new image.
    - **Health Check**: Monitors the rollout and rolls back if the service fails to become healthy.
2.  **IAM Refinement**: 
    - Reduce the existing GitLab OIDC role permissions. It no longer needs broad Terraform or ECR access; it only needs `states:StartExecution`.
    - Create a dedicated IAM role for the Step Function with permissions to trigger CodeBuild and update ECS.

#### Phase 2: GitLab CI Refactoring
1.  **Update `.gitlab-ci.yml`**: Replace the existing script blocks in `tf_apply` and `promote_to_prod` with a focused AWS CLI command:
    ```bash
    aws stepfunctions start-execution \
      --state-machine-arn "arn:aws:states:..." \
      --input "{\"environment\": \"prod\", \"sha\": \"$CI_COMMIT_SHA\", \"version\": \"$VERSION\"}"
    ```
2.  **Feedback Loop**: The GitLab job can either wait for the execution to complete (using `aws states describe-execution`) to provide immediate feedback in the CI logs, or use a Webhook/Lambda to report status back to GitLab.

#### Phase 3: Orchestration Flow in AWS
1.  **Trigger**: GitLab CI starts the Step Function.
2.  **Execution**: 
    - **State "Run Terraform"**: Step Function triggers CodeBuild. CodeBuild fetches the TF state and applies changes.
    - **State "Promote Image"**: (For Prod) Step Function triggers a Lambda to run the image promotion logic.
    - **State "Deploy ECS"**: Step Function updates the ECS service.
    - **State "Wait for Health"**: Step Function polls the ECS service health.
3.  **Outcome**: If any step fails, the Step Function enters a "Rollback" state, reverting the ECS service to the previous image and notifying the team.

### 3. Benefits of this approach
- **Least Privilege**: GitLab's security footprint is drastically reduced.
- **Resilient Deployments**: AWS manages the deployment lifecycle; even if a GitLab runner times out, the deployment continues or rolls back safely.
- **Consistency**: The same Step Function is used whether triggered by GitLab, a scheduled task, or an emergency manual trigger.

---

## Challenges & Lessons Learned

During the development of this project, several challenges were encountered regarding the CI/CD implementation:

### 1. Docker-in-Docker (dind) vs. Kaniko
When building the Docker image in GitLab CI, using a standard `dind` image was not possible due to privilege restrictions on the runners. This led to the adoption of **Kaniko** for building images. 
- **Impact**: This required an extra step for ECR authentication (`ecr_auth_preprod`) to generate a `config.json` that Kaniko can use.
- **Future Improvement**: If time allowed, a custom GitLab runner with the correct permissions to run `dind` would simplify the build process.

### 2. Monorepo CI/CD Complexity
GitLab is limited to one `.gitlab-ci.yml` file per repository. In a monorepo setup (containing both application code and multiple Terraform projects), this adds significant complexity to the pipeline definition.
- **Impact**: We had to use extensive `include` statements and complex `rules` to ensure that only the relevant parts of the pipeline run based on which files were modified.
