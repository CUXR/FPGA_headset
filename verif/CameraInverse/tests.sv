`timescale 1ns/1ps

// Hierarchical task calls keep this module plain and avoid virtual interfaces.
module tests #(
  parameter integer DATA_W = 18,
  parameter integer FRAC_W = 0
) (
  input logic clk,
  input logic o_inverse_valid
);
  localparam integer ONE = 1 << FRAC_W;
  string name;
  integer index, operation_id;

  task identity_inputs;
    begin
      for (index = 0; index < 16; index = index + 1)
        tb_CameraInverse.input_driver.matrix[index] = (index / 4 == index % 4) ? ONE : 0;
    end
  endtask

  task check_identity;
    begin
      tb_CameraInverse.result_checker.expect_matrix(
        ONE, 0,   0,   0,
        0,   ONE, 0,   0,
        0,   0,   ONE, 0,
        0,   0,   0,   ONE);
      tb_CameraInverse.input_driver.send_operation();
      tb_CameraInverse.result_checker.wait_complete();
    end
  endtask

  task test_identity;
    begin
      identity_inputs();
      check_identity();
    end
  endtask

  task test_translation;
    begin
      identity_inputs();
      tb_CameraInverse.input_driver.matrix[3] = 3 * ONE;
      tb_CameraInverse.input_driver.matrix[7] = -2 * ONE;
      tb_CameraInverse.input_driver.matrix[11] = 7 * ONE;

      tb_CameraInverse.result_checker.expect_matrix(
        ONE, 0,   0,   -3 * ONE,
        0,   ONE, 0,    2 * ONE,
        0,   0,   ONE, -7 * ONE,
        0,   0,   0,    ONE);
      tb_CameraInverse.input_driver.send_operation();
      tb_CameraInverse.result_checker.wait_complete();
    end
  endtask

  task test_rotations;
    begin
      // +90 degrees around Z, with translation (3, -2, 7).
      identity_inputs();
      tb_CameraInverse.input_driver.matrix[0] = 0;
      tb_CameraInverse.input_driver.matrix[1] = -ONE;
      tb_CameraInverse.input_driver.matrix[4] = ONE;
      tb_CameraInverse.input_driver.matrix[5] = 0;
      tb_CameraInverse.input_driver.matrix[3] = 3 * ONE;
      tb_CameraInverse.input_driver.matrix[7] = -2 * ONE;
      tb_CameraInverse.input_driver.matrix[11] = 7 * ONE;

      tb_CameraInverse.result_checker.expect_matrix(
        0,    ONE, 0,    2 * ONE,
        -ONE, 0,   0,    3 * ONE,
        0,    0,   ONE, -7 * ONE,
        0,    0,   0,    ONE);
      tb_CameraInverse.input_driver.send_operation();
      tb_CameraInverse.result_checker.wait_complete();
    end
  endtask

  task test_reset(input logic wait_output);
    begin
      identity_inputs();
      tb_CameraInverse.input_driver.hold_output = 1;
      tb_CameraInverse.input_driver.send_operation();

      if (wait_output) begin
        wait (o_inverse_valid === 1'b1);
        repeat (3) @(negedge clk);
      end

      tb_CameraInverse.input_driver.reset_dut();
      tb_CameraInverse.input_driver.hold_output = 0;
      check_identity();
    end
  endtask

  initial begin
    if (!$value$plusargs("TEST=%s", name)) $fatal(1, "Missing TEST");
    if (DATA_W < 8 || DATA_W > 30 || FRAC_W < 0 || FRAC_W > DATA_W - 4)
      $fatal(1, "These tests support DATA_W 8 through 30 and FRAC_W 0 through DATA_W-4");

    tb_CameraInverse.input_driver.reset_dut();

    if (name == "identity") test_identity();
    else if (name == "translation") test_translation();
    else if (name == "rotations") test_rotations();
    else if (name == "multiple") begin
      for (operation_id = 0; operation_id < 12; operation_id = operation_id + 1)
        test_identity();
    end else if (name == "input_stalls") begin
      tb_CameraInverse.input_driver.input_gap = 3;
      test_identity();
    end else if (name == "output_backpressure") begin
      tb_CameraInverse.input_driver.ready_period = 5;
      test_identity();
    end else if (name == "reset_processing") test_reset(0);
    else if (name == "reset_output") test_reset(1);
    else $fatal(1, "Unknown test %s", name);

    repeat (20) @(negedge clk);
    tb_CameraInverse.result_checker.report();
    $display("Test: %s", name);
    $finish;
  end
endmodule
