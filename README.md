# FPGA Headset

## Floating-point reference renderer

The Python renderer is a deliberately modular, wireframe-only golden model for
a future FPGA graphics pipeline. It uses homogeneous column vectors and this
coordinate flow:

```text
local -> world -> camera -> clip -> NDC -> screen
      -> rasterized pixels -> framebuffer
```

World/camera coordinates use **+x right, +y up, +z forward**. NDC x and y span
`[-1, 1]`, while NDC z spans `[0, 1]`. Screen coordinates use a **top-left
origin**, +x right and +y down. The model uses float64 mathematics until the
integer viewport and Bresenham stages; it intentionally has no fixed-point
quantization, filling, depth buffering, lighting, or anti-aliasing.

From `python/`, run `pytest -q` to verify every stage, or
`python render_cornell.py` to produce `python/output/cornell_wireframe.png`.

## Module handshake rules


