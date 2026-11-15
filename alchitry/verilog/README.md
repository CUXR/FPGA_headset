# SystemVerilog translation

alchitry_top.sv translates fpgahead/source/alchitry_top.luc.

The five files in fpgahead/luc are all empty (0 bytes). Their corresponding
.sv files therefore contain comments only, with no invented implementations.

fpgahead.alp references Alchitry library components for async_fifo, ddr_arbiter,
fifo, lru_cache, mig_wrapper, and reset_conditioner. Those component sources
are not included in this project directory. The top module retains its
reset_conditioner dependency; provide the library module when building.
The conditioned reset is unused in the original top module.

The original project files have not been modified. No SystemVerilog compiler
was available on PATH, so compilation has not been verified.
