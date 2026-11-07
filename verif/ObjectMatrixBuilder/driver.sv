`timescale 1ns/1ps

module driver #(
  parameter integer DATA_W = 18,
  parameter integer OBJECT_ID_W = 4
) (
  input  logic                     clk,
  output logic                     rst,

  input  logic                     o_object_ready,
  output logic                     i_object_valid,
  output logic [OBJECT_ID_W-1:0]   i_object_id,
  output logic signed [DATA_W-1:0] i_translation[0:2],
  output logic signed [DATA_W-1:0] i_scale[0:2],
  output logic signed [DATA_W-1:0] i_sin[0:2],
  output logic signed [DATA_W-1:0] i_cos[0:2],

  output logic                     i_object_mat_ready
);
  logic [OBJECT_ID_W-1:0] object_id;
  integer translation [0:2];
  integer scale [0:2];
  integer sin [0:2];
  integer cos [0:2];
  integer input_gap = 0;
  integer ready_period = 1;
  integer ready_cycle;
  logic   hold_output = 0;

  initial begin
    rst = 1;
    i_object_valid = 0;
    i_object_mat_ready = 0;
    ready_cycle = 0;
  end

  always @(negedge clk) begin
    if (rst || hold_output) begin
      i_object_mat_ready <= 0;
    end else begin
      i_object_mat_ready <= (ready_cycle % ready_period == 0);
    end

    ready_cycle <= ready_cycle + 1;
  end

  task reset_dut;
    begin
      @(negedge clk);
      rst = 1;
      i_object_valid = 0;

      repeat (3) @(negedge clk);
      rst = 0;
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
      for (index = 0; index < 3; index = index + 1) begin
        i_translation[index] = DATA_W'(translation[index]);
        i_scale[index]       = DATA_W'(scale[index]);
        i_sin[index]         = DATA_W'(sin[index]);
        i_cos[index]         = DATA_W'(cos[index]);
      end
      i_object_valid = 1;

      @(posedge clk);
      while (o_object_ready !== 1'b1) @(posedge clk);
    end
  endtask

  task finish_operation;
    begin
      @(negedge clk);
      i_object_valid = 0;
    end
  endtask
endmodule
