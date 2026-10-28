`include "CameraInverse.sv"

module HeadsetTop #(
    parameter int H_RES = 1280,
    parameter int V_RES = 720
)(
    input  logic clk,
    input  logic rst,
    output logic [15:0] result_check,
    output logic result_valid
);

    localparam int DATA_W = 20;
    localparam int FRAC_W = 12;

    // 4x4 matrices, each element 20 bits
    logic signed [DATA_W-1:0] i_matrix[3:0][3:0];
    logic signed [DATA_W-1:0] o_inverse[3:0][3:0];

    logic i_matrix_valid;
    logic o_matrix_ready;
    logic o_inverse_valid;
    logic i_inverse_ready;

    // Internal 320-bit input generator
    logic [319:0] matrix_data;

    assign i_matrix_valid = 1'b1;
    assign i_inverse_ready = 1'b1;

    // Generate changing input data
    always_ff @(posedge clk) begin
        if (rst) begin
            matrix_data <= 320'h123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789ABCDEF;
        end
        else if (o_matrix_ready) begin
            matrix_data <= {
                matrix_data[318:0],
                matrix_data[319] ^ matrix_data[316]
            };
        end
    end

    // Convert 320-bit vector to 4x4 unpacked array
    for (genvar i = 0; i < 4; i++) begin : ROW
        for (genvar j = 0; j < 4; j++) begin : COL
            assign i_matrix[i][j] =
                matrix_data[(i*4+j)*DATA_W +: DATA_W];
        end
    end

    // DUT
    CameraInverse #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) dut (
        .clk             (clk),
        .rst             (rst),
        .i_matrix        (i_matrix),
        .i_matrix_valid  (i_matrix_valid),
        .o_matrix_ready  (o_matrix_ready),
        .o_inverse       (o_inverse),
        .o_inverse_valid (o_inverse_valid),
        .i_inverse_ready (i_inverse_ready)
    );

    // Compress 320 output bits into 16 observable bits
    always_ff @(posedge clk) begin
        if (rst) begin
            result_check <= '0;
            result_valid <= 1'b0;
        end
        else begin
            result_valid <= o_inverse_valid;

            if (o_inverse_valid) begin
                for (int i = 0; i < 4; i++) begin
                    for (int j = 0; j < 4; j++) begin
                        result_check[i*4+j] <= ^o_inverse[i][j];
                    end
                end
            end
        end
    end
endmodule