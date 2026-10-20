`timescale 1ns/1ps

module scoreboard #(parameter integer DATA_W = 18) (
  input logic clk,
  input logic rst,
  input logic o_inverse_valid,
  input logic i_inverse_ready,
  input wire signed [DATA_W-1:0] o_inverse[3:0][3:0]
);
  integer expected [0:1023];
  integer expected_count = 0;
  integer actual_count;
  integer index;

  initial begin
    actual_count = 0;  // To fix lint warning. Dunno why.
  end

  // Write all 16 expected elements manually, in row-major order.
  task expect_matrix(
    input integer m00, m01, m02, m03,
    input integer m10, m11, m12, m13,
    input integer m20, m21, m22, m23,
    input integer m30, m31, m32, m33
  );
    begin
      if (expected_count + 16 > 1024) $fatal(1, "Scoreboard capacity exceeded");

      expected[expected_count]      = m00;
      expected[expected_count + 1]  = m01;
      expected[expected_count + 2]  = m02;
      expected[expected_count + 3]  = m03;
      expected[expected_count + 4]  = m10;
      expected[expected_count + 5]  = m11;
      expected[expected_count + 6]  = m12;
      expected[expected_count + 7]  = m13;
      expected[expected_count + 8]  = m20;
      expected[expected_count + 9]  = m21;
      expected[expected_count + 10] = m22;
      expected[expected_count + 11] = m23;
      expected[expected_count + 12] = m30;
      expected[expected_count + 13] = m31;
      expected[expected_count + 14] = m32;
      expected[expected_count + 15] = m33;
      expected_count = expected_count + 16;
    end
  endtask

  always @(posedge clk) begin
    if (!rst && o_inverse_valid === 1'b1 && i_inverse_ready === 1'b1) begin
      if (actual_count >= expected_count)
        $fatal(1, "Unexpected extra output matrix");

      for (index = 0; index < 16; index = index + 1) begin
        if (int'($signed(o_inverse[index / 4][index % 4])) !== expected[actual_count + index])
          $fatal(1, "Output [%0d][%0d]: expected %0d, received %0d",
                 index / 4, index % 4, expected[actual_count + index],
                 $signed(o_inverse[index / 4][index % 4]));
      end

      actual_count <= actual_count + 16;
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
      $display("PASS: %0d output matrices checked", actual_count / 16);
    end
  endtask
endmodule
