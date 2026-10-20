`timescale 1ns/1ps

module driver #(parameter integer DATA_W = 18) (
  input  logic clk,
  output logic rst,

  input  logic o_mat_in_ready,
  output logic i_mat_in_valid,
  output logic signed [DATA_W-1:0] i_matrix_in[0:3][0:3],

  input  logic o_vec_in_ready,
  output logic i_vec_in_valid,
  output logic signed [DATA_W-1:0] i_vector_in[0:3],

  output logic i_is_matrix_col,
  output logic i_is_end_vec,
  output logic i_is_end_mat,

  output logic i_mat_out_ready,
  output logic i_vec_out_ready
);
  integer matrix [0:15];
  integer vector [0:3];
  integer input_gap = 0;
  integer ready_period = 1;
  integer ready_cycle;
  logic   hold_output = 0;

  initial begin
    rst = 1;
    i_mat_in_valid = 0;
    i_vec_in_valid = 0;
    i_is_matrix_col = 0;
    i_is_end_vec = 0;
    i_is_end_mat = 0;
    i_mat_out_ready = 0;
    i_vec_out_ready = 0;
    ready_cycle = 0;
  end

  always @(negedge clk) begin
    if (rst || hold_output) begin
      i_mat_out_ready <= 0;
      i_vec_out_ready <= 0;
    end else begin
      i_mat_out_ready <= (ready_cycle % ready_period == 0);
      i_vec_out_ready <= (ready_cycle % ready_period == 0);
    end

    ready_cycle <= ready_cycle + 1;
  end

  task reset_dut;
    begin
      @(negedge clk);
      rst = 1;
      i_mat_in_valid = 0;
      i_vec_in_valid = 0;
      i_is_matrix_col = 0;
      i_is_end_vec = 0;
      i_is_end_mat = 0;

      repeat (3) @(negedge clk);
      rst = 0;
    end
  endtask

  task send_matrix;
    integer index;

    begin
      @(negedge clk);
      if (input_gap > 0) begin
        i_mat_in_valid = 0;
        i_vec_in_valid = 0;
        repeat (input_gap) @(negedge clk);
      end

      i_mat_in_valid = 1;
      i_vec_in_valid = 0;
      i_is_matrix_col = 0;
      i_is_end_vec = 1;
      i_is_end_mat = 0;
      for (index = 0; index < 16; index = index + 1)
        i_matrix_in[index / 4][index % 4] = DATA_W'(matrix[index]);

      @(posedge clk);
      while (o_mat_in_ready !== 1'b1) @(posedge clk);

      // Return on the acceptance edge; the next task drives at negedge.
    end
  endtask

  task send_vector(input logic matrix_col, end_vec, end_mat);
    integer index;
    begin
      @(negedge clk);
      i_mat_in_valid = 0;
      i_vec_in_valid = 0;
      i_is_matrix_col = 0;
      i_is_end_vec = 0;
      i_is_end_mat = 0;
      if (input_gap > 0)
        repeat (input_gap) @(negedge clk);

      for (index = 0; index < 4; index = index + 1)
        i_vector_in[index] = DATA_W'(vector[index]);
      i_is_matrix_col = matrix_col;
      i_is_end_vec = end_vec;
      i_is_end_mat = end_mat;
      i_vec_in_valid = 1;

      @(posedge clk);
      while (o_vec_in_ready !== 1'b1) @(posedge clk);
    end
  endtask

  task finish_operation;
    begin
      @(negedge clk);
      i_mat_in_valid = 0;
      i_vec_in_valid = 0;
      i_is_matrix_col = 0;
      i_is_end_vec = 0;
      i_is_end_mat = 0;
    end
  endtask
endmodule
