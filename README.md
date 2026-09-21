# FPGA Headset

## 1. Floating-point reference renderer

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

We will use ready/valid transactions between blocks.

```rtl
input  logic         in_valid;
output logic         in_ready;
input  line_packet_t in_data;

output logic         out_valid;
input  logic         out_ready;
output line_packet_t out_data;
```

A transaction transfers on a rising clock edge when:

```rtl
transfer = valid && ready;
```

- The producer asserts `valid` when it has a transaction available.
- If `valid` is high and `ready` is low, the producer holds both `valid` and
the payload stable.
- The consumer asserts `ready` when it can accept a transaction.
- The producer must not wait for `ready` before asserting `valid`.

## 3. Hardware renderer

### 3.1 Model transform

[`rtl/model_transform.sv`](rtl/model_transform.sv) multiplies one signed 4×4
matrix by one signed four-component vector. Send the 16 matrix elements in
row-major order, one per accepted input cycle. Send the four vector components
alongside the first four matrix elements. The module returns four result
components in row order; each output stays valid and unchanged until accepted.

The three registered stages capture operands, multiply, and accumulate. With
no input gaps, loading takes 16 clock cycles. The first output becomes valid
three clock edges after the last input is accepted. Sending the four outputs
takes four more handshakes, or four cycles if `i_ready` stays high. Input or
output stalls extend these times.

Inputs and outputs are signed `DATA_W`-bit values (18 bits by default). Each
product is `2*DATA_W` bits and each row accumulator is `2*DATA_W+2` bits. The
output uses the low `DATA_W` bits of the sum.
