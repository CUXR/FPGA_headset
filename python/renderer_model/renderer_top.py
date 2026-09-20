"""Top-level, stage-by-stage software equivalent of the FPGA renderer.

For each local-space line this block visibly sequences geometry fetch, model,
view, projection, homogeneous clipping, divide, viewport mapping, Bresenham,
and framebuffer writes. Matrices are intentionally not pre-combined.
"""

from dataclasses import dataclass

from .clipper import clip_line
from .config import FAR, FOV_Y_DEG, HEIGHT, NEAR, WIDTH
from .framebuffer import Framebuffer
from .geometry_fetch import fetch_lines
from .line_rasterizer import rasterize_line
from .model_transform import transform_vertex as model_transform_vertex
from .perspective_divide import perspective_divide
from .projection import build_projection_matrix, project_vertex
from .types import Camera, Scene
from .view_transform import build_view_matrix, transform_vertex as view_transform_vertex
from .viewport_transform import ndc_to_screen


@dataclass(frozen=True)
class RenderStats:
    """Pipeline counters useful for test benches and command-line reporting."""

    scene_edges: int = 0
    visible_edges: int = 0
    pixels_written: int = 0


class Renderer:
    """Deterministic floating-point wireframe pipeline."""

    def __init__(
        self,
        width: int = WIDTH,
        height: int = HEIGHT,
        fov_y_deg: float = FOV_Y_DEG,
        near: float = NEAR,
        far: float = FAR,
    ) -> None:
        self.width = width
        self.height = height
        self.projection_matrix = build_projection_matrix(fov_y_deg, width / height, near, far)
        self.last_stats = RenderStats()

    def render(self, scene: Scene, camera: Camera) -> Framebuffer:
        """Render a fresh framebuffer and retain counters in ``last_stats``."""
        framebuffer = Framebuffer(self.width, self.height)
        view_matrix = build_view_matrix(camera)
        scene_edges = visible_edges = pixels_written = 0

        for line in fetch_lines(scene):
            scene_edges += 1

            world_v0 = model_transform_vertex(line.v0, line.model_matrix)
            world_v1 = model_transform_vertex(line.v1, line.model_matrix)

            camera_v0 = view_transform_vertex(world_v0, view_matrix)
            camera_v1 = view_transform_vertex(world_v1, view_matrix)

            clip_v0 = project_vertex(camera_v0, self.projection_matrix)
            clip_v1 = project_vertex(camera_v1, self.projection_matrix)

            clipped = clip_line(clip_v0, clip_v1)
            if clipped is None:
                continue
            clipped_v0, clipped_v1 = clipped
            visible_edges += 1

            ndc_v0 = perspective_divide(clipped_v0)
            ndc_v1 = perspective_divide(clipped_v1)

            screen_v0 = ndc_to_screen(ndc_v0, self.width, self.height)
            screen_v1 = ndc_to_screen(ndc_v1, self.width, self.height)

            for pixel in rasterize_line(*screen_v0, *screen_v1, line.color):
                framebuffer.write_pixel(pixel.x, pixel.y, pixel.color)
                pixels_written += 1

        self.last_stats = RenderStats(scene_edges, visible_edges, pixels_written)
        return framebuffer


def render(scene: Scene, camera: Camera) -> Framebuffer:
    """Convenience entry point using the configured default display."""
    return Renderer().render(scene, camera)
