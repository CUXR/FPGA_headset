`ifndef MAT_VEC_ENGINE_SV
`define MAT_VEC_ENGINE_SV

`timescale 1ns/1ps

module MatVecEngine #(
    parameter int DATA_W = 18,
    parameter int FRAC_W = 10
) (
    // Clock and Reset
    input  logic clk,
    input  logic rst,

    // Load static matrix
    input  logic                     i_mat_valid,
    output logic                     o_mat_ready,
    input  logic signed [DATA_W-1:0] i_matrix [0:3][0:3],
    input  logic                     i_matrix_mode,

    // Send one vector
    input  logic                     i_vec_valid,
    output logic                     o_vec_ready,
    input  logic signed [DATA_W-1:0] i_vec [0:3],

    // Vector output
    output logic                     o_vec_valid,
    input  logic                     i_vec_ready,
    output logic signed [DATA_W-1:0] o_vec [0:3],

    // Matrix output
    output logic                     o_mat_valid,
    input  logic                     i_mat_ready,
    output logic signed [DATA_W-1:0] o_mat [0:3][0:3]
);

    localparam int PROD_W = 2 * DATA_W;
    localparam int ACC_W  = PROD_W + 2;

    logic signed [DATA_W-1:0] active_matrix [0:3][0:3];
    logic                     matrix_loaded;

    logic                     mat_accept;
    logic                     vec_accept;
    logic [1:0]               next_column;  // Used to increment the column
    logic                     operation_matrix_mode;  // The input matrix mode
    logic                     accepted_matrix_mode;  // The matrix mode that is accepted, either from the input or from the previous operation

    logic signed [DATA_W-1:0] stage1_vector [0:3];
    logic [1:0]               stage1_column;
    logic                     stage1_matrix_mode;
    logic                     stage1_valid;
    logic                     stage1_ready;

    logic signed [PROD_W-1:0] stage2_prod [0:3][0:3];
    logic [1:0]               stage2_column;
    logic                     stage2_matrix_mode;
    logic                     stage2_valid;
    logic                     stage2_ready;

    logic signed [ACC_W-1:0]  stage3_sum [0:3];
    logic [1:0]               stage3_column;
    logic                     stage3_matrix_mode;
    logic                     stage3_valid;
    logic                     stage3_ready;

    // The three columns of the matrix that need to be stored, waiting for the last column
    logic signed [DATA_W-1:0] matrix_columns [0:3][0:2];
    logic                     final_column;
    logic                     vector_sent;  // Did vector output send?
    logic                     matrix_sent;  // Did matrix output send?
    logic                     vector_done;
    logic                     matrix_done;

    // -------------------------------------------------------------------------
    // Stage 0
    // -------------------------------------------------------------------------

    assign o_mat_ready = !rst && (next_column == 2'd0) && stage1_ready;
    assign mat_accept  = i_mat_valid && o_mat_ready;
    assign accepted_matrix_mode = (next_column == 2'd0)
                                ? i_matrix_mode : operation_matrix_mode;

    // not resetting, stage 1 ready, and the matrix is accepting or already loaded
    assign o_vec_ready = !rst && stage1_ready && (matrix_loaded || mat_accept);
    assign vec_accept  = i_vec_valid && o_vec_ready;

    // Operation mode handling
    always_ff @(posedge clk) begin
        if (rst) begin
            next_column           <= 2'd0;
            operation_matrix_mode <= 1'b0;
        end else if (vec_accept) begin
            // Accept the matrix mode on the first column
            if (next_column == 2'd0) begin
                operation_matrix_mode <= i_matrix_mode;
            end

            // If in vector mode or finished with matrix, set next column to 0
            if (!accepted_matrix_mode || next_column == 2'd3) begin
                next_column <= 2'd0;
            end else begin // If in matrix mode, increment the column
                next_column <= next_column + 2'd1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Stage 1: Load vector and matrix
    // -------------------------------------------------------------------------

    // stage 1 empty - accept a vector
    // stage 1 full and stage 2 ready - accept a vector
    // stage 1 full and stage 2 not ready - do not accept a vector
    assign stage1_ready = !stage1_valid || stage2_ready;

    // Matrix loading
    always_ff @(posedge clk) begin
        if (rst) begin
            matrix_loaded <= 1'b0;
        end else if (mat_accept) begin
            for (int i = 0; i < 4; i++) begin
                for (int j = 0; j < 4; j++) begin
                    active_matrix[i][j] <= i_matrix[i][j];
                end
            end

            matrix_loaded <= 1'b1;
        end
    end

    // Vector loading
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 4; i++) begin
                stage1_vector[i] <= '0;
            end
            stage1_column      <= 2'd0;
            stage1_matrix_mode <= 1'b0;
            stage1_valid       <= 1'b0;
        end else if (stage1_ready) begin
            stage1_valid <= vec_accept;

            if (vec_accept) begin
                for (int i = 0; i < 4; i++) begin
                    stage1_vector[i] <= i_vec[i];
                end

                stage1_column      <= next_column;
                stage1_matrix_mode <= accepted_matrix_mode;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Stage 2: Multiply
    // -------------------------------------------------------------------------

    // stage 2 empty - accept a vector
    // stage 2 full and stage 3 ready - accept a vector
    // stage 2 full and stage 3 not ready - do not accept a vector
    assign stage2_ready = !stage2_valid || stage3_ready;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 4; i++) begin
                for (int j = 0; j < 4; j++) begin
                    stage2_prod[i][j] <= '0;
                end
            end
            stage2_column      <= 2'd0;
            stage2_matrix_mode <= 1'b0;
            stage2_valid       <= 1'b0;
        end else if (stage2_ready) begin
            stage2_valid <= stage1_valid;

            if (stage1_valid) begin
                for (int i = 0; i < 4; i++) begin
                    for (int j = 0; j < 4; j++) begin
                        stage2_prod[i][j] <= $signed(active_matrix[i][j]) * 
                                             $signed(stage1_vector[j]);
                    end
                end
                
                stage2_column      <= stage1_column;
                stage2_matrix_mode <= stage1_matrix_mode;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Stage 3: Sum
    // -------------------------------------------------------------------------

    // stage 3 empty - accept a vector
    // stage 3 full and stage 4 ready - accept a vector
    // stage 3 full and stage 4 not ready - do not accept a vector
    assign stage3_ready = !stage3_valid || (vector_done && matrix_done);

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 4; i++) begin
                stage3_sum[i] <= '0;
            end
            stage3_column      <= 2'd0;
            stage3_matrix_mode <= 1'b0;
            stage3_valid       <= 1'b0;
        end else if (stage3_ready) begin
            stage3_valid <= stage2_valid;

            if (stage2_valid) begin
                for (int i = 0; i < 4; i++) begin
                    // Sign extend to ACC_W and sum the four products
                    stage3_sum[i] <= ACC_W'($signed(stage2_prod[i][0])) +
                                     ACC_W'($signed(stage2_prod[i][1])) +
                                     ACC_W'($signed(stage2_prod[i][2])) +
                                     ACC_W'($signed(stage2_prod[i][3]));
                end

                stage3_column      <= stage2_column;
                stage3_matrix_mode <= stage2_matrix_mode;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            vector_sent <= 1'b0;
            matrix_sent <= 1'b0;
        end else if (stage3_ready) begin
            vector_sent <= 1'b0;
            matrix_sent <= 1'b0;
        end else begin
            if (o_vec_valid && i_vec_ready) begin
                vector_sent <= 1'b1;
            end 
            
            if (o_mat_valid && i_mat_ready) begin
                matrix_sent <= 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst && stage3_valid && stage3_ready && stage3_matrix_mode &&
            (stage3_column != 2'b11)) begin
            
            for (int row = 0; row < 4; row++) begin
                matrix_columns[row][stage3_column] <= o_vec[row];
            end
        end
    end

    // -------------------------------------------------------------------------
    // Output (Chat helped with this part. Very confusing.)
    // -------------------------------------------------------------------------

    assign final_column = stage3_matrix_mode && (stage3_column == 2'b11);
    assign o_vec_valid  = !rst && stage3_valid && !vector_sent;
    assign o_mat_valid  = !rst && stage3_valid && final_column && !matrix_sent;
    assign vector_done  = vector_sent || i_vec_ready;
    assign matrix_done  = !final_column || matrix_sent || i_mat_ready;

    always_comb begin
        for (int row = 0; row < 4; row++) begin
            o_vec[row] = DATA_W'(stage3_sum[row] >>> FRAC_W);

            for (int col = 0; col < 3; col++) begin
                o_mat[row][col] = matrix_columns[row][col];
            end

            o_mat[row][3] = o_vec[row];
        end
    end
endmodule

`endif // MATRIX_VEC_ENGINE_SV
