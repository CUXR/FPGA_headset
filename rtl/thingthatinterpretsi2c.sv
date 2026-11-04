module thingthatinterpretsi2c
(
    input logic clk,
    input logic rst,
    input logic [6:0] slave_address,
    input logic [7:0] data,
    input logic sda,
    output logic scl
    input logic begin_transaction,
    output logic transaction_active
    );
   
    // States 
    localparam IDLE = 4'd0;
    localparam START = 4'd1;
    localparam SEND_SLAVE_ADDR = 4'd2;
    localparam ACK_WAIT = 4'd3;
    localparam SEND_RW_BIT = 4'd4;
    localparam SEND_DATA = 4'd5;
    localparam READ_DATA = 4'd6;
    localparam DATA_ACK_WAIT = 4'd7;
    localparam STOP = 4'd8;
    localparam DONE = 4'd9;

    // SCL Divider

    logic [3:0] counter;
    logic do_i2c;
    always_ff @(posedge clk) begin
        if (rst) begin
            counter <= 3'b0;
            scl <= 1;
            do_i2c <= 0;
        end
        else if (state == IDLE) begin
            scl <= 1'b1;
            counter <= 3'b0;
            do_i2c <= 1'b0;
        end
        else if (counter == 3'd7) begin
            counter <= 3'b0;
            scl <= ~scl;
            do_i2c <= 1'b1;
        end
        else begin
            counter <= counter + 1;
            do_i2c <= 1'b0;
        end
    end

    logic [3:0] state;
    logic [3:0] next_state;

    // State Register
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= 4'b0;
        end
        else if (do_i2c) begin
            state <= next_state;
        end
    end

    logic sda_dr;
    assign sda = (sda_dr) ? 1'bz : 1'b0;
    // Next State Transitions
    always_comb begin

        case (state) begin
            (IDLE) : next_state = (begin_transaction) ? START : IDLE;
        endcase

    end

    // Outputs
    always_comb begin

        case (state) begin
            (IDLE) :  begin
                transaction_active = 1'b0;
                sda_dr = 1'b1;
        endcase
