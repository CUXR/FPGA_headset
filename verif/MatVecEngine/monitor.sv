`timescale 1ns/1ps

module monitor #(parameter integer DATA_W = 18) (
  input logic clk,
  input logic rst,

  input logic o_mat_out_valid,
  input logic i_mat_out_ready,
  input wire signed [DATA_W-1:0] o_mat_out[0:3][0:3],

  input logic o_vec_out_valid,
  input logic i_vec_out_ready,
  input wire signed [DATA_W-1:0] o_vec_out[0:3]
);
  logic mat_held;
  logic signed [DATA_W-1:0] held_mat_data[0:3][0:3];

  logic vec_held;
  logic signed [DATA_W-1:0] held_vec_data[0:3];

  integer row, column;

  initial begin
    mat_held = 0;
    vec_held = 0;
  end

  always @(posedge clk) begin
    if (rst) begin
      mat_held <= 0;
      vec_held <= 0;
    end else begin
      // Matrix
      if (mat_held && o_mat_out_valid !== 1'b1)
        $fatal(1, "Output valid changed while stalled");

      for (row = 0; row < 4; row = row + 1) begin
        for (column = 0; column < 4; column = column + 1) begin
          if (mat_held && o_mat_out[row][column] !== held_mat_data[row][column])
            $fatal(1, "Output changed while stalled");

          if (o_mat_out_valid === 1'b1 && i_mat_out_ready === 1'b1 &&
              (^o_mat_out[row][column] === 1'bx))
            $fatal(1, "Unknown accepted output");

          held_mat_data[row][column] <= o_mat_out[row][column];
        end
      end

      mat_held <= (o_mat_out_valid === 1'b1 && i_mat_out_ready === 1'b0);

      // Vector
      if (vec_held && o_vec_out_valid !== 1'b1)
        $fatal(1, "Output valid changed while stalled");
      
      for (row = 0; row < 4; row = row + 1) begin
        if (vec_held && o_vec_out[row] !== held_vec_data[row])
          $fatal(1, "Output changed while stalled");
        
        if (o_vec_out_valid === 1'b1 && i_vec_out_ready === 1'b1 &&
            (^o_vec_out[row] === 1'bx))
          $fatal(1, "Unknown accepted output");

        held_vec_data[row] <= o_vec_out[row];
      end

      vec_held <= (o_vec_out_valid === 1'b1 && i_vec_out_ready === 1'b0);
    end
  end
endmodule
