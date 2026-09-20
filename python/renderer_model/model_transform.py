"""Local-to-world transform block.

Input vertices are local-space homogeneous column vectors; output vertices are
world-space homogeneous vectors.  Affine matrices use ``T @ Rz @ Ry @ Rx @ S``
so the right-most operation is applied first. Inputs are never modified.
"""

import numpy as np
from numpy.typing import ArrayLike, NDArray

from .transforms import (
    rotation_x_matrix,
    rotation_y_matrix,
    rotation_z_matrix,
    scale_matrix,
    translation_matrix,
)


def build_model_matrix(
    translation: ArrayLike = (0.0, 0.0, 0.0),
    rotation_xyz: ArrayLike = (0.0, 0.0, 0.0),
    scale: ArrayLike = (1.0, 1.0, 1.0),
) -> NDArray[np.float64]:
    """Build a float64 local-to-world affine matrix."""
    tx, ty, tz = np.asarray(translation, dtype=np.float64)
    rx, ry, rz = np.asarray(rotation_xyz, dtype=np.float64)
    sx, sy, sz = np.asarray(scale, dtype=np.float64)
    return np.asarray(
        translation_matrix(tx, ty, tz)
        @ rotation_z_matrix(rz)
        @ rotation_y_matrix(ry)
        @ rotation_x_matrix(rx)
        @ scale_matrix(sx, sy, sz),
        dtype=np.float64,
    )


def transform_vertex(vertex: ArrayLike, model_matrix: ArrayLike) -> NDArray[np.float64]:
    """Apply a model matrix to one homogeneous local-space vertex."""
    return np.asarray(model_matrix, dtype=np.float64) @ np.asarray(vertex, dtype=np.float64)
