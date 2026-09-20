import numpy as np

from renderer_model.geometry_fetch import fetch_lines
from renderer_model.types import Mesh, Scene, SceneObject


def make_object(edges):
    mesh = Mesh(
        np.array([[0, 0, 1, 1], [1, 2, 3, 1], [4, 5, 6, 1]], dtype=np.float64),
        np.asarray(edges, dtype=np.int64).reshape((-1, 2)),
        (1, 2, 3),
    )
    return SceneObject(mesh, np.diag([2.0, 3.0, 4.0, 1.0]), "fixture")


def test_one_edge_emits_one_exact_line_with_metadata():
    obj = make_object([[2, 0]])
    lines = list(fetch_lines(Scene((obj,))))
    assert len(lines) == 1
    assert np.array_equal(lines[0].v0, obj.mesh.vertices[2])
    assert np.array_equal(lines[0].v1, obj.mesh.vertices[0])
    assert np.array_equal(lines[0].model_matrix, obj.model_matrix)
    assert lines[0].color == (1, 2, 3)


def test_n_edges_and_multiple_objects_preserve_order():
    a, b = make_object([[0, 1], [1, 2]]), make_object([[2, 1]])
    lines = list(fetch_lines(Scene((a, b))))
    assert len(lines) == 3
    assert [line.v0.tolist() for line in lines] == [
        a.mesh.vertices[0].tolist(), a.mesh.vertices[1].tolist(), b.mesh.vertices[2].tolist()
    ]


def test_empty_mesh_is_cleanly_skipped():
    assert list(fetch_lines(Scene((make_object([]),)))) == []
