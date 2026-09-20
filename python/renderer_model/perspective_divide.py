"""Clip-to-NDC perspective-divide block.

Input is a four-component clip vector and output is three-component NDC. A
near-zero w is invalid because it represents a point at the projection apex.
"""

import numpy as np
from numpy.typing import ArrayLike, NDArray

from .config import EPSILON


def perspective_divide(vertex: ArrayLike, epsilon: float = EPSILON) -> NDArray[np.float64]:
    """Divide clip-space xyz by w without mutating the input."""
    clip = np.asarray(vertex, dtype=np.float64)
    if clip.shape != (4,):
        raise ValueError("clip vertex must have shape (4,)")
    if abs(float(clip[3])) < epsilon:
        raise ValueError("perspective divide requires non-zero clip w")
    return clip[:3] / clip[3]
