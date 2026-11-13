`include "MatVecEngine.sv"
`include "CameraInverse.sv"

`ifndef VIEW_VERTEX_PROCESSOR_SV
`define VIEW_VERTEX_PROCESSOR_SV

`timescale 1ns/1ps

module ViewVertexProcessor #(
    parameter int DATA_W      = 18,
    parameter int FRAC_W      = 10,
    parameter int OBJECT_ID_W = 4
) (
    input  logic                     clk,
    input  logic                     rst,
    
    input  logic                     i_camera_valid,
    output logic                     o_camera_ready,
    input  logic signed [DATA_W-1:0] i_camera_translation [0:2],
    input  logic signed [DATA_W-1:0] i_camera_sin [0:2],
    input  logic signed [DATA_W-1:0] i_camera_cos [0:2],

    input  logic                     i_object_valid,
    output logic                     o_object_ready,
    input  logic [OBJECT_ID_W-1:0]   i_object_id,
    input  logic signed [DATA_W-1:0] i_object_matrix [0:3][0:3],

    input  logic                     i_vertex_valid,
    output logic                     o_vertex_ready,
    input  logic signed [DATA_W-1:0] i_vertex [0:3],

    output logic                     o_result_valid,
    input  logic                     i_result_ready,
    output logic [OBJECT_ID_W-1:0]   o_result_object_id,
    output wire signed [DATA_W-1:0]  o_result_vertex [0:3]
);

    localparam logic [DATA_W-1:0] ONE = DATA_W'(1 << FRAC_W);

    // -------------------------------------------------------------------------
    // Control signals and datapath status
    // -------------------------------------------------------------------------

    logic                     camera_accept;
    logic                     object_accept;
    logic                     vertex_accept;
    logic                     store_camera;
    logic                     PV_reg_en;
    logic        [1:0]        left_matrix_select;
    logic                     engine_operation;
    logic signed [DATA_W-1:0] right_matrix_stored [0:3][0:3];
    logic                     right_matrix_select;
    logic                     reset_vec_counter;
    logic                     advance_vec_counter;
    logic                     vector_select;
    logic                     engine_mat_in_valid;
    logic                     engine_mat_in_ready;
    logic                     engine_vec_in_valid;
    logic                     engine_vec_in_ready;
    logic                     engine_mat_out_valid;
    logic                     engine_mat_out_ready;
    logic                     inverse_mat_in_valid;
    logic                     inverse_mat_in_ready;
    logic                     inverse_mat_out_valid;
    logic                     inverse_mat_out_ready;
    logic                     engine_vec_out_valid;
    logic                     engine_vec_out_ready;
    logic                     allow_vertices;
    logic                     forward_vertex_results;
    logic                     update_requested;
    logic                     vertex_stalled;
    logic                     result_accept;
    logic                     PV_valid;
    logic                     PVO_valid;
    logic                     load_PVO;
    logic        [2:0]        outstanding_vertices;


    // -------------------------------------------------------------------------
    // Datapath
    // -------------------------------------------------------------------------

    // Camera state registers
    logic signed [DATA_W-1:0] camera_translation [0:2];
    logic signed [DATA_W-1:0] camera_sin [0:2];
    logic signed [DATA_W-1:0] camera_cos [0:2];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 3; i++) begin
                camera_translation[i] <= '0;
                camera_sin[i]         <= '0;
                camera_cos[i]         <= '0;
            end
        end else if (store_camera) begin
            for (int i = 0; i < 3; i++) begin
                camera_translation[i] <= i_camera_translation[i];
                camera_sin[i]         <= i_camera_sin[i];
                camera_cos[i]         <= i_camera_cos[i];
            end
        end
    end

    // Object matrix register
    logic signed [DATA_W-1:0] object_matrix_stored [0:3][0:3];

    always_ff @(posedge clk) begin
        if (!rst && object_accept) begin
            for (int i = 0; i < 4; i++) begin
                for (int j = 0; j < 4; j++) begin
                    object_matrix_stored[i][j] <= i_object_matrix[i][j];
                end
            end
        end
    end

    // Object ID stays unchanged until netx object loaded
    always_ff @(posedge clk) begin
        if (rst) begin
            o_result_object_id <= '0;
        end else if (object_accept) begin
            o_result_object_id <= i_object_id;
        end
    end

    // Translation matrix
    logic signed [DATA_W-1:0] camera_translation_matrix [0:3][0:3];

    always_comb begin
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
                camera_translation_matrix[i][j] = '0;
            end
        end

        camera_translation_matrix[0][0] = ONE;
        camera_translation_matrix[1][1] = ONE;
        camera_translation_matrix[2][2] = ONE;
        camera_translation_matrix[3][3] = ONE;
        camera_translation_matrix[0][3] = camera_translation[0];
        camera_translation_matrix[1][3] = camera_translation[1];
        camera_translation_matrix[2][3] = camera_translation[2];
    end

    // Projection matrix
    typedef logic signed [DATA_W-1:0] fixed_t;
    logic signed [DATA_W-1:0] projection_matrix [0:3][0:3];

    always_comb begin
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
                projection_matrix[i][j] = '0;
            end
        end

        // 60-degree vertical FOV, 16:9 aspect, near 0.1, far 100.
        projection_matrix[0][0] = fixed_t'(0.9742785792574936 * (2.0 ** FRAC_W));
        projection_matrix[1][1] = fixed_t'(1.7320508075688772 * (2.0 ** FRAC_W));
        projection_matrix[2][2] = fixed_t'(1.0010010010010010 * (2.0 ** FRAC_W));
        projection_matrix[2][3] = fixed_t'(-0.1001001001001001 * (2.0 ** FRAC_W));
        projection_matrix[3][2] = ONE;
    end

    // Engine result matrix
    wire signed [DATA_W-1:0] engine_result_matrix [0:3][0:3];

    // PV register
    logic signed [DATA_W-1:0] PV_matrix [0:3][0:3];
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 4; i ++) begin
                for (int j = 0; j < 4; j ++) begin
                    PV_matrix[i][j] <= '0;
                end
            end
        end else if (PV_reg_en) begin
            for (int i = 0; i < 4; i ++) begin
                for (int j = 0; j < 4; j ++) begin
                    PV_matrix[i][j] <= engine_result_matrix[i][j];
                end
            end
        end
    end

    // Left matrix mux
    logic signed [DATA_W-1:0] left_matrix [0:3][0:3];

    always_comb begin
        case (left_matrix_select) 
            2'b00: begin
                for (int i = 0; i < 4; i ++) begin
                    for (int j = 0; j < 4; j ++) begin
                        left_matrix[i][j] = engine_result_matrix[i][j];
                    end
                end
            end
            2'b01: begin
                for (int i = 0; i < 4; i ++) begin
                    for (int j = 0; j < 4; j ++) begin
                        left_matrix[i][j] = camera_translation_matrix[i][j];
                    end
                end
            end
            2'b10: begin
                for (int i = 0; i < 4; i ++) begin
                    for (int j = 0; j < 4; j ++) begin
                        left_matrix[i][j] = projection_matrix[i][j];
                    end
                end
            end
            2'b11: begin
                for (int i = 0; i < 4; i ++) begin
                    for (int j = 0; j < 4; j ++) begin
                        left_matrix[i][j] = PV_matrix[i][j];
                    end
                end
            end
        endcase
    end
    
    // Vector counter
    logic [2:0] engine_vec_counter;
    logic [1:0] right_matrix_column;

    always_ff @(posedge clk) begin
        if (rst || reset_vec_counter) begin
            engine_vec_counter <= 3'b000;
        end else if (advance_vec_counter) begin
            engine_vec_counter <= engine_vec_counter + 3'b001;
        end
    end

    assign right_matrix_column = engine_vec_counter[1:0];

    // Right matrix mux
    wire signed [DATA_W-1:0] inverse_output_matrix [0:3][0:3];

    always_comb begin
        if (right_matrix_select) begin
            for (int i = 0; i < 4; i ++) begin
                for (int j = 0; j < 4; j ++) begin
                    right_matrix[i][j] = inverse_output_matrix[i][j];
                end
            end
        end else begin
            for (int i = 0; i < 4; i ++) begin
                for (int j = 0; j < 4; j ++) begin
                    right_matrix[i][j] = right_matrix_stored[i][j];
                end
            end
        end
    end

    // Right vector muxes
    logic signed [DATA_W-1:0] right_matrix [0:3][0:3];
    logic signed [DATA_W-1:0] engine_vec [0:3];

    always_comb begin
        for (int row = 0; row < 4; row++) begin
            if (vector_select) begin
                engine_vec[row] = i_vertex[row];
            end else begin
                engine_vec[row] = right_matrix[row][right_matrix_column];
            end
        end
    end

    MatVecEngine #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) engine (
        .clk           (clk),
        .rst           (rst),

        .i_mat_valid   (engine_mat_in_valid),
        .o_mat_ready   (engine_mat_in_ready),
        .i_matrix      (left_matrix),
        .i_matrix_mode (engine_operation),

        .i_vec_valid   (engine_vec_in_valid),
        .o_vec_ready   (engine_vec_in_ready),
        .i_vec         (engine_vec),

        .o_vec_valid   (engine_vec_out_valid),
        .i_vec_ready   (engine_vec_out_ready),
        .o_vec         (o_result_vertex),

        .o_mat_valid   (engine_mat_out_valid),
        .i_mat_ready   (engine_mat_out_ready),
        .o_mat         (engine_result_matrix)
    );

    // Camera inverse
    CameraInverse #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) inverse (
        .clk             (clk),
        .rst             (rst),

        .i_matrix        (engine_result_matrix),
        .i_matrix_valid  (inverse_mat_in_valid),
        .o_matrix_ready  (inverse_mat_in_ready),

        .o_inverse       (inverse_output_matrix),
        .o_inverse_valid (inverse_mat_out_valid),
        .i_inverse_ready (inverse_mat_out_ready)
    );

    // -------------------------------------------------------------------------
    // Control
    // -------------------------------------------------------------------------

    // States
    localparam logic [3:0] STATE_IDLE        = 4'b0000;
    localparam logic [3:0] STATE_CAMERA_M1   = 4'b0001;
    localparam logic [3:0] STATE_CAMERA_M2   = 4'b0010;
    localparam logic [3:0] STATE_CAMERA_M3   = 4'b0011;
    localparam logic [3:0] STATE_CAMERA_I    = 4'b0100;
    localparam logic [3:0] STATE_CAMERA_M4   = 4'b0101;
    localparam logic [3:0] STATE_DRAIN       = 4'b0110;
    localparam logic [3:0] STATE_OBJECT_M1   = 4'b0111;
    localparam logic [3:0] STATE_LOAD_PVO    = 4'b1000;

    logic [3:0]  state;
    logic [3:0]  next_state;


    assign camera_accept = i_camera_valid && o_camera_ready;
    assign object_accept = i_object_valid && o_object_ready;
    assign vertex_accept = i_vertex_valid && o_vertex_ready;

    // Requesters hold updates until the drain is complete and ready asserts.
    assign update_requested = i_camera_valid || i_object_valid;
    assign o_camera_ready = (state == STATE_DRAIN) &&
                            (outstanding_vertices == 0);
    assign o_object_ready = (state == STATE_DRAIN) &&
                            (outstanding_vertices == 0) && PV_valid && !i_camera_valid;
    // Finish an already-presented stalled vertex before stopping admission.
    assign allow_vertices = (state == STATE_IDLE) && PVO_valid &&
                            (!update_requested || vertex_stalled);
    assign o_vertex_ready = allow_vertices && engine_vec_in_ready;

    assign store_camera = camera_accept;
    assign reset_vec_counter = (state != next_state);
    // Counter stays at zero while in IDLE state (when doing vector stuff)
    assign advance_vec_counter = engine_operation &&
                                 engine_vec_in_valid && engine_vec_in_ready &&
                                 engine_vec_counter < 3'd4;

    // The engine has three vertex pipeline stages, so three bits cover occupancy.
    assign forward_vertex_results = (outstanding_vertices != 0);
    assign result_accept = o_result_valid && i_result_ready;
    assign load_PVO = (state == STATE_LOAD_PVO) &&
                      engine_mat_out_valid && engine_mat_out_ready &&
                      engine_mat_in_valid && engine_mat_in_ready;

    always_ff @(posedge clk) begin
        if (rst) begin
            outstanding_vertices <= 0;
            vertex_stalled       <= 0;
            PV_valid             <= 0;
            PVO_valid            <= 0;
        end else begin
            // Increment vertices count if vertex enters, decrement if exits
            case ({vertex_accept, result_accept})
                2'b10: outstanding_vertices <= outstanding_vertices + 3'd1;
                2'b01: outstanding_vertices <= outstanding_vertices - 3'd1;
                default: ;
            endcase
            vertex_stalled <= (state == STATE_IDLE) &&
                              engine_vec_in_valid && !engine_vec_in_ready;
            if (camera_accept) begin
                PV_valid  <= 0;
                PVO_valid <= 0;
            end else begin
                if (PV_reg_en) begin
                    PV_valid <= 1;
                end

                if (object_accept) begin
                    PVO_valid <= 0;
                end else if (load_PVO) begin
                    PVO_valid <= 1;
                end
            end
        end
    end

    assign o_result_valid = forward_vertex_results && engine_vec_out_valid;
    assign engine_vec_out_ready = forward_vertex_results ? i_result_ready : 1'b1;

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        engine_operation      = 1'b1;

        engine_vec_in_valid   = 1'b0;
        engine_mat_in_valid   = 1'b0;
        engine_mat_out_ready  = 1'b0;
        inverse_mat_in_valid  = 1'b0;
        inverse_mat_out_ready = 1'b0;

        PV_reg_en             = 1'b0;
        left_matrix_select    = 2'b00;
        
        right_matrix_select   = 1'b0;
        vector_select         = 1'b0;

        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
                right_matrix_stored[i][j] = '0;
            end
        end

        case (state)
            STATE_IDLE: begin
                engine_operation = 1'b0;
                vector_select = 1'b1;
                engine_vec_in_valid = allow_vertices && i_vertex_valid;

                if (update_requested && (!vertex_stalled || vertex_accept)) begin
                    next_state = STATE_DRAIN;
                end
            end
            STATE_DRAIN: begin
                engine_operation = 1'b0;
                if (camera_accept)
                    next_state = STATE_CAMERA_M1;
                else if (object_accept)
                    next_state = STATE_OBJECT_M1;
                else if (!update_requested)
                    next_state = STATE_IDLE;
            end
            STATE_CAMERA_M1: begin
                engine_vec_in_valid = engine_vec_counter < 3'd4;
                engine_mat_out_ready = 1'b1;
                left_matrix_select = 2'b1;

                // T * Rz
                right_matrix_stored[0][0] =  camera_cos[2];
                right_matrix_stored[0][1] = -camera_sin[2];
                right_matrix_stored[1][0] =  camera_sin[2];
                right_matrix_stored[1][1] =  camera_cos[2];
                right_matrix_stored[2][2] = ONE;
                right_matrix_stored[3][3] = ONE;

                if (engine_mat_out_valid && engine_mat_out_ready) begin
                    next_state = STATE_CAMERA_M2;
                end
            end
            STATE_CAMERA_M2: begin
                engine_vec_in_valid = engine_vec_counter < 3'd4;
                engine_mat_out_ready = 1'b1;

                // (T * Rz) * Ry
                right_matrix_stored[0][0] =  camera_cos[1];
                right_matrix_stored[0][2] =  camera_sin[1];
                right_matrix_stored[1][1] = ONE;
                right_matrix_stored[2][0] = -camera_sin[1];
                right_matrix_stored[2][2] =  camera_cos[1];
                right_matrix_stored[3][3] = ONE;
                
                if (engine_mat_out_valid && engine_mat_out_ready) begin
                    next_state = STATE_CAMERA_M3;
                end
            end
            STATE_CAMERA_M3: begin
                engine_vec_in_valid = engine_vec_counter < 3'd4;

                // (T * Rz * Ry) * Rx
                right_matrix_stored[0][0] = ONE;
                right_matrix_stored[1][1] =  camera_cos[0];
                right_matrix_stored[1][2] = -camera_sin[0];
                right_matrix_stored[2][1] =  camera_sin[0];
                right_matrix_stored[2][2] =  camera_cos[0];
                right_matrix_stored[3][3] = ONE;

                inverse_mat_in_valid = engine_mat_out_valid;
                engine_mat_out_ready = inverse_mat_in_ready;

                if (engine_mat_out_valid && engine_mat_out_ready) begin
                    next_state = STATE_CAMERA_I;
                end
            end
            STATE_CAMERA_I:  begin
                inverse_mat_out_ready = 1'b1;

                if (inverse_mat_out_valid && inverse_mat_out_ready) begin
                    next_state = STATE_CAMERA_M4;
                end
            end
            STATE_CAMERA_M4: begin
                engine_vec_in_valid = engine_vec_counter < 3'd4;
                engine_mat_out_ready = 1'b1;
                PV_reg_en = engine_mat_out_valid && engine_mat_out_ready;
                left_matrix_select = 2'b10;
                right_matrix_select = 1'b1;

                if (engine_mat_out_valid && engine_mat_out_ready) begin
                    next_state = STATE_IDLE;
                end
            end
            STATE_OBJECT_M1: begin
                engine_vec_in_valid = engine_vec_counter < 3'd4;
                left_matrix_select = 2'b11;

                // PV * O
                for (int i = 0; i < 4; i++) begin
                    for (int j = 0; j < 4; j++) begin
                        right_matrix_stored[i][j] = object_matrix_stored[i][j];
                    end
                end

                // Hold the result for the PVO load state.
                if (engine_mat_out_valid) begin
                    next_state = STATE_LOAD_PVO;
                end
            end
            STATE_LOAD_PVO: begin
                engine_operation = 1'b0;
                left_matrix_select = 2'b00;
                engine_mat_in_valid = engine_mat_out_valid;
                // The input pipeline is empty after the object calculation.
                engine_mat_out_ready = 1'b1;

                if (load_PVO) begin
                    next_state = STATE_IDLE;
                end
            end
            default: begin
                next_state = STATE_IDLE;
            end
        endcase

        if (engine_operation && engine_vec_in_valid && engine_vec_counter == 0)
            engine_mat_in_valid = 1'b1;
    end

endmodule

`endif // VIEW_VERTEX_PROCESSOR_SV
