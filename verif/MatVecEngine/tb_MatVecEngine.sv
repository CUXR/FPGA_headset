`timescale 1ns/1ps

module tb_MatVecEngine;
  parameter integer DATA_W = 18;
  parameter integer NUM_COLS = 4;

  logic clk;
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  logic rst;

  logic i_mat_in_valid;
  logic o_mat_in_ready;
  wire signed [DATA_W-1:0] i_matrix_in[0:3][0:3];

  logic i_vec_in_valid;
  logic o_vec_in_ready;
  wire signed [DATA_W-1:0] i_vector_in[0:3];

  logic i_is_matrix_col;
  logic i_is_end_vec;
  logic i_is_end_mat;

  logic o_mat_out_valid;
  logic i_mat_out_ready;
  wire signed [DATA_W-1:0] o_matrix_out[0:3][0:3];

  logic o_vec_out_valid;
  logic i_vec_out_ready;
  wire signed [DATA_W-1:0] o_vector_out[0:3];

  MatVecEngine #(
    .DATA_W(DATA_W), 
    .NUM_COLS(NUM_COLS)
  ) dut (
    .clk             (clk),
    .rst             (rst),

    .mat_in_val      (i_mat_in_valid),
    .mat_in_rdy      (o_mat_in_ready),
    .matrix_in       (i_matrix_in),

    .vec_in_val      (i_vec_in_valid),
    .vec_in_rdy      (o_vec_in_ready),
    .vector_in       (i_vector_in),

    .is_matrix_col   (i_is_matrix_col),
    .isend_vec       (i_is_end_vec),
    .isend_mat       (i_is_end_mat),

    .mat_out_val     (o_mat_out_valid),
    .mat_out_rdy     (i_mat_out_ready),
    .matrix_out      (o_matrix_out),

    .vec_out_val     (o_vec_out_valid),
    .vec_out_rdy     (i_vec_out_ready),
    .vector_out      (o_vector_out)
  );

  driver #(
    .DATA_W(DATA_W)
  ) input_driver (
    .clk             (clk),
    .rst             (rst),

    .o_mat_in_ready  (o_mat_in_ready),
    .i_mat_in_valid  (i_mat_in_valid),
    .i_matrix_in     (i_matrix_in),

    .o_vec_in_ready  (o_vec_in_ready),
    .i_vec_in_valid  (i_vec_in_valid),
    .i_vector_in     (i_vector_in),
    
    .i_is_matrix_col (i_is_matrix_col),
    .i_is_end_vec    (i_is_end_vec),
    .i_is_end_mat    (i_is_end_mat),
    .i_mat_out_ready (i_mat_out_ready),
    .i_vec_out_ready (i_vec_out_ready)
  );

  monitor #(
    .DATA_W(DATA_W)
  ) output_monitor (
    .clk             (clk),
    .rst             (rst),
    .o_mat_out_valid (o_mat_out_valid),
    .i_mat_out_ready (i_mat_out_ready),
    .o_mat_out       (o_matrix_out),
    .o_vec_out_valid (o_vec_out_valid),
    .i_vec_out_ready (i_vec_out_ready),
    .o_vec_out       (o_vector_out)
  );

  scoreboard #(
    .DATA_W(DATA_W)
  ) result_checker (
    .clk             (clk),
    .rst             (rst),
    .o_mat_out_valid (o_mat_out_valid),
    .i_mat_out_ready (i_mat_out_ready),
    .o_mat_out       (o_matrix_out),
    .o_vec_out_valid (o_vec_out_valid),
    .i_vec_out_ready (i_vec_out_ready),
    .o_vec_out       (o_vector_out)
  );

  tests #(
    .DATA_W(DATA_W)
  ) test_cases (
    .clk             (clk)
  );

  initial begin
    // TODO: Add vcd dump for waveform viewing
    #1000000;
    $fatal(1, "Simulation timeout");
  end
endmodule
