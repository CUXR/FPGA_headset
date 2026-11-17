`include "SceneMemory.sv"
`include "ViewVertexProcessor.sv"
`include "ObjectMatrixBuilder.sv"

module HeadsetTop #(
    parameter int H_RES  = 1280,
    parameter int V_RES  = 720,
    parameter int DATA_W = 18,
    parameter int FRAC_W = 10
)(
    input  logic clk,
    input  logic rst,
);

    SceneMemory #(
        .DATA_W(DATA_W)
    ) scene_mem (
        .clk (clk),
        .rst (rst),

        .i_object_read_en ()
    )

endmodule