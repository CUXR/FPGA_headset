"""Geometry ROM address-generation and primitive-issue block.

The input is an ordered scene of local-space meshes. The output is an ordered
stream of local-space line endpoints with model matrix and color metadata.
Vertices are fetched by explicit edge indices but are not transformed here.
"""

from collections.abc import Iterator

from .types import LinePrimitive, Scene


def fetch_lines(scene: Scene) -> Iterator[LinePrimitive]:
    """Yield one local-space line for every scene edge, in ROM order."""
    for scene_object in scene:
        mesh = scene_object.mesh
        for index0, index1 in mesh.edges:
            yield LinePrimitive(
                v0=mesh.vertices[int(index0)].copy(),
                v1=mesh.vertices[int(index1)].copy(),
                color=mesh.color,
                model_matrix=scene_object.model_matrix.copy(),
            )
