`timescale 1ns/1ps

// Expected clip-space vertices are written explicitly, independently of the DUT.
// Q10 P = [998 0 0 0; 0 1774 0 0; 0 0 1025 -103; 0 0 1024 0].
// Integral translations and quarter turns keep the transform arithmetic exact.
module tests #(
  parameter integer DATA_W = 18,
  parameter integer FRAC_W = 10,
  parameter integer OBJECT_ID_W = 4
) (
  input logic clk
);
  localparam integer ONE = 1 << FRAC_W;
  string name;
  integer cycles;
  integer accepted;
  integer consumed;
  integer camera_updates;
  integer object_updates;
  integer consecutive;
  integer last_accept_cycle;
  logic check_arbitration = 0;

  // Check external transactions, without depending on DUT state names.
  always @(posedge clk) begin
    if (tb_ViewVertexProcessor.rst) begin
      cycles = 0;
      accepted = 0;
      consumed = 0;
      camera_updates = 0;
      object_updates = 0;
      consecutive = 0;
      last_accept_cycle = -2;
    end else begin
      cycles = cycles + 1;
      if (tb_ViewVertexProcessor.o_result_valid && tb_ViewVertexProcessor.i_result_ready)
        consumed = consumed + 1;
      if (tb_ViewVertexProcessor.i_camera_valid && tb_ViewVertexProcessor.o_camera_ready) begin
        if (accepted != consumed) $fatal(1, "Camera accepted before vertices drained");
        if (tb_ViewVertexProcessor.i_object_valid && tb_ViewVertexProcessor.o_object_ready)
          $fatal(1, "Two updates accepted together");
        camera_updates = camera_updates + 1;
      end
      if (tb_ViewVertexProcessor.i_object_valid && tb_ViewVertexProcessor.o_object_ready) begin
        if (accepted != consumed) $fatal(1, "Object accepted before vertices drained");
        if (tb_ViewVertexProcessor.i_camera_valid)
          $fatal(1, "Object accepted ahead of pending camera");
        object_updates = object_updates + 1;
      end
      if (tb_ViewVertexProcessor.i_vertex_valid && tb_ViewVertexProcessor.o_vertex_ready) begin
        if (check_arbitration && (camera_updates != 2 || object_updates != 2))
          $fatal(1, "Vertex accepted before both updates");
        accepted = accepted + 1;
        if (last_accept_cycle == cycles - 1) consecutive = consecutive + 1;
        last_accept_cycle = cycles;
      end
    end
  end

  task camera(
    input integer tx, ty, tz,
    input integer sx, sy, sz,
    input integer cx, cy, cz
  );
    begin
      tb_ViewVertexProcessor.input_driver.camera_translation[0] = tx;
      tb_ViewVertexProcessor.input_driver.camera_translation[1] = ty;
      tb_ViewVertexProcessor.input_driver.camera_translation[2] = tz;
      tb_ViewVertexProcessor.input_driver.camera_sin[0] = sx;
      tb_ViewVertexProcessor.input_driver.camera_sin[1] = sy;
      tb_ViewVertexProcessor.input_driver.camera_sin[2] = sz;
      tb_ViewVertexProcessor.input_driver.camera_cos[0] = cx;
      tb_ViewVertexProcessor.input_driver.camera_cos[1] = cy;
      tb_ViewVertexProcessor.input_driver.camera_cos[2] = cz;
      tb_ViewVertexProcessor.input_driver.send_camera();
      tb_ViewVertexProcessor.input_driver.finish_camera();
      // The source may change its payload immediately after acceptance.
      for (integer i = 0; i < 3; i++) begin
        tb_ViewVertexProcessor.input_driver.i_camera_translation[i] = '0;
        tb_ViewVertexProcessor.input_driver.i_camera_sin[i] = '0;
        tb_ViewVertexProcessor.input_driver.i_camera_cos[i] = '0;
      end
    end
  endtask

  task object_matrix(
    input logic [OBJECT_ID_W-1:0] id,
    input integer m00, m01, m02, m03,
    input integer m10, m11, m12, m13,
    input integer m20, m21, m22, m23,
    input integer m30, m31, m32, m33
  );
    begin
      tb_ViewVertexProcessor.input_driver.object_id = OBJECT_ID_W'(id);
      tb_ViewVertexProcessor.input_driver.object_matrix[0] = m00;
      tb_ViewVertexProcessor.input_driver.object_matrix[1] = m01;
      tb_ViewVertexProcessor.input_driver.object_matrix[2] = m02;
      tb_ViewVertexProcessor.input_driver.object_matrix[3] = m03;
      tb_ViewVertexProcessor.input_driver.object_matrix[4] = m10;
      tb_ViewVertexProcessor.input_driver.object_matrix[5] = m11;
      tb_ViewVertexProcessor.input_driver.object_matrix[6] = m12;
      tb_ViewVertexProcessor.input_driver.object_matrix[7] = m13;
      tb_ViewVertexProcessor.input_driver.object_matrix[8] = m20;
      tb_ViewVertexProcessor.input_driver.object_matrix[9] = m21;
      tb_ViewVertexProcessor.input_driver.object_matrix[10] = m22;
      tb_ViewVertexProcessor.input_driver.object_matrix[11] = m23;
      tb_ViewVertexProcessor.input_driver.object_matrix[12] = m30;
      tb_ViewVertexProcessor.input_driver.object_matrix[13] = m31;
      tb_ViewVertexProcessor.input_driver.object_matrix[14] = m32;
      tb_ViewVertexProcessor.input_driver.object_matrix[15] = m33;
      tb_ViewVertexProcessor.input_driver.send_object();
      tb_ViewVertexProcessor.input_driver.finish_object();
      tb_ViewVertexProcessor.input_driver.i_object_id = '0;
      for (integer row = 0; row < 4; row++) begin
        for (integer col = 0; col < 4; col++) begin
          tb_ViewVertexProcessor.input_driver.i_object_matrix[row][col] = '0;
        end
      end
    end
  endtask

  task identity_object(input logic [OBJECT_ID_W-1:0] id);
    begin
      object_matrix(id,
        ONE, 0,   0,   0,
        0,   ONE, 0,   0,
        0,   0,   ONE, 0,
        0,   0,   0,   ONE);
    end
  endtask

  task setup_identity;
    begin
      camera(0, 0, 0, 0, 0, 0, ONE, ONE, ONE);
      identity_object(1);
    end
  endtask

  // Return at the acceptance edge; call finish_vertex after the final vertex.
  task vertex(input integer x, y, z, w);
    begin
      tb_ViewVertexProcessor.input_driver.vertex[0] = x;
      tb_ViewVertexProcessor.input_driver.vertex[1] = y;
      tb_ViewVertexProcessor.input_driver.vertex[2] = z;
      tb_ViewVertexProcessor.input_driver.vertex[3] = w;
      tb_ViewVertexProcessor.input_driver.send_vertex();
    end
  endtask

  task test_basic_projection;
    begin
      setup_identity();
      // P * [1, 2, 4, 1]. z_clip = 1025*4 - 103; w_clip = 4.
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, 998, 3548, 3997, 4096);
      vertex(ONE, 2*ONE, 4*ONE, ONE);
      // Negative coordinates and a fractional input; retain homogeneous w.
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, -998, -887, 1947, 2048);
      vertex(-ONE, -ONE/2, 2*ONE, ONE);
      tb_ViewVertexProcessor.input_driver.finish_vertex();
      tb_ViewVertexProcessor.result_checker.wait_complete();
    end
  endtask

  task test_camera_transform;
    begin
      // C = T(1,-2,3) * Rz(+90):
      // [0 -1 0 1; 1 0 0 -2; 0 0 1 3; 0 0 0 1].
      // C^-1 * [2,3,8,1] = [5,-1,5,1].
      camera(ONE, -2*ONE, 3*ONE, 0, 0, ONE, ONE, ONE, 0);
      identity_object(1);
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, 4990, -1774, 5022, 5120);
      vertex(2*ONE, 3*ONE, 8*ONE, ONE);
      tb_ViewVertexProcessor.input_driver.finish_vertex();
      tb_ViewVertexProcessor.result_checker.wait_complete();

      // C = Rx(+90) = [1 0 0 0; 0 0 -1 0; 0 1 0 0; 0 0 0 1].
      // C^-1 * [1,2,3,1] = [1,3,-2,1]. No clipping in this module.
      camera(0, 0, 0, ONE, 0, 0, 0, ONE, ONE);
      identity_object(2);
      tb_ViewVertexProcessor.result_checker.expect_vertex(2, 998, 5322, -2153, -2048);
      vertex(ONE, 2*ONE, 3*ONE, ONE);
      tb_ViewVertexProcessor.input_driver.finish_vertex();
      tb_ViewVertexProcessor.result_checker.wait_complete();

      // C = Ry(+90) = [0 0 1 0; 0 1 0 0; -1 0 0 0; 0 0 0 1].
      // C^-1 * [1,2,3,1] = [-3,2,1,1].
      camera(0, 0, 0, 0, ONE, 0, ONE, 0, ONE);
      identity_object(3);
      tb_ViewVertexProcessor.result_checker.expect_vertex(3, -2994, 3548, 922, 1024);
      vertex(ONE, 2*ONE, 3*ONE, ONE);
      tb_ViewVertexProcessor.input_driver.finish_vertex();
      tb_ViewVertexProcessor.result_checker.wait_complete();

      // C = T(1,-2,3) * Rz(+90) * Rx(+90):
      // [0 0 1 1; 1 0 0 -2; 0 1 0 3; 0 0 0 1].
      // C^-1 * [2,3,8,1] = [5,5,1,1]. Order matters here.
      camera(ONE, -2*ONE, 3*ONE, ONE, 0, ONE, 0, ONE, 0);
      identity_object(1);
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, 4990, 8870, 922, 1024);
      vertex(2*ONE, 3*ONE, 8*ONE, ONE);
      tb_ViewVertexProcessor.input_driver.finish_vertex();
      tb_ViewVertexProcessor.result_checker.wait_complete();
    end
  endtask

  task test_object_transform;
    begin
      camera(0, 0, 0, 0, 0, 0, ONE, ONE, ONE);
      // O = translation (1,-2,6), scale (2,3,1).
      object_matrix(2,
        2*ONE, 0,     0,   ONE,
        0,     3*ONE, 0,   -2*ONE,
        0,     0,     ONE, 6*ONE,
        0,     0,     0,   ONE);
      // O * [1,2,3,1] = [3,4,9,1].
      tb_ViewVertexProcessor.result_checker.expect_vertex(2, 2994, 7096, 9122, 9216);
      vertex(ONE, 2*ONE, 3*ONE, ONE);
      tb_ViewVertexProcessor.input_driver.finish_vertex();
      tb_ViewVertexProcessor.result_checker.wait_complete();

      // O = translation (-2,1,6) * Rz(+90).
      object_matrix(3,
        0,   -ONE, 0,   -2*ONE,
        ONE, 0,    0,   ONE,
        0,   0,    ONE, 6*ONE,
        0,   0,    0,   ONE);
      // O * [1,2,3,1] = [-4,2,9,1].
      tb_ViewVertexProcessor.result_checker.expect_vertex(3, -3992, 3548, 9122, 9216);
      vertex(ONE, 2*ONE, 3*ONE, ONE);
      tb_ViewVertexProcessor.input_driver.finish_vertex();
      tb_ViewVertexProcessor.result_checker.wait_complete();

      // Reflect x, scale y by 1/2, and translate z by 4.
      object_matrix(1,
        -ONE, 0,     0,   0,
        0,    ONE/2, 0,   0,
        0,    0,     ONE, 4*ONE,
        0,    0,     0,   ONE);
      // O * [1/2,-1,1,1] = [-1/2,-1/2,5,1].
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, -499, -887, 5022, 5120);
      vertex(ONE/2, -ONE, ONE, ONE);
      tb_ViewVertexProcessor.input_driver.finish_vertex();
      tb_ViewVertexProcessor.result_checker.wait_complete();
    end
  endtask

  task test_vertex_streaming;
    integer before_consecutive;
    begin
      setup_identity();
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, -2994, 0, 3997, 4096);
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, -1996, 1774, 5022, 5120);
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, -998, -1774, 6047, 6144);
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, 0, 3548, 7072, 7168);
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, 998, -3548, 8097, 8192);
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, 1996, 0, 9122, 9216);
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, 2994, 1774, 10147, 10240);
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, 3992, -1774, 11172, 11264);
      before_consecutive = consecutive;
      vertex(-3*ONE, 0, 4*ONE, ONE);
      vertex(-2*ONE, ONE, 5*ONE, ONE);
      vertex(-ONE, -ONE, 6*ONE, ONE);
      vertex(0, 2*ONE, 7*ONE, ONE);
      vertex(ONE, -2*ONE, 8*ONE, ONE);
      vertex(2*ONE, 0, 9*ONE, ONE);
      vertex(3*ONE, ONE, 10*ONE, ONE);
      vertex(4*ONE, -ONE, 11*ONE, ONE);
      tb_ViewVertexProcessor.input_driver.finish_vertex();
      tb_ViewVertexProcessor.result_checker.wait_complete();
      if (consecutive - before_consecutive != 7)
        $fatal(1, "Vertices were not accepted on eight consecutive cycles");
      if (accepted != 8 || consumed != 8) $fatal(1, "Streaming transaction count mismatch");
    end
  endtask

  task test_backpressure;
    begin
      setup_identity();
      tb_ViewVertexProcessor.input_driver.hold_output = 1;
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, 998, 0, 3997, 4096);
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, 1996, 0, 3997, 4096);
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, 2994, 0, 3997, 4096);
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, 3992, 0, 3997, 4096);
      vertex(ONE, 0, 4*ONE, ONE);
      vertex(2*ONE, 0, 4*ONE, ONE);
      vertex(3*ONE, 0, 4*ONE, ONE);
      fork
        begin
          vertex(4*ONE, 0, 4*ONE, ONE);
          tb_ViewVertexProcessor.input_driver.finish_vertex();
        end
        begin
          wait (tb_ViewVertexProcessor.o_result_valid === 1'b1);
          repeat (8) @(negedge clk);
          if (accepted != 3 || consumed != 0 || tb_ViewVertexProcessor.o_vertex_ready !== 1'b0)
            $fatal(1, "Backpressure did not fill and stall the pipeline");
          tb_ViewVertexProcessor.input_driver.ready_period = 4;
          tb_ViewVertexProcessor.input_driver.hold_output = 0;
        end
      join
      tb_ViewVertexProcessor.result_checker.wait_complete();
      tb_ViewVertexProcessor.input_driver.ready_period = 1;
    end
  endtask

  task test_draining;
    begin
      setup_identity();
      tb_ViewVertexProcessor.input_driver.hold_output = 1;
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, 998, 0, 3997, 4096);
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, 1996, 0, 3997, 4096);
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, 2994, 0, 3997, 4096);
      tb_ViewVertexProcessor.result_checker.expect_vertex(1, 3992, 0, 3997, 4096);
      vertex(ONE, 0, 4*ONE, ONE);
      vertex(2*ONE, 0, 4*ONE, ONE);
      vertex(3*ONE, 0, 4*ONE, ONE);
      fork
        begin
          vertex(4*ONE, 0, 4*ONE, ONE);
          tb_ViewVertexProcessor.input_driver.finish_vertex();
        end
        begin
          // Wait until the fourth vertex is presented to a full pipeline.
          @(posedge clk);
          while (!(tb_ViewVertexProcessor.i_vertex_valid && !tb_ViewVertexProcessor.o_vertex_ready)) @(posedge clk);
          // New O translates x by +1. The four old vertices must retain ID 1.
          object_matrix(2,
            ONE, 0,   0,   ONE,
            0,   ONE, 0,   0,
            0,   0,   ONE, 0,
            0,   0,   0,   ONE);
        end
        begin
          wait (tb_ViewVertexProcessor.i_object_valid === 1'b1);
          repeat (8) begin
            @(negedge clk);
            if (tb_ViewVertexProcessor.o_object_ready !== 1'b0 || consumed != 0)
              $fatal(1, "Object update bypassed stalled vertices");
          end
          tb_ViewVertexProcessor.input_driver.hold_output = 0;
        end
      join
      tb_ViewVertexProcessor.result_checker.expect_vertex(2, 1996, 0, 3997, 4096);
      vertex(ONE, 0, 4*ONE, ONE);
      tb_ViewVertexProcessor.input_driver.finish_vertex();
      tb_ViewVertexProcessor.result_checker.wait_complete();

      // Also drain for a camera change, with the old object's ID still live.
      tb_ViewVertexProcessor.input_driver.hold_output = 1;
      tb_ViewVertexProcessor.result_checker.expect_vertex(2, 2994, 0, 3997, 4096);
      vertex(2*ONE, 0, 4*ONE, ONE);
      tb_ViewVertexProcessor.input_driver.finish_vertex();
      fork
        camera(ONE, 0, 0, 0, 0, 0, ONE, ONE, ONE);
        begin
          wait (tb_ViewVertexProcessor.i_camera_valid === 1'b1);
          repeat (6) begin
            @(negedge clk);
            if (tb_ViewVertexProcessor.o_camera_ready !== 1'b0)
              $fatal(1, "Camera update bypassed stalled vertex");
          end
          tb_ViewVertexProcessor.input_driver.hold_output = 0;
        end
      join
      identity_object(3);
      tb_ViewVertexProcessor.result_checker.expect_vertex(3, 998, 0, 3997, 4096);
      vertex(2*ONE, 0, 4*ONE, ONE);
      tb_ViewVertexProcessor.input_driver.finish_vertex();
      tb_ViewVertexProcessor.result_checker.wait_complete();
    end
  endtask

  task test_arbitration;
    begin
      setup_identity();
      check_arbitration = 1;
      tb_ViewVertexProcessor.result_checker.expect_vertex(2, 2994, 1774, 3997, 4096);
      fork
        camera(ONE, 0, 0, 0, 0, 0, ONE, ONE, ONE);
        // O scales x by 2. The NEW camera subtracts 1 from world x.
        object_matrix(2,
          2*ONE, 0,   0,   0,
          0,     ONE, 0,   0,
          0,     0,   ONE, 0,
          0,     0,   0,   ONE);
        begin
          vertex(2*ONE, ONE, 4*ONE, ONE);
          tb_ViewVertexProcessor.input_driver.finish_vertex();
        end
      join
      tb_ViewVertexProcessor.result_checker.wait_complete();
      check_arbitration = 0;
      if (camera_updates != 2 || object_updates != 2)
        $fatal(1, "Updates were duplicated or lost");
    end
  endtask

  initial begin
    if (!$value$plusargs("TEST=%s", name)) $fatal(1, "Missing TEST");
    if (FRAC_W != 10 || DATA_W < 18 || DATA_W > 30 || OBJECT_ID_W < 2)
      $fatal(1, "Manual values require FRAC_W=10, DATA_W=18..30, OBJECT_ID_W>=2");
    tb_ViewVertexProcessor.input_driver.reset_dut();
    if (name == "basic_projection") test_basic_projection();
    else if (name == "camera_transform") test_camera_transform();
    else if (name == "object_transform") test_object_transform();
    else if (name == "vertex_streaming") test_vertex_streaming();
    else if (name == "backpressure") test_backpressure();
    else if (name == "draining") test_draining();
    else if (name == "arbitration") test_arbitration();
    else $fatal(1, "Unknown test %s", name);

    // Detect late, duplicate, or leaked matrix-column outputs.
    repeat (20) @(negedge clk);
    tb_ViewVertexProcessor.result_checker.report();
    $display("Test: %s", name);
    $finish;
  end
endmodule
