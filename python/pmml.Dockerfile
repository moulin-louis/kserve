ARG PYTHON_VERSION=3.12
ARG JAVA_VERSION=21
ARG BASE_IMAGE=eclipse-temurin:${JAVA_VERSION}-jdk-noble
ARG VENV_PATH=/prod_venv

FROM ${BASE_IMAGE} AS builder

ARG PYTHON_VERSION
# Install python
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    "python${PYTHON_VERSION}" \
    "python${PYTHON_VERSION}-dev" \
    "python${PYTHON_VERSION}-venv" \
    python3-pip \
    curl \
    gcc build-essential && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    ln -s /root/.local/bin/uv /usr/local/bin/uv

# Setup virtual environment
ARG VENV_PATH
ENV VIRTUAL_ENV=${VENV_PATH}
RUN uv venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Copy workspace manifests for dependency resolution
COPY pyproject.toml uv.lock ./
COPY kserve/pyproject.toml kserve/
COPY storage/pyproject.toml storage/
COPY huggingfaceserver/pyproject.toml huggingfaceserver/
COPY sklearnserver/pyproject.toml sklearnserver/
COPY xgbserver/pyproject.toml xgbserver/
COPY lgbserver/pyproject.toml lgbserver/
COPY paddleserver/pyproject.toml paddleserver/
COPY pmmlserver/pyproject.toml pmmlserver/
COPY artexplainer/pyproject.toml artexplainer/
COPY aiffairness/pyproject.toml aiffairness/
COPY predictiveserver/pyproject.toml predictiveserver/

# Install external dependencies (cache layer)
RUN uv sync --package pmmlserver --no-install-workspace --active --no-cache

# Copy source and install workspace packages
COPY kserve kserve
COPY storage storage
COPY pmmlserver pmmlserver
RUN uv sync --package pmmlserver --active --no-cache

# Generate third-party licenses
COPY third_party/pip-licenses.py pip-licenses.py
RUN uv pip install --no-cache-dir tomli
RUN mkdir -p third_party/library && python3 pip-licenses.py

# ---------- Production image ----------
FROM ${BASE_IMAGE} AS prod

ARG PYTHON_VERSION
# Install python
RUN apt-get update && \
    apt-get install -y --no-install-recommends "python${PYTHON_VERSION}" && \
    ln -s /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Activate virtual env
ARG VENV_PATH
ENV VIRTUAL_ENV=${VENV_PATH}
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Create non-root user
RUN useradd kserve -m -u 1001 -d /home/kserve

COPY --from=builder --chown=kserve:kserve third_party third_party
COPY --from=builder --chown=kserve:kserve $VIRTUAL_ENV $VIRTUAL_ENV
COPY --from=builder kserve kserve
COPY --from=builder storage storage
COPY --from=builder pmmlserver pmmlserver

USER 1001
ENV PYTHONPATH=/pmmlserver
ENTRYPOINT ["python3", "-m", "pmmlserver"]
