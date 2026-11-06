`timescale 1ns/1ps

module driver #(parameter integer DATA_W = 18) (
  input  logic clk,
  output logic rst,

  input  logic o_mat_ready,
  output logic i_mat_valid,
  output logic signed [DATA_W-1:0] i_matrix[0:3][0:3],

  input  logic o_vec_ready,
  output logic i_vec_valid,
  output logic signed [DATA_W-1:0] i_vec[0:3],

  output logic i_matrix_mode,

  output logic i_mat_ready,
  output logic i_vec_ready
);
  integer matrix [0:15];
  integer vector [0:3];
  integer input_gap = 0;
  integer ready_period = 1;
  integer ready_cycle;
  logic   hold_output = 0;

  initial begin
    rst = 1;
    i_mat_valid = 0;
    i_vec_valid = 0;
    i_matrix_mode = 0;
    i_mat_ready = 0;
    i_vec_ready = 0;
    ready_cycle = 0;
  end

  always @(negedge clk) begin
    if (rst || hold_output) begin
      i_mat_ready <= 0;
      i_vec_ready <= 0;
    end else begin
      i_mat_ready <= (ready_cycle % ready_period == 0);
      i_vec_ready <= (ready_cycle % ready_period == 0);
    end

    ready_cycle <= ready_cycle + 1;
  end

  task reset_dut;
    begin
      @(negedge clk);
      rst = 1;
      i_mat_valid = 0;
      i_vec_valid = 0;
      i_matrix_mode = 0;

      repeat (3) @(negedge clk);
      rst = 0;
    end
  endtask

  task send_matrix;
    integer index;
    begin
      @(negedge clk);
      i_mat_valid = 0;
      i_vec_valid = 0;
      i_matrix_mode = 0;
      if (input_gap > 0)
        repeat (input_gap) @(negedge clk);

      for (index = 0; index < 16; index = index + 1)
        i_matrix[index / 4][index % 4] = DATA_W'(matrix[index]);
      i_mat_valid = 1;

      @(posedge clk);
      while (o_mat_ready !== 1'b1) @(posedge clk);
    end
  endtask

  task send_vector(input logic matrix_mode);
    integer index;
    begin
      @(negedge clk);
      i_mat_valid = 0;
      i_vec_valid = 0;
      i_matrix_mode = 0;
      if (input_gap > 0)
        repeat (input_gap) @(negedge clk);

      for (index = 0; index < 4; index = index + 1)
        i_vec[index] = DATA_W'(vector[index]);
      i_matrix_mode = matrix_mode;
      i_vec_valid = 1;

      @(posedge clk);
      while (o_vec_ready !== 1'b1) @(posedge clk);
    end
  endtask

  task send_matrix_and_vector(input logic matrix_mode);
    integer index;
    begin
      @(negedge clk);
      i_mat_valid = 0;
      i_vec_valid = 0;
      i_matrix_mode = 0;
      if (input_gap > 0)
        repeat (input_gap) @(negedge clk);

      for (index = 0; index < 16; index = index + 1)
        i_matrix[index / 4][index % 4] = DATA_W'(matrix[index]);
      for (index = 0; index < 4; index = index + 1)
        i_vec[index] = DATA_W'(vector[index]);
      i_matrix_mode = matrix_mode;
      i_mat_valid = 1;
      i_vec_valid = 1;

      @(posedge clk);
      while (o_mat_ready !== 1'b1 || o_vec_ready !== 1'b1) begin
        if (o_mat_ready === 1'b1 || o_vec_ready === 1'b1)
          $fatal(1, "send_matrix_and_vector requires a matrix operation boundary");
        @(posedge clk);
      end
    end
  endtask

  task finish_operation;
    begin
      @(negedge clk);
      i_mat_valid = 0;
      i_vec_valid = 0;
      i_matrix_mode = 0;
    end
  endtask
endmodule
