`timescale 1ns/1ps

module tb_CameraInverse;
  parameter integer DATA_W = 18;
  parameter integer FRAC_W = 0;

  logic clk;
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  logic rst;
  logic i_matrix_valid;
  logic o_matrix_ready;
  wire signed [DATA_W-1:0] i_matrix[3:0][3:0];

  logic o_inverse_valid;
  logic i_inverse_ready;
  wire signed [DATA_W-1:0] o_inverse[3:0][3:0];

  CameraInverse #(.DATA_W(DATA_W), .FRAC_W(FRAC_W)) dut (
    .clk             (clk),
    .rst             (rst),
    .i_matrix_valid  (i_matrix_valid),
    .o_matrix_ready  (o_matrix_ready),
    .i_matrix        (i_matrix),
    .o_inverse_valid (o_inverse_valid),
    .i_inverse_ready (i_inverse_ready),
    .o_inverse       (o_inverse)
  );

  driver #(.DATA_W(DATA_W)) input_driver (
    .clk             (clk),
    .rst             (rst),
    .i_matrix_valid  (i_matrix_valid),
    .o_matrix_ready  (o_matrix_ready),
    .i_matrix        (i_matrix),
    .i_inverse_ready (i_inverse_ready)
  );

  monitor #(.DATA_W(DATA_W)) output_monitor (
    .clk             (clk),
    .rst             (rst),
    .o_inverse_valid (o_inverse_valid),
    .i_inverse_ready (i_inverse_ready),
    .o_inverse       (o_inverse)
  );

  scoreboard #(.DATA_W(DATA_W)) result_checker (
    .clk             (clk),
    .rst             (rst),
    .o_inverse_valid (o_inverse_valid),
    .i_inverse_ready (i_inverse_ready),
    .o_inverse       (o_inverse)
  );

  tests #(.DATA_W(DATA_W), .FRAC_W(FRAC_W)) test_cases (
    .clk             (clk),
    .o_inverse_valid (o_inverse_valid)
  );

  initial begin
    // TODO: Add vcd dump for waveform viewing
    #1000000;
    $fatal(1, "Simulation timeout");
  end
endmodule
