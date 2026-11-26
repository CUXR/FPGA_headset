`include "SceneMemory.sv"
`include "SceneController.sv"
`include "ViewVertexProcessor.sv"
`include "ObjectMatrixBuilder.sv"
`include "EdgeAssembler.sv"

`timescale 1ns/1ps

module HeadsetTop #(
    parameter int H_RES       = 1280,
    parameter int V_RES       = 720,
    parameter int DATA_W      = 18,
    parameter int FRAC_W      = 10,
    parameter int OBJECT_ID_W = 3
) (
    input  logic                               clk,
    input  logic                               rst,

    // External frame request.
    input  logic                               i_frame_valid,
    output logic                               o_frame_ready,

    // Clip-space lines for a downstream clipper or testbench.
    output logic signed [DATA_W-1:0]           o_line_vertex_1 [0:3],
    output logic signed [DATA_W-1:0]           o_line_vertex_2 [0:3],
    output logic        [OBJECT_ID_W-1:0]      o_line_object_id,
    output logic        [15:0]                 o_line_color,
    output logic                               o_line_valid,
    input  logic                               i_line_ready
);

    // Default Python camera: origin, zero rotation, looking along +Z.
    logic signed [DATA_W-1:0] default_camera_translation [0:2];
    logic signed [DATA_W-1:0] default_camera_sin [0:2];
    logic signed [DATA_W-1:0] default_camera_cos [0:2];

    always_comb begin
        for (int i = 0; i < 3; i ++) begin
            default_camera_translation[i] = '0;
            default_camera_sin[i] = '0;
            default_camera_cos[i] = DATA_W'(1) << FRAC_W;
        end
    end

    // -------------------------------------------------------------------------
    // SceneController connections
    // -------------------------------------------------------------------------

    logic                     vvp_camera_valid;
    logic                     vvp_camera_ready;
    logic signed [DATA_W-1:0] vvp_camera_translation [0:2];
    logic signed [DATA_W-1:0] vvp_camera_sin [0:2];
    logic signed [DATA_W-1:0] vvp_camera_cos [0:2];
    logic                     vvp_object_valid;
    logic                     vvp_object_ready;
    logic                     vvp_vertex_valid;
    logic                     vvp_vertex_ready;
    logic signed [DATA_W-1:0] vvp_vertex [0:3];
    logic                     omb_object_valid;
    logic                     omb_object_ready;
    logic [OBJECT_ID_W-1:0]   omb_object_id;
    logic signed [DATA_W-1:0] omb_translation [0:2];
    logic signed [DATA_W-1:0] omb_scale [0:2];
    logic signed [DATA_W-1:0] omb_sin [0:2];
    logic signed [DATA_W-1:0] omb_cos [0:2];
    logic                     omb_object_mat_valid;
    logic                     omb_object_mat_ready;
    logic                     ea_object_valid;
    logic                     ea_object_ready;
    logic [OBJECT_ID_W-1:0]   ea_object_id;
    logic [3:0]               ea_vertex_count;
    logic [4:0]               ea_edge_base;
    logic [5:0]               ea_edge_count;
    logic [15:0]              ea_color;
    logic                     ea_object_done;
    logic                     mem_object_read_en;
    logic [2:0]               mem_object_read_addr;
    logic [12*DATA_W+36-1:0]  mem_object_data;
    logic                     mem_object_valid;
    logic                     mem_vertex_read_en;
    logic [4:0]               mem_vertex_read_addr;
    logic [3*DATA_W-1:0]      mem_vertex_data;
    logic                     mem_vertex_valid;

    // OMB matrix data bypasses the controller; its valid/ready go through it.
    logic [OBJECT_ID_W-1:0]   built_object_id;
    logic signed [DATA_W-1:0] built_object_matrix [0:3][0:3];

    // VVP results go directly to EdgeAssembler, including backpressure.
    logic                     result_valid;
    logic                     result_ready;
    logic [OBJECT_ID_W-1:0]   result_object_id;
    logic signed [DATA_W-1:0] result_vertex [0:3];

    // EdgeAssembler owns SceneMemory's edge read interface.
    logic                     edge_read_en;
    logic [4:0]               edge_read_addr;
    logic [5:0]               edge_data;
    logic                     edge_valid;

    // -------------------------------------------------------------------------
    // Scene controller
    // -------------------------------------------------------------------------

    SceneController #(
        .DATA_W(DATA_W),
        .OBJECT_ID_W(OBJECT_ID_W),
        .FRAC_W(FRAC_W)
    ) scene_controller (
        .clk                      (clk),
        .rst                      (rst),
        .i_frame_valid            (i_frame_valid),
        .o_frame_ready            (o_frame_ready),
        .i_camera_translation     (default_camera_translation),
        .i_camera_sin             (default_camera_sin),
        .i_camera_cos             (default_camera_cos),
        .o_vvp_camera_valid       (vvp_camera_valid),
        .i_vvp_camera_ready       (vvp_camera_ready),
        .o_vvp_camera_translation (vvp_camera_translation),
        .o_vvp_camera_sin         (vvp_camera_sin),
        .o_vvp_camera_cos         (vvp_camera_cos),
        .o_vvp_object_valid       (vvp_object_valid),
        .i_vvp_object_ready       (vvp_object_ready),
        .o_vvp_vertex_valid       (vvp_vertex_valid),
        .i_vvp_vertex_ready       (vvp_vertex_ready),
        .o_vvp_vertex             (vvp_vertex),
        .o_omb_object_valid       (omb_object_valid),
        .i_omb_object_ready       (omb_object_ready),
        .o_omb_object_id          (omb_object_id),
        .o_omb_translation        (omb_translation),
        .o_omb_scale              (omb_scale),
        .o_omb_sin                (omb_sin),
        .o_omb_cos                (omb_cos),
        .i_omb_object_mat_valid   (omb_object_mat_valid),
        .o_omb_object_mat_ready   (omb_object_mat_ready),
        .o_ea_object_valid        (ea_object_valid),
        .i_ea_object_ready        (ea_object_ready),
        .o_ea_object_id           (ea_object_id),
        .o_ea_vertex_count        (ea_vertex_count),
        .o_ea_edge_base           (ea_edge_base),
        .o_ea_edge_count          (ea_edge_count),
        .o_ea_color               (ea_color),
        .i_ea_object_done         (ea_object_done),
        .o_mem_object_read_en     (mem_object_read_en),
        .o_mem_object_read_addr   (mem_object_read_addr),
        .i_mem_object_data        (mem_object_data),
        .i_mem_object_valid       (mem_object_valid),
        .o_mem_vertex_read_en     (mem_vertex_read_en),
        .o_mem_vertex_read_addr   (mem_vertex_read_addr),
        .i_mem_vertex_data        (mem_vertex_data),
        .i_mem_vertex_valid       (mem_vertex_valid)
    );

    // -------------------------------------------------------------------------
    // Scene memory
    // -------------------------------------------------------------------------

    SceneMemory #(
        .DATA_W(DATA_W)
    ) scene_mem (
        .clk                     (clk),
        .rst                     (rst),
        .i_object_read_en        (mem_object_read_en),
        .i_object_read_addr      (mem_object_read_addr),
        .o_object_data           (mem_object_data),
        .o_object_valid          (mem_object_valid),
        .i_vertex_read_en        (mem_vertex_read_en),
        .i_vertex_read_addr      (mem_vertex_read_addr),
        .o_vertex_data           (mem_vertex_data),
        .o_vertex_valid          (mem_vertex_valid),
        .i_edge_read_en          (edge_read_en),
        .i_edge_read_addr        (edge_read_addr),
        .o_edge_data             (edge_data),
        .o_edge_valid            (edge_valid)
    );

    // -------------------------------------------------------------------------
    // Object matrix builder
    // -------------------------------------------------------------------------

    ObjectMatrixBuilder #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W),
        .OBJECT_ID_W(OBJECT_ID_W)
    ) object_matrix_builder (
        .clk                     (clk),
        .rst                     (rst),
        .i_object_valid          (omb_object_valid),
        .o_object_ready          (omb_object_ready),
        .i_object_id             (omb_object_id),
        .i_translation           (omb_translation),
        .i_scale                 (omb_scale),
        .i_sin                   (omb_sin),
        .i_cos                   (omb_cos),
        .o_object_mat_valid      (omb_object_mat_valid),
        .i_object_mat_ready      (omb_object_mat_ready),
        .o_object_id             (built_object_id),
        .o_object_mat            (built_object_matrix)
    );

    // -------------------------------------------------------------------------
    // View/vertex processor
    // -------------------------------------------------------------------------

    ViewVertexProcessor #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W),
        .OBJECT_ID_W(OBJECT_ID_W)
    ) view_vertex_processor (
        .clk                     (clk),
        .rst                     (rst),
        .i_camera_valid          (vvp_camera_valid),
        .o_camera_ready          (vvp_camera_ready),
        .i_camera_translation    (vvp_camera_translation),
        .i_camera_sin            (vvp_camera_sin),
        .i_camera_cos            (vvp_camera_cos),
        .i_object_valid          (vvp_object_valid),
        .o_object_ready          (vvp_object_ready),
        .i_object_id             (built_object_id),
        .i_object_matrix         (built_object_matrix),
        .i_vertex_valid          (vvp_vertex_valid),
        .o_vertex_ready          (vvp_vertex_ready),
        .i_vertex                (vvp_vertex),
        .o_result_valid          (result_valid),
        .i_result_ready          (result_ready),
        .o_result_object_id      (result_object_id),
        .o_result_vertex         (result_vertex)
    );

    // -------------------------------------------------------------------------
    // Edge assembler
    // -------------------------------------------------------------------------

    EdgeAssembler #(
        .DATA_W(DATA_W),
        .OBJECT_ID_W(OBJECT_ID_W)
    ) edge_assembler (
        .clk                     (clk),
        .rst                     (rst),
        .i_object_id             (ea_object_id),
        .i_vertex_count          (ea_vertex_count),
        .i_edge_base             (ea_edge_base),
        .i_edge_count            (ea_edge_count),
        .i_color                 (ea_color),
        .i_object_valid          (ea_object_valid),
        .o_object_ready          (ea_object_ready),
        .i_vertex                (result_vertex),
        .i_v_object_id           (result_object_id),
        .i_vertex_valid          (result_valid),
        .o_vertex_ready          (result_ready),
        .o_edge_read_en          (edge_read_en),
        .o_edge_read_addr        (edge_read_addr),
        .i_edge_data             (edge_data),
        .i_edge_valid            (edge_valid),
        .o_vertex_1              (o_line_vertex_1),
        .o_vertex_2              (o_line_vertex_2),
        .o_object_id             (o_line_object_id),
        .o_color                 (o_line_color),
        .o_vertex_valid          (o_line_valid),
        .i_vertex_ready          (i_line_ready),
        .o_object_done           (ea_object_done)
    );

endmodule
