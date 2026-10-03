`timescale 1ns/1ps

module monitor #(parameter integer DATA_W = 18) (
  input logic clk,
  input logic rst,
  input logic o_valid,
  input logic i_ready,
  input logic signed [DATA_W-1:0] o_vector_data
);
  logic held = 0;
  logic signed [DATA_W-1:0] held_data;

  always @(posedge clk) begin
    if (rst) begin
      held = 0;
    end else begin
      if (held && (o_valid !== 1'b1 || o_vector_data !== held_data))
        $fatal(1, "Output changed while stalled");

      if (o_valid === 1'b1 && i_ready === 1'b1 && $isunknown(o_vector_data))
        $fatal(1, "Unknown accepted output");

      held = (o_valid === 1'b1 && i_ready === 1'b0);
      held_data = o_vector_data;
    end
  end
endmodule
