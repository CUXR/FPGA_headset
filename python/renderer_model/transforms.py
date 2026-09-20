"""Shared float64 affine matrices for homogeneous column vectors.

These helpers support the model and view blocks. Angles are in radians and
matrices act as ``matrix @ vertex``; affine points retain w=1.
"""

import numpy as np
from numpy.typing import NDArray


def translation_matrix(tx: float, ty: float, tz: float) -> NDArray[np.float64]:
    """Translate a point along the three coordinate axes."""
    return np.array([
        [1, 0, 0, tx],
        [0, 1, 0, ty],
        [0, 0, 1, tz],
        [0, 0, 0, 1],
    ], dtype=np.float64)


def scale_matrix(sx: float, sy: float, sz: float) -> NDArray[np.float64]:
    """Scale the three spatial coordinates, leaving w unchanged."""
    return np.diag(np.array([sx, sy, sz, 1.0], dtype=np.float64))


def rotation_x_matrix(theta: float) -> NDArray[np.float64]:
    """Rotate about x by theta radians."""
    c, s = np.cos(theta), np.sin(theta)
    return np.array([
        [1, 0, 0, 0],
        [0, c, -s, 0],
        [0, s, c, 0],
        [0, 0, 0, 1],
    ], dtype=np.float64)


def rotation_y_matrix(theta: float) -> NDArray[np.float64]:
    """Rotate about y by theta radians."""
    c, s = np.cos(theta), np.sin(theta)
    return np.array([
        [c, 0, s, 0],
        [0, 1, 0, 0],
        [-s, 0, c, 0],
        [0, 0, 0, 1],
    ], dtype=np.float64)


def rotation_z_matrix(theta: float) -> NDArray[np.float64]:
    """Rotate about z by theta radians (+x rotates toward +y)."""
    c, s = np.cos(theta), np.sin(theta)
    return np.array([
        [c, -s, 0, 0],
        [s, c, 0, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 1],
    ], dtype=np.float64)
