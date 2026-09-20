"""Final RGB pixel-memory block.

The framebuffer stores top-left-origin screen pixels in a uint8 ``H x W x 3``
array. Out-of-range writes are programming errors and are explicitly rejected.
Pillow is used only at the output boundary to encode PNG files.
"""

from pathlib import Path

import numpy as np
from numpy.typing import NDArray
from PIL import Image

from .config import BACKGROUND_COLOR, HEIGHT, WIDTH
from .types import Color


def _validate_color(color: Color) -> tuple[int, int, int]:
    if len(color) != 3 or any(not isinstance(c, (int, np.integer)) or not 0 <= int(c) <= 255 for c in color):
        raise ValueError("color must contain three integer channels in [0, 255]")
    return tuple(int(c) for c in color)


class Framebuffer:
    """Bounds-checked RGB framebuffer memory."""

    def __init__(self, width: int = WIDTH, height: int = HEIGHT, background_color: Color = BACKGROUND_COLOR):
        if width <= 0 or height <= 0:
            raise ValueError("framebuffer dimensions must be positive")
        self.width = int(width)
        self.height = int(height)
        self.background_color = _validate_color(background_color)
        self._image = np.empty((self.height, self.width, 3), dtype=np.uint8)
        self.clear()

    @property
    def image(self) -> NDArray[np.uint8]:
        """Return the live framebuffer array."""
        return self._image

    def clear(self) -> None:
        """Reset every pixel to the configured background color."""
        self._image[...] = self.background_color

    def _check_bounds(self, x: int, y: int) -> None:
        if not 0 <= x < self.width or not 0 <= y < self.height:
            raise IndexError(f"pixel ({x}, {y}) outside {self.width}x{self.height} framebuffer")

    def write_pixel(self, x: int, y: int, color: Color) -> None:
        """Write one checked RGB pixel."""
        self._check_bounds(x, y)
        self._image[y, x] = _validate_color(color)

    def get_pixel(self, x: int, y: int) -> Color:
        """Read one checked RGB pixel."""
        self._check_bounds(x, y)
        return tuple(int(c) for c in self._image[y, x])

    def save_png(self, path: str | Path) -> None:
        """Encode the framebuffer as a PNG, creating parent directories."""
        output_path = Path(path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(self._image, mode="RGB").save(output_path)
