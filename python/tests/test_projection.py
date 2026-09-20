import numpy as np
import pytest

from renderer_model.projection import build_projection_matrix, project_vertex


def test_axis_and_w_equals_camera_z():
    projected = project_vertex([0, 0, 7, 1], build_projection_matrix())
    assert projected[0] == 0 and projected[1] == 0
    assert projected[3] == 7


def test_sign_and_x_symmetry():
    projection = build_projection_matrix()
    positive = project_vertex([2, 3, 5, 1], projection)
    negative = project_vertex([-2, 3, 5, 1], projection)
    assert positive[0] > 0 and positive[1] > 0
    assert np.isclose(positive[0], -negative[0])


def test_near_and_far_map_to_zero_and_one():
    near, far = 0.25, 20.0
    projection = build_projection_matrix(60, 1.5, near, far)
    for z, expected in [(near, 0.0), (far, 1.0)]:
        clip = project_vertex([0, 0, z, 1], projection)
        assert np.isclose(clip[2] / clip[3], expected)


def test_narrower_fov_increases_projected_magnitude():
    narrow = project_vertex([1, 1, 3, 1], build_projection_matrix(30))
    wide = project_vertex([1, 1, 3, 1], build_projection_matrix(90))
    assert narrow[0] > wide[0] and narrow[1] > wide[1]


@pytest.mark.parametrize(
    "arguments", [(0, 1, .1, 10), (180, 1, .1, 10), (60, 0, .1, 10), (60, 1, 0, 10), (60, 1, 1, 1)]
)
def test_invalid_parameters_raise(arguments):
    with pytest.raises(ValueError):
        build_projection_matrix(*arguments)
