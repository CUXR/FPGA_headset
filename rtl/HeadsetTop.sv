`include "CameraInverse.sv"

module HeadsetTop #(
    parameter int H_RES = 1280,
    parameter int V_RES = 720
)(
    input  logic       clk,
    input  logic       rst,
    output logic [8:0] result_check,
    output logic       result_valid
);

    localparam int DATA_W = 20;
    localparam int FRAC_W = 12;
    localparam int MATRIX_W = 9 * DATA_W;

    // CameraInverse signals
    logic i_matrix_valid;
    logic o_matrix_ready;
    logic [MATRIX_W-1:0] i_matrix;

    logic o_inverse_valid;
    logic i_inverse_ready;
    logic [MATRIX_W-1:0] o_inverse;

    // Generate changing input matrices internally
    logic [MATRIX_W-1:0] matrix_lfsr;

    assign i_matrix_valid = 1'b1;
    assign i_inverse_ready = 1'b1;
    assign i_matrix       = matrix_lfsr;

    // LFSR-based input generator
    always_ff @(posedge clk) begin
        if (rst) begin
            matrix_lfsr <= 180'h123456789ABCDEF123456789ABCDEF123456789ABCDE;
        end
        else if (o_matrix_ready) begin
            matrix_lfsr <= {
                matrix_lfsr[MATRIX_W-2:0],
                matrix_lfsr[179] ^ matrix_lfsr[176]
                              ^ matrix_lfsr[174] ^ matrix_lfsr[171]
            };
        end
    end

    // DUT
    CameraInverse #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) dut (
        .clk             (clk),
        .rst             (rst),
        .i_matrix_valid  (i_matrix_valid),
        .o_matrix_ready  (o_matrix_ready),
        .i_matrix        (i_matrix),
        .o_inverse_valid (o_inverse_valid),
        .i_inverse_ready (i_inverse_ready),
        .o_inverse       (o_inverse)
    );

    // Register output checksums to prevent optimization
    // without exposing all 180 output bits as physical pins.
    always_ff @(posedge clk) begin
        if (rst) begin
            result_check <= '0;
            result_valid <= 1'b0;
        end
        else begin
            result_valid <= o_inverse_valid;

            if (o_inverse_valid) begin
                for (int i = 0; i < 9; i++) begin
                    result_check[i] <=
                        ^o_inverse[i*DATA_W +: DATA_W];
                end
            end
        end
    end
endmodule