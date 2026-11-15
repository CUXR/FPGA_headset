// Translated from fpgahead/source/alchitry_top.luc.
module alchitry_top (
    input  logic       clk,     // 100 MHz clock
    input  logic       rst_n,   // Reset button (active low)
    output logic [7:0] led,
    input  logic       usb_rx,
    output logic       usb_tx
);
    wire rst;

    // External Alchitry library dependency, as in the Lucid project.
    reset_conditioner reset_cond (
        .clk (clk),
        .in  (~rst_n),
        .out (rst)
    );

    assign led    = 8'h00;
    assign usb_tx = usb_rx;
endmodule
