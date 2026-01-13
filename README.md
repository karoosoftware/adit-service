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

### Planned additions
- Automated container builds
- Smoke tests against the running container
- Deployment via GitLab CI pipelines (e.g. pushing images to Amazon ECR)

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
