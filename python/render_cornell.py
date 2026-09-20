"""Render the static Cornell-box wireframe to a PNG."""

from pathlib import Path

import numpy as np

from renderer_model.config import HEIGHT, WIDTH
from renderer_model.renderer_top import Renderer
from renderer_model.scene_rom import get_cornell_box_scene
from renderer_model.types import Camera


def main() -> None:
    scene = get_cornell_box_scene()
    camera = Camera(np.zeros(3, dtype=np.float64), np.zeros(3, dtype=np.float64))
    renderer = Renderer()
    framebuffer = renderer.render(scene, camera)
    output_path = Path(__file__).resolve().parent / "output" / "cornell_wireframe.png"
    framebuffer.save_png(output_path)
    stats = renderer.last_stats
    print(f"Resolution: {WIDTH}x{HEIGHT}")
    print(f"Scene edges: {stats.scene_edges}")
    print(f"Visible/clipped edges: {stats.visible_edges}")
    print(f"Pixels written: {stats.pixels_written}")
    print(f"Output: {output_path}")


if __name__ == "__main__":
    main()
