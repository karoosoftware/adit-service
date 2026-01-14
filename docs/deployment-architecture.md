# Hybrid Deployment Architecture

This document outlines the hybrid deployment architecture where GitLab CI remains responsible for artifact management, while AWS handles the orchestration of ECS deployments.

## Overview

- **GitLab CI** remains responsible for “artifact promotion” (preprod → prod ECR via `skopeo copy`).
- **AWS** owns “deployment to ECS” (so ECS deploy is abstracted away from CI).

This gives the separation of concerns while keeping the current promotion flow working.

---

## Hybrid Architecture

### GitLab CI Responsibilities
1.  **Build once on develop**: Push to preprod ECR.
2.  **On v* tag**: Promote image to prod ECR (via `skopeo copy`).
3.  **Emit a deploy request to AWS**:
    - After preprod push (deploy preprod).
    - After prod promotion (deploy prod).

### AWS Responsibilities (No ECS logic in CI)
1.  **Orchestration**: Decide how to deploy (rolling / canary / approvals).
2.  **Service Management**: Update ECS service and wait for stability.
3.  **Resilience**: Health checks and automated rollback.
4.  **Audit**: Maintain an audit log of all deployments.

---

## What Triggers What

### A) Develop → Deploy to Preprod ECS
- **Trigger**: CI successfully pushes `preprod:${CI_COMMIT_SHA}` (or `preprod:develop`).
- **Action**: CI sends a deploy event to AWS:
  ```json
  {
    "environment": "preprod",
    "image": "preprod:${CI_COMMIT_SHA}",
    "service": "adit-service-preprod"
  }
  ```
- **AWS Action**: Performs the ECS deployment for the pre-production environment.

### B) Tag v* → Promote + Deploy to Prod ECS
- **Trigger**: CI tag pipeline runs promotion (skopeo copy) to `prod:vX.Y.Z`.
- **Action**: CI sends a deploy event to AWS:
  ```json
  {
    "environment": "prod",
    "image": "prod:vX.Y.Z",
    "service": "adit-service-prod"
  }
  ```
- **AWS Action**: Performs the ECS deploy, monitors health, and handles potential rollbacks.

---

## How to “Abstract ECS Away” Cleanly

### 1. Add a small AWS “Deploy API”
Choose one of the following implementation paths:

#### Option 1: API Gateway + Lambda (Simple)
- CI calls an HTTPS endpoint with the payload `{env, cluster, service, image}`.
- Lambda updates the task definition and runs `ecs:updateService`.
- Lambda (or a triggered Step Function) waits for stability.

#### Option 2: API Gateway + Step Functions (Better Orchestration)
- API Gateway starts a Step Functions state machine.
- **Steps**:
  1. Validate request.
  2. Register new task definition revision.
  3. Update ECS service.
  4. Wait for stable / check alarms.
  5. Rollback if needed.
  6. Write audit record to DynamoDB.

---

## Security Model

- **Least Privilege**: The CI role does not need `ecs:*` permissions at all.
- **Protection**: The deploy API is protected by:
  - GitLab OIDC calling AWS (Best).
  - A scoped token (Acceptable), plus allowlist IPs and rate limiting.
- **Isolation**: The Lambda/Step Function execution role is the only one authorized to update ECS.

---

## Rollback in this Model

Rollback is a **deployment concern**, not a CI concern.

- The AWS deploy orchestrator handles rollbacks by:
  - Reusing the previous task definition revision.
  - Or redeploying the previous image digest.
  - Optionally triggered automatically by CloudWatch alarms.
- **CI Role**: CI can still expose a “rollback” job that calls the same deploy API with an older tag or digest.
