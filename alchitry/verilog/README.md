# SystemVerilog translation

The five modules from `fpgahead/luc` are in their corresponding `.sv` files.
Compile `mig_wrapper.sv` before `ddr_arbiter.sv` and `lru_cache.sv` because it
defines the shared `memory_pkg` packed structs for the DDR interface.

Both FIFOs use Alchitry's `simple_dual_port_ram` component. The MIG wrapper
requires the generated Xilinx `mig_7series_0` core.

`alchitry_top.sv` translates `fpgahead/source/alchitry_top.luc` and uses the
Alchitry `reset_conditioner` component.
