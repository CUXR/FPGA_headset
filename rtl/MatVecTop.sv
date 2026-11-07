// CHAT GENERATED FILE. ONLY USED FOR TIMING ANALYSIS.

`include "ObjectMatrixBuilder.sv"

`timescale 1ns/1ps

// Temporary ObjectMatrixBuilder timing harness. Keep the small external
// interface while exercising every transform input and observing every result.
module MatVecTop (
    input  logic clk,
    input  logic rst,
    output logic [15:0] result_check,
    output logic result_valid
);
    localparam int DATA_W = 18;
    localparam int FRAC_W = 10;
    localparam int OBJECT_ID_W = 4;
    localparam int STIMULUS_W = 12 * DATA_W;

    logic [STIMULUS_W-1:0] stimulus;
    logic [OBJECT_ID_W-1:0] object_id;
    wire signed [DATA_W-1:0] translation[0:2];
    wire signed [DATA_W-1:0] scale[0:2];
    wire signed [DATA_W-1:0] sin[0:2];
    wire signed [DATA_W-1:0] cos[0:2];
    wire signed [DATA_W-1:0] object_mat[0:3][0:3];
    wire [OBJECT_ID_W-1:0] result_object_id;
    logic object_ready;
    logic object_mat_valid;

    // Synthetic bit patterns exercise the arithmetic, including overflow;
    // they are not constrained to physically valid sine/cosine pairs.
    // Advance only on acceptance, keeping the entire request stable otherwise.
    always_ff @(posedge clk) begin
        if (rst) begin
            stimulus <= 216'h123456789abcdef123_456789abcdef123456_789abcdef123456789;
            object_id <= '0;
        end else if (object_ready) begin
            stimulus <= {stimulus[STIMULUS_W-2:0],
                         stimulus[215] ^ stimulus[213] ^ stimulus[210] ^ stimulus[208]};
            object_id <= object_id + 1'b1;
        end
    end

    for (genvar axis = 0; axis < 3; axis++) begin : INPUTS
        assign translation[axis] = stimulus[(axis + 0)*DATA_W +: DATA_W];
        assign scale[axis]       = stimulus[(axis + 3)*DATA_W +: DATA_W];
        assign sin[axis]         = stimulus[(axis + 6)*DATA_W +: DATA_W];
        assign cos[axis]         = stimulus[(axis + 9)*DATA_W +: DATA_W];
    end

    ObjectMatrixBuilder #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W),
        .OBJECT_ID_W(OBJECT_ID_W)
    ) dut (
        .clk                (clk),
        .rst                (rst),
        .i_object_valid     (!rst),
        .o_object_ready     (object_ready),
        .i_object_id        (object_id),
        .i_translation      (translation),
        .i_scale            (scale),
        .i_sin              (sin),
        .i_cos              (cos),
        .o_object_mat_valid (object_mat_valid),
        .i_object_mat_ready (1'b1),
        .o_object_id        (result_object_id),
        .o_object_mat       (object_mat)
    );

    // Register the signature so timing includes a real output capture stage.
    // Each matrix element contributes to an observable output bit; fold in ID
    // to retain the metadata path as well. Hold the signature between results.
    always_ff @(posedge clk) begin
        if (rst) begin
            result_check <= '0;
            result_valid <= 1'b0;
        end else begin
            result_valid <= object_mat_valid;
            if (object_mat_valid) begin
                for (int row = 0; row < 4; row++) begin
                    for (int col = 0; col < 4; col++) begin
                        result_check[row*4+col] <= ^object_mat[row][col]
                            ^ result_object_id[(row*4+col) % OBJECT_ID_W];
                    end
                end
            end
        end
    end
endmodule
