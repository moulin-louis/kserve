ARG PYTHON_VERSION=3.11
ARG BASE_IMAGE=registry.access.redhat.com/ubi9/python-311:1
ARG VENV_PATH=/prod_venv

FROM ${BASE_IMAGE} AS builder

# Switch to root to install system dependencies
USER 0

# Install system dependencies
RUN dnf install -y python3.11-devel gcc gcc-c++ make && \
    dnf clean all

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    ln -s /root/.local/bin/uv /usr/local/bin/uv

# Create virtual environment with Python 3.11
ARG VENV_PATH
ENV VIRTUAL_ENV=${VENV_PATH}
RUN uv venv --python python3.11 $VIRTUAL_ENV
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
RUN uv sync --package predictiveserver --no-install-workspace --active --no-cache

# Copy source and install workspace packages
COPY kserve kserve
COPY storage storage
COPY sklearnserver sklearnserver
COPY xgbserver xgbserver
COPY lgbserver lgbserver
COPY predictiveserver predictiveserver
RUN uv sync --package predictiveserver --active --no-cache

# Generate third-party licenses
COPY third_party third_party
RUN pip install --no-cache-dir tomli
RUN mkdir -p third_party/library && python3 third_party/pip-licenses.py


# =================== Final stage ===================
FROM ${BASE_IMAGE} AS prod

# Switch to root to install runtime dependencies
USER 0

# Install runtime dependencies (libgomp for lightgbm, xgboost, etc.)
RUN dnf install -y libgomp && \
    dnf clean all

# Activate virtual env
ARG VENV_PATH
ENV VIRTUAL_ENV=${VENV_PATH}
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# UBI python image runs as user 1001 by default
COPY --from=builder --chown=1001:0 /opt/app-root/src/third_party third_party
COPY --from=builder --chown=1001:0 $VIRTUAL_ENV $VIRTUAL_ENV
COPY --from=builder --chown=1001:0 /opt/app-root/src/kserve kserve
COPY --from=builder --chown=1001:0 /opt/app-root/src/storage storage
COPY --from=builder --chown=1001:0 /opt/app-root/src/sklearnserver sklearnserver
COPY --from=builder --chown=1001:0 /opt/app-root/src/xgbserver xgbserver
COPY --from=builder --chown=1001:0 /opt/app-root/src/lgbserver lgbserver
COPY --from=builder --chown=1001:0 /opt/app-root/src/predictiveserver predictiveserver

USER 1001
ENV PYTHONPATH=/predictiveserver:/sklearnserver:/xgbserver:/lgbserver
LABEL io.kserve.runtime="predictiveserver" \
      io.kserve.frameworks="sklearn,lightgbm,xgboost"
ENTRYPOINT ["python", "-m", "predictiveserver"]
