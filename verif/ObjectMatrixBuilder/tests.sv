`timescale 1ns/1ps

// Hierarchical task calls follow the MatVecEngine verification structure.
module tests #(
  parameter integer DATA_W = 18,
  parameter integer FRAC_W = 10,
  parameter integer OBJECT_ID_W = 4
) (
  input logic clk
);
  localparam integer ONE = 1 << FRAC_W;
  string name;

  task test_basic;
    begin
      // short_box:
      // translation = (-0.75, -1.45, 6.2)
      // rotation XYZ = (0, 0.28, 0) radians
      // scale       = (1.2, 1.1, 1.15)
      // Constants below are rounded to the nearest Q10 integer.
      if (FRAC_W != 10 || DATA_W < 14 || OBJECT_ID_W < 3)
        $fatal(1, "test_basic requires FRAC_W=10, DATA_W>=14, OBJECT_ID_W>=3");

      tb_ObjectMatrixBuilder.input_driver.object_id = OBJECT_ID_W'(5);
      tb_ObjectMatrixBuilder.input_driver.translation[0] = -768;
      tb_ObjectMatrixBuilder.input_driver.translation[1] = -1485;
      tb_ObjectMatrixBuilder.input_driver.translation[2] = 6349;
      tb_ObjectMatrixBuilder.input_driver.scale[0] = 1229;
      tb_ObjectMatrixBuilder.input_driver.scale[1] = 1126;
      tb_ObjectMatrixBuilder.input_driver.scale[2] = 1178;
      tb_ObjectMatrixBuilder.input_driver.sin[0] = 0;
      tb_ObjectMatrixBuilder.input_driver.sin[1] = 283;
      tb_ObjectMatrixBuilder.input_driver.sin[2] = 0;
      tb_ObjectMatrixBuilder.input_driver.cos[0] = ONE;
      tb_ObjectMatrixBuilder.input_driver.cos[1] = 984;
      tb_ObjectMatrixBuilder.input_driver.cos[2] = ONE;

      // T * Rz * Ry * Rx * S, using the quantized inputs above.
      // Nontrivial entries are (984*1229)>>10, (283*1178)>>10,
      // (-283*1229)>>10, and (984*1178)>>10. Arithmetic shifts
      // truncate toward negative infinity, so the negative entry is -340.
      tb_ObjectMatrixBuilder.result_checker.expect_matrix(
        OBJECT_ID_W'(5),
        1180,    0,  325, -768,
           0, 1126,    0, -1485,
        -340,    0, 1131, 6349,
           0,    0,    0, ONE);

      tb_ObjectMatrixBuilder.input_driver.send_object();
      tb_ObjectMatrixBuilder.input_driver.finish_operation();
      tb_ObjectMatrixBuilder.result_checker.wait_complete();
    end
  endtask

  initial begin
    if (!$value$plusargs("TEST=%s", name)) $fatal(1, "Missing TEST");

    tb_ObjectMatrixBuilder.input_driver.reset_dut();
    if (name == "test_basic") test_basic();
    else $fatal(1, "Unknown test %s", name);

    repeat (20) @(negedge clk);
    tb_ObjectMatrixBuilder.result_checker.report();
    $display("Test: %s", name);
    $finish;
  end
endmodule
