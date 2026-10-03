`timescale 1ns/1ps

module tb_model_transform;
  parameter integer DATA_W = 18;

  logic clk = 0;
  always #5 clk = ~clk;

  logic rst;
  logic i_valid;
  logic o_ready;
  logic signed [DATA_W-1:0] i_matrix_data;
  logic signed [DATA_W-1:0] i_vector_data;
  
  logic o_valid;
  logic i_ready;
  logic signed [DATA_W-1:0] o_vector_data;

  model_transform #(.DATA_W(DATA_W)) dut (
    .clk           (clk), 
    .rst           (rst),
    .i_valid       (i_valid), 
    .o_ready       (o_ready),
    .i_matrix_data (i_matrix_data), 
    .i_vector_data (i_vector_data),
    .o_valid       (o_valid), 
    .i_ready       (i_ready), 
    .o_vector_data (o_vector_data)
  );

  driver #(.DATA_W(DATA_W)) input_driver (
    .clk           (clk), 
    .rst           (rst),
    .i_valid       (i_valid), 
    .o_ready       (o_ready),
    .i_matrix_data (i_matrix_data), 
    .i_vector_data (i_vector_data),
    .i_ready       (i_ready)
  );

  monitor #(.DATA_W(DATA_W)) output_monitor (
    .clk           (clk), 
    .rst           (rst),
    .o_valid       (o_valid), 
    .i_ready       (i_ready), 
    .o_vector_data (o_vector_data)
  );

  scoreboard #(.DATA_W(DATA_W)) result_checker (
    .clk           (clk), 
    .rst           (rst),
    .o_valid       (o_valid), 
    .i_ready       (i_ready), 
    .o_vector_data (o_vector_data)
  );

  tests #(.DATA_W(DATA_W)) test_cases (
    .clk           (clk), 
    .o_valid       (o_valid)
  );

  initial begin
    // TODO: Add vcd dump for waveform viewing
    #1000000;
    $fatal(1, "Simulation timeout");
  end
endmodule
