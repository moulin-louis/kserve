# Copyright 2024 The KServe Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import json
import pytest
import unittest.mock as mock
from kserve_storage import Storage

STORAGE_MODULE = "kserve_storage.kserve_storage"


@mock.patch("mlflow.set_tracking_uri")
@mock.patch("mlflow.artifacts.download_artifacts")
@mock.patch.dict(os.environ, {"MLFLOW_TRACKING_URI": "http://mlflow.example.com"})
def test_download_mlflow_success(mock_download_artifacts, mock_set_tracking_uri):
    # given
    mlflow_uri = "mlflow://models/my-model/1"
    out_dir = "/tmp/models"

    # when
    result = Storage._download_mlflow(mlflow_uri, out_dir)

    # then
    mock_set_tracking_uri.assert_called_once_with("http://mlflow.example.com")
    mock_download_artifacts.assert_called_once_with(
        artifact_uri="models/my-model/1", dst_path=out_dir
    )
    assert result == out_dir


@mock.patch("mlflow.set_tracking_uri")
@mock.patch("mlflow.artifacts.download_artifacts")
@mock.patch.dict(
    os.environ,
    {
        "MLFLOW_TRACKING_URI": "http://mlflow.example.com",
        "MLFLOW_TRACKING_USERNAME": "user",
        "MLFLOW_TRACKING_PASSWORD": "pass",
    },
)
def test_download_mlflow_with_username_password(
    mock_download_artifacts, mock_set_tracking_uri
):
    # given
    mlflow_uri = "mlflow://models/my-model/1"
    out_dir = "/tmp/models"

    # when
    result = Storage._download_mlflow(mlflow_uri, out_dir)

    # then
    mock_set_tracking_uri.assert_called_once_with("http://mlflow.example.com")
    mock_download_artifacts.assert_called_once_with(
        artifact_uri="models/my-model/1", dst_path=out_dir
    )
    assert result == out_dir


@mock.patch("mlflow.set_tracking_uri")
@mock.patch("mlflow.artifacts.download_artifacts")
@mock.patch.dict(
    os.environ,
    {
        "MLFLOW_TRACKING_URI": "http://mlflow.example.com",
        "MLFLOW_TRACKING_TOKEN": "my-token",
    },
)
def test_download_mlflow_with_token(mock_download_artifacts, mock_set_tracking_uri):
    # given
    mlflow_uri = "mlflow://models/my-model/1"
    out_dir = "/tmp/models"

    # when
    result = Storage._download_mlflow(mlflow_uri, out_dir)

    # then
    mock_set_tracking_uri.assert_called_once_with("http://mlflow.example.com")
    mock_download_artifacts.assert_called_once_with(
        artifact_uri="models/my-model/1", dst_path=out_dir
    )
    assert result == out_dir


@mock.patch.dict(os.environ, {}, clear=True)
def test_download_mlflow_missing_tracking_uri():
    # given
    mlflow_uri = "mlflow://models/my-model/1"
    out_dir = "/tmp/models"

    # when/then
    with pytest.raises(ValueError, match="Cannot find MLFlow tracking Uri"):
        Storage._download_mlflow(mlflow_uri, out_dir)


@mock.patch.dict(
    os.environ,
    {
        "MLFLOW_TRACKING_URI": "http://mlflow.example.com",
        "MLFLOW_TRACKING_USERNAME": "user",
        "MLFLOW_TRACKING_PASSWORD": "pass",
        "MLFLOW_TRACKING_TOKEN": "token",
    },
)
def test_download_mlflow_token_with_username_password_conflict():
    # given
    mlflow_uri = "mlflow://models/my-model/1"
    out_dir = "/tmp/models"

    # when/then
    with pytest.raises(
        ValueError, match="Tracking Token cannot be set with Username/Password combo"
    ):
        Storage._download_mlflow(mlflow_uri, out_dir)


@mock.patch.dict(os.environ, {"MLFLOW_TRACKING_URI": "http://mlflow.example.com"})
def test_download_mlflow_empty_model_uri():
    # given
    mlflow_uri = "mlflow://"
    out_dir = "/tmp/models"

    # when/then
    with pytest.raises(ValueError, match="Model uri cannot be empty"):
        Storage._download_mlflow(mlflow_uri, out_dir)


@mock.patch("mlflow.set_tracking_uri")
@mock.patch("mlflow.artifacts.download_artifacts")
@mock.patch.dict(os.environ, {"MLFLOW_TRACKING_URI": "http://mlflow.example.com"})
def test_download_mlflow_exception(mock_download_artifacts, mock_set_tracking_uri):
    # given
    from mlflow.exceptions import MlflowException

    mlflow_uri = "mlflow://models/my-model/1"
    out_dir = "/tmp/models"
    mock_download_artifacts.side_effect = MlflowException("Download failed")

    # when/then
    with pytest.raises(RuntimeError, match="Failed to download model from MLFlow"):
        Storage._download_mlflow(mlflow_uri, out_dir)


@mock.patch("mlflow.set_tracking_uri")
@mock.patch("mlflow.artifacts.download_artifacts")
@mock.patch.dict(os.environ, {"MLFLOW_TRACKING_URI": "http://mlflow.example.com"})
def test_storage_download_with_mlflow_uri(
    mock_download_artifacts, mock_set_tracking_uri
):
    # given
    mlflow_uri = "mlflow://models/my-model/1"

    # when
    Storage.download(mlflow_uri)

    # then
    mock_set_tracking_uri.assert_called_once_with("http://mlflow.example.com")
    assert mock_download_artifacts.called


