module model_transform #(
  parameter int DATA_W = 18
) (
  input  logic clk,
  input  logic rst,

  input  logic                     i_valid,
  output logic                     o_ready,
  input  logic signed [DATA_W-1:0] i_matrix_data,
  input  logic signed [DATA_W-1:0] i_vector_data,

  output logic                     o_valid,
  input  logic                     i_ready,
  output logic signed [DATA_W-1:0] o_vector_data
);

  localparam int PROD_W = 2 * DATA_W;
  localparam int ACC_W  = PROD_W + 2;

  localparam logic [1:0] STATE_IDLE = 2'b00;
  localparam logic [1:0] STATE_LOAD_MATRIX = 2'b01;
  localparam logic [1:0] STATE_SEND_VECTOR = 2'b10;

  logic [1:0]               state;
  logic [1:0]               next_state;

  logic                     in_accept;
  logic                     vector_in_accept;

  logic [4:0]               matrix_id;
  logic [1:0]               output_id;

  logic signed [DATA_W-1:0] vertex [0:3];

  // Stage 1 signals
  logic signed [DATA_W-1:0] stage1_matrix_data;
  logic signed [DATA_W-1:0] stage1_vertex_data;
  logic [1:0]               stage1_row;
  logic [1:0]               stage1_col;
  logic                     stage1_valid;

  // Stage 2 signals
  logic signed [PROD_W-1:0] stage2_product;
  logic signed [ACC_W-1:0]  stage2_extended_product;
  logic [1:0]               stage2_row;
  logic [1:0]               stage2_col;
  logic                     stage2_valid;

  // Stage 3 signals
  logic signed [ACC_W-1:0]  stage3_accum;
  logic [1:0]               stage3_row;
  logic [1:0]               stage3_col;
  logic                     stage3_valid;

  logic signed [ACC_W-1:0]  result [0:3];
  logic                     out_accept;

  // -----------------------------------------------------------------------------
  // Input storing
  // -----------------------------------------------------------------------------
  assign in_accept = i_valid && o_ready;
  assign vector_in_accept = in_accept && (matrix_id < 5'd4);

  always_ff @(posedge clk) begin
    if (rst) begin
      matrix_id <= '0;
    end else if (out_accept && output_id == 2'd3) begin
      // Reset matrix id for next operation when sending vector
      matrix_id <= '0;
    end else if (in_accept) begin
      // Increment matrix id on every send
      matrix_id <= matrix_id + 5'd1;
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < 4; i++) begin
        vertex[i] <= '0;
      end
    end else if (vector_in_accept) begin
      // Store the vertex
      vertex[matrix_id[1:0]] <= i_vector_data;
    end
  end

  // -----------------------------------------------------------------------------
  // Stage 1: Save matrix and vector operands
  // -----------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rst) begin
      stage1_matrix_data <= '0;
      stage1_vertex_data <= '0;
      stage1_row         <= '0;
      stage1_col         <= '0;
      stage1_valid       <= 1'b0;
    end else if (in_accept) begin
      stage1_matrix_data <= i_matrix_data;
      stage1_row         <= matrix_id[3:2];
      stage1_col         <= matrix_id[1:0];

      if (matrix_id < 5'd4)
        // Vector is sending, so use that data
        stage1_vertex_data <= i_vector_data;
      else
        // Vector is not sending anymore, use stored data
        stage1_vertex_data <= vertex[matrix_id[1:0]];

      stage1_valid <= 1'b1;
    end else begin
      stage1_valid <= 1'b0;
    end
  end

  // -----------------------------------------------------------------------------
  // Stage 2: Multiply
  // -----------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rst) begin
      stage2_product <= '0;
      stage2_row     <= '0;
      stage2_col     <= '0;
      stage2_valid   <= 1'b0;
    end else begin
      stage2_valid <= stage1_valid;
      if (stage1_valid) begin
        stage2_product <= $signed(stage1_matrix_data) * $signed(stage1_vertex_data);
        stage2_row     <= stage1_row;
        stage2_col     <= stage1_col;
      end
    end
  end

  // -----------------------------------------------------------------------------
  // Stage 3: Accumulate each row
  // -----------------------------------------------------------------------------
  assign stage2_extended_product =
    {{(ACC_W-PROD_W){stage2_product[PROD_W-1]}}, stage2_product};

  // Row and column describe the registered accumulation, not the product
  // currently entering this stage.
  always_ff @(posedge clk) begin
    if (rst) begin
      stage3_accum <= '0;
      stage3_row   <= '0;
      stage3_col   <= '0;
      stage3_valid <= 1'b0;
    end else begin
      stage3_valid <= stage2_valid;
      if (stage2_valid) begin
        if (stage2_col == 2'd0)
          stage3_accum <= stage2_extended_product;
        else
          stage3_accum <= stage3_accum + stage2_extended_product;
        stage3_row <= stage2_row;
        stage3_col <= stage2_col;
      end
    end
  end

  // -----------------------------------------------------------------------------
  // Output buffer
  // -----------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < 4; i++) begin
        result[i] <= '0;
      end
    end else if (state == STATE_LOAD_MATRIX && stage3_valid &&
                 stage3_col == 2'd3) begin
      result[stage3_row] <= stage3_accum;
    end
  end

  assign out_accept = o_valid && i_ready;
  assign o_vector_data = result[output_id][DATA_W-1:0];

  always_ff @(posedge clk) begin
    if (rst) begin
      output_id <= '0;
    end else if (out_accept) begin
      if (output_id == 2'd3)
        output_id <= '0;
      else
        output_id <= output_id + 2'd1;
    end
  end

  // -----------------------------------------------------------------------------
  // FSM
  // -----------------------------------------------------------------------------

  always_ff @(posedge clk) begin
    if (rst) begin
      state <= STATE_IDLE;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin
    next_state = state;
    case (state)
      STATE_IDLE: begin
        o_ready = 1'b1;
        o_valid = 1'b0;

        // Next state logic
        if (in_accept) begin
          next_state = STATE_LOAD_MATRIX;
        end
      end

      STATE_LOAD_MATRIX: begin
        if (matrix_id < 5'd16)
          o_ready = 1'b1;
        else
          o_ready = 1'b0;
        
        o_valid = 1'b0;

        // Next state logic
        if (matrix_id == 5'd16 && stage3_valid &&
            stage3_row == 2'd3 && stage3_col == 2'd3) begin
          next_state = STATE_SEND_VECTOR;
        end
      end

      STATE_SEND_VECTOR: begin
        o_ready = 1'b0;
        o_valid = 1'b1;
        
        // Next state logic
        if (out_accept && output_id == 2'd3)
          next_state = STATE_IDLE;
      end

      default: begin
        next_state = STATE_IDLE;
        o_ready = 1'b0;
        o_valid = 1'b0;
      end
    endcase
  end

endmodule
