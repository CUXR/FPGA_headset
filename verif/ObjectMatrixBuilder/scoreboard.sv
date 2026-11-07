`timescale 1ns/1ps

module scoreboard #(
  parameter integer DATA_W = 18,
  parameter integer OBJECT_ID_W = 4
) (
  input logic clk,
  input logic rst,
  input logic o_object_mat_valid,
  input logic i_object_mat_ready,
  input wire signed [DATA_W-1:0] o_object_mat[0:3][0:3],
  input logic [OBJECT_ID_W-1:0] o_object_id
);
  integer mat_expected [0:1023];
  logic [OBJECT_ID_W-1:0] object_id_expected [0:63];
  integer mat_expected_count = 0;
  integer mat_actual_count;
  integer index;

  initial begin
    mat_actual_count = 0;
  end

  // Write all 16 expected elements manually, in row-major order.
  task expect_matrix(
    input logic [OBJECT_ID_W-1:0] object_id,
    input integer m00, m01, m02, m03,
    input integer m10, m11, m12, m13,
    input integer m20, m21, m22, m23,
    input integer m30, m31, m32, m33
  );
    begin
      if (mat_expected_count + 16 > 1024) $fatal(1, "Scoreboard capacity exceeded");

      object_id_expected[mat_expected_count / 16] = object_id;

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

  always @(posedge clk) begin
    if (!rst && o_object_mat_valid === 1'b1 && i_object_mat_ready === 1'b1) begin
      if (mat_actual_count >= mat_expected_count)
        $fatal(1, "Unexpected extra output matrix");

      if (o_object_id !== object_id_expected[mat_actual_count / 16])
        $fatal(1, "Object ID: expected %0d, received %0d",
               object_id_expected[mat_actual_count / 16], o_object_id);

      for (index = 0; index < 16; index = index + 1) begin
        if (int'($signed(o_object_mat[index / 4][index % 4])) !== mat_expected[mat_actual_count + index])
          $fatal(1, "Output [%0d][%0d]: expected %0d, received %0d",
                 index / 4, index % 4, mat_expected[mat_actual_count + index],
                 $signed(o_object_mat[index / 4][index % 4]));
      end

      mat_actual_count <= mat_actual_count + 16;
    end
  end

  task wait_complete;
    begin
      while (mat_actual_count < mat_expected_count)
        @(negedge clk);
    end
  endtask

  task report;
    begin
      if (mat_actual_count != mat_expected_count)
        $fatal(1, "Missing outputs");
      $display("PASS: %0d output matrices checked", mat_actual_count / 16);
    end
  endtask
endmodule
