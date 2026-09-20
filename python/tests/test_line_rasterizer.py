import pytest

from renderer_model.line_rasterizer import rasterize_line


def positions(start, end):
    return [(p.x, p.y) for p in rasterize_line(*start, *end, (7, 8, 9))]


@pytest.mark.parametrize(
    "start,end,expected",
    [((2, 3), (2, 3), [(2, 3)]),
     ((1, 2), (4, 2), [(1, 2), (2, 2), (3, 2), (4, 2)]),
     ((2, 1), (2, 4), [(2, 1), (2, 2), (2, 3), (2, 4)]),
     ((0, 0), (3, 3), [(0, 0), (1, 1), (2, 2), (3, 3)]),
     ((0, 3), (3, 0), [(0, 3), (1, 2), (2, 1), (3, 0)]),
     ((0, 0), (4, 2), [(0, 0), (1, 1), (2, 1), (3, 2), (4, 2)]),
     ((0, 0), (2, 4), [(0, 0), (1, 1), (1, 2), (2, 3), (2, 4)]),
     ((0, 2), (4, 0), [(0, 2), (1, 1), (2, 1), (3, 0), (4, 0)]),
     ((0, 4), (2, 0), [(0, 4), (1, 3), (1, 2), (2, 1), (2, 0)])],
)
def test_known_lines_in_all_octants(start, end, expected):
    assert positions(start, end) == expected


def test_reversed_endpoints_and_pixel_invariants():
    points = list(rasterize_line(7, 2, 1, 5, (12, 34, 56)))
    assert (points[0].x, points[0].y) == (7, 2)
    assert (points[-1].x, points[-1].y) == (1, 5)
    assert all(pixel.color == (12, 34, 56) for pixel in points)
    for a, b in zip(points, points[1:]):
        delta = abs(a.x - b.x), abs(a.y - b.y)
        assert delta != (0, 0)
        assert delta[0] <= 1 and delta[1] <= 1
