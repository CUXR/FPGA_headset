`timescale 1ns/1ps

module driver #(
  parameter integer DATA_W = 18,
  parameter integer OBJECT_ID_W = 4
) (
  input  logic clk,
  output logic rst,

  input  logic o_camera_ready,
  output logic i_camera_valid,
  output logic signed [DATA_W-1:0] i_camera_translation[0:2],
  output logic signed [DATA_W-1:0] i_camera_sin[0:2],
  output logic signed [DATA_W-1:0] i_camera_cos[0:2],

  input  logic o_object_ready,
  output logic i_object_valid,
  output logic [OBJECT_ID_W-1:0] i_object_id,
  output logic signed [DATA_W-1:0] i_object_matrix[0:3][0:3],

  input  logic o_vertex_ready,
  output logic i_vertex_valid,
  output logic signed [DATA_W-1:0] i_vertex[0:3],

  output logic i_result_ready
);
  integer camera_translation[0:2];
  integer camera_sin[0:2];
  integer camera_cos[0:2];
  logic [OBJECT_ID_W-1:0] object_id;
  integer object_matrix[0:15];
  integer vertex[0:3];
  integer input_gap = 0;
  integer ready_period = 1;
  integer ready_cycle;
  logic hold_output = 0;

  initial begin
    rst = 1;
    i_camera_valid = 0;
    i_object_valid = 0;
    i_vertex_valid = 0;
    i_result_ready = 0;
    ready_cycle = 0;
  end

  always @(negedge clk) begin
    if (rst || hold_output)
      i_result_ready <= 0;
    else
      i_result_ready <= (ready_cycle % ready_period == 0);

    ready_cycle <= ready_cycle + 1;
  end

  task reset_dut;
    begin
      @(negedge clk);
      rst = 1;
      i_camera_valid = 0;
      i_object_valid = 0;
      i_vertex_valid = 0;

      repeat (3) @(negedge clk);
      rst = 0;
    end
  endtask

  // Each send task drives only its own channel and returns on acceptance.
  // Finish that channel before waiting for a different channel to complete.
  // Successive send_vertex calls can issue vertices on consecutive cycles.
  task send_camera;
    integer index;
    begin
      @(negedge clk);
      i_camera_valid = 0;
      if (input_gap > 0)
        repeat (input_gap) @(negedge clk);

      for (index = 0; index < 3; index = index + 1) begin
        i_camera_translation[index] = DATA_W'(camera_translation[index]);
        i_camera_sin[index] = DATA_W'(camera_sin[index]);
        i_camera_cos[index] = DATA_W'(camera_cos[index]);
      end
      i_camera_valid = 1;

      @(posedge clk);
      while (o_camera_ready !== 1'b1) @(posedge clk);
    end
  endtask

  task finish_camera;
    begin
      @(negedge clk);
      i_camera_valid = 0;
    end
  endtask

  task send_object;
    integer index;
    begin
      @(negedge clk);
      i_object_valid = 0;
      if (input_gap > 0)
        repeat (input_gap) @(negedge clk);

      i_object_id = object_id;
      for (index = 0; index < 16; index = index + 1)
        i_object_matrix[index / 4][index % 4] = DATA_W'(object_matrix[index]);
      i_object_valid = 1;

      @(posedge clk);
      while (o_object_ready !== 1'b1) @(posedge clk);
    end
  endtask

  task finish_object;
    begin
      @(negedge clk);
      i_object_valid = 0;
    end
  endtask

  task send_vertex;
    integer index;
    begin
      @(negedge clk);
      i_vertex_valid = 0;
      if (input_gap > 0)
        repeat (input_gap) @(negedge clk);

      for (index = 0; index < 4; index = index + 1)
        i_vertex[index] = DATA_W'(vertex[index]);
      i_vertex_valid = 1;

      @(posedge clk);
      while (o_vertex_ready !== 1'b1) @(posedge clk);
    end
  endtask

  task finish_vertex;
    begin
      @(negedge clk);
      i_vertex_valid = 0;
    end
  endtask

  task finish_operation;
    begin
      @(negedge clk);
      i_camera_valid = 0;
      i_object_valid = 0;
      i_vertex_valid = 0;
    end
  endtask
endmodule
