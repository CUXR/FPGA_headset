`timescale 1ns/1ps

module tb_ViewVertexProcessor;
  parameter integer DATA_W = 18;
  parameter integer FRAC_W = 10;
  parameter integer OBJECT_ID_W = 4;

  logic clk;
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  logic rst;

  logic i_camera_valid;
  logic o_camera_ready;
  wire signed [DATA_W-1:0] i_camera_translation[0:2];
  wire signed [DATA_W-1:0] i_camera_sin[0:2];
  wire signed [DATA_W-1:0] i_camera_cos[0:2];

  logic i_object_valid;
  logic o_object_ready;
  wire [OBJECT_ID_W-1:0] i_object_id;
  wire signed [DATA_W-1:0] i_object_matrix[0:3][0:3];

  logic i_vertex_valid;
  logic o_vertex_ready;
  wire signed [DATA_W-1:0] i_vertex[0:3];

  logic o_result_valid;
  logic i_result_ready;
  wire [OBJECT_ID_W-1:0] o_result_object_id;
  wire signed [DATA_W-1:0] o_result_vertex[0:3];

  ViewVertexProcessor #(
    .DATA_W(DATA_W),
    .FRAC_W(FRAC_W),
    .OBJECT_ID_W(OBJECT_ID_W)
  ) dut (
    .clk                    (clk),
    .rst                    (rst),
    .i_camera_valid         (i_camera_valid),
    .o_camera_ready         (o_camera_ready),
    .i_camera_translation   (i_camera_translation),
    .i_camera_sin           (i_camera_sin),
    .i_camera_cos           (i_camera_cos),
    .i_object_valid         (i_object_valid),
    .o_object_ready         (o_object_ready),
    .i_object_id            (i_object_id),
    .i_object_matrix        (i_object_matrix),
    .i_vertex_valid         (i_vertex_valid),
    .o_vertex_ready         (o_vertex_ready),
    .i_vertex               (i_vertex),
    .o_result_valid         (o_result_valid),
    .i_result_ready         (i_result_ready),
    .o_result_object_id     (o_result_object_id),
    .o_result_vertex        (o_result_vertex)
  );

  driver #(
    .DATA_W(DATA_W),
    .OBJECT_ID_W(OBJECT_ID_W)
  ) input_driver (
    .clk                    (clk),
    .rst                    (rst),
    .i_camera_valid         (i_camera_valid),
    .o_camera_ready         (o_camera_ready),
    .i_camera_translation   (i_camera_translation),
    .i_camera_sin           (i_camera_sin),
    .i_camera_cos           (i_camera_cos),
    .i_object_valid         (i_object_valid),
    .o_object_ready         (o_object_ready),
    .i_object_id            (i_object_id),
    .i_object_matrix        (i_object_matrix),
    .i_vertex_valid         (i_vertex_valid),
    .o_vertex_ready         (o_vertex_ready),
    .i_vertex               (i_vertex),
    .i_result_ready         (i_result_ready)
  );

  monitor #(
    .DATA_W(DATA_W),
    .OBJECT_ID_W(OBJECT_ID_W)
  ) output_monitor (
    .clk                    (clk),
    .rst                    (rst),
    .o_result_valid         (o_result_valid),
    .i_result_ready         (i_result_ready),
    .o_result_object_id     (o_result_object_id),
    .o_result_vertex        (o_result_vertex)
  );

  scoreboard #(
    .DATA_W(DATA_W),
    .OBJECT_ID_W(OBJECT_ID_W)
  ) result_checker (
    .clk                    (clk),
    .rst                    (rst),
    .o_result_valid         (o_result_valid),
    .i_result_ready         (i_result_ready),
    .o_result_object_id     (o_result_object_id),
    .o_result_vertex        (o_result_vertex)
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
      $dumpvars(0, tb_ViewVertexProcessor);
    end
  end

  initial begin
    #1000000;
    $fatal(1, "Simulation timeout");
  end
endmodule
