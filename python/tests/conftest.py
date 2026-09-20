"""Shared pytest setup and fixtures for the renderer model."""

import sys
from pathlib import Path

import numpy as np
import pytest

PYTHON_ROOT = Path(__file__).resolve().parents[1]
if str(PYTHON_ROOT) not in sys.path:
    sys.path.insert(0, str(PYTHON_ROOT))

from renderer_model.types import Camera  # noqa: E402


@pytest.fixture
def origin_camera() -> Camera:
    return Camera(np.zeros(3, dtype=np.float64), np.zeros(3, dtype=np.float64))
