// Translated from fpgahead/luc/ddr_arbiter.luc.
module ddr_arbiter #(
    parameter int DEVICES = 2
) (
    input  logic                  clk,
    input  logic                  rst,
    output memory_pkg::mem_in_t   master_in,
    input  memory_pkg::mem_out_t  master_out,
    input  memory_pkg::mem_in_t   [DEVICES-1:0] device_in,
    output memory_pkg::mem_out_t  [DEVICES-1:0] device_out
);
    localparam int DEVICE_BITS = $clog2(DEVICES);
    typedef logic [DEVICE_BITS-1:0] device_id_t;
    typedef enum logic [1:0] {WAIT_CMD, WAIT_WRITE, WAIT_RDY} state_t;

    state_t state, next_state;
    device_id_t device, next_device;
    device_id_t read_device, request_device;
    logic request_put;

    fifo #(.WIDTH(DEVICE_BITS), .ENTRIES(256)) read_requests (
        .clk(clk),
        .rst(rst),
        .din(request_device),
        .wput(request_put),
        .full(),
        .dout(read_device),
        .rget(master_out.rd_valid),
        .empty()
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            state  <= WAIT_CMD;
            device <= '0;
        end else begin
            state  <= next_state;
            device <= next_device;
        end
    end

    always_comb begin
        logic selected;

        next_state = state;
        next_device = device;
        request_device = 'x;
        request_put = 1'b0;
        master_in = '0;
        master_in.addr = 'x;
        master_in.wr_data = 'x;
        device_out = '0;
        selected = 1'b0;

        case (state)
            WAIT_CMD: begin
                for (int i = 0; i < DEVICES; i++) begin
                    if (!selected && (device_in[i].enable || device_in[i].wr_enable)) begin
                        selected = 1'b1;
                        next_device = device_id_t'(i);
                        master_in = device_in[i];
                        device_out[i] = master_out;
                        if (device_in[i].enable && device_in[i].cmd == 3'b001) begin
                            request_put = 1'b1;
                            request_device = device_id_t'(i);
                            if (!master_out.rdy)
                                next_state = WAIT_RDY;
                        end else begin
                            next_state = master_out.wr_rdy ? WAIT_RDY : WAIT_WRITE;
                        end
                    end
                end
            end

            WAIT_WRITE: begin
                master_in = device_in[device];
                device_out[device] = master_out;
                if (master_out.wr_rdy) begin
                    if (device_in[device].enable && master_out.rdy)
                        next_state = WAIT_CMD;
                    else
                        next_state = WAIT_RDY;
                end
            end

            WAIT_RDY: begin
                master_in = device_in[device];
                device_out[device] = master_out;
                if (master_out.rdy)
                    next_state = WAIT_CMD;
            end
            default: begin end
        endcase

        for (int i = 0; i < DEVICES; i++) begin
            device_out[i].rd_data = 'x;
            device_out[i].rd_valid = 1'b0;
        end
        if (master_out.rd_valid) begin
            device_out[read_device].rd_data = master_out.rd_data;
            device_out[read_device].rd_valid = 1'b1;
        end
    end
endmodule
