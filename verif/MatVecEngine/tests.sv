`timescale 1ns/1ps

// Hierarchical task calls follow the CameraInverse verification structure.
module tests #(
  parameter integer DATA_W = 18,
  parameter integer FRAC_W = 10
) (
  input logic clk
);
  localparam integer ONE = 1 << FRAC_W;
  string name;

  task test_matrix_multiply(
    input integer input_gap = 0,
    input integer ready_period = 1
  );
    begin
      tb_MatVecEngine.input_driver.input_gap = input_gap;
      tb_MatVecEngine.input_driver.ready_period = ready_period;

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

      
      tb_MatVecEngine.input_driver.vector[0] = ONE;
      tb_MatVecEngine.input_driver.vector[1] = 5 * ONE;
      tb_MatVecEngine.input_driver.vector[2] = 9 * ONE;
      tb_MatVecEngine.input_driver.vector[3] = 13 * ONE;

      tb_MatVecEngine.input_driver.send_matrix_and_vector(1);

      tb_MatVecEngine.input_driver.vector[0] = 2 * ONE;
      tb_MatVecEngine.input_driver.vector[1] = 6 * ONE;
      tb_MatVecEngine.input_driver.vector[2] = 10 * ONE;
      tb_MatVecEngine.input_driver.vector[3] = 14 * ONE;
      tb_MatVecEngine.input_driver.send_vector(1);

      tb_MatVecEngine.input_driver.vector[0] = 3 * ONE;
      tb_MatVecEngine.input_driver.vector[1] = 7 * ONE;
      tb_MatVecEngine.input_driver.vector[2] = 11 * ONE;
      tb_MatVecEngine.input_driver.vector[3] = 15 * ONE;
      tb_MatVecEngine.input_driver.send_vector(1);

      tb_MatVecEngine.input_driver.vector[0] = 4 * ONE;
      tb_MatVecEngine.input_driver.vector[1] = 8 * ONE;
      tb_MatVecEngine.input_driver.vector[2] = 12 * ONE;
      tb_MatVecEngine.input_driver.vector[3] = 16 * ONE;
      tb_MatVecEngine.input_driver.send_vector(1);
      tb_MatVecEngine.input_driver.finish_operation();
      tb_MatVecEngine.result_checker.wait_complete();
    end
  endtask

  task test_vector_multiply(
    input integer input_gap = 0,
    input integer ready_period = 1
  );
    integer index;
    begin
      tb_MatVecEngine.input_driver.input_gap = input_gap;
      tb_MatVecEngine.input_driver.ready_period = ready_period;

      for (index = 0; index < 16; index = index + 1)
        tb_MatVecEngine.input_driver.matrix[index] = 0;
      for (index = 0; index < 4; index = index + 1)
        tb_MatVecEngine.input_driver.matrix[index * 4 + index] = ONE;
      tb_MatVecEngine.input_driver.matrix[1] = 2 * ONE;
      tb_MatVecEngine.input_driver.matrix[6] = ONE;
      tb_MatVecEngine.input_driver.matrix[11] = 2 * ONE;

      tb_MatVecEngine.input_driver.vector[0] = ONE;
      tb_MatVecEngine.input_driver.vector[1] = 5 * ONE;
      tb_MatVecEngine.input_driver.vector[2] = 9 * ONE;
      tb_MatVecEngine.input_driver.vector[3] = 13 * ONE;

      tb_MatVecEngine.result_checker.expect_vector(11 * ONE, 14 * ONE, 35 * ONE, 13 * ONE);

      tb_MatVecEngine.input_driver.send_matrix_and_vector(0);
      tb_MatVecEngine.input_driver.finish_operation();
      tb_MatVecEngine.result_checker.wait_complete();
    end
  endtask

  task test_multiple_matrix_multiply(
    input integer input_gap = 0,
    input integer ready_period = 1
  );
    integer operation;
    integer index;
    integer row;
    integer column;
    begin
      tb_MatVecEngine.input_driver.input_gap = input_gap;
      tb_MatVecEngine.input_driver.ready_period = ready_period;

      tb_MatVecEngine.result_checker.expect_vector(11 * ONE, 14 * ONE, 35 * ONE, 13 * ONE);
      tb_MatVecEngine.result_checker.expect_vector(14 * ONE, 16 * ONE, 38 * ONE, 14 * ONE);
      tb_MatVecEngine.result_checker.expect_vector(17 * ONE, 18 * ONE, 41 * ONE, 15 * ONE);
      tb_MatVecEngine.result_checker.expect_vector(20 * ONE, 20 * ONE, 44 * ONE, 16 * ONE);
      tb_MatVecEngine.result_checker.expect_matrix(
        11 * ONE, 14 * ONE, 17 * ONE, 20 * ONE,
        14 * ONE, 16 * ONE, 18 * ONE, 20 * ONE,
        35 * ONE, 38 * ONE, 41 * ONE, 44 * ONE,
        13 * ONE, 14 * ONE, 15 * ONE, 16 * ONE);

      tb_MatVecEngine.result_checker.expect_vector(-ONE, 10 * ONE, 9 * ONE, -26 * ONE);
      tb_MatVecEngine.result_checker.expect_vector(-2 * ONE, 12 * ONE, 10 * ONE, -28 * ONE);
      tb_MatVecEngine.result_checker.expect_vector(-3 * ONE, 14 * ONE, 11 * ONE, -30 * ONE);
      tb_MatVecEngine.result_checker.expect_vector(-4 * ONE, 16 * ONE, 12 * ONE, -32 * ONE);
      tb_MatVecEngine.result_checker.expect_matrix(
        -ONE, -2 * ONE, -3 * ONE, -4 * ONE,
        10 * ONE, 12 * ONE, 14 * ONE, 16 * ONE,
        9 * ONE, 10 * ONE, 11 * ONE, 12 * ONE,
        -26 * ONE, -28 * ONE, -30 * ONE, -32 * ONE);

      for (operation = 0; operation < 2; operation = operation + 1) begin
        for (index = 0; index < 16; index = index + 1)
          tb_MatVecEngine.input_driver.matrix[index] = 0;

        if (operation == 0) begin
          for (index = 0; index < 4; index = index + 1)
            tb_MatVecEngine.input_driver.matrix[index * 4 + index] = ONE;
          tb_MatVecEngine.input_driver.matrix[1] = 2 * ONE;
          tb_MatVecEngine.input_driver.matrix[6] = ONE;
          tb_MatVecEngine.input_driver.matrix[11] = 2 * ONE;
        end else begin
          tb_MatVecEngine.input_driver.matrix[0] = -ONE;
          tb_MatVecEngine.input_driver.matrix[5] = 2 * ONE;
          tb_MatVecEngine.input_driver.matrix[10] = ONE;
          tb_MatVecEngine.input_driver.matrix[15] = -2 * ONE;
        end

        for (column = 0; column < 4; column = column + 1) begin
          for (row = 0; row < 4; row = row + 1)
            tb_MatVecEngine.input_driver.vector[row] = (row * 4 + column + 1) * ONE;

          if (column == 0)
            tb_MatVecEngine.input_driver.send_matrix_and_vector(1);
          else
            tb_MatVecEngine.input_driver.send_vector(1);
        end
      end

      tb_MatVecEngine.input_driver.finish_operation();
      tb_MatVecEngine.result_checker.wait_complete();
    end
  endtask

  task test_multiple_vector_multiply(
    input integer input_gap = 0,
    input integer ready_period = 1
  );
    integer request;
    integer index;
    begin
      tb_MatVecEngine.input_driver.input_gap = input_gap;
      tb_MatVecEngine.input_driver.ready_period = ready_period;

      for (index = 0; index < 16; index = index + 1)
        tb_MatVecEngine.input_driver.matrix[index] = 0;
      for (index = 0; index < 4; index = index + 1)
        tb_MatVecEngine.input_driver.matrix[index * 4 + index] = ONE;
      tb_MatVecEngine.input_driver.matrix[1] = 2 * ONE;
      tb_MatVecEngine.input_driver.matrix[6] = ONE;
      tb_MatVecEngine.input_driver.matrix[11] = 2 * ONE;

      for (request = 0; request < 8; request = request + 1) begin
        for (index = 0; index < 4; index = index + 1)
          tb_MatVecEngine.input_driver.vector[index] = (request + index + 1) * ONE;

        if (request < 4) begin
          tb_MatVecEngine.result_checker.expect_vector(
            (3 * request + 5) * ONE, (2 * request + 5) * ONE,
            (3 * request + 11) * ONE, (request + 4) * ONE);
        end else begin
          tb_MatVecEngine.result_checker.expect_vector(
            -(request + 1) * ONE, 2 * (request + 2) * ONE,
            (request + 3) * ONE, -2 * (request + 4) * ONE);
        end

        if (request == 4) begin
          for (index = 0; index < 16; index = index + 1)
            tb_MatVecEngine.input_driver.matrix[index] = 0;
          tb_MatVecEngine.input_driver.matrix[0] = -ONE;
          tb_MatVecEngine.input_driver.matrix[5] = 2 * ONE;
          tb_MatVecEngine.input_driver.matrix[10] = ONE;
          tb_MatVecEngine.input_driver.matrix[15] = -2 * ONE;
        end

        if (request == 0 || request == 4)
          tb_MatVecEngine.input_driver.send_matrix_and_vector(0);
        else
          tb_MatVecEngine.input_driver.send_vector(0);
      end

      tb_MatVecEngine.input_driver.finish_operation();
      tb_MatVecEngine.result_checker.wait_complete();
    end
  endtask

  initial begin
    if (!$value$plusargs("TEST=%s", name)) $fatal(1, "Missing TEST");
    // Keep all encoded inputs and expected results inside signed DATA_W.
    if (DATA_W < 7 || DATA_W > 30 || FRAC_W < 0 || FRAC_W > DATA_W - 7)
      $fatal(1, "Test values require DATA_W 7 through 30 and at least 7 integer bits");

    tb_MatVecEngine.input_driver.reset_dut();
    if (name == "matrix_multiply") test_matrix_multiply();
    else if (name == "matrix_multiply_input_stalls") test_matrix_multiply(3, 1);
    else if (name == "matrix_multiply_output_backpressure") test_matrix_multiply(0, 8);
    else if (name == "matrix_multiply_both") test_matrix_multiply(3, 8);
    else if (name == "vector_multiply") test_vector_multiply();
    else if (name == "vector_multiply_input_stalls") test_vector_multiply(3, 1);
    else if (name == "vector_multiply_output_backpressure") test_vector_multiply(0, 8);
    else if (name == "vector_multiply_both") test_vector_multiply(3, 8);
    else if (name == "multiple_matrix_multiply") test_multiple_matrix_multiply();
    else if (name == "multiple_matrix_multiply_input_stalls") test_multiple_matrix_multiply(3, 1);
    else if (name == "multiple_matrix_multiply_output_backpressure") test_multiple_matrix_multiply(0, 8);
    else if (name == "multiple_matrix_multiply_both") test_multiple_matrix_multiply(3, 8);
    else if (name == "multiple_vector_multiply") test_multiple_vector_multiply();
    else if (name == "multiple_vector_multiply_input_stalls") test_multiple_vector_multiply(3, 1);
    else if (name == "multiple_vector_multiply_output_backpressure") test_multiple_vector_multiply(0, 8);
    else if (name == "multiple_vector_multiply_both") test_multiple_vector_multiply(3, 8);
    else $fatal(1, "Unknown test %s", name);

    // Catch repeated outputs after the expected operation has completed.
    repeat (20) @(negedge clk);
    tb_MatVecEngine.result_checker.report();
    $display("Test: %s", name);
    $finish;
  end
endmodule
