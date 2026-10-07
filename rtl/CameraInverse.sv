module CameraInverse #(
  parameter int DATA_W = 18,
  parameter int FRAC_W = 0
) (
  input  logic clk,
  input  logic rst,

  input  logic [DATA_W-1:0] i_matrix[3:0][3:0],
  input  logic              i_matrix_valid,
  output logic              o_matrix_ready,

  output logic [DATA_W-1:0] o_inverse[3:0][3:0],
  output logic              o_inverse_valid,
  input  logic              i_inverse_ready
);

  localparam int PROD_W = 2 * DATA_W;
  localparam int ACC_W  = PROD_W + 2;

  localparam logic STATE_IDLE    = 1'b0;
  localparam logic STATE_PROCESS = 1'b1;

  logic              state;
  logic              next_state;

  logic              in_accept;

  logic [DATA_W-1:0] matrix_stored[3:0][3:0];

  logic [1:0]        stage1_index;
  logic signed [PROD_W-1:0] stage1_prod[2:0];
  logic              stage1_valid;

  logic [1:0]        stage2_index;
  logic signed [ACC_W-1:0]  stage2_accum[2:0];
  logic              stage2_valid;

  logic [DATA_W-1:0] stage3_result[2:0];
  logic              stage3_valid;

  logic              out_accept;

  assign in_accept  = i_matrix_valid && o_matrix_ready;
  assign out_accept = o_inverse_valid && i_inverse_ready;

  // --------------------------------------------------------------------------
  // Input storing
  // --------------------------------------------------------------------------

  always_ff @(posedge clk) begin
    if (rst) begin
      // Nothing yet. no point in resetting the stored matrix, as it will be 
      // overwritten when the next matrix is loaded.
    end else if (state == STATE_IDLE && in_accept) begin
      for (int i = 0; i < 4; i++) begin
        for (int j = 0; j < 4; j++) begin
          matrix_stored[i][j] <= i_matrix[i][j];
        end
      end
    end
  end

  // --------------------------------------------------------------------------
  // Stage 1: Multiply matrix element by vector component
  // --------------------------------------------------------------------------

  always_ff @(posedge clk) begin
    if (rst) begin
      stage1_valid <= 1'b0;
      stage1_index <= 2'd0;
      stage2_index <= 2'd0;
    end else if (in_accept) begin
      stage1_index <= 2'd0;
      stage1_valid <= 1'b0;
    end else if (state == STATE_PROCESS) begin
      if (stage1_index < 2'd3) begin
        stage1_prod[0] <= $signed(matrix_stored[stage1_index][0])
                        * $signed(matrix_stored[stage1_index][3]);
        stage1_prod[1] <= $signed(matrix_stored[stage1_index][1])
                        * $signed(matrix_stored[stage1_index][3]);
        stage1_prod[2] <= $signed(matrix_stored[stage1_index][2])
                        * $signed(matrix_stored[stage1_index][3]);

        // Show that stage 1 is valid and pass the index onto the next stage
        stage1_valid <= 1'b1;
        stage2_index <= stage1_index;

        // Increment the index for the next cycle
        stage1_index <= stage1_index + 2'd1;
      end else begin
        stage1_valid <= 1'b0;
      end
    end else begin
      stage1_valid <= 1'b0;
    end
  end

  // --------------------------------------------------------------------------
  // Stage 2: Accumulate products
  // --------------------------------------------------------------------------

  always_ff @(posedge clk) begin
    if (rst) begin
      stage2_valid <= 1'b0;
    end else begin
      if (stage1_valid) begin
        // Only valid when the last index is reached, 
        if (stage2_index == 2'b10) begin
          stage2_valid <= 1'b1;
        end else begin
          stage2_valid <= 1'b0;
        end

        if (stage2_index == 2'b00) begin
          stage2_accum[0] <= {{(ACC_W-PROD_W){stage1_prod[0][PROD_W-1]}}, stage1_prod[0]};
          stage2_accum[1] <= {{(ACC_W-PROD_W){stage1_prod[1][PROD_W-1]}}, stage1_prod[1]};
          stage2_accum[2] <= {{(ACC_W-PROD_W){stage1_prod[2][PROD_W-1]}}, stage1_prod[2]};
        end else begin
          stage2_accum[0] <= stage2_accum[0] + $signed({{(ACC_W-PROD_W){stage1_prod[0][PROD_W-1]}}, stage1_prod[0]});
          stage2_accum[1] <= stage2_accum[1] + $signed({{(ACC_W-PROD_W){stage1_prod[1][PROD_W-1]}}, stage1_prod[1]});
          stage2_accum[2] <= stage2_accum[2] + $signed({{(ACC_W-PROD_W){stage1_prod[2][PROD_W-1]}}, stage1_prod[2]});
        end
      end else begin
        stage2_valid <= 1'b0;
      end
    end
  end

  // --------------------------------------------------------------------------
  // Stage 3: Negate the accumulated sums
  // --------------------------------------------------------------------------

  always_ff @(posedge clk) begin
    if (rst) begin
      stage3_valid <= 1'b0;
    end else begin
      if (stage2_valid) begin
        stage3_result[0] <= DATA_W'((-stage2_accum[0]) >>> FRAC_W);
        stage3_result[1] <= DATA_W'((-stage2_accum[1]) >>> FRAC_W);
        stage3_result[2] <= DATA_W'((-stage2_accum[2]) >>> FRAC_W);
        stage3_valid     <= 1'b1;
      end else begin
        stage3_valid <= 1'b0;
      end
    end
  end

  // --------------------------------------------------------------------------
  // Stage 4: Send the output
  // --------------------------------------------------------------------------

  always_ff @(posedge clk) begin
    if (rst) begin
      o_inverse_valid <= 1'b0;
    end else begin
      if (stage3_valid) begin
        // 3x3 block B
        o_inverse[0][0] <= matrix_stored[0][0];
        o_inverse[0][1] <= matrix_stored[1][0];
        o_inverse[0][2] <= matrix_stored[2][0];
        o_inverse[1][0] <= matrix_stored[0][1];
        o_inverse[1][1] <= matrix_stored[1][1];
        o_inverse[1][2] <= matrix_stored[2][1];
        o_inverse[2][0] <= matrix_stored[0][2];
        o_inverse[2][1] <= matrix_stored[1][2];
        o_inverse[2][2] <= matrix_stored[2][2];

        // 3x1 block T
        o_inverse[0][3] <= stage3_result[0];
        o_inverse[1][3] <= stage3_result[1];
        o_inverse[2][3] <= stage3_result[2];

        // 1x3 block 0
        o_inverse[3][0] <= '0;
        o_inverse[3][1] <= '0;
        o_inverse[3][2] <= '0;

        // 1x1 block 1
        o_inverse[3][3] <= matrix_stored[3][3];

        o_inverse_valid <= 1'b1;
      end else if (out_accept) begin
        o_inverse_valid <= 1'b0;
      end
    end
  end

  // --------------------------------------------------------------------------
  // FSM
  // --------------------------------------------------------------------------

  always_ff @(posedge clk) begin
    if (rst) begin
      state <= STATE_IDLE;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin
    next_state = state;
    o_matrix_ready = 1'b0;
    case (state)
      STATE_IDLE: begin
        if (in_accept) begin
          next_state = STATE_PROCESS;
        end

        o_matrix_ready = !rst;
      end
      STATE_PROCESS: begin
        if (out_accept) begin
          next_state = STATE_IDLE;
        end

        o_matrix_ready = 1'b0;
      end
      default: next_state = STATE_IDLE;
    endcase
  end

endmodule
