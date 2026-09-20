"""Static scene-ROM block.

This block constructs deterministic local-space mesh records and model matrices
that stand in for future FPGA ROM contents. No rendering transformations occur
here. Explicit edges describe only intended wireframe lines, avoiding triangle
split diagonals.

The Cornell room spans x=-2..2, y=-2..2, z=4..8 and is open at z=4. Two
instances of one centered unit-cube mesh form the interior boxes.
"""

import numpy as np

from .model_transform import build_model_matrix
from .types import Color, Mesh, Scene, SceneObject

WHITE: Color = (220, 220, 220)
RED: Color = (220, 50, 50)
GREEN: Color = (50, 200, 70)


def _quad(vertices: list[tuple[float, float, float]], color: Color) -> Mesh:
    homogeneous = np.array([[x, y, z, 1.0] for x, y, z in vertices], dtype=np.float64)
    edges = np.array([[0, 1], [1, 2], [2, 3], [3, 0]], dtype=np.int64)
    return Mesh(homogeneous, edges, color)


def _unit_cube(color: Color) -> Mesh:
    vertices = np.array(
        [[-0.5, -0.5, -0.5, 1.0], [0.5, -0.5, -0.5, 1.0],
         [0.5, 0.5, -0.5, 1.0], [-0.5, 0.5, -0.5, 1.0],
         [-0.5, -0.5, 0.5, 1.0], [0.5, -0.5, 0.5, 1.0],
         [0.5, 0.5, 0.5, 1.0], [-0.5, 0.5, 0.5, 1.0]],
        dtype=np.float64,
    )
    edges = np.array(
        [[0, 1], [1, 2], [2, 3], [3, 0],
         [4, 5], [5, 6], [6, 7], [7, 4],
         [0, 4], [1, 5], [2, 6], [3, 7]],
        dtype=np.int64,
    )
    return Mesh(vertices, edges, color)


def get_cornell_box_scene() -> Scene:
    """Return the deterministic open-front room and two transformed boxes."""
    identity = np.eye(4, dtype=np.float64)
    objects = [
        SceneObject(_quad([(-2, -2, 4), (2, -2, 4), (2, -2, 8), (-2, -2, 8)], WHITE), identity.copy(), "floor"),
        SceneObject(_quad([(-2, 2, 4), (-2, 2, 8), (2, 2, 8), (2, 2, 4)], WHITE), identity.copy(), "ceiling"),
        SceneObject(_quad([(-2, -2, 8), (2, -2, 8), (2, 2, 8), (-2, 2, 8)], WHITE), identity.copy(), "back_wall"),
        SceneObject(_quad([(-2, -2, 4), (-2, -2, 8), (-2, 2, 8), (-2, 2, 4)], RED), identity.copy(), "left_wall"),
        SceneObject(_quad([(2, -2, 4), (2, 2, 4), (2, 2, 8), (2, -2, 8)], GREEN), identity.copy(), "right_wall"),
    ]
    cube = _unit_cube(WHITE)
    objects.extend(
        [
            SceneObject(
                cube,
                build_model_matrix((-0.75, -1.45, 6.2), (0.0, 0.28, 0.0), (1.2, 1.1, 1.15)),
                "short_box",
            ),
            SceneObject(
                cube,
                build_model_matrix((0.75, -0.85, 6.8), (0.0, -0.22, 0.0), (0.9, 2.3, 1.0)),
                "tall_box",
            ),
        ]
    )
    return Scene(tuple(objects))
