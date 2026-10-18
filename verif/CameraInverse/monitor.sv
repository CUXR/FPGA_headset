`timescale 1ns/1ps

module monitor #(parameter integer DATA_W = 18) (
  input logic clk,
  input logic rst,
  input logic o_inverse_valid,
  input logic i_inverse_ready,
  input wire signed [DATA_W-1:0] o_inverse[3:0][3:0]
);
  logic held = 0;
  logic signed [DATA_W-1:0] held_data[3:0][3:0];
  integer row, column;

  always @(posedge clk) begin
    if (rst) begin
      held = 0;
    end else begin
      if (held && o_inverse_valid !== 1'b1)
        $fatal(1, "Output valid changed while stalled");

      for (row = 0; row < 4; row = row + 1) begin
        for (column = 0; column < 4; column = column + 1) begin
          if (held && o_inverse[row][column] !== held_data[row][column])
            $fatal(1, "Output changed while stalled");

          if (o_inverse_valid === 1'b1 && i_inverse_ready === 1'b1 &&
              (^o_inverse[row][column] === 1'bx))
            $fatal(1, "Unknown accepted output");

          held_data[row][column] = o_inverse[row][column];
        end
      end

      held = (o_inverse_valid === 1'b1 && i_inverse_ready === 1'b0);
    end
  end
endmodule
