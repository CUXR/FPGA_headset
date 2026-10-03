`timescale 1ns/1ps

// Hierarchical task calls keep this module plain and avoid virtual interfaces.
module tests #(parameter integer DATA_W = 18) (
  input logic clk,
  input logic o_valid
);
  string name;
  integer seed, random_state, unused;
  integer index, operation_id;

  task identity_inputs;
    begin
      for (index = 0; index < 16; index = index + 1)
        tb_model_transform.input_driver.matrix[index] = (index / 4 == index % 4);

      tb_model_transform.input_driver.vector[0] = 3;
      tb_model_transform.input_driver.vector[1] = -2;
      tb_model_transform.input_driver.vector[2] = 7;
      tb_model_transform.input_driver.vector[3] = 1;
    end
  endtask

  task check_identity;
    begin
      tb_model_transform.result_checker.expect_vector(3, -2, 7, 1);
      tb_model_transform.input_driver.send_operation(16);
      tb_model_transform.result_checker.wait_complete();
    end
  endtask

  task test_identity;
    begin
      identity_inputs();
      check_identity();
    end
  endtask

  task test_zero;
    begin
      identity_inputs();
      for (index = 0; index < 16; index = index + 1)
        tb_model_transform.input_driver.matrix[index] = 0;

      tb_model_transform.result_checker.expect_vector(0, 0, 0, 0);
      tb_model_transform.input_driver.send_operation(16);
      tb_model_transform.result_checker.wait_complete();
    end
  endtask

  task test_signed;
    begin
      identity_inputs();
      for (index = 0; index < 16; index = index + 1)
        tb_model_transform.input_driver.matrix[index] = index - 8;

      tb_model_transform.result_checker.expect_vector(-57, -21, 15, 51);
      tb_model_transform.input_driver.send_operation(16);
      tb_model_transform.result_checker.wait_complete();
    end
  endtask

  task test_overflow;
    begin
      // Four products of the largest positive value wrap to four.
      for (index = 0; index < 16; index = index + 1)
        tb_model_transform.input_driver.matrix[index] = (1 << (DATA_W - 1)) - 1;

      for (index = 0; index < 4; index = index + 1)
        tb_model_transform.input_driver.vector[index] = (1 << (DATA_W - 1)) - 1;

      tb_model_transform.result_checker.expect_vector(4, 4, 4, 4);
      tb_model_transform.input_driver.send_operation(16);
      tb_model_transform.result_checker.wait_complete();

      for (index = 0; index < 16; index = index + 1)
        tb_model_transform.input_driver.matrix[index] = -(1 << (DATA_W - 1));

      for (index = 0; index < 4; index = index + 1)
        tb_model_transform.input_driver.vector[index] = -(1 << (DATA_W - 1));

      tb_model_transform.result_checker.expect_vector(0, 0, 0, 0);
      tb_model_transform.input_driver.send_operation(16);
      tb_model_transform.result_checker.wait_complete();
    end
  endtask

  task test_reset(input integer transfers);
    begin
      identity_inputs();
      tb_model_transform.input_driver.hold_output = 1;
      tb_model_transform.input_driver.send_operation(transfers);

      if (transfers == 16) begin
        wait (o_valid === 1'b1);
        repeat (3) @(negedge clk);
      end

      tb_model_transform.input_driver.reset_dut();
      tb_model_transform.input_driver.hold_output = 0;
      check_identity();
    end
  endtask

  task expect_transform;
    integer row, column;
    longint signed total, matrix_value, vector_value;
    logic signed [DATA_W-1:0] expected [0:3];

    begin
      // A direct dot product is independent of the DUT's pipeline.
      // Widen operands before multiplication to avoid 32-bit overflow.
      for (row = 0; row < 4; row = row + 1) begin
        total = 0;
        for (column = 0; column < 4; column = column + 1) begin
          matrix_value = tb_model_transform.input_driver.matrix[row * 4 + column];
          vector_value = tb_model_transform.input_driver.vector[column];
          total = total + matrix_value * vector_value;
        end

        // Assignment keeps the low DATA_W bits and interprets them as signed.
        expected[row] = total;
      end

      tb_model_transform.result_checker.expect_vector(
        expected[0], expected[1], expected[2], expected[3]);
    end
  endtask

  task test_random;
    logic signed [DATA_W-1:0] value;

    begin
      for (operation_id = 0; operation_id < 40; operation_id = operation_id + 1) begin
        for (index = 0; index < 16; index = index + 1) begin
          value = $urandom;
          tb_model_transform.input_driver.matrix[index] = value;
        end

        for (index = 0; index < 4; index = index + 1) begin
          value = $urandom;
          tb_model_transform.input_driver.vector[index] = value;
        end

        tb_model_transform.input_driver.input_gap = $urandom_range(0, 3);
        tb_model_transform.input_driver.ready_period = $urandom_range(1, 5);

        expect_transform();
        tb_model_transform.input_driver.send_operation(16);
        tb_model_transform.result_checker.wait_complete();
      end
    end
  endtask

  initial begin
    if (!$value$plusargs("TEST=%s", name)) $fatal(1, "Missing TEST");
    if (!$value$plusargs("SEED=%d", seed)) seed = 1;

    random_state = seed;
    unused = $urandom(random_state);
    if (DATA_W < 8 || DATA_W > 30) $fatal(1, "These tests support DATA_W 8 through 30");

    tb_model_transform.input_driver.reset_dut();

    if (name == "identity") test_identity();
    else if (name == "zero") test_zero();
    else if (name == "signed") test_signed();
    else if (name == "overflow") test_overflow();
    else if (name == "multiple") begin
      for (operation_id = 0; operation_id < 12; operation_id = operation_id + 1)
        test_identity();
    end else if (name == "input_stalls") begin
      tb_model_transform.input_driver.input_gap = 3;
      test_identity();
    end else if (name == "output_backpressure") begin
      tb_model_transform.input_driver.ready_period = 5;
      test_identity();
    end else if (name == "random_stalls") test_random();
    else if (name == "reset_input") test_reset(7);
    else if (name == "reset_output") test_reset(16);
    else $fatal(1, "Unknown test %s", name);

    repeat (20) @(negedge clk);
    tb_model_transform.result_checker.report();
    $display("Test: %s, seed: %0d", name, seed);
    $finish;
  end
endmodule
