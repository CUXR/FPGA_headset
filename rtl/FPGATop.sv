`ifndef FPGA_TOP_SV
`define FPGA_TOP_SV

`timescale 1ns/1ps

module FpgaTop (
    input  logic       clk_100,

    output logic       TMDS_Clk_p,
    output logic       TMDS_Clk_n,
    output logic [2:0] TMDS_Data_p,
    output logic [2:0] TMDS_Data_n
);

    logic        pix_clk;
    logic        pix_aresetn;

    logic [23:0] video_tdata;
    logic        video_tvalid;
    logic        video_tready;
    logic        video_tlast;
    logic [0:0]  video_tuser;

    HDMI_BLOCK hdmi_block (
        .clk_100         (clk_100),
        .TMDS_Clk_p      (TMDS_Clk_p),
        .TMDS_Clk_n      (TMDS_Clk_n),
        .TMDS_Data_p     (TMDS_Data_p),
        .TMDS_Data_n     (TMDS_Data_n),
        .pix_clk         (pix_clk),
        .pix_aresetn     (pix_aresetn),
        .video_in_tdata  (video_tdata),
        .video_in_tvalid (video_tvalid),
        .video_in_tready (video_tready),
        .video_in_tlast  (video_tlast),
        .video_in_tuser  (video_tuser)
    );

    hdmi_axi_test_source test_source (
        .aclk                (pix_clk),
        .aresetn             (pix_aresetn),
        .m_axis_video_tdata  (video_tdata),
        .m_axis_video_tvalid (video_tvalid),
        .m_axis_video_tready (video_tready),
        .m_axis_video_tlast  (video_tlast),
        .m_axis_video_tuser  (video_tuser)
    );

endmodule

`endif // FPGA_TOP_SV