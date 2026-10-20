`timescale 1ns/1ps

// Hierarchical task calls follow the CameraInverse verification structure.
module tests #(parameter integer DATA_W = 18) (
  input logic clk
);
  // Todo: Need to change to actual system
  localparam integer ONE = 1 << (DATA_W / 2);
  string name;

  task test_matrix_multiply;
    begin
      // A = [1 2 0 0; 
      //      0 1 1 0; 
      //      0 0 1 2; 
      //      0 0 0 1]
      tb_MatVecEngine.input_driver.matrix[0]  = ONE;
      tb_MatVecEngine.input_driver.matrix[1]  = 2 * ONE;
      tb_MatVecEngine.input_driver.matrix[2]  = 0;
      tb_MatVecEngine.input_driver.matrix[3]  = 0;
      tb_MatVecEngine.input_driver.matrix[4]  = 0;
      tb_MatVecEngine.input_driver.matrix[5]  = ONE;
      tb_MatVecEngine.input_driver.matrix[6]  = ONE;
      tb_MatVecEngine.input_driver.matrix[7]  = 0;
      tb_MatVecEngine.input_driver.matrix[8]  = 0;
      tb_MatVecEngine.input_driver.matrix[9]  = 0;
      tb_MatVecEngine.input_driver.matrix[10] = ONE;
      tb_MatVecEngine.input_driver.matrix[11] = 2 * ONE;
      tb_MatVecEngine.input_driver.matrix[12] = 0;
      tb_MatVecEngine.input_driver.matrix[13] = 0;
      tb_MatVecEngine.input_driver.matrix[14] = 0;
      tb_MatVecEngine.input_driver.matrix[15] = ONE;

      // B = [1  2  3  4; 
      //      5  6  7  8; 
      //      9  10 11 12; 
      //      13 14 15 16].
      tb_MatVecEngine.result_checker.expect_vector(11 * ONE, 14 * ONE, 35 * ONE, 13 * ONE);
      tb_MatVecEngine.result_checker.expect_vector(14 * ONE, 16 * ONE, 38 * ONE, 14 * ONE);
      tb_MatVecEngine.result_checker.expect_vector(17 * ONE, 18 * ONE, 41 * ONE, 15 * ONE);
      tb_MatVecEngine.result_checker.expect_vector(20 * ONE, 20 * ONE, 44 * ONE, 16 * ONE);
      tb_MatVecEngine.result_checker.expect_matrix(
        11 * ONE, 14 * ONE, 17 * ONE, 20 * ONE,
        14 * ONE, 16 * ONE, 18 * ONE, 20 * ONE,
        35 * ONE, 38 * ONE, 41 * ONE, 44 * ONE,
        13 * ONE, 14 * ONE, 15 * ONE, 16 * ONE);

      tb_MatVecEngine.input_driver.send_matrix();

      // Consecutive columns: every result is a vector output, and only
      // the fourth input marks the completed output matrix.
      tb_MatVecEngine.input_driver.vector[0] = ONE;
      tb_MatVecEngine.input_driver.vector[1] = 5 * ONE;
      tb_MatVecEngine.input_driver.vector[2] = 9 * ONE;
      tb_MatVecEngine.input_driver.vector[3] = 13 * ONE;
      tb_MatVecEngine.input_driver.send_vector(1, 1, 0);

      tb_MatVecEngine.input_driver.vector[0] = 2 * ONE;
      tb_MatVecEngine.input_driver.vector[1] = 6 * ONE;
      tb_MatVecEngine.input_driver.vector[2] = 10 * ONE;
      tb_MatVecEngine.input_driver.vector[3] = 14 * ONE;
      tb_MatVecEngine.input_driver.send_vector(1, 1, 0);

      tb_MatVecEngine.input_driver.vector[0] = 3 * ONE;
      tb_MatVecEngine.input_driver.vector[1] = 7 * ONE;
      tb_MatVecEngine.input_driver.vector[2] = 11 * ONE;
      tb_MatVecEngine.input_driver.vector[3] = 15 * ONE;
      tb_MatVecEngine.input_driver.send_vector(1, 1, 0);

      tb_MatVecEngine.input_driver.vector[0] = 4 * ONE;
      tb_MatVecEngine.input_driver.vector[1] = 8 * ONE;
      tb_MatVecEngine.input_driver.vector[2] = 12 * ONE;
      tb_MatVecEngine.input_driver.vector[3] = 16 * ONE;
      tb_MatVecEngine.input_driver.send_vector(1, 1, 1);
      tb_MatVecEngine.input_driver.finish_operation();
      tb_MatVecEngine.result_checker.wait_complete();
    end
  endtask

  initial begin
    if (!$value$plusargs("TEST=%s", name)) $fatal(1, "Missing TEST");
    // Keep all encoded inputs and expected results inside signed DATA_W.
    if (DATA_W < 13 || DATA_W > 30)
      $fatal(1, "This test supports DATA_W 13 through 30");

    tb_MatVecEngine.input_driver.reset_dut();
    if (name == "matrix_multiply") test_matrix_multiply();
    else $fatal(1, "Unknown test %s", name);

    // Catch repeated outputs after the expected operation has completed.
    repeat (20) @(negedge clk);
    tb_MatVecEngine.result_checker.report();
    $display("Test: %s", name);
    $finish;
  end
endmodule
