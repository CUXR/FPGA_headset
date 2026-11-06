`include "MatVecEngine.sv"

`timescale 1ns/1ps

module MatVecTop (
    input  logic clk,
    input  logic rst,
    output logic [15:0] result_check,
    output logic result_valid
);

    localparam int DATA_W = 18;
    localparam int FRAC_W = 10;

    logic signed [DATA_W-1:0] i_matrix[0:3][0:3];
    logic signed [DATA_W-1:0] i_vec[0:3];
    wire signed [DATA_W-1:0]  o_mat[0:3][0:3];
    wire signed [DATA_W-1:0]  o_vec[0:3];

    logic i_mat_valid;
    logic o_mat_ready;
    logic o_vec_ready;
    logic o_mat_valid;
    logic o_vec_valid;

    logic [287:0] matrix_data;
    logic [71:0]  vector_data;
    logic [1:0]   input_column;

    assign i_mat_valid = (input_column == 2'd0);

    // -------------------------------------------------------------------------
    // Input generation
    // -------------------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (rst) begin
            matrix_data <= 288'h123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789ABC;
            vector_data <= 72'h123456789ABCDEF123;
            input_column <= 2'd0;
        end else begin
            if (i_mat_valid && o_mat_ready) begin
                matrix_data <= {
                    matrix_data[286:0],
                    matrix_data[287] ^ matrix_data[284]
                };
            end

            if (o_vec_ready) begin
                vector_data <= {
                    vector_data[70:0],
                    vector_data[71] ^ vector_data[69] ^
                    vector_data[68] ^ vector_data[65]
                };
                input_column <= input_column + 2'd1;
            end
        end
    end

    generate
        for (genvar row = 0; row < 4; row++) begin : ROW
            assign i_vec[row] = vector_data[row*DATA_W +: DATA_W];

            for (genvar col = 0; col < 4; col++) begin : COL
                assign i_matrix[row][col] =
                    matrix_data[(row*4+col)*DATA_W +: DATA_W];
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // MatVecEngine
    // -------------------------------------------------------------------------

    MatVecEngine #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) dut (
        .clk           (clk),
        .rst           (rst),
        .i_mat_valid   (i_mat_valid),
        .o_mat_ready   (o_mat_ready),
        .i_matrix      (i_matrix),
        .i_matrix_mode (1'b1),
        .i_vec_valid   (1'b1),
        .o_vec_ready   (o_vec_ready),
        .i_vec         (i_vec),
        .o_vec_valid   (o_vec_valid),
        .i_vec_ready   (1'b1),
        .o_vec         (o_vec),
        .o_mat_valid   (o_mat_valid),
        .i_mat_ready   (1'b1),
        .o_mat         (o_mat)
    );

    // -------------------------------------------------------------------------
    // Output checksum
    // -------------------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (rst) begin
            result_check <= '0;
            result_valid <= 1'b0;
        end else begin
            result_valid <= o_vec_valid;

            if (o_mat_valid) begin
                for (int row = 0; row < 4; row++) begin
                    for (int col = 0; col < 4; col++) begin
                        result_check[row*4+col] <= ^o_mat[row][col];
                    end
                end
            end else if (o_vec_valid) begin
                result_check <= '0;
                for (int row = 0; row < 4; row++) begin
                    result_check[row] <= ^o_vec[row];
                end
            end
        end
    end
endmodule
