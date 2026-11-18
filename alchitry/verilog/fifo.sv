// Translated from fpgahead/luc/fifo.luc.
module fifo #(
    parameter int WIDTH = 4,
    parameter int ENTRIES = 8
) (
    input  logic             clk,
    input  logic             rst,
    input  logic [WIDTH-1:0] din,
    input  logic             wput,
    output logic             full,
    output logic [WIDTH-1:0] dout,
    input  logic             rget,
    output logic             empty
);
    localparam int ADDR_SIZE = $clog2(ENTRIES);

    logic [ADDR_SIZE-1:0] waddr, waddr_delay, raddr;
    wire [ADDR_SIZE-1:0] next_write = waddr + 1'b1;
    wire [ADDR_SIZE-1:0] read_addr = raddr + (rget && !empty);

    // Reserve one slot to distinguish full from empty.
    assign full = next_write == raddr;
    assign empty = raddr == waddr_delay;

    always_ff @(posedge clk) begin
        if (rst) begin
            waddr       <= '0;
            waddr_delay <= '0;
            raddr       <= '0;
        end else begin
            if (wput && !full)
                waddr <= next_write;
            waddr_delay <= waddr;
            raddr <= read_addr;
        end
    end

    simple_dual_port_ram #(.WIDTH(WIDTH), .ENTRIES(ENTRIES)) ram (
        .wclk(clk),
        .rclk(clk),
        .waddr(waddr),
        .raddr(read_addr),
        .write_enable(wput && !full),
        .write_data(din),
        .read_data(dout)
    );
endmodule
