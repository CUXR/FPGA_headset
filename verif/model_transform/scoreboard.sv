`timescale 1ns/1ps

module scoreboard #(parameter integer DATA_W = 18) (
  input logic clk,
  input logic rst,
  input logic o_valid,
  input logic i_ready,
  input logic signed [DATA_W-1:0] o_vector_data
);
  integer expected [0:1023];
  integer expected_count = 0;
  integer actual_count = 0;

  task expect_vector(input integer x, y, z, w);
    begin
      if (expected_count + 4 > 1024) $fatal(1, "Scoreboard capacity exceeded");

      expected[expected_count] = x;
      expected[expected_count + 1] = y;
      expected[expected_count + 2] = z;
      expected[expected_count + 3] = w;
      expected_count = expected_count + 4;
    end
  endtask

  always @(posedge clk) begin
    if (!rst && o_valid === 1'b1 && i_ready === 1'b1) begin
      if (actual_count >= expected_count)
        $fatal(1, "Unexpected extra output %0d", $signed(o_vector_data));

      if ($signed(o_vector_data) !== expected[actual_count])
        $fatal(1, "Output %0d: expected %0d, received %0d",
               actual_count, expected[actual_count], $signed(o_vector_data));

      actual_count = actual_count + 1;
    end
  end

  task wait_complete;
    begin
      while (actual_count < expected_count) @(negedge clk);
    end
  endtask

  task report;
    begin
      if (actual_count != expected_count) $fatal(1, "Missing outputs");
      $display("PASS: %0d outputs checked", actual_count);
    end
  endtask
endmodule
