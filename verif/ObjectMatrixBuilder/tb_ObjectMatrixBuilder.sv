`timescale 1ns/1ps

module tb_ObjectMatrixBuilder;
  parameter integer DATA_W = 18;
  parameter integer FRAC_W = 10;
  parameter integer OBJECT_ID_W = 4;

  logic clk;
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  logic rst;

  logic i_object_valid;
  logic o_object_ready;
  wire [OBJECT_ID_W-1:0]   i_object_id;
  wire signed [DATA_W-1:0] i_translation[0:2];
  wire signed [DATA_W-1:0] i_scale[0:2];
  wire signed [DATA_W-1:0] i_sin[0:2];
  wire signed [DATA_W-1:0] i_cos[0:2];

  logic                    o_object_mat_valid;
  logic                    i_object_mat_ready;
  wire [OBJECT_ID_W-1:0]   o_object_id;
  wire signed [DATA_W-1:0] o_object_mat[0:3][0:3];

  ObjectMatrixBuilder #(
    .DATA_W(DATA_W),
    .FRAC_W(FRAC_W),
    .OBJECT_ID_W(OBJECT_ID_W)
  ) dut (
    .clk                  (clk),
    .rst                  (rst),
    .i_object_valid       (i_object_valid),
    .o_object_ready       (o_object_ready),
    .i_object_id          (i_object_id),
    .i_translation        (i_translation),
    .i_scale              (i_scale),
    .i_sin                (i_sin),
    .i_cos                (i_cos),
    .o_object_mat_valid   (o_object_mat_valid),
    .i_object_mat_ready   (i_object_mat_ready),
    .o_object_id          (o_object_id),
    .o_object_mat         (o_object_mat)
  );

  driver #(
    .DATA_W(DATA_W),
    .OBJECT_ID_W(OBJECT_ID_W)
  ) input_driver (
    .clk                  (clk),
    .rst                  (rst),
    .i_object_valid       (i_object_valid),
    .o_object_ready       (o_object_ready),
    .i_object_id          (i_object_id),
    .i_translation        (i_translation),
    .i_scale              (i_scale),
    .i_sin                (i_sin),
    .i_cos                (i_cos),
    .i_object_mat_ready   (i_object_mat_ready)
  );

  monitor #(
    .DATA_W(DATA_W),
    .OBJECT_ID_W(OBJECT_ID_W)
  ) output_monitor (
    .clk                  (clk),
    .rst                  (rst),
    .o_object_mat_valid   (o_object_mat_valid),
    .i_object_mat_ready   (i_object_mat_ready),
    .o_object_id          (o_object_id),
    .o_object_mat         (o_object_mat)
  );

  scoreboard #(
    .DATA_W(DATA_W),
    .OBJECT_ID_W(OBJECT_ID_W)
  ) result_checker (
    .clk                  (clk),
    .rst                  (rst),
    .o_object_mat_valid   (o_object_mat_valid),
    .i_object_mat_ready   (i_object_mat_ready),
    .o_object_id          (o_object_id),
    .o_object_mat         (o_object_mat)
  );

  tests #(
    .DATA_W(DATA_W),
    .FRAC_W(FRAC_W),
    .OBJECT_ID_W(OBJECT_ID_W)
  ) test_cases (
    .clk                  (clk)
  );

  string waves_file;

  initial begin
    if ($value$plusargs("WAVES=%s", waves_file)) begin
      $dumpfile(waves_file);
      $dumpvars(0, tb_ObjectMatrixBuilder);
    end
  end

  initial begin
    #1000000;
    $fatal(1, "Simulation timeout");
  end
endmodule
