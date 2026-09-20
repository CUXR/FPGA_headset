import numpy as np
import pytest
from PIL import Image

from renderer_model.framebuffer import Framebuffer


def test_default_shape_dtype_and_background():
    fb = Framebuffer()
    assert fb.image.shape == (720, 1280, 3)
    assert fb.image.dtype == np.uint8
    assert not np.any(fb.image)


def test_write_changes_exactly_one_pixel_and_preserves_rgb():
    fb = Framebuffer(5, 4)
    fb.write_pixel(3, 2, (10, 20, 30))
    assert fb.get_pixel(3, 2) == (10, 20, 30)
    assert np.count_nonzero(np.any(fb.image != 0, axis=2)) == 1


def test_clear_resets_writes_to_custom_background():
    fb = Framebuffer(3, 2, (4, 5, 6))
    fb.write_pixel(1, 1, (100, 100, 100)); fb.clear()
    assert np.all(fb.image == np.array([4, 5, 6], dtype=np.uint8))


@pytest.mark.parametrize("x,y", [(-1, 0), (3, 0), (0, -1), (0, 2)])
def test_out_of_bounds_access_raises(x, y):
    fb = Framebuffer(3, 2)
    with pytest.raises(IndexError): fb.write_pixel(x, y, (1, 2, 3))
    with pytest.raises(IndexError): fb.get_pixel(x, y)


def test_save_png_creates_valid_image(tmp_path):
    path = tmp_path / "nested" / "frame.png"
    fb = Framebuffer(5, 4); fb.write_pixel(1, 2, (3, 4, 5)); fb.save_png(path)
    with Image.open(path) as image:
        assert image.format == "PNG" and image.size == (5, 4)
