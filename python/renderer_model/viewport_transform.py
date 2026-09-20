"""NDC-to-screen viewport transform block.

NDC x/y in [-1,1] become integer pixels with a top-left origin. Positive NDC y
therefore maps upward (toward smaller screen y). Nonnegative coordinates use
the deterministic round-half-up rule ``floor(value + 0.5)``.
"""

import math

from numpy.typing import ArrayLike

from .config import HEIGHT, WIDTH


def ndc_to_screen(vertex: ArrayLike, width: int = WIDTH, height: int = HEIGHT) -> tuple[int, int]:
    """Map one visible NDC point to an integer framebuffer coordinate."""
    if width <= 0 or height <= 0:
        raise ValueError("viewport dimensions must be positive")
    x_ndc, y_ndc = float(vertex[0]), float(vertex[1])
    x_float = (x_ndc + 1.0) * 0.5 * (width - 1)
    y_float = (1.0 - y_ndc) * 0.5 * (height - 1)
    return math.floor(x_float + 0.5), math.floor(y_float + 0.5)
