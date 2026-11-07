`timescale 1ns/1ps

module monitor #(
  parameter integer DATA_W = 18,
  parameter integer OBJECT_ID_W = 4
) (
  input logic                    clk,
  input logic                    rst,

  input logic                    o_object_mat_valid,
  input logic                    i_object_mat_ready,
  input wire signed [DATA_W-1:0] o_object_mat[0:3][0:3],
  input logic [OBJECT_ID_W-1:0]  o_object_id
);
  logic mat_held;
  logic signed [DATA_W-1:0] held_mat_data[0:3][0:3];

  logic [OBJECT_ID_W-1:0] held_object_id;

  integer row, column;

  initial begin
    mat_held = 0;
  end

  always @(posedge clk) begin
    if (rst) begin
      mat_held <= 0;
    end else begin
      if (mat_held && o_object_id !== held_object_id)
        $fatal(1, "Object ID changed while stalled");

      if (o_object_mat_valid === 1'b1 && i_object_mat_ready === 1'b1 &&
          (^o_object_id === 1'bx))
        $fatal(1, "Unknown accepted object ID");

      held_object_id <= o_object_id;

      // Matrix
      if (mat_held && o_object_mat_valid !== 1'b1)
        $fatal(1, "Output valid changed while stalled");

      for (row = 0; row < 4; row = row + 1) begin
        for (column = 0; column < 4; column = column + 1) begin
          if (mat_held && o_object_mat[row][column] !== held_mat_data[row][column])
            $fatal(1, "Output changed while stalled");

          if (o_object_mat_valid === 1'b1 && i_object_mat_ready === 1'b1 &&
              (^o_object_mat[row][column] === 1'bx))
            $fatal(1, "Unknown accepted output");

          held_mat_data[row][column] <= o_object_mat[row][column];
        end
      end

      mat_held <= (o_object_mat_valid === 1'b1 && i_object_mat_ready === 1'b0);
    end
  end
endmodule
