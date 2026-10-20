`timescale 1ns/1ps

module scoreboard #(parameter integer DATA_W = 18) (
  input logic clk,
  input logic rst,
  input logic o_mat_out_valid,
  input logic i_mat_out_ready,
  input wire signed [DATA_W-1:0] o_mat_out[0:3][0:3],

  input logic o_vec_out_valid,
  input logic i_vec_out_ready,
  input wire signed [DATA_W-1:0] o_vec_out[0:3]
);
  integer mat_expected [0:1023];
  integer vec_expected [0:1023];
  integer mat_expected_count = 0;
  integer vec_expected_count = 0;
  integer mat_actual_count;
  integer vec_actual_count;
  integer index;

  initial begin
    mat_actual_count = 0;
    vec_actual_count = 0;
  end

  // Write all 16 expected elements manually, in row-major order.
  task expect_matrix(
    input integer m00, m01, m02, m03,
    input integer m10, m11, m12, m13,
    input integer m20, m21, m22, m23,
    input integer m30, m31, m32, m33
  );
    begin
      if (mat_expected_count + 16 > 1024) $fatal(1, "Scoreboard capacity exceeded");

      mat_expected[mat_expected_count]      = m00;
      mat_expected[mat_expected_count + 1]  = m01;
      mat_expected[mat_expected_count + 2]  = m02;
      mat_expected[mat_expected_count + 3]  = m03;
      mat_expected[mat_expected_count + 4]  = m10;
      mat_expected[mat_expected_count + 5]  = m11;
      mat_expected[mat_expected_count + 6]  = m12;
      mat_expected[mat_expected_count + 7]  = m13;
      mat_expected[mat_expected_count + 8]  = m20;
      mat_expected[mat_expected_count + 9]  = m21;
      mat_expected[mat_expected_count + 10] = m22;
      mat_expected[mat_expected_count + 11] = m23;
      mat_expected[mat_expected_count + 12] = m30;
      mat_expected[mat_expected_count + 13] = m31;
      mat_expected[mat_expected_count + 14] = m32;
      mat_expected[mat_expected_count + 15] = m33;
      mat_expected_count = mat_expected_count + 16;
    end
  endtask

  // Write the four expected vector components in row order.
  task expect_vector(
    input integer v0, 
    input integer v1, 
    input integer v2, 
    input integer v3
  );
    begin
      if (vec_expected_count + 4 > 1024) $fatal(1, "Scoreboard capacity exceeded");

      vec_expected[vec_expected_count]      = v0;
      vec_expected[vec_expected_count + 1]  = v1;
      vec_expected[vec_expected_count + 2]  = v2;
      vec_expected[vec_expected_count + 3]  = v3;
      vec_expected_count = vec_expected_count + 4;
    end
  endtask

  always @(posedge clk) begin
    if (!rst && o_mat_out_valid === 1'b1 && i_mat_out_ready === 1'b1) begin
      if (mat_actual_count >= mat_expected_count)
        $fatal(1, "Unexpected extra output matrix");

      for (index = 0; index < 16; index = index + 1) begin
        if (int'($signed(o_mat_out[index / 4][index % 4])) !== mat_expected[mat_actual_count + index])
          $fatal(1, "Output [%0d][%0d]: expected %0d, received %0d",
                 index / 4, index % 4, mat_expected[mat_actual_count + index],
                 $signed(o_mat_out[index / 4][index % 4]));
      end

      mat_actual_count <= mat_actual_count + 16;
    end

    if (!rst && o_vec_out_valid === 1'b1 && i_vec_out_ready === 1'b1) begin
      if (vec_actual_count >= vec_expected_count)
        $fatal(1, "Unexpected extra output vector");

      for (index = 0; index < 4; index = index + 1) begin
        if (int'($signed(o_vec_out[index])) !== vec_expected[vec_actual_count + index])
          $fatal(1, "Output [%0d]: expected %0d, received %0d",
                 index, vec_expected[vec_actual_count + index],
                 $signed(o_vec_out[index]));
      end

      vec_actual_count <= vec_actual_count + 4;
    end
  end

  task wait_complete;
    begin
      while (mat_actual_count < mat_expected_count || 
             vec_actual_count < vec_expected_count) 
        @(negedge clk);
    end
  endtask

  task report;
    begin
      if (mat_actual_count != mat_expected_count || 
          vec_actual_count != vec_expected_count) 
        $fatal(1, "Missing outputs");
      $display("PASS: %0d output matrices checked", mat_actual_count / 16);
      $display("PASS: %0d output vectors checked", vec_actual_count / 4);
    end
  endtask
endmodule
