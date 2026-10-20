# FPGA Headset

## 1. Floating-point reference renderer (Codex generated)

### 1.1 Coordinate conventions

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

### 1.2 Running the reference model

From `python/`, run `pytest -q` to verify every stage, or
`python render_cornell.py` to produce `python/output/cornell_wireframe.png`.

## 2. Module handshake rules

### 2.1 Ready/valid transfers

We just use ready valid for the whole thing. Nothin crazy here.

## 3. Hardware renderer

### 3.1 MatVecEngine

UPDATE README

### 3.2 Camera inverse

Yea so chat lowkey gave a genius idea to make the inverse module fast. The 
camera matrix that comes in only contains rotational and translational data.
For these cases, the inverse is just the following:

$$
A^{-1}
=
\begin{bmatrix}
R & t \\
0 & 1
\end{bmatrix}^{-1}
=
\begin{bmatrix}
R^{T} & -R^{T}t \\
0 & 1
\end{bmatrix}
$$

Where R is a 3x3 sub-matrix (storing the rotational data) and t is a 3x1 
vector (storing the translational data).

ts is genuenly so easy to do in hardware (compared to an actual inverse). The 
only element that requires computation is the $-R^\mathsf{T}t$ element. The 
module is pipeline in the following method:

- Stage 0: Input storing
- Stage 1: Multiply matrix element by vector component (3 multiplications, one per 
  vector element)
- Stage 2: Accumulate products
- Stage 3: Negate the accumulated sums (because there is a negative sign)
- Stage 4: Send the output



Run these commands to test it:
```sh
source env/login.sh
lint CameraInverse
sim CameraInverse --list
sim CameraInverse rotations
regress CameraInverse
```
