`include "MatVecEngine.sv"

`ifndef OBJECT_MATRIX_BUILDER_SV
`define OBJECT_MATRIX_BUILDER_SV

`timescale 1ns/1ps

module ObjectMatrixBuilder #(
    parameter int DATA_W      = 18,
    parameter int FRAC_W      = 10,
    parameter int OBJECT_ID_W = 4
) (
    input  logic clk,
    input  logic rst,

    // Object request
    input  logic                     i_object_valid,
    output logic                     o_object_ready,
    input  logic [OBJECT_ID_W-1:0]   i_object_id,

    // x, y, z translation and scale inputs
    input  logic signed [DATA_W-1:0] i_translation [0:2],
    input  logic signed [DATA_W-1:0] i_scale [0:2],

    // sin and cos inputs for rotation about x, y, and z axes
    input  logic signed [DATA_W-1:0] i_sin [0:2],
    input  logic signed [DATA_W-1:0] i_cos [0:2],

    // Output matrix
    output logic                     o_object_mat_valid,
    input  logic                     i_object_mat_ready,
    output logic [OBJECT_ID_W-1:0]   o_object_id,
    output logic signed [DATA_W-1:0] o_object_mat [0:3][0:3]
);

    // Notes:
    // FSM: IDLE, M1, M2, M3, M4, DONE

    localparam logic [DATA_W-1:0] ONE = DATA_W'(1 << FRAC_W);

    localparam logic [2:0] STATE_IDLE = 3'b000;
    localparam logic [2:0] STATE_M1   = 3'b001;
    localparam logic [2:0] STATE_M2   = 3'b010;
    localparam logic [2:0] STATE_M3   = 3'b011;
    localparam logic [2:0] STATE_M4   = 3'b100;
    localparam logic [2:0] STATE_DONE = 3'b101;

    logic [2:0]               state;
    logic [2:0]               next_state;

    logic                     in_accept;

    logic [OBJECT_ID_W-1:0]   object_id;
    logic signed [DATA_W-1:0] translation [0:2];
    logic signed [DATA_W-1:0] scale [0:2];
    logic signed [DATA_W-1:0] sin [0:2];
    logic signed [DATA_W-1:0] cos [0:2];
    logic signed [DATA_W-1:0] right_matrix [0:3][0:3];

    logic signed [DATA_W-1:0] translation_matrix [0:3][0:3];
    logic                     use_engine_result;
    logic signed [DATA_W-1:0] left_matrix [0:3][0:3];

    logic                     engine_mat_valid;
    logic                     engine_mat_ready;
    logic                     engine_vec_valid;
    logic                     engine_vec_ready;
    logic signed [DATA_W-1:0] engine_vec [0:3];
    logic        [2:0]        engine_vec_counter;

    logic                     engine_result_valid;
    logic                     engine_result_ready;
    wire signed [DATA_W-1:0] engine_result_matrix [0:3][0:3];

    assign in_accept = i_object_valid && o_object_ready;
    assign o_object_ready = !rst && (state == STATE_IDLE);
    assign o_object_mat_valid = !rst && (state == STATE_DONE);
    assign o_object_id = object_id;

    assign engine_result_ready = !rst && ((state == STATE_M1)
                                      || (state == STATE_M2)
                                      || (state == STATE_M3)
                                      || (state == STATE_M4));

    // -------------------------------------------------------------------------
    // Output matrix register
    // -------------------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int row = 0; row < 4; row++) begin
                for (int col = 0; col < 4; col++) begin
                    o_object_mat[row][col] <= '0;
                end
            end
        end else if ((state == STATE_M4) && engine_result_valid && engine_result_ready) begin
            for (int row = 0; row < 4; row++) begin
                for (int col = 0; col < 4; col++) begin
                    o_object_mat[row][col] <= engine_result_matrix[row][col];
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Input storing
    // -------------------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (rst) begin
            object_id <= '0;
            for (int i = 0; i < 3; i++) begin
                translation[i] <= '0;
                scale[i]       <= '0;
                sin[i]         <= '0;
                cos[i]         <= '0;
            end
        end else if (state == STATE_IDLE && in_accept) begin
            object_id <= i_object_id;
            for (int i = 0; i < 3; i++) begin
                translation[i] <= i_translation[i];
                scale[i]       <= i_scale[i];
                sin[i]         <= i_sin[i];
                cos[i]         <= i_cos[i];
            end
        end
    end

    // -------------------------------------------------------------------------
    // Translation matrix (1st matrix)
    // -------------------------------------------------------------------------

    always_comb begin
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
                translation_matrix[i][j] = '0;
            end
        end

        translation_matrix[0][0] = ONE;
        translation_matrix[1][1] = ONE;
        translation_matrix[2][2] = ONE;
        translation_matrix[3][3] = ONE;
        translation_matrix[0][3] = translation[0];
        translation_matrix[1][3] = translation[1];
        translation_matrix[2][3] = translation[2];
    end

    // -------------------------------------------------------------------------
    // Left matrix selection and right matrix column selection
    // -------------------------------------------------------------------------

    always_comb begin
        for (int row = 0; row < 4; row++) begin
            for (int col = 0; col < 4; col++) begin
                left_matrix[row][col] = use_engine_result
                                     ? engine_result_matrix[row][col]
                                     : translation_matrix[row][col];
            end

            engine_vec[row] = '0;
            if (engine_vec_counter < 3'd4) begin
                engine_vec[row] = right_matrix[row][engine_vec_counter[1:0]];
            end
        end
    end

    // -------------------------------------------------------------------------
    // Matrix loading and column counter
    // -------------------------------------------------------------------------

    // Load the matrix WITH the first column.
    assign engine_mat_valid = engine_vec_valid && (engine_vec_counter == 3'd0);

    // 0-3 pick a column; 4 means all columns are sent.
    always_ff @(posedge clk) begin
        if (rst) begin
            engine_vec_counter <= 3'd0;
        end else if (in_accept || (engine_result_valid && engine_result_ready)) begin
            engine_vec_counter <= 3'd0;
        end else if (engine_vec_valid && engine_vec_ready) begin
            engine_vec_counter <= engine_vec_counter + 3'd1;
        end
    end


    // -------------------------------------------------------------------------
    // MatVecEngine instance
    // -------------------------------------------------------------------------

    MatVecEngine #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) dut (
        .clk           (clk),
        .rst           (rst),

        .i_mat_valid   (engine_mat_valid),
        .o_mat_ready   (engine_mat_ready),
        .i_matrix      (left_matrix),
        .i_matrix_mode (1'b1),

        .i_vec_valid   (engine_vec_valid),
        .o_vec_ready   (engine_vec_ready),
        .i_vec         (engine_vec),

        .o_vec_valid   (),
        .i_vec_ready   (1'b1),
        .o_vec         (),

        .o_mat_valid   (engine_result_valid),
        .i_mat_ready   (engine_result_ready),
        .o_mat         (engine_result_matrix)
    );

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
                right_matrix[i][j] = '0;
            end
        end
        use_engine_result = 1'b0;
        engine_vec_valid = 1'b0;

        case (state)
            STATE_IDLE: begin
                if (in_accept) begin
                    next_state = STATE_M1;
                end
            end
            STATE_M1: begin
                engine_vec_valid = !rst && (engine_vec_counter < 3'd4);
                // Rz: T * Rz
                right_matrix[0][0] =  cos[2];
                right_matrix[0][1] = -sin[2];
                right_matrix[1][0] =  sin[2];
                right_matrix[1][1] =  cos[2];
                right_matrix[2][2] = ONE;
                right_matrix[3][3] = ONE;

                if (engine_result_valid && engine_result_ready) begin
                    next_state = STATE_M2;
                end
            end
            STATE_M2: begin
                engine_vec_valid = !rst && (engine_vec_counter < 3'd4);
                // Ry: (T * Rz) * Ry
                right_matrix[0][0] =  cos[1];
                right_matrix[0][2] =  sin[1];
                right_matrix[1][1] = ONE;
                right_matrix[2][0] = -sin[1];
                right_matrix[2][2] =  cos[1];
                right_matrix[3][3] = ONE;

                if (engine_result_valid && engine_result_ready) begin
                    next_state = STATE_M3;
                end

                use_engine_result = 1'b1;
            end
            STATE_M3: begin
                engine_vec_valid = !rst && (engine_vec_counter < 3'd4);
                // Rx: (T * Rz * Ry) * Rx
                right_matrix[0][0] = ONE;
                right_matrix[1][1] =  cos[0];
                right_matrix[1][2] = -sin[0];
                right_matrix[2][1] =  sin[0];
                right_matrix[2][2] =  cos[0];
                right_matrix[3][3] = ONE;

                if (engine_result_valid && engine_result_ready) begin
                    next_state = STATE_M4;
                end

                use_engine_result = 1'b1;
            end
            STATE_M4: begin
                engine_vec_valid = !rst && (engine_vec_counter < 3'd4);
                // S: (T * Rz * Ry * Rx) * S
                right_matrix[0][0] = scale[0];
                right_matrix[1][1] = scale[1];
                right_matrix[2][2] = scale[2];
                right_matrix[3][3] = ONE;

                if (engine_result_valid && engine_result_ready) begin
                    next_state = STATE_DONE;
                end

                use_engine_result = 1'b1;
            end
            STATE_DONE: begin
                if (o_object_mat_valid && i_object_mat_ready) begin
                    next_state = STATE_IDLE;
                end
            end
            default: begin
                next_state = STATE_IDLE;
            end
        endcase
    end
endmodule

`endif // OBJECT_MATRIX_BUILDER_SV
