import numpy as np
import pytest

from renderer_model.perspective_divide import perspective_divide


@pytest.mark.parametrize(
    "clip,expected",
    [([2, 4, 6, 2], [1, 2, 3]), ([1, -2, 3, 1], [1, -2, 3]), ([-2, -4, -6, 2], [-1, -2, -3])],
)
def test_divide_values(clip, expected):
    assert np.allclose(perspective_divide(clip), expected)


def test_input_is_not_mutated():
    value = np.array([2., 4., 6., 2.])
    original = value.copy()
    perspective_divide(value)
    assert np.array_equal(value, original)


@pytest.mark.parametrize("w", [0.0, 1e-15, -1e-15])
def test_near_zero_w_raises(w):
    with pytest.raises(ValueError, match="non-zero"):
        perspective_divide([1, 2, 3, w])
