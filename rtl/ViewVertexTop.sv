// CHAT GENERATED FILE. ONLY USED FOR TIMING ANALYSIS.

`include "ViewVertexProcessor.sv"

`timescale 1ns/1ps

module ViewVertexTop (
    input  logic clk,
    input  logic rst,
    output logic [15:0] result_check,
    output logic result_valid
);
    localparam int DATA_W = 18;
    localparam int FRAC_W = 10;
    localparam int OBJECT_ID_W = 4;
    localparam int STIMULUS_W = 29 * DATA_W;

    // -------------------------------------------------------------------------
    // Input generation
    // -------------------------------------------------------------------------

    localparam logic [1:0] STATE_CAMERA = 2'b00;
    localparam logic [1:0] STATE_OBJECT = 2'b01;
    localparam logic [1:0] STATE_VERTEX = 2'b10;

    logic [1:0] state;
    logic [3:0] vertex_counter;
    logic [3:0] ready_counter;
    logic [OBJECT_ID_W-1:0] object_id;
    logic [STIMULUS_W-1:0] stimulus;

    logic camera_valid;
    logic camera_ready;
    logic object_valid;
    logic object_ready;
    logic vertex_valid;
    logic vertex_ready;
    logic output_valid;
    logic output_ready;

    wire signed [DATA_W-1:0] camera_translation [0:2];
    wire signed [DATA_W-1:0] camera_sin [0:2];
    wire signed [DATA_W-1:0] camera_cos [0:2];
    wire signed [DATA_W-1:0] object_matrix [0:3][0:3];
    wire signed [DATA_W-1:0] vertex [0:3];
    wire signed [DATA_W-1:0] result_vertex [0:3];
    wire [OBJECT_ID_W-1:0] result_object_id;

    assign camera_valid = !rst && (state == STATE_CAMERA);
    assign object_valid = !rst && (state == STATE_OBJECT);
    assign vertex_valid = !rst && (state == STATE_VERTEX);
    assign output_ready = !rst && (ready_counter != 4'd0);

    // Changing synthetic data keeps the arithmetic observable in synthesis.
    // Sine/cosine pairs are deliberately unrestricted bit patterns.
    // Only one input channel is active, and its payload holds until accepted.
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= STATE_CAMERA;
            vertex_counter <= '0;
            ready_counter <= '0;
            object_id <= '0;
            stimulus <= {29{18'h2a5c3}};
        end else begin
            ready_counter <= ready_counter + 4'd1;

            if ((camera_valid && camera_ready) ||
                (object_valid && object_ready) ||
                (vertex_valid && vertex_ready)) begin
                stimulus <= {stimulus[STIMULUS_W-2:0],
                             stimulus[521] ^ stimulus[519] ^
                             stimulus[516] ^ stimulus[513]};
            end

            case (state)
                STATE_CAMERA: begin
                    if (camera_valid && camera_ready) begin
                        state <= STATE_OBJECT;
                    end
                end
                STATE_OBJECT: begin
                    if (object_valid && object_ready) begin
                        state <= STATE_VERTEX;
                        vertex_counter <= '0;
                        object_id <= object_id + 1'b1;
                    end
                end
                STATE_VERTEX: begin
                    if (vertex_valid && vertex_ready) begin
                        vertex_counter <= vertex_counter + 4'd1;
                        if (vertex_counter == 4'd15) begin
                            state <= STATE_CAMERA;
                        end
                    end
                end
                default: begin
                    state <= STATE_CAMERA;
                end
            endcase
        end
    end

    for (genvar axis = 0; axis < 3; axis++) begin : CAMERA_INPUTS
        assign camera_translation[axis] = stimulus[axis*DATA_W +: DATA_W];
        assign camera_sin[axis] = stimulus[(axis+3)*DATA_W +: DATA_W];
        assign camera_cos[axis] = stimulus[(axis+6)*DATA_W +: DATA_W];
    end

    for (genvar row = 0; row < 4; row++) begin : VERTEX_INPUTS
        assign vertex[row] = stimulus[(row+25)*DATA_W +: DATA_W];
        for (genvar col = 0; col < 4; col++) begin : MATRIX_INPUTS
            assign object_matrix[row][col] = stimulus[(row*4+col+9)*DATA_W +: DATA_W];
        end
    end

    // -------------------------------------------------------------------------
    // ViewVertexProcessor
    // -------------------------------------------------------------------------

    ViewVertexProcessor #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W),
        .OBJECT_ID_W(OBJECT_ID_W)
    ) dut (
        .clk                  (clk),
        .rst                  (rst),

        .i_camera_valid       (camera_valid),
        .o_camera_ready       (camera_ready),
        .i_camera_translation (camera_translation),
        .i_camera_sin         (camera_sin),
        .i_camera_cos         (camera_cos),

        .i_object_valid       (object_valid),
        .o_object_ready       (object_ready),
        .i_object_id          (object_id),
        .i_object_matrix      (object_matrix),

        .i_vertex_valid       (vertex_valid),
        .o_vertex_ready       (vertex_ready),
        .i_vertex             (vertex),

        .o_result_valid       (output_valid),
        .i_result_ready       (output_ready),
        .o_result_object_id   (result_object_id),
        .o_result_vertex      (result_vertex)
    );

    // -------------------------------------------------------------------------
    // Registered output signature
    // -------------------------------------------------------------------------

    logic [15:0] next_result_check;

    always_comb begin
        next_result_check = '0;
        for (int row = 0; row < 4; row++) begin
            for (int bit_index = 0; bit_index < DATA_W; bit_index++) begin
                next_result_check[(row*DATA_W+bit_index) % 16] ^=
                    result_vertex[row][bit_index];
            end
        end
        for (int bit_index = 0; bit_index < OBJECT_ID_W; bit_index++) begin
            next_result_check[bit_index] ^= result_object_id[bit_index];
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            result_check <= '0;
            result_valid <= 1'b0;
        end else begin
            result_valid <= output_valid && output_ready;
            if (output_valid && output_ready) begin
                result_check <= next_result_check;
            end
        end
    end
endmodule
