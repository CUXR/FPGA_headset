import numpy as np

from renderer_model.model_transform import build_model_matrix, transform_vertex


def test_identity_and_input_not_mutated():
    vertex = np.array([1.0, 2.0, 3.0, 1.0])
    original = vertex.copy()
    assert np.allclose(transform_vertex(vertex, np.eye(4)), vertex)
    assert np.array_equal(vertex, original)


def test_translation():
    actual = transform_vertex([1, 2, 3, 1], build_model_matrix((10, 20, 30)))
    assert np.allclose(actual, [11, 22, 33, 1])


def test_scaling_and_affine_w():
    actual = transform_vertex([1, 2, 3, 1], build_model_matrix(scale=(2, 3, 4)))
    assert np.allclose(actual, [2, 6, 12, 1])


def test_positive_z_rotation():
    matrix = build_model_matrix(rotation_xyz=(0, 0, np.pi / 2))
    assert np.allclose(transform_vertex([1, 0, 0, 1], matrix), [0, 1, 0, 1])


def test_composition_matches_explicit_sequential_operations():
    from renderer_model.transforms import rotation_x_matrix, rotation_y_matrix, rotation_z_matrix, scale_matrix, translation_matrix

    vertex = np.array([0.5, -1.0, 2.0, 1.0])
    translation, rotation, scale = (3, 4, 5), (0.2, -0.4, 0.6), (2, 3, 4)
    expected = translation_matrix(*translation) @ (rotation_z_matrix(rotation[2]) @ (rotation_y_matrix(rotation[1]) @ (rotation_x_matrix(rotation[0]) @ (scale_matrix(*scale) @ vertex))))
    assert np.allclose(transform_vertex(vertex, build_model_matrix(translation, rotation, scale)), expected)
