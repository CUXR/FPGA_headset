`timescale 1ns/1ps

module monitor #(
  parameter integer DATA_W = 18,
  parameter integer OBJECT_ID_W = 4
) (
  input logic                    clk,
  input logic                    rst,

  input logic                    o_result_valid,
  input logic                    i_result_ready,
  input wire signed [DATA_W-1:0] o_result_vertex[0:3],
  input logic [OBJECT_ID_W-1:0]  o_result_object_id
);
  logic vec_held;
  logic signed [DATA_W-1:0] held_vec_data[0:3];

  logic [OBJECT_ID_W-1:0] held_object_id;

  integer row;

  initial begin
    vec_held = 0;
  end

  always @(posedge clk) begin
    if (rst) begin
      vec_held <= 0;
    end else begin
      if (vec_held && o_result_object_id !== held_object_id)
        $fatal(1, "Object ID changed while stalled");

      if (o_result_valid === 1'b1 && i_result_ready === 1'b1 &&
          (^o_result_object_id === 1'bx))
        $fatal(1, "Unknown accepted object ID");

      held_object_id <= o_result_object_id;

      // Vertex
      if (vec_held && o_result_valid !== 1'b1)
        $fatal(1, "Output valid changed while stalled");

      for (row = 0; row < 4; row = row + 1) begin
        if (vec_held && o_result_vertex[row] !== held_vec_data[row])
          $fatal(1, "Output changed while stalled");

        if (o_result_valid === 1'b1 && i_result_ready === 1'b1 &&
            (^o_result_vertex[row] === 1'bx))
          $fatal(1, "Unknown accepted output");

        held_vec_data[row] <= o_result_vertex[row];
      end

      vec_held <= (o_result_valid === 1'b1 && i_result_ready === 1'b0);
    end
  end
endmodule
