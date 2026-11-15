module thingthatinterpretsi2c #(
    parameter int HALF_PERIOD = 750,
    parameter int READ_BYTES = 1
)(
    input logic clk,
    input logic rst,
    input logic [6:0] slave_address,
    input logic [7:0] data,
    inout wire sda,
    output wire scl,
    input logic begin_transaction,
    output logic transaction_active,
    input logic r_w, // 0 = read, 1 = write
    input logic ack_pull, 
    input logic [7:0] register_address,
    output logic [8*READ_BYTES-1:0] read_data, // first byte in [7:0]
    output logic ack_error,
    output logic transaction_done
    );

    // States
    localparam IDLE = 4'd0;
    localparam START = 4'd1;
    localparam SEND_SLAVE_ADDR = 4'd2;
    localparam ACK_WAIT = 4'd3;
    localparam SEND_REG_ADDR = 4'd4;
    localparam SEND_DATA = 4'd5;
    localparam READ_DATA = 4'd6;
    localparam DATA_ACK_WAIT = 4'd7;
    localparam STOP = 4'd8;
    localparam DONE = 4'd9;
    localparam RESTART = 4'd10;

    // clog2 = round up log 2 to get widths
    localparam int COUNTER_W = (HALF_PERIOD > 1) ? $clog2(HALF_PERIOD) : 1;
    localparam int BYTE_W = (READ_BYTES > 1) ? $clog2(READ_BYTES) : 1;
    logic [COUNTER_W-1:0] counter;
    logic [BYTE_W-1:0] byte_counter;
    logic [2:0] bit_counter;
    logic [3:0] state;
    logic [3:0] next_state;
    logic [3:0] prev_state;
    logic phase;
    logic do_i2c;
    logic read_phase;
    logic write_transaction;
    logic begin_prev;
    logic [6:0] address_latched;
    logic [7:0] register_latched;
    logic [7:0] data_latched;
    logic [7:0] send_byte;
    logic sda_dr;
    logic scl_dr;

    assign do_i2c = (counter == HALF_PERIOD - 1);
    assign sda = sda_dr ? 1'bz : 1'b0;
    assign scl = scl_dr ? 1'bz : 1'b0;
    assign transaction_active = (state != IDLE);

    // Clock Divider and State Registers
    always_ff @(posedge clk) begin
        if (rst) begin
            counter <= '0;
            byte_counter <= '0;
            bit_counter <= 3'd7;
            state <= IDLE;
            prev_state <= IDLE;
            phase <= 1'b0;
            read_phase <= 1'b0;
            write_transaction <= 1'b0;
            begin_prev <= 1'b0;
            address_latched <= '0;
            register_latched <= '0;
            data_latched <= '0;
            read_data <= '0;
            ack_error <= 1'b0;
            transaction_done <= 1'b0;
        end
        else begin
            begin_prev <= begin_transaction;
            transaction_done <= 1'b0;
            if (state == IDLE) begin
                counter <= '0;
                phase <= 1'b0;
                if (begin_transaction && !begin_prev) begin
                    state <= START;
                    address_latched <= slave_address;
                    register_latched <= register_address;
                    data_latched <= data;
                    write_transaction <= r_w;
                    read_phase <= 1'b0;
                    read_data <= '0;
                    ack_error <= 1'b0;
                    byte_counter <= '0;
                    bit_counter <= 3'd7;
                end
            end
            else if (do_i2c) begin
                counter <= '0;
                if (state == START || state == DONE || phase) begin
                    phase <= 1'b0;
                    state <= next_state;
                    if (state == SEND_SLAVE_ADDR || state == SEND_REG_ADDR ||
                        state == SEND_DATA || state == READ_DATA) begin
                        if (state == READ_DATA)
                            read_data[8*byte_counter + bit_counter] <= sda;
                        if (bit_counter == 0) begin
                            bit_counter <= 3'd7;
                            prev_state <= state;
                        end
                        else bit_counter <= bit_counter - 1'b1;
                    end
                    if (state == ACK_WAIT && sda != 1'b0)
                        ack_error <= 1'b1;
                    if (state == RESTART)
                        read_phase <= 1'b1;
                    if (state == DATA_ACK_WAIT && byte_counter != READ_BYTES - 1)
                        byte_counter <= byte_counter + 1'b1;
                    if (state == DONE)
                        transaction_done <= 1'b1;
                end
                else phase <= 1'b1;
            end
            else counter <= counter + 1'b1;
        end
    end

    // Next State Transitions
    always_comb begin
        next_state = state;
        case (state)
            IDLE : next_state = START;
            START : next_state = SEND_SLAVE_ADDR;
            SEND_SLAVE_ADDR, SEND_REG_ADDR, SEND_DATA :
                if (bit_counter == 0) next_state = ACK_WAIT;
            ACK_WAIT : begin
                if (sda != 1'b0) next_state = STOP;
                else begin
                    case (prev_state)
                        SEND_SLAVE_ADDR : next_state = read_phase ? READ_DATA : SEND_REG_ADDR;
                        SEND_REG_ADDR : next_state = write_transaction ? SEND_DATA : RESTART;
                        SEND_DATA : next_state = STOP;
                        default : next_state = STOP;
                    endcase
                end
            end
            RESTART : next_state = START;
            READ_DATA : if (bit_counter == 0) next_state = DATA_ACK_WAIT;
            DATA_ACK_WAIT : next_state = (byte_counter == READ_BYTES - 1) ? STOP : READ_DATA;
            STOP : next_state = DONE;
            DONE : next_state = IDLE;
            default : next_state = IDLE;
        endcase
    end

    // Outputs
    always_comb begin
        send_byte = {address_latched, read_phase};
        if (state == SEND_REG_ADDR) send_byte = register_latched;
        else if (state == SEND_DATA) send_byte = data_latched;
        sda_dr = 1'b1;
        scl_dr = phase;
        case (state)
            IDLE, DONE : scl_dr = 1'b1;
            START : begin
                scl_dr = 1'b1;
                sda_dr = 1'b0;
            end
            SEND_SLAVE_ADDR, SEND_REG_ADDR, SEND_DATA : sda_dr = send_byte[bit_counter];
            DATA_ACK_WAIT : sda_dr = (byte_counter == READ_BYTES - 1);
            STOP : sda_dr = 1'b0;
            default : begin end
        endcase
    end
endmodule
