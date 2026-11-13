`timescale 1ns/1ps

module scoreboard #(
  parameter integer DATA_W = 18,
  parameter integer OBJECT_ID_W = 4
) (
  input logic clk,
  input logic rst,
  input logic o_result_valid,
  input logic i_result_ready,
  input wire signed [DATA_W-1:0] o_result_vertex[0:3],
  input logic [OBJECT_ID_W-1:0] o_result_object_id
);
  integer vec_expected[0:1023];
  logic [OBJECT_ID_W-1:0] object_id_expected[0:255];
  integer vec_expected_count = 0;
  integer vec_actual_count;
  integer index;

  initial begin
    vec_actual_count = 0;
  end

  // Queue the four expected components in x, y, z, w order.
  task expect_vertex(
    input logic [OBJECT_ID_W-1:0] object_id,
    input integer x, y, z, w
  );
    begin
      if (vec_expected_count + 4 > 1024)
        $fatal(1, "Scoreboard capacity exceeded");

      object_id_expected[vec_expected_count / 4] = object_id;
      vec_expected[vec_expected_count]     = x;
      vec_expected[vec_expected_count + 1] = y;
      vec_expected[vec_expected_count + 2] = z;
      vec_expected[vec_expected_count + 3] = w;
      vec_expected_count = vec_expected_count + 4;
    end
  endtask

  always @(posedge clk) begin
    if (!rst && o_result_valid === 1'b1 && i_result_ready === 1'b1) begin
      if (vec_actual_count >= vec_expected_count)
        $fatal(1, "Unexpected extra output vertex");

      if (o_result_object_id !== object_id_expected[vec_actual_count / 4])
        $fatal(1, "Object ID: expected %0d, received %0d",
               object_id_expected[vec_actual_count / 4], o_result_object_id);

      for (index = 0; index < 4; index = index + 1) begin
        if (int'($signed(o_result_vertex[index])) !== vec_expected[vec_actual_count + index])
          $fatal(1, "Output [%0d]: expected %0d, received %0d",
                 index, vec_expected[vec_actual_count + index],
                 $signed(o_result_vertex[index]));
      end

      vec_actual_count <= vec_actual_count + 4;
    end
  end

  task wait_complete;
    begin
      while (vec_actual_count < vec_expected_count)
        @(negedge clk);
    end
  endtask

  // Reset may cancel vertices which were accepted but have not produced results.
  task discard_pending;
    begin
      vec_expected_count = vec_actual_count;
    end
  endtask

  task report;
    begin
      if (vec_actual_count != vec_expected_count)
        $fatal(1, "Missing outputs");
      $display("PASS: %0d output vertices checked", vec_actual_count / 4);
    end
  endtask
endmodule
