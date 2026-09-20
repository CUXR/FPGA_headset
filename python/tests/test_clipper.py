import numpy as np
import pytest

from renderer_model.clipper import clip_line


def assert_inside(point):
    x, y, z, w = point
    assert x + w >= -1e-10
    assert w - x >= -1e-10
    assert y + w >= -1e-10
    assert w - y >= -1e-10
    assert z >= -1e-10
    assert w - z >= -1e-10


def test_inside_is_unchanged():
    p0, p1 = np.array([-.5, .2, .1, 1.]), np.array([.8, -.3, .9, 1.])
    result = clip_line(p0, p1)
    assert result is not None
    assert np.array_equal(result[0], p0) and np.array_equal(result[1], p1)


@pytest.mark.parametrize(
    "p0,p1",
    [([-3, 0, .5, 1], [-2, 0, .5, 1]), ([2, 0, .5, 1], [3, 0, .5, 1]),
     ([0, 2, .5, 1], [0, 3, .5, 1]), ([0, -3, .5, 1], [0, -2, .5, 1]),
     ([0, 0, -2, 1], [0, 0, -1, 1]), ([0, 0, 2, 1], [0, 0, 3, 1])],
)
def test_fully_outside_each_plane_returns_none(p0, p1):
    assert clip_line(p0, p1) is None


@pytest.mark.parametrize(
    "outside,inside,expected",
    [([-2, 0, .5, 1], [0, 0, .5, 1], [-1, 0, .5, 1]),
     ([2, 0, .5, 1], [0, 0, .5, 1], [1, 0, .5, 1]),
     ([0, 0, -.5, 1], [0, 0, .5, 1], [0, 0, 0, 1]),
     ([0, 0, 1.5, 1], [0, 0, .5, 1], [0, 0, 1, 1])],
)
def test_crossing_plane_shortens_at_expected_boundary(outside, inside, expected):
    result = clip_line(outside, inside)
    assert result is not None
    assert np.allclose(result[0], expected)
    assert np.allclose(result[1], inside)


def test_crossing_multiple_planes_and_on_plane_endpoint():
    result = clip_line([-2, -2, -.5, 1], [1, 1, 1, 1])
    assert result is not None
    assert_inside(result[0]); assert_inside(result[1])
    on_plane = np.array([-1, 0, 0, 1], dtype=float)
    accepted = clip_line(on_plane, [0, 0, .5, 1])
    assert accepted is not None and np.array_equal(accepted[0], on_plane)


def test_deterministic_random_results_are_inside_volume():
    rng = np.random.default_rng(1204)
    for _ in range(1000):
        result = clip_line(rng.uniform(-4, 4, 4), rng.uniform(-4, 4, 4))
        if result is not None:
            assert_inside(result[0]); assert_inside(result[1])
