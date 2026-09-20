import numpy as np

from renderer_model.types import Camera
from renderer_model.view_transform import build_camera_world_matrix, build_view_matrix, transform_vertex


def camera(position=(0, 0, 0), rotation=(0, 0, 0)):
    return Camera(np.asarray(position, dtype=np.float64), np.asarray(rotation, dtype=np.float64))


def test_origin_camera_has_identity_view():
    assert np.allclose(build_view_matrix(camera()), np.eye(4))


def test_camera_translation_is_inverted():
    view = build_view_matrix(camera((2, 1, 5)))
    assert np.allclose(transform_vertex([5, 4, 10, 1], view), [3, 3, 5, 1])
    assert np.allclose(transform_vertex([2, 1, 5, 1], view), [0, 0, 0, 1])


def test_positive_90_degree_yaw_has_inverse_view_rotation():
    view = build_view_matrix(camera(rotation=(0, np.pi / 2, 0)))
    assert np.allclose(transform_vertex([1, 0, 0, 1], view), [0, 0, 1, 1])


def test_view_and_camera_world_are_inverses_and_preserve_w():
    value = camera((1, 2, 3), (0.2, -0.3, 0.4))
    view = build_view_matrix(value)
    assert np.allclose(view @ build_camera_world_matrix(value), np.eye(4))
    assert np.isclose(transform_vertex([3, 4, 5, 1], view)[3], 1.0)