def test_update_with_storage_spec_mlflow(monkeypatch):
    # save the environment and restore it after the test to avoid mutating it
    # since _update_with_storage_spec modifies it
    previous_env = os.environ.copy()

    monkeypatch.setenv("STORAGE_CONFIG", '{"type": "mlflow"}')
    Storage._update_with_storage_spec()

    for var in (
        "MLFLOW_TRACKING_URI",
        "MLFLOW_TRACKING_USERNAME",
        "MLFLOW_TRACKING_PASSWORD",
        "MLFLOW_TRACKING_TOKEN",
    ):
        assert os.getenv(var) is None

    storage_config = {
        "type": "mlflow",
        "tracking_uri": "http://mlflow.example.com",
        "tracking_username": "user",
        "tracking_password": "password",
        "tracking_token": "token123",
    }

    monkeypatch.setenv("STORAGE_CONFIG", json.dumps(storage_config))
    Storage._update_with_storage_spec()

    assert os.getenv("MLFLOW_TRACKING_URI") == storage_config["tracking_uri"]
    assert os.getenv("MLFLOW_TRACKING_USERNAME") == storage_config["tracking_username"]
    assert os.getenv("MLFLOW_TRACKING_PASSWORD") == storage_config["tracking_password"]
    assert os.getenv("MLFLOW_TRACKING_TOKEN") == storage_config["tracking_token"]

    # revert changes
    os.environ = previous_env


def test_update_with_storage_spec_mlflow_partial(monkeypatch):
    # save the environment and restore it after the test
    previous_env = os.environ.copy()

    # Test with only tracking_uri set
    storage_config = {
        "type": "mlflow",
        "tracking_uri": "http://mlflow.example.com",
    }

    monkeypatch.setenv("STORAGE_CONFIG", json.dumps(storage_config))
    Storage._update_with_storage_spec()

    assert os.getenv("MLFLOW_TRACKING_URI") == storage_config["tracking_uri"]
    # Other vars should not be set
    assert os.getenv("MLFLOW_TRACKING_USERNAME") is None
    assert os.getenv("MLFLOW_TRACKING_PASSWORD") is None
    assert os.getenv("MLFLOW_TRACKING_TOKEN") is None

    # revert changes
    os.environ = previous_env


@mock.patch("mlflow.set_tracking_uri")
@mock.patch("mlflow.artifacts.download_artifacts")
@mock.patch.dict(os.environ, {"MLFLOW_TRACKING_URI": "http://mlflow.example.com"})
def test_download_mlflow_with_version_path(
    mock_download_artifacts, mock_set_tracking_uri
):
    # given
    mlflow_uri = "mlflow://models/my-model/version/1"
    out_dir = "/tmp/models"

    # when
    result = Storage._download_mlflow(mlflow_uri, out_dir)

    # then
    mock_set_tracking_uri.assert_called_once_with("http://mlflow.example.com")
    mock_download_artifacts.assert_called_once_with(
        artifact_uri="models/my-model/version/1", dst_path=out_dir
    )
    assert result == out_dir


@mock.patch("mlflow.set_tracking_uri")
@mock.patch("mlflow.artifacts.download_artifacts")
@mock.patch.dict(os.environ, {"MLFLOW_TRACKING_URI": "http://mlflow.example.com"})
def test_download_mlflow_with_run_id(mock_download_artifacts, mock_set_tracking_uri):
    # given
    mlflow_uri = "mlflow://runs/abc123def456/artifacts/model"
    out_dir = "/tmp/models"

    # when
    result = Storage._download_mlflow(mlflow_uri, out_dir)

    # then
    mock_set_tracking_uri.assert_called_once_with("http://mlflow.example.com")
    mock_download_artifacts.assert_called_once_with(
        artifact_uri="runs/abc123def456/artifacts/model", dst_path=out_dir
    )
    assert result == out_dir


@mock.patch("mlflow.set_tracking_uri")
@mock.patch("mlflow.artifacts.download_artifacts")
@mock.patch.dict(
    os.environ,
    {
        "MLFLOW_TRACKING_URI": "https://mlflow.secure.com",
        "MLFLOW_TRACKING_TOKEN": "secure-token-123",
    },
)
def test_download_mlflow_with_https_tracking_uri(
    mock_download_artifacts, mock_set_tracking_uri
):
    # given
    mlflow_uri = "mlflow://models/secure-model/production"
    out_dir = "/tmp/models"

    # when
    result = Storage._download_mlflow(mlflow_uri, out_dir)

    # then
    mock_set_tracking_uri.assert_called_once_with("https://mlflow.secure.com")
    mock_download_artifacts.assert_called_once_with(
        artifact_uri="models/secure-model/production", dst_path=out_dir
    )
    assert result == out_dir


@mock.patch.dict(
    os.environ,
    {
        "MLFLOW_TRACKING_URI": "http://mlflow.example.com",
        "MLFLOW_TRACKING_USERNAME": "user",
    },
)
def test_download_mlflow_with_username_only_no_password():
    # given
    mlflow_uri = "mlflow://models/my-model/1"
    out_dir = "/tmp/models"

    # This should work - username alone doesn't cause a conflict
    # Only when both username AND password AND token are set together
    with mock.patch("mlflow.set_tracking_uri"), mock.patch(
        "mlflow.artifacts.download_artifacts"
    ):
        result = Storage._download_mlflow(mlflow_uri, out_dir)
        assert result == out_dir
