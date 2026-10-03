`timescale 1ns/1ps

module driver #(parameter integer DATA_W = 18) (
  input logic clk,
  input logic o_ready,
  output logic rst = 1,
  output logic i_valid = 0,
  output logic signed [DATA_W-1:0] i_matrix_data = 0,
  output logic signed [DATA_W-1:0] i_vector_data = 0,
  output logic i_ready = 0
);
  integer matrix [0:15];
  integer vector [0:3];
  integer input_gap = 0;
  integer ready_period = 1;
  integer ready_cycle = 0;
  logic hold_output = 0;

  always @(negedge clk) begin
    if (rst || hold_output)
      i_ready = 0;
    else
      i_ready = (ready_cycle % ready_period == 0);

    ready_cycle = ready_cycle + 1;
  end

  task reset_dut;
    begin
      @(negedge clk);
      rst = 1;
      i_valid = 0;

      repeat (3) @(negedge clk);
      rst = 0;
    end
  endtask

  task send_operation(input integer transfers);
    integer index;

    begin
      for (index = 0; index < transfers; index = index + 1) begin
        @(negedge clk);
        if (input_gap > 0) begin
          i_valid = 0;
          repeat (input_gap) @(negedge clk);
        end

        i_valid = 1;

        i_matrix_data = matrix[index];
        i_vector_data = 0;
        if (index < 4) i_vector_data = vector[index];

        @(posedge clk);
        while (o_ready !== 1'b1) @(posedge clk);
      end

      @(negedge clk);
      i_valid = 0;
    end
  endtask
endmodule
