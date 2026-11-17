`ifndef EDGE_ASSEMBLER_SV
`define EDGE_ASSEMBLER_SV

`timescale 1ns/1ps

module EdgeAssembler #(
    parameter int DATA_W      = 18,
    parameter int OBJECT_ID_W = 3
) (
    input  logic clk,
    input  logic rst,

    input  logic [OBJECT_ID_W-1:0]   i_object_id,
    input  logic [3:0]               i_vertex_count,
    input  logic [4:0]               i_edge_base,
    input  logic [5:0]               i_edge_count,
    input  logic [15:0]              i_color,
    input  logic                     i_object_valid,
    output logic                     o_object_ready,

    input  logic signed [DATA_W-1:0] i_vertex [0:3],
    input  logic [OBJECT_ID_W-1:0]   i_v_object_id,
    input  logic                     i_vertex_valid,
    output logic                     o_vertex_ready,

    output logic                     o_edge_read_en,
    output logic [4:0]               o_edge_read_addr,
    input  logic [5:0]               i_edge_data,
    input  logic                     i_edge_valid,

    output logic signed [DATA_W-1:0] o_vertex_1 [0:3],
    output logic signed [DATA_W-1:0] o_vertex_2 [0:3],
    output logic [OBJECT_ID_W-1:0]   o_object_id,
    output logic [15:0]              o_color,
    output logic                     o_vertex_valid,
    input  logic                     i_vertex_ready,

    output logic                     o_object_done
);

    localparam int MAX_OBJECT_VERTICES = 8;
    localparam int MAX_OBJECT_EDGES = 12;

    localparam logic [2:0] STATE_IDLE             = 3'b000;
    localparam logic [2:0] STATE_COLLECT_VERTICES = 3'b001;
    localparam logic [2:0] STATE_REQUEST_EDGE     = 3'b010;
    localparam logic [2:0] STATE_WAIT_EDGE        = 3'b011;
    localparam logic [2:0] STATE_OUTPUT_LINE      = 3'b100;

    logic [2:0]               state;
    logic [2:0]               next_state;
    logic                     capture_edge;

    // -------------------------------------------------------------------------
    // IDLE State
    // -------------------------------------------------------------------------

    logic [OBJECT_ID_W-1:0]   object_id;
    logic [3:0]               vertex_count;
    logic [4:0]               edge_base;
    logic [5:0]               edge_count;
    logic [15:0]              color;

    always_ff @(posedge clk) begin
        if (rst) begin
            object_id    <= '0;
            vertex_count <= '0;
            edge_base    <= '0;
            edge_count   <= '0;
            color        <= '0;
        end else if (i_object_valid && o_object_ready) begin
            object_id      <= i_object_id;
            vertex_count   <= i_vertex_count;
            edge_base      <= i_edge_base;
            edge_count     <= i_edge_count;
            color          <= i_color;
        end
    end

    // -------------------------------------------------------------------------
    // COLLECT_VERTICES State
    // -------------------------------------------------------------------------

    localparam int VEC_COUNTER_W = $clog2(MAX_OBJECT_VERTICES);

    logic [VEC_COUNTER_W-1:0] vector_counter;
    logic signed [DATA_W-1:0] vector_buffer [0:3][0:7];

    always_ff @(posedge clk) begin
        if (rst) begin
            vector_counter <= '0;
        end else if (i_object_valid && o_object_ready) begin
            vector_counter <= '0;
        end else if (i_vertex_valid && o_vertex_ready) begin
            vector_counter <= vector_counter + 1'b1;
            for (int i = 0; i < 4; i ++) begin
                vector_buffer[i][vector_counter] <= i_vertex[i];
            end
        end
    end

    // -------------------------------------------------------------------------
    // REQUEST_EDGE State
    // -------------------------------------------------------------------------

    localparam int EDGE_COUNTER_W = $clog2(MAX_OBJECT_EDGES);

    logic [EDGE_COUNTER_W-1:0] edge_counter;
    logic [5:0]                edge_data;   
    logic [2:0]                vector_1_addr;
    logic [2:0]                vector_2_addr;

    assign vector_1_addr = edge_data[5:3];
    assign vector_2_addr = edge_data[2:0];
    assign o_edge_read_addr = edge_base + 5'(edge_counter);

    always_ff @(posedge clk) begin
        if (rst) begin
            edge_counter <= '0;
        end else if (i_object_valid && o_object_ready) begin
            edge_counter <= '0;
        end else if (o_vertex_valid && i_vertex_ready) begin
            edge_counter <= edge_counter + 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            edge_data <= '0;
        end else if (capture_edge) begin
            edge_data    <= i_edge_data;
        end
    end

    // -------------------------------------------------------------------------
    // OUTPUT_LINE State
    // -------------------------------------------------------------------------

    assign o_object_id = object_id;
    assign o_color = color;

    always_comb begin
        for (int i = 0; i < 4; i ++) begin
            o_vertex_1[i] = vector_buffer[i][vector_1_addr];
            o_vertex_2[i] = vector_buffer[i][vector_2_addr];
        end
    end

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
        
        o_object_ready = 1'b0;
        o_vertex_ready = 1'b0;
        o_edge_read_en = 1'b0;
        o_vertex_valid = 1'b0;
        o_object_done  = 1'b0;
        capture_edge   = 1'b0;

        case (state)
            STATE_IDLE: begin
                o_object_ready = 1'b1;

                if (i_object_valid && o_object_ready) begin
                    next_state = STATE_COLLECT_VERTICES;
                end
            end
            STATE_COLLECT_VERTICES: begin
                o_vertex_ready = 1'b1;

                if (i_vertex_valid && o_vertex_ready && 
                    4'(vector_counter) == vertex_count - 4'd1) begin
                    
                    next_state = STATE_REQUEST_EDGE;
                end
            end
            STATE_REQUEST_EDGE: begin
                o_edge_read_en = 1'b1;

                next_state = STATE_WAIT_EDGE;
            end
            STATE_WAIT_EDGE: begin
                if (i_edge_valid) begin
                    capture_edge = 1'b1;
                    next_state = STATE_OUTPUT_LINE;
                end
            end
            STATE_OUTPUT_LINE: begin
                o_vertex_valid = 1'b1;

                if (o_vertex_valid && i_vertex_ready) begin
                    if (6'(edge_counter) == edge_count - 6'd1) begin
                        o_object_done = 1'b1;
                        next_state = STATE_IDLE;
                    end else begin
                        next_state = STATE_REQUEST_EDGE;
                    end
                end
            end
            default: begin
                next_state = STATE_IDLE;
            end
        endcase
    end

endmodule

`endif // EDGE_ASSEMBLER_SV
