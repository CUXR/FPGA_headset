import numpy as np

from renderer_model.renderer_top import Renderer
from renderer_model.scene_rom import GREEN, RED, get_cornell_box_scene
from renderer_model.types import Mesh, Scene, SceneObject


def line_scene(lines, color=(255, 255, 255)):
    vertices = []
    edges = []
    for start, end in lines:
        index = len(vertices)
        vertices.extend([(*start, 1.0), (*end, 1.0)])
        edges.append((index, index + 1))
    mesh = Mesh(np.asarray(vertices, dtype=np.float64), np.asarray(edges, dtype=np.int64), color)
    return Scene((SceneObject(mesh, np.eye(4), "lines"),))


def test_center_line_produces_expected_center_pixels(origin_camera):
    renderer = Renderer(width=101, height=101)
    fb = renderer.render(line_scene([((0, -1, 3), (0, 1, 3))]), origin_camera)
    assert renderer.last_stats.visible_edges == 1
    assert np.any(fb.image[:, 50] != 0)
    assert fb.get_pixel(50, 50) == (255, 255, 255)


def test_outside_line_is_discarded(origin_camera):
    renderer = Renderer(101, 101)
    fb = renderer.render(line_scene([((10, 0, 1), (11, 0, 1))]), origin_camera)
    assert renderer.last_stats.visible_edges == 0
    assert not np.any(fb.image)


def test_partially_visible_line_is_clipped_and_rendered_in_bounds(origin_camera):
    renderer = Renderer(101, 101)
    fb = renderer.render(line_scene([((-10, 0, 2), (0, 0, 2))]), origin_camera)
    assert renderer.last_stats.visible_edges == 1
    assert fb.get_pixel(0, 50) == (255, 255, 255)
    assert np.count_nonzero(np.any(fb.image != 0, axis=2)) > 1


def test_cornell_render_properties_and_determinism(origin_camera):
    renderer = Renderer()
    first = renderer.render(get_cornell_box_scene(), origin_camera).image.copy()
    first_stats = renderer.last_stats
    second = renderer.render(get_cornell_box_scene(), origin_camera).image.copy()
    assert first.shape == (720, 1280, 3) and first.dtype == np.uint8
    assert np.array_equal(first, second)
    assert np.any(np.all(first == RED, axis=2))
    assert np.any(np.all(first == GREEN, axis=2))
    painted = np.count_nonzero(np.any(first != 0, axis=2))
    assert 0 < painted < first.shape[0] * first.shape[1] // 10
    assert first_stats.scene_edges == 44 and first_stats.visible_edges > 0
