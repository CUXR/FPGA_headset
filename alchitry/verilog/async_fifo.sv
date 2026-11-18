// Translated from fpgahead/luc/async_fifo.luc.
module async_fifo #(
    parameter int WIDTH = 4,
    parameter int ENTRIES = 8,
    parameter int SYNC_STAGES = 3
) (
    input  logic             wclk,
    input  logic             wrst,
    input  logic [WIDTH-1:0] din,
    input  logic             wput,
    output logic             full,
    input  logic             rclk,
    input  logic             rrst,
    output logic [WIDTH-1:0] dout,
    input  logic             rget,
    output logic             empty
);
    localparam int ADDR_SIZE = $clog2(ENTRIES);

    logic [ADDR_SIZE-1:0] waddr, raddr;
    logic [ADDR_SIZE-1:0] gwsync, grsync;
    (* ASYNC_REG = "TRUE" *) logic [ADDR_SIZE-1:0] wsync [0:SYNC_STAGES-1];
    (* ASYNC_REG = "TRUE" *) logic [ADDR_SIZE-1:0] rsync [0:SYNC_STAGES-1];

    wire [ADDR_SIZE-1:0] next_write = waddr + 1'b1;
    wire [ADDR_SIZE-1:0] read_addr = raddr + (rget && !empty);
    wire [ADDR_SIZE-1:0] waddr_gray = (waddr >> 1) ^ waddr;
    wire [ADDR_SIZE-1:0] raddr_gray = (raddr >> 1) ^ raddr;
    wire [ADDR_SIZE-1:0] next_write_gray = (next_write >> 1) ^ next_write;

    assign full = next_write_gray == wsync[SYNC_STAGES-1];
    assign empty = raddr_gray == rsync[SYNC_STAGES-1];

    always_ff @(posedge wclk) begin
        if (wrst) begin
            waddr  <= '0;
            gwsync <= '0;
            for (int i = 0; i < SYNC_STAGES; i++)
                wsync[i] <= '0;
        end else begin
            if (wput && !full)
                waddr <= next_write;
            gwsync   <= waddr_gray;
            wsync[0] <= grsync;
            for (int i = 1; i < SYNC_STAGES; i++)
                wsync[i] <= wsync[i-1];
        end
    end

    always_ff @(posedge rclk) begin
        if (rrst) begin
            raddr  <= '0;
            grsync <= '0;
            for (int i = 0; i < SYNC_STAGES; i++)
                rsync[i] <= '0;
        end else begin
            raddr    <= read_addr;
            grsync   <= raddr_gray;
            rsync[0] <= gwsync;
            for (int i = 1; i < SYNC_STAGES; i++)
                rsync[i] <= rsync[i-1];
        end
    end

    simple_dual_port_ram #(.WIDTH(WIDTH), .ENTRIES(ENTRIES)) ram (
        .wclk(wclk),
        .rclk(rclk),
        .waddr(waddr),
        .raddr(read_addr),
        .write_enable(wput && !full),
        .write_data(din),
        .read_data(dout)
    );
endmodule
