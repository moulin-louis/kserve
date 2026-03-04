ARG PYTHON_VERSION=3.11
ARG BASE_IMAGE=python:${PYTHON_VERSION}-slim-bookworm
ARG VENV_PATH=/prod_venv

FROM ${BASE_IMAGE} AS builder

# Install all system dependencies first
RUN apt-get update && apt-get install -y --no-install-recommends python3-dev curl build-essential && apt-get clean && \
    rm -rf /var/lib/apt/lists/*
# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    ln -s /root/.local/bin/uv /usr/local/bin/uv

# Activate virtual env
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
RUN uv sync --package kserve-storage --no-install-workspace --active --no-cache

# Copy source and install workspace packages
COPY storage storage
RUN uv sync --package kserve-storage --active --no-cache

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    gcc \
    libkrb5-dev \
    krb5-config \
    && rm -rf /var/lib/apt/lists/*

# Install Kerberos-related packages
RUN uv pip install --no-cache \
    krbcontext==0.10 \
    hdfs~=2.6.0 \
    requests-kerberos==0.14.0

# Generate third-party licenses
COPY third_party/pip-licenses.py pip-licenses.py
RUN pip install --no-cache-dir tomli
RUN mkdir -p third_party/library && python3 pip-licenses.py

FROM ${BASE_IMAGE} AS prod

# Activate virtual env
ARG VENV_PATH
ENV VIRTUAL_ENV=${VENV_PATH}
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN useradd kserve -m -u 1000 -d /home/kserve

COPY --from=builder --chown=kserve:kserve third_party third_party
COPY --from=builder --chown=kserve:kserve $VIRTUAL_ENV $VIRTUAL_ENV
COPY --from=builder storage storage
COPY ./storage-initializer /storage-initializer

RUN chmod +x /storage-initializer/scripts/initializer-entrypoint
RUN mkdir /work
WORKDIR /work

# Set a writable /mnt folder to avoid permission issue on Huggingface download. See https://huggingface.co/docs/hub/spaces-sdks-docker#permissions
RUN chown -R kserve:kserve /mnt
USER 1000
ENTRYPOINT ["/storage-initializer/scripts/initializer-entrypoint"]
