"""World-to-camera transform block.

The camera pose maps camera coordinates into world coordinates as
``T @ Rz @ Ry @ Rx``.  This block outputs camera-space homogeneous vectors by
applying its inverse. The camera looks along +z and affine points retain w=1.
"""

import numpy as np
from numpy.typing import ArrayLike, NDArray

from .transforms import rotation_x_matrix, rotation_y_matrix, rotation_z_matrix, translation_matrix

from .types import Camera


def build_camera_world_matrix(camera: Camera) -> NDArray[np.float64]:
    """Build the camera-to-world affine matrix."""
    tx, ty, tz = np.asarray(camera.position, dtype=np.float64)
    rx, ry, rz = np.asarray(camera.rotation_xyz, dtype=np.float64)
    return np.asarray(
        translation_matrix(tx, ty, tz)
        @ rotation_z_matrix(rz)
        @ rotation_y_matrix(ry)
        @ rotation_x_matrix(rx),
        dtype=np.float64,
    )


def build_view_matrix(camera: Camera) -> NDArray[np.float64]:
    """Return the inverse of the camera's world transform."""
    return np.linalg.inv(build_camera_world_matrix(camera))


def transform_vertex(vertex: ArrayLike, view_matrix: ArrayLike) -> NDArray[np.float64]:
    """Apply a view matrix to one world-space homogeneous vertex."""
    return np.asarray(view_matrix, dtype=np.float64) @ np.asarray(vertex, dtype=np.float64)
