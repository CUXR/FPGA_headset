module thingthatinterpretsi2c
(
    input logic clk,
    input logic rst,
    input logic [6:0] slave_address,
    input logic [7:0] data,
    inout logic sda,
    output logic scl,
    input logic begin_transaction,
    output logic transaction_active,
    input logic r_w, // 0 = read, 1 = write
    input logic ack_pull
    );
   
    //notes 
    //rw bit - pull low for writing, pull up (high imp) for reading
    // States 
    localparam IDLE = 4'd0;
    localparam START = 4'd1;
    localparam SEND_SLAVE_ADDR = 4'd2;
    localparam ACK_WAIT = 4'd4;
    localparam SEND_RW_BIT = 4'd3;
    localparam SEND_DATA = 4'd5;
    localparam READ_DATA = 4'd6;
    localparam DATA_ACK_WAIT = 4'd7;
    localparam STOP = 4'd8;
    localparam DONE = 4'd9;
    localparam logic [6:0] SLAVE_ADDR = 7'b0;

    // Counters

    // Clock Divider and Early State Handling
    logic [9:0] counter;
    logic do_i2c;
    always_ff @(posedge clk) begin
        if (rst) begin
            counter <= 10'b0;
            scl <= 1;
            do_i2c <= 0;
        end
        else if (state == IDLE || state == START) begin
            scl <= 1'b1;
            counter <= 10'b0;
            do_i2c <= 1'b0;
        end
        else if (state == SEND_SLAVE_ADDR && prev_state == START) begin
            counter <= 0;
            scl <= 0;
            do_i2c <= 0;
        end
        else if (counter == 10'd749) begin
            counter <= 10'b0;
            scl <= ~scl;
            do_i2c <= 1'b1;
        end
        else begin
            counter <= counter + 1;
            do_i2c <= 1'b0;
        end
    end

    // Start State Timing Counter
    logic [9:0] start_counter;
    always_ff @(posedge clk) begin
        if (rst || state != START) begin
            start_counter <= 1'b0;
        end
        else if (state == START && start_counter < 10'd599) begin
            start_counter <= start_counter + 1;
        end
    end
    
    assign end_start = (start_counter == 10'd599);

    // Slave Address Counter
    logic [3:0] slv_counter;
    always_ff @(posedge clk) begin
        if (rst) begin
            slv_counter <= 4'd6;
        end
        else if (do_i2c && state == SEND_SLAVE_ADDR && !scl && slv_counter != 4'b0) begin
            slv_counter <= slv_counter - 1;
        end
    end

    logic [3:0] state;
    logic [3:0] next_state;
    logic [3:0] prev_state;

    // State Registers
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= 4'b0;
        end
        else if (state == IDLE || state == START) begin
            state <= next_state;
        end
        else if (do_i2c) begin
            state <= next_state;
        end
    end

    logic sda_dr;
    assign sda = (sda_dr) ? 1'bz : 1'b0;
// 914-619-0498
    always_ff @(posedge clk) begin
        if (rst) begin
            prev_state <= 4'b0;
        end
        else begin
            prev_state <= state;
        end
    end

    // Next State Transitions
    always_comb begin

        case (state) 
            (IDLE) : next_state = (begin_transaction) ? START : IDLE;
            (START) : next_state = (end_start) ? SEND_SLAVE_ADDR : START;
            (SEND_SLAVE_ADDR) : next_state = (do_i2c && !scl && slv_counter == 4'b0) ? SEND_RW_BIT : SEND_SLAVE_ADDR;
            (SEND_RW_BIT) : next_state = (do_i2c) ? ACK_WAIT : SEND_RW_BIT;
            (ACK_WAIT) : begin
                if (do_i2c) begin
                    if (ack_pull) begin
                        next_state = (r_w) ? SEND_DATA : READ_DATA;
                    end
                    else begin
                        next_state = STOP;
                    end
                end
                else begin
                    next_state = ACK_WAIT;
        endcase

    end

    // Outputs
    always_comb begin

        case (state) 
            (IDLE) :  begin
                transaction_active = 1'b0;
                sda_dr = 1'b1;
            end
            (START) : begin
                transaction_active = 1'b1;
                sda_dr = 1'b0;
            end
            (SEND_SLAVE_ADDR) : begin
                transaction_active = 1'b1;
                sda_dr = SLAVE_ADDR[slv_counter];
            end
            (SEND_RW_BIT) : begin
                sda_dr = !r_w;
            end
            (ACK_WAIT) : begin
                sda_dr = 1'b1;
            end

        endcase
