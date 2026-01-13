# ---- builder stage: build the wheel ----
FROM python:3.14.2-slim AS builder

WORKDIR /src
COPY pyproject.toml README.md ./
COPY src/ ./src/

RUN python -m pip install --upgrade pip build \
 && python -m build --wheel

# ---- runtime stage: install the wheel ----
FROM python:3.14.2-slim

RUN groupadd -r app && useradd -r -g app -m -d /home/app app
WORKDIR /app

COPY --from=builder src/dist/*.whl /tmp/
RUN python -m pip install --no-cache-dir /tmp/*.whl \
 && rm -rf /tmp/*.whl

USER app
EXPOSE 8080

CMD ["adit-service"]