"""Floating-point, wireframe reference renderer for the FPGA pipeline."""

from .renderer_top import Renderer, RenderStats, render
from .types import Camera, Mesh, Pixel, Scene, SceneObject

__all__ = [
    "Camera", "Mesh", "Pixel", "Renderer", "RenderStats", "Scene",
    "SceneObject", "render",
]
