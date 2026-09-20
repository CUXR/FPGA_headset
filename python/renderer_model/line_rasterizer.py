"""Integer screen-space line rasterizer block.

Two integer screen endpoints become an ordered stream of pixels using the
all-octant Bresenham algorithm. Both endpoints are emitted. Only integer adds,
subtracts, comparisons, and unit steps are used in the loop.
"""

from collections.abc import Iterator

from .types import Color, Pixel


def rasterize_line(x0: int, y0: int, x1: int, y1: int, color: Color) -> Iterator[Pixel]:
    """Yield the inclusive Bresenham path from the first endpoint to the second."""
    x, y = int(x0), int(y0)
    target_x, target_y = int(x1), int(y1)
    dx = abs(target_x - x)
    step_x = 1 if x < target_x else -1
    dy = -abs(target_y - y)
    step_y = 1 if y < target_y else -1
    error = dx + dy

    while True:
        yield Pixel(x, y, color)
        if x == target_x and y == target_y:
            break
        doubled_error = 2 * error
        if doubled_error >= dy:
            error += dy
            x += step_x
        if doubled_error <= dx:
            error += dx
            y += step_y
