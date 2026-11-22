
module hdmi_test_pattern (
    input  logic        pixel_clk,
    input  logic        rst,

    output logic [23:0] rgb,
    output logic        hsync,
    output logic        vsync,
    output logic        vde
);

    // 640x480 @ approximately 60 Hz
    localparam H_ACTIVE = 640;
    localparam H_FRONT  = 16;
    localparam H_SYNC   = 96;
    localparam H_BACK   = 48;
    localparam H_TOTAL  = 800;

    localparam V_ACTIVE = 480;
    localparam V_FRONT  = 10;
    localparam V_SYNC   = 2;
    localparam V_BACK   = 33;
    localparam V_TOTAL  = 525;

    logic [9:0] x;
    logic [9:0] y;

    // Pixel position counters
    always_ff @(posedge pixel_clk) begin
        if (rst) begin
            x <= 0;
            y <= 0;
        end
        else if (x == H_TOTAL-1) begin
            x <= 0;

            if (y == V_TOTAL-1)
                y <= 0;
            else
                y <= y + 1'b1;
        end
        else begin
            x <= x + 1'b1;
        end
    end

    // Active-low sync pulses
    assign hsync = ~((x >= H_ACTIVE + H_FRONT) &&
                     (x < H_ACTIVE + H_FRONT + H_SYNC));

    assign vsync = ~((y >= V_ACTIVE + V_FRONT) &&
                     (y < V_ACTIVE + V_FRONT + V_SYNC));

    // Visible video region
    assign vde = (x < H_ACTIVE) && (y < V_ACTIVE);

    // RGB color bars
    always_comb begin
        rgb = 24'h000000;

        if (vde) begin
            if      (x < 80)  rgb = 24'hFFFFFF; // White
            else if (x < 160) rgb = 24'hFFFF00; // Yellow
            else if (x < 240) rgb = 24'h00FFFF; // Cyan
            else if (x < 320) rgb = 24'h00FF00; // Green
            else if (x < 400) rgb = 24'hFF00FF; // Magenta
            else if (x < 480) rgb = 24'hFF0000; // Red
            else if (x < 560) rgb = 24'h0000FF; // Blue
            else              rgb = 24'h000000; // Black
        end
    end

endmodule

