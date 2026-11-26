`ifndef SCENE_CONTROLLER_SV
`define SCENE_CONTROLLER_SV

`timescale 1ns/1ps

module SceneController #(
    parameter int DATA_W      = 18,
    parameter int OBJECT_ID_W = 3,
    parameter int FRAC_W      = 10
) (
    input  logic clk,
    input  logic rst,

    input  logic                     i_frame_valid,
    output logic                     o_frame_ready,
    input  logic signed [DATA_W-1:0] i_camera_translation [0:2],
    input  logic signed [DATA_W-1:0] i_camera_sin [0:2],
    input  logic signed [DATA_W-1:0] i_camera_cos [0:2],


    // ViewVertexProcessor interface
    output logic                     o_vvp_camera_valid,
    input  logic                     i_vvp_camera_ready,
    output logic signed [DATA_W-1:0] o_vvp_camera_translation [0:2],
    output logic signed [DATA_W-1:0] o_vvp_camera_sin [0:2],
    output logic signed [DATA_W-1:0] o_vvp_camera_cos [0:2],

    output logic                     o_vvp_object_valid,
    input  logic                     i_vvp_object_ready,

    output logic                     o_vvp_vertex_valid,
    input  logic                     i_vvp_vertex_ready,
    output logic signed [DATA_W-1:0] o_vvp_vertex [0:3],

    // ObjectMatrixBuilder interface
    output logic                     o_omb_object_valid,
    input  logic                     i_omb_object_ready,
    output logic [OBJECT_ID_W-1:0]   o_omb_object_id,
    output logic signed [DATA_W-1:0] o_omb_translation [0:2],
    output logic signed [DATA_W-1:0] o_omb_scale [0:2],
    output logic signed [DATA_W-1:0] o_omb_sin [0:2],
    output logic signed [DATA_W-1:0] o_omb_cos [0:2],

    input  logic                     i_omb_object_mat_valid,
    output logic                     o_omb_object_mat_ready,

    // EdgeAssembler interface
    output logic                     o_ea_object_valid,
    input  logic                     i_ea_object_ready,
    output logic [OBJECT_ID_W-1:0]   o_ea_object_id,
    output logic [3:0]               o_ea_vertex_count,
    output logic [4:0]               o_ea_edge_base,
    output logic [5:0]               o_ea_edge_count,
    output logic [15:0]              o_ea_color,

    input  logic                     i_ea_object_done,

    // Memory Interface
    output logic                     o_mem_object_read_en,
    output logic [2:0]               o_mem_object_read_addr,
    input  logic [12*DATA_W+36-1:0]  i_mem_object_data,
    input  logic                     i_mem_object_valid,

    output logic                     o_mem_vertex_read_en,
    output logic [4:0]               o_mem_vertex_read_addr,
    input  logic [3*DATA_W-1:0]      i_mem_vertex_data,
    input  logic                     i_mem_vertex_valid
);
    localparam int OBJECT_COUNT = 7;

    logic last_object_done;

    logic frame_accept;
    assign frame_accept = i_frame_valid && o_frame_ready;

    // -------------------------------------------------------------------------
    // Camera FSM
    // -------------------------------------------------------------------------

    localparam logic [1:0] C_IDLE        = 2'b00;
    localparam logic [1:0] C_SEND_CAMERA = 2'b01;
    localparam logic [1:0] C_RUN_FRAME   = 2'b10;

    logic [1:0] c_state;
    logic [1:0] next_c_state;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 3; i ++) begin
                o_vvp_camera_translation[i] <= '0;
                o_vvp_camera_sin[i]         <= '0;
                o_vvp_camera_cos[i]         <= '0;
            end 
        end else if (frame_accept) begin
            for (int i = 0; i < 3; i ++) begin
                o_vvp_camera_translation[i] <= i_camera_translation[i];
                o_vvp_camera_sin[i]         <= i_camera_sin[i];
                o_vvp_camera_cos[i]         <= i_camera_cos[i];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            c_state <= C_IDLE;
        end else begin
            c_state <= next_c_state;
        end
    end

    always_comb begin
        next_c_state = c_state;

        o_frame_ready  = 1'b0;
        o_vvp_camera_valid = 1'b0;
        
        case (c_state)
            C_IDLE: begin
                o_frame_ready = 1'b1;

                if (frame_accept) begin
                    next_c_state = C_SEND_CAMERA;
                end
            end
            C_SEND_CAMERA: begin
                o_vvp_camera_valid = 1'b1;

                if (o_vvp_camera_valid && i_vvp_camera_ready) begin
                    next_c_state = C_RUN_FRAME;
                end
            end
            C_RUN_FRAME: begin
                if (last_object_done) begin
                    next_c_state = C_IDLE;
                end
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Object FSM
    // -------------------------------------------------------------------------

    localparam logic [2:0] O_IDLE            = 3'b000;
    localparam logic [2:0] O_REQUEST_DATA    = 3'b001;
    localparam logic [2:0] O_WAIT_DATA       = 3'b010;
    localparam logic [2:0] O_SEND_TO_BUILDER = 3'b011;
    localparam logic [2:0] O_WAIT_HANDOFF    = 3'b100;

    logic [2:0] o_state;
    logic [2:0] next_o_state;

    logic [OBJECT_ID_W-1:0]   prepare_object_id;
    logic                     object_handoff;

    logic [12*DATA_W+36-1:0]  object_data;
    logic [4:0]               object_vertex_base;
    logic [3:0]               object_vertex_count;
    logic [4:0]               object_edge_base;
    logic [5:0]               object_edge_count;
    logic [15:0]              object_color;
    logic signed [DATA_W-1:0] object_translation [0:2];
    logic signed [DATA_W-1:0] object_scale [0:2];
    logic signed [DATA_W-1:0] object_sin [0:2];
    logic signed [DATA_W-1:0] object_cos [0:2];
    
    assign o_mem_object_read_addr = prepare_object_id;

    assign {object_vertex_base, object_vertex_count,
            object_edge_base, object_edge_count,
            object_translation[0], object_translation[1], object_translation[2],
            object_scale[0], object_scale[1], object_scale[2],
            object_sin[0], object_sin[1], object_sin[2],
            object_cos[0], object_cos[1], object_cos[2],
            object_color} = object_data;

    assign o_omb_object_id = prepare_object_id;

    always_comb begin
        for (int i = 0; i < 3; i ++) begin
                o_omb_translation[i] = object_translation[i];
                o_omb_scale[i]       = object_scale[i];
                o_omb_sin[i]         = object_sin[i];
                o_omb_cos[i]         = object_cos[i];
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            prepare_object_id <= '0;
        end else if (frame_accept) begin
            prepare_object_id <= '0;
        end else if (object_handoff && prepare_object_id != 3'(OBJECT_COUNT - 1)) begin
            prepare_object_id <= prepare_object_id + 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            object_data <= '0;
        end else if (i_mem_object_valid) begin
            object_data <= i_mem_object_data;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            o_state <= O_IDLE;
        end else begin
            o_state <= next_o_state;
        end
    end

    always_comb begin
        next_o_state = o_state;

        o_mem_object_read_en = 1'b0;
        o_omb_object_valid   = 1'b0;

        case (o_state)
            O_IDLE: begin
                if (frame_accept) begin
                    next_o_state = O_REQUEST_DATA;
                end
            end
            O_REQUEST_DATA: begin
                o_mem_object_read_en   = 1'b1;

                next_o_state = O_WAIT_DATA;
            end
            O_WAIT_DATA: begin
                if (i_mem_object_valid) begin
                    next_o_state = O_SEND_TO_BUILDER;
                end
            end
            O_SEND_TO_BUILDER: begin
                o_omb_object_valid = 1'b1;

                if (o_omb_object_valid && i_omb_object_ready) begin
                    next_o_state = O_WAIT_HANDOFF;
                end
            end
            O_WAIT_HANDOFF: begin
                if (object_handoff) begin
                    if (prepare_object_id == OBJECT_ID_W'(OBJECT_COUNT - 1)) begin
                        next_o_state = O_IDLE;
                    end else begin
                        next_o_state = O_REQUEST_DATA;
                    end
                end
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Vertex FSM
    // -------------------------------------------------------------------------

    logic [1:0] v_state;
    logic [1:0] next_v_state;

    localparam logic [1:0] V_WAIT_PREPARED   = 2'b00;
    localparam logic [1:0] V_SEND_MATRIX     = 2'b01;
    localparam logic [1:0] V_STREAM_VERTICES = 2'b10;

    logic [4:0] current_vertex_base;
    logic [3:0] current_vertex_count;
    logic [3:0] requested_vertices;
    logic [3:0] sent_vertices;
    logic       vertex_accept;
    logic       descriptor_pending;

    assign object_handoff = o_vvp_object_valid && i_vvp_object_ready;
    assign vertex_accept  = o_vvp_vertex_valid && i_vvp_vertex_ready;

    always_ff @(posedge clk) begin
        if (rst) begin
            current_vertex_base  <= '0;
            current_vertex_count <= '0;
            requested_vertices   <= '0;
            sent_vertices        <= '0;
        end else if (object_handoff) begin
            current_vertex_base  <= object_vertex_base;
            current_vertex_count <= object_vertex_count;

            requested_vertices <= '0;
            sent_vertices      <= '0;
        end else begin
            if (o_mem_vertex_read_en) begin
                requested_vertices <= requested_vertices + 1'b1;
            end
            if (vertex_accept) begin
                sent_vertices <= sent_vertices + 1'b1;
            end
        end
    end

    // Vertex FIFO
    logic [3*DATA_W-1:0] vertex_fifo [0:1];
    logic                fifo_write_ptr;
    logic                fifo_read_ptr;
    logic [1:0]          fifo_count;
    logic                read_pending;
    logic                fifo_push;
    logic [2:0]          reserved_slots;

    // SceneMemory returns one cycle later. reserve a slot for it
    assign reserved_slots         = {1'b0, fifo_count} + {2'b0, read_pending};
    assign fifo_push              = read_pending && i_mem_vertex_valid;
    assign o_mem_vertex_read_addr = current_vertex_base + 5'(requested_vertices);

    assign o_vvp_vertex[0] = vertex_fifo[fifo_read_ptr][3*DATA_W-1:2*DATA_W];
    assign o_vvp_vertex[1] = vertex_fifo[fifo_read_ptr][2*DATA_W-1:DATA_W];
    assign o_vvp_vertex[2] = vertex_fifo[fifo_read_ptr][DATA_W-1:0];
    assign o_vvp_vertex[3] = DATA_W'(1) << FRAC_W;  // w = ONE

    always_ff @(posedge clk) begin
        if (rst || object_handoff) begin
            fifo_write_ptr <= 1'b0;
            fifo_read_ptr  <= 1'b0;
            fifo_count     <= '0;
            read_pending   <= 1'b0;
        end else begin
            read_pending <= o_mem_vertex_read_en;

            if (fifo_push) begin
                vertex_fifo[fifo_write_ptr] <= i_mem_vertex_data;
                fifo_write_ptr              <= !fifo_write_ptr;
            end
            if (vertex_accept) begin
                fifo_read_ptr <= !fifo_read_ptr;
            end

            case ({fifo_push, vertex_accept})
                2'b10: fifo_count <= fifo_count + 1'b1;
                2'b01: fifo_count <= fifo_count - 1'b1;
                default: ;  // Nothing
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            v_state <= V_WAIT_PREPARED;
        end else begin
            v_state <= next_v_state;
        end
    end

    always_comb begin
        next_v_state = v_state;

        o_vvp_object_valid     = 1'b0;
        o_omb_object_mat_ready = 1'b0;
        o_vvp_vertex_valid     = 1'b0;
        o_mem_vertex_read_en   = 1'b0;

        case (v_state)
            V_WAIT_PREPARED: begin
                // Camera has been sent, OMB is waiting for handoff, object 
                // matrix is valid and there is no pending object descriptor
                if (c_state == C_RUN_FRAME && o_state == O_WAIT_HANDOFF &&
                    i_omb_object_mat_valid && !descriptor_pending) begin
                        
                    next_v_state = V_SEND_MATRIX;
                end
            end
            V_SEND_MATRIX: begin
                o_vvp_object_valid     = i_omb_object_mat_valid;
                o_omb_object_mat_ready = i_vvp_object_ready;

                if (object_handoff) begin
                    next_v_state = V_STREAM_VERTICES;
                end
            end
            V_STREAM_VERTICES: begin
                o_vvp_vertex_valid = (fifo_count != 0);

                o_mem_vertex_read_en = 
                    (requested_vertices < current_vertex_count) &&
                    ((reserved_slots < 3'd2) || vertex_accept);
                    
                if (vertex_accept && 
                    sent_vertices == current_vertex_count - 4'b1) begin

                    next_v_state = V_WAIT_PREPARED;        
                end
            end
        endcase
    end

    // EdgeAssembler stuff
    logic assembler_accept;

    assign assembler_accept = o_ea_object_valid && i_ea_object_ready;
    assign o_ea_object_valid = descriptor_pending;

    always_ff @(posedge clk) begin
        if (rst) begin
            o_ea_object_id     <= '0;
            o_ea_vertex_count  <= '0;
            o_ea_edge_base     <= '0;
            o_ea_edge_count    <= '0;
            o_ea_color         <= '0;
            
            descriptor_pending <= 1'b0;
        end else if (object_handoff) begin
            o_ea_object_id     <= prepare_object_id;
            o_ea_vertex_count  <= object_vertex_count;
            o_ea_edge_base     <= object_edge_base;
            o_ea_edge_count    <= object_edge_count;
            o_ea_color         <= object_color;

            descriptor_pending <= 1'b1;
        end else if (assembler_accept) begin
            descriptor_pending <= 1'b0;
        end
    end

    logic [$clog2(OBJECT_COUNT + 1)-1:0] completed_objects;

    always_ff @(posedge clk) begin
        if (rst) begin
            completed_objects <= '0;
        end else if (frame_accept) begin
            completed_objects <= '0;
        end else if ((c_state = C_RUN_FRAME) && i_ea_object_done) begin
            completed_objects <= completed_objects + 1'b1;
        end
    end

    assign last_object_done = 
        (c_state == C_RUN_FRAME) &&
        i_ea_object_done &&
        (completed_objects == OBJECT_COUNT - 1);

endmodule

`endif // SCENE_CONTROLLER_SV
