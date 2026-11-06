`timescale 1ns/1ps

module tb_MatVecEngine;
  parameter integer DATA_W = 18;
  parameter integer FRAC_W = 10;

  logic clk;
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  logic rst;

  logic i_mat_valid;
  logic o_mat_ready;
  wire signed [DATA_W-1:0] i_matrix[0:3][0:3];

  logic i_vec_valid;
  logic o_vec_ready;
  wire signed [DATA_W-1:0] i_vec[0:3];

  logic i_matrix_mode;

  logic o_mat_valid;
  logic i_mat_ready;
  wire signed [DATA_W-1:0] o_mat[0:3][0:3];

  logic o_vec_valid;
  logic i_vec_ready;
  wire signed [DATA_W-1:0] o_vec[0:3];

  MatVecEngine #(
    .DATA_W(DATA_W), 
    .FRAC_W(FRAC_W)
  ) dut (
    .clk             (clk),
    .rst             (rst),

    .i_mat_valid     (i_mat_valid),
    .o_mat_ready     (o_mat_ready),
    .i_matrix        (i_matrix),

    .i_vec_valid     (i_vec_valid),
    .o_vec_ready     (o_vec_ready),
    .i_vec           (i_vec),

    .i_matrix_mode   (i_matrix_mode),

    .o_mat_valid     (o_mat_valid),
    .i_mat_ready     (i_mat_ready),
    .o_mat           (o_mat),

    .o_vec_valid     (o_vec_valid),
    .i_vec_ready     (i_vec_ready),
    .o_vec           (o_vec)
  );

  driver #(
    .DATA_W(DATA_W)
  ) input_driver (
    .clk             (clk),
    .rst             (rst),

    .o_mat_ready     (o_mat_ready),
    .i_mat_valid     (i_mat_valid),
    .i_matrix        (i_matrix),

    .o_vec_ready     (o_vec_ready),
    .i_vec_valid     (i_vec_valid),
    .i_vec           (i_vec),
    
    .i_matrix_mode   (i_matrix_mode),
    .i_mat_ready     (i_mat_ready),
    .i_vec_ready     (i_vec_ready)
  );

  monitor #(
    .DATA_W(DATA_W)
  ) output_monitor (
    .clk             (clk),
    .rst             (rst),
    .o_mat_valid     (o_mat_valid),
    .i_mat_ready     (i_mat_ready),
    .o_mat           (o_mat),
    .o_vec_valid     (o_vec_valid),
    .i_vec_ready     (i_vec_ready),
    .o_vec           (o_vec)
  );

  scoreboard #(
    .DATA_W(DATA_W)
  ) result_checker (
    .clk             (clk),
    .rst             (rst),
    .o_mat_valid     (o_mat_valid),
    .i_mat_ready     (i_mat_ready),
    .o_mat           (o_mat),
    .o_vec_valid     (o_vec_valid),
    .i_vec_ready     (i_vec_ready),
    .o_vec           (o_vec)
  );

  tests #(
    .DATA_W(DATA_W),
    .FRAC_W(FRAC_W)
  ) test_cases (
    .clk             (clk)
  );

  initial begin
    // TODO: Add vcd dump for waveform viewing
    #1000000;
    $fatal(1, "Simulation timeout");
  end
endmodule
