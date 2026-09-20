"""Homogeneous clip-space line clipping block.

Input and output endpoints are homogeneous clip vectors. A parametric segment
is clipped against x in [-w,w], y in [-w,w], and z in [0,w]. The routine runs
before perspective division and returns ``None`` for an invisible segment.
"""

import numpy as np
from numpy.typing import ArrayLike, NDArray

from .config import EPSILON

# Each row defines a half-space dot(row, [x,y,z,w]) >= 0.
_PLANES = np.array(
    [[1.0, 0.0, 0.0, 1.0], [-1.0, 0.0, 0.0, 1.0],
     [0.0, 1.0, 0.0, 1.0], [0.0, -1.0, 0.0, 1.0],
     [0.0, 0.0, 1.0, 0.0], [0.0, 0.0, -1.0, 1.0]],
    dtype=np.float64,
)


def clip_line(
    p0: ArrayLike, p1: ArrayLike, epsilon: float = EPSILON
) -> tuple[NDArray[np.float64], NDArray[np.float64]] | None:
    """Clip a homogeneous segment against all six canonical clip planes."""
    start = np.asarray(p0, dtype=np.float64)
    end = np.asarray(p1, dtype=np.float64)
    if start.shape != (4,) or end.shape != (4,):
        raise ValueError("clip endpoints must each have shape (4,)")
    if not np.all(np.isfinite(start)) or not np.all(np.isfinite(end)):
        raise ValueError("clip endpoints must be finite")

    t_enter, t_leave = 0.0, 1.0
    for plane in _PLANES:
        g0 = float(plane @ start)
        g1 = float(plane @ end)
        if g0 < -epsilon and g1 < -epsilon:
            return None
        if g0 < -epsilon or g1 < -epsilon:
            t = g0 / (g0 - g1)
            if g0 < -epsilon:
                t_enter = max(t_enter, t)
            else:
                t_leave = min(t_leave, t)
            if t_enter > t_leave + epsilon:
                return None

    delta = end - start
    return start + t_enter * delta, start + t_leave * delta
