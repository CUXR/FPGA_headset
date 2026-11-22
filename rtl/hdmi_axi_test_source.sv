// AXI4-Stream Video color-bar source for Xilinx AXI4-Stream to Video Out.
// One 24-bit RGB pixel per accepted transfer.
// TUSER[0] = start of frame, TLAST = end of line.
module hdmi_axi_test_source #(
    parameter int unsigned H_ACTIVE = 640,
    parameter int unsigned V_ACTIVE = 480
) (
    input  logic        aclk,
    input  logic        aresetn,
    output logic [23:0] m_axis_video_tdata,
    output logic        m_axis_video_tvalid,
    input  logic        m_axis_video_tready,
    output logic        m_axis_video_tlast,
    output logic [0:0]  m_axis_video_tuser
);
    localparam int unsigned X_BITS = (H_ACTIVE > 1) ? $clog2(H_ACTIVE) : 1;
    localparam int unsigned Y_BITS = (V_ACTIVE > 1) ? $clog2(V_ACTIVE) : 1;

    logic [X_BITS-1:0] x;
    logic [Y_BITS-1:0] y;
    logic [2:0] bar;

    // Stay valid whenever reset is deasserted. Hold all outputs on backpressure.
    assign m_axis_video_tvalid = aresetn;
    assign m_axis_video_tuser  = (x == 0 && y == 0);
    assign m_axis_video_tlast  = (x == H_ACTIVE - 1);

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            x <= '0;
            y <= '0;
        end else if (m_axis_video_tvalid && m_axis_video_tready) begin
            if (x == H_ACTIVE - 1) begin
                x <= '0;
                if (y == V_ACTIVE - 1)
                    y <= '0;
                else
                    y <= y + 1'b1;
            end else begin
                x <= x + 1'b1;
            end
        end
    end

    // 8 evenly-spaced vertical bars, including non-multiples-of-8 widths.
    // Constrain H_ACTIVE >= 8 for eight non-empty bars.
    always_comb begin
        bar = (x * 8) / H_ACTIVE;
        case (bar)
            3'd0: m_axis_video_tdata = 24'hFFFFFF; // White
            3'd1: m_axis_video_tdata = 24'hFFFF00; // Yellow
            3'd2: m_axis_video_tdata = 24'h00FFFF; // Cyan
            3'd3: m_axis_video_tdata = 24'h00FF00; // Green
            3'd4: m_axis_video_tdata = 24'hFF00FF; // Magenta
            3'd5: m_axis_video_tdata = 24'hFF0000; // Red
            3'd6: m_axis_video_tdata = 24'h0000FF; // Blue
            default: m_axis_video_tdata = 24'h000000; // Black
        endcase
    end
endmodule

