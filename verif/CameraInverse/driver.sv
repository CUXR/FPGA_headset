`timescale 1ns/1ps

module driver #(parameter integer DATA_W = 18) (
  input logic clk,
  input logic o_matrix_ready,
  output logic rst = 1,
  output logic i_matrix_valid = 0,
  output logic signed [DATA_W-1:0] i_matrix[3:0][3:0],
  output logic i_inverse_ready = 0
);
  integer matrix [0:15];
  integer input_gap = 0;
  integer ready_period = 1;
  integer ready_cycle = 0;
  logic hold_output = 0;

  always @(negedge clk) begin
    if (rst || hold_output)
      i_inverse_ready = 0;
    else
      i_inverse_ready = (ready_cycle % ready_period == 0);

    ready_cycle = ready_cycle + 1;
  end

  task reset_dut;
    begin
      @(negedge clk);
      rst = 1;
      i_matrix_valid = 0;

      repeat (3) @(negedge clk);
      rst = 0;
    end
  endtask

  task send_operation;
    integer index;

    begin
      @(negedge clk);
      if (input_gap > 0) begin
        i_matrix_valid = 0;
        repeat (input_gap) @(negedge clk);
      end

      i_matrix_valid = 1;
      for (index = 0; index < 16; index = index + 1)
        i_matrix[index / 4][index % 4] = matrix[index];

      @(posedge clk);
      while (o_matrix_ready !== 1'b1) @(posedge clk);

      @(negedge clk);
      i_matrix_valid = 0;
    end
  endtask
endmodule
