import numpy as np

from renderer_model.scene_rom import GREEN, RED, WHITE, get_cornell_box_scene


def test_cornell_scene_has_expected_major_objects():
    scene = get_cornell_box_scene()
    assert {obj.name for obj in scene.objects} == {
        "floor", "ceiling", "back_wall", "left_wall", "right_wall", "short_box", "tall_box"
    }


def test_scene_mesh_data_is_valid():
    for obj in get_cornell_box_scene().objects:
        vertices, edges = obj.mesh.vertices, obj.mesh.edges
        assert vertices.ndim == 2 and vertices.shape[1] == 4
        assert np.all(vertices[:, 3] == 1.0)
        assert np.all(np.isfinite(vertices))
        assert edges.ndim == 2 and edges.shape[1] == 2
        assert np.all((edges >= 0) & (edges < len(vertices)))
        assert all(0 <= channel <= 255 for channel in obj.mesh.color)
        assert np.all(np.isfinite(obj.model_matrix))


def test_scene_colors_include_cornell_walls_and_neutrals():
    colors = {obj.mesh.color for obj in get_cornell_box_scene().objects}
    assert {RED, GREEN, WHITE} <= colors


def test_scene_generation_is_deterministic():
    first, second = get_cornell_box_scene(), get_cornell_box_scene()
    for a, b in zip(first.objects, second.objects, strict=True):
        assert a.name == b.name and a.mesh.color == b.mesh.color
        assert np.array_equal(a.mesh.vertices, b.mesh.vertices)
        assert np.array_equal(a.mesh.edges, b.mesh.edges)
        assert np.array_equal(a.model_matrix, b.model_matrix)


def test_boxes_reuse_local_geometry_with_distinct_transforms():
    scene = get_cornell_box_scene()
    short, tall = scene.objects[-2:]
    assert short.mesh is tall.mesh
    assert not np.array_equal(short.model_matrix, np.eye(4))
    assert not np.array_equal(short.model_matrix, tall.model_matrix)
