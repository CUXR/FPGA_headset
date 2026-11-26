// Temporary wrapper for synthesis and timing analysis.

`include "HeadsetTop.sv"

`timescale 1ns/1ps

module HeadsetTimingTop (
    input  logic        clk,
    input  logic        rst,
    output logic [15:0] result_check,
    output logic        result_valid,
    output logic        frame_ready
);
    localparam int DATA_W = 18;
    localparam int OBJECT_ID_W = 3;

    logic signed [DATA_W-1:0] line_vertex_1 [0:3];
    logic signed [DATA_W-1:0] line_vertex_2 [0:3];
    logic [OBJECT_ID_W-1:0]   line_object_id;
    logic [15:0]              line_color;
    logic                     line_valid;
    logic [15:0]              next_result_check;

    HeadsetTop #(
        .DATA_W(DATA_W),
        .OBJECT_ID_W(OBJECT_ID_W)
    ) headset_top (
        .clk              (clk),
        .rst              (rst),
        .i_frame_valid    (!rst),
        .o_frame_ready    (frame_ready),
        .o_line_vertex_1  (line_vertex_1),
        .o_line_vertex_2  (line_vertex_2),
        .o_line_object_id (line_object_id),
        .o_line_color     (line_color),
        .o_line_valid     (line_valid),
        .i_line_ready     (1'b1)
    );

    // Fold every output data bit into a small, observable result.
    always_comb begin
        next_result_check = line_color;
        for (int axis = 0; axis < 4; axis ++) begin
            for (int bit_index = 0; bit_index < DATA_W; bit_index ++) begin
                next_result_check[(axis*DATA_W + bit_index) % 16] ^=
                    line_vertex_1[axis][bit_index];
                next_result_check[((axis+4)*DATA_W + bit_index) % 16] ^=
                    line_vertex_2[axis][bit_index];
            end
        end
        for (int bit_index = 0; bit_index < OBJECT_ID_W; bit_index ++) begin
            next_result_check[bit_index] ^= line_object_id[bit_index];
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            result_check <= '0;
            result_valid <= 1'b0;
        end else begin
            result_valid <= line_valid;
            if (line_valid) begin
                result_check <= next_result_check;
            end
        end
    end
endmodule
