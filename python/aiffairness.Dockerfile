ARG PYTHON_VERSION=3.11
ARG BASE_IMAGE=python:${PYTHON_VERSION}-slim-bookworm
ARG VENV_PATH=/prod_venv

FROM ${BASE_IMAGE} AS builder

# Required for building packages for arm64 arch
RUN apt-get update && apt-get install -y --no-install-recommends curl python3-dev build-essential && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    ln -s /root/.local/bin/uv /usr/local/bin/uv

# Set up and activate virtual environment
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
RUN uv sync --package aifserver --no-install-workspace --active --no-cache

# Copy source and install workspace packages
COPY kserve kserve
COPY storage storage
COPY aiffairness aiffairness
RUN uv sync --package aifserver --active --no-cache

# Generate third-party licenses
COPY third_party/pip-licenses.py pip-licenses.py
RUN pip install --no-cache-dir tomli
RUN mkdir -p third_party/library && python3 pip-licenses.py


# ------------------ Final Stage ------------------
FROM ${BASE_IMAGE} AS prod

# Activate virtual env
ARG VENV_PATH
ENV VIRTUAL_ENV=${VENV_PATH}
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN useradd kserve -m -u 1000 -d /home/kserve

COPY --from=builder --chown=kserve:kserve third_party third_party
COPY --from=builder --chown=kserve:kserve $VIRTUAL_ENV $VIRTUAL_ENV
COPY --from=builder kserve kserve
COPY --from=builder storage storage
COPY --from=builder aiffairness aiffairness

USER 1000
ENV PYTHONPATH=/aiffairness
ENTRYPOINT ["python", "-m", "aifserver"]
