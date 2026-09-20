"""Camera-to-clip perspective projection block.

The input is +z-forward camera space and the output is homogeneous clip space.
The matrix maps the near/far planes to NDC z=0/1 after division and produces
``w_clip = z_camera``.
"""

import math

import numpy as np
from numpy.typing import ArrayLike, NDArray

from .config import FAR, FOV_Y_DEG, HEIGHT, NEAR, WIDTH


def build_projection_matrix(
    fov_y_deg: float = FOV_Y_DEG,
    aspect: float = WIDTH / HEIGHT,
    near: float = NEAR,
    far: float = FAR,
) -> NDArray[np.float64]:
    """Build a +z-forward perspective matrix with NDC z in [0, 1]."""
    if not 0.0 < fov_y_deg < 180.0:
        raise ValueError("vertical field of view must be between 0 and 180 degrees")
    if not np.isfinite(aspect) or aspect <= 0.0:
        raise ValueError("aspect ratio must be positive and finite")
    if not np.isfinite(near) or near <= 0.0:
        raise ValueError("near plane must be positive and finite")
    if not np.isfinite(far) or far <= near:
        raise ValueError("far plane must be finite and greater than near plane")
    f = 1.0 / math.tan(math.radians(fov_y_deg) / 2.0)
    depth = far - near
    return np.array(
        [[f / aspect, 0.0, 0.0, 0.0],
         [0.0, f, 0.0, 0.0],
         [0.0, 0.0, far / depth, -near * far / depth],
         [0.0, 0.0, 1.0, 0.0]],
        dtype=np.float64,
    )


def project_vertex(vertex: ArrayLike, projection_matrix: ArrayLike) -> NDArray[np.float64]:
    """Project one camera-space homogeneous vertex into clip space."""
    return np.asarray(projection_matrix, dtype=np.float64) @ np.asarray(vertex, dtype=np.float64)
