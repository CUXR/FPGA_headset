import pytest

from renderer_model.viewport_transform import ndc_to_screen


@pytest.mark.parametrize(
    "ndc,expected", [((-1, 1, 0), (0, 0)), ((1, -1, 1), (1279, 719)), ((0, 0, .5), (640, 360))]
)
def test_known_viewport_positions(ndc, expected):
    assert ndc_to_screen(ndc) == expected


def test_axes_have_expected_screen_direction():
    left, right = ndc_to_screen((-.5, 0, 0)), ndc_to_screen((.5, 0, 0))
    lower, upper = ndc_to_screen((0, -.5, 0)), ndc_to_screen((0, .5, 0))
    assert right[0] > left[0]
    assert upper[1] < lower[1]


def test_visible_grid_produces_bounded_integer_coordinates():
    for x in [-1, -.25, 0, .25, 1]:
        for y in [-1, -.25, 0, .25, 1]:
            px, py = ndc_to_screen((x, y, 0))
            assert isinstance(px, int) and isinstance(py, int)
            assert 0 <= px < 1280 and 0 <= py < 720
