// Translated from fpgahead/luc/lru_cache.luc.
module lru_cache #(
    parameter int ENTRIES = 4,
    parameter int WORD_SIZE = 16,
    parameter int AGE_BITS = 3
) (
    input  logic                                    clk,
    input  logic                                    rst,
    input  logic [23+$clog2(128/WORD_SIZE):0]         wr_addr,
    input  logic [WORD_SIZE-1:0]                     wr_data,
    input  logic                                    wr_valid,
    output logic                                    wr_ready,
    input  logic [23+$clog2(128/WORD_SIZE):0]         rd_addr,
    input  logic                                    rd_cmd_valid,
    output logic                                    rd_ready,
    output logic [WORD_SIZE-1:0]                     rd_data,
    output logic                                    rd_data_valid,
    input  logic                                    flush,
    output logic                                    flush_ready,
    input  memory_pkg::mem_out_t                     mem_out,
    output memory_pkg::mem_in_t                      mem_in
);
    localparam int WORDS_PER_LINE = 128 / WORD_SIZE;
    localparam int BYTES_PER_WORD = WORD_SIZE / 8;
    localparam int SUB_ADDR_BITS = $clog2(WORDS_PER_LINE);
    localparam int ADDR_SIZE = 24 + SUB_ADDR_BITS;
    localparam int ENTRY_BITS = ENTRIES > 1 ? $clog2(ENTRIES) : 1;
    localparam int WORD_INDEX_BITS = SUB_ADDR_BITS > 0 ? SUB_ADDR_BITS : 1;

    typedef logic [ENTRY_BITS-1:0] entry_id_t;
    typedef logic [WORD_INDEX_BITS-1:0] word_index_t;
    typedef enum logic [2:0] {
        IDLE, PREP_WRITE_ENTRY, PREP_READ_ENTRY, FLUSH,
        WRITE_DATA, WRITE_CMD, READ_CMD, WAIT_READ
    } state_t;
    typedef enum logic {WRITE_IDLE, WRITE_PUT} write_state_t;
    typedef enum logic {READ_IDLE, READ_FETCH} read_state_t;

    logic [ENTRIES-1:0] active = '0, next_active;
    state_t state = IDLE, next_state;
    write_state_t write_state = WRITE_IDLE, next_write_state;
    read_state_t read_state = READ_IDLE, next_read_state;
    logic [ENTRIES-1:0][WORDS_PER_LINE-1:0][WORD_SIZE-1:0] buffer = '0, next_buffer;
    logic [ENTRIES-1:0][24:0] address = '0, next_address;
    logic [ENTRIES-1:0] written = '0, next_written;
    logic [ENTRIES-1:0][WORDS_PER_LINE-1:0] valid = '0, next_valid;
    logic [ENTRIES-1:0][AGE_BITS-1:0] age = '0, next_age;
    entry_id_t active_entry = '0, next_active_entry;
    logic [WORD_SIZE-1:0] read_data = '0, next_read_data;
    logic read_valid = '0, next_read_valid;
    logic read_pending = '0, next_read_pending;
    logic [ADDR_SIZE-1:0] read_addr = '0, next_read_addr;
    logic write_pending = '0, next_write_pending;
    logic [ADDR_SIZE-1:0] write_addr = '0, next_write_addr;
    logic [WORD_SIZE-1:0] write_data = '0, next_write_data;
    logic [ENTRIES-1:0] old_active = '0, next_old_active;
    state_t return_state = IDLE, next_return_state;

    wire word_index_t rd_addr_word = WORDS_PER_LINE == 1 ? '0 : word_index_t'(rd_addr);
    wire word_index_t wr_addr_word = WORDS_PER_LINE == 1 ? '0 : word_index_t'(wr_addr);
    wire word_index_t read_addr_word = WORDS_PER_LINE == 1 ? '0 : word_index_t'(read_addr);
    wire word_index_t write_addr_word = WORDS_PER_LINE == 1 ? '0 : word_index_t'(write_addr);

    always_ff @(posedge clk) begin
        if (rst) begin
            active <= '0;
            state <= IDLE;
            write_state <= WRITE_IDLE;
            read_state <= READ_IDLE;
        end else begin
            active <= next_active;
            state <= next_state;
            write_state <= next_write_state;
            read_state <= next_read_state;
        end
    end

    always_ff @(posedge clk) begin
        buffer <= next_buffer;
        address <= next_address;
        written <= next_written;
        valid <= next_valid;
        age <= next_age;
        active_entry <= next_active_entry;
        read_data <= next_read_data;
        read_valid <= next_read_valid;
        read_pending <= next_read_pending;
        read_addr <= next_read_addr;
        write_pending <= next_write_pending;
        write_addr <= next_write_addr;
        write_data <= next_write_data;
        old_active <= next_old_active;
        return_state <= next_return_state;
    end

    always_comb begin
        logic handled;
        entry_id_t oldest_entry, entry;
        logic [AGE_BITS-1:0] max_age;

        next_active = active;
        next_state = state;
        next_write_state = write_state;
        next_read_state = read_state;
        next_buffer = buffer;
        next_address = address;
        next_written = written;
        next_valid = valid;
        next_age = age;
        next_active_entry = active_entry;
        next_read_data = read_data;
        next_read_valid = read_valid;
        next_read_pending = read_pending;
        next_read_addr = read_addr;
        next_write_pending = write_pending;
        next_write_addr = write_addr;
        next_write_data = write_data;
        next_old_active = old_active;
        next_return_state = return_state;

        mem_in.enable = 0;
        mem_in.wr_data = buffer[active_entry];
        mem_in.cmd = 'x;
        mem_in.addr = {address[active_entry], 3'b000};
        mem_in.wr_enable = 0;
        flush_ready = state == IDLE;
        wr_ready = write_state == WRITE_IDLE;
        rd_ready = read_state == READ_IDLE;
        rd_data = read_data;
        rd_data_valid = read_valid;

        next_read_valid = 0;

        // only write out valid bytes (0 = write)
        for (int i = 0; i < WORDS_PER_LINE; i++)
            mem_in.wr_mask[i*BYTES_PER_WORD+:BYTES_PER_WORD] = {BYTES_PER_WORD{~valid[active_entry][i]}};

        // Keep track of the oldest entry (the one to replace)
        max_age = 0;
        oldest_entry = 0;
        entry = 'x;

        handled = 0;
        for (int i = 0; i < ENTRIES; i++) begin
            if (!handled) begin
                if (!active[i]) begin // entry isn't in use
                    oldest_entry = entry_id_t'(i); // use the inactive entry
                    handled = 1; // stop the for loop
                end
                if (age[i] > max_age) begin
                    max_age = age[i];
                    oldest_entry = entry_id_t'(i);
                end
            end
        end

        case (read_state)
            READ_IDLE: begin
                if (rd_cmd_valid) begin
                    for (int i = 0; i < ENTRIES; i++) // increment all the entry ages
                        if (!(&age[i]))
                            next_age[i] = age[i] + 1;

                    handled = 0;
                    for (int i = 0; i < ENTRIES; i++) begin
                        if (!handled && active[i] && valid[i][rd_addr_word] && (address[i] == 25'(rd_addr[ADDR_SIZE-1:SUB_ADDR_BITS]))) begin
                            handled = 1;
                            next_read_valid = 1;
                            next_read_data = buffer[i][rd_addr_word];
                            next_age[i] = 0; // reset the age on an access
                        end
                    end
                    if (!handled) begin // entry isn't in the cache
                        next_read_pending = 1;
                        next_read_addr = rd_addr;
                        next_read_state = READ_FETCH;
                    end
                end

            end
            READ_FETCH: begin
                next_read_pending = 1;

                handled = 0;
                for (int i = 0; i < ENTRIES; i++) begin
                    if (!handled && active[i] && valid[i][read_addr_word] && (address[i] == 25'(read_addr[ADDR_SIZE-1:SUB_ADDR_BITS]))) begin
                        handled = 1;
                        next_read_valid = 1;
                        next_read_data = buffer[i][read_addr_word];
                        next_age[i] = 0; // reset the age on an access
                    end
                end
                if (handled) begin
                    next_read_pending = 0;
                    next_read_state = READ_IDLE;
                end
            end
            default: begin end
        endcase

        case (write_state)
            WRITE_IDLE: begin
                if (wr_valid) begin
                    for (int i = 0; i < ENTRIES; i++) // increment all the entry ages
                        if (!(&age[i]))
                            next_age[i] = age[i] + 1;

                    handled = 0;
                    for (int i = 0; i < ENTRIES; i++) begin
                        if (!handled && active[i] && (address[i] == 25'(wr_addr[ADDR_SIZE-1:SUB_ADDR_BITS]))) begin
                            handled = 1;
                            next_written[i] = 1;
                            next_valid[i][wr_addr_word] = 1;
                            next_buffer[i][wr_addr_word] = wr_data;
                            next_age[i] = 0; // reset the age on an access
                        end
                    end

                    if (!handled) begin // entry isn't in the cache
                        next_write_pending = 1;
                        next_write_data = wr_data;
                        next_write_addr = wr_addr;
                        next_write_state = WRITE_PUT;
                    end
                end

            end
            WRITE_PUT: begin
                next_write_pending = 1;

                handled = 0;
                for (int i = 0; i < ENTRIES; i++) begin
                    if (!handled && active[i] && (address[i] == 25'(write_addr[ADDR_SIZE-1:SUB_ADDR_BITS]))) begin
                        handled = 1;
                        next_written[i] = 1;
                        next_valid[i][write_addr_word] = 1;
                        next_buffer[i][write_addr_word] = write_data;
                        next_age[i] = 0; // reset the age on an access
                    end
                end

                if (handled) begin
                    next_write_pending = 0;
                    next_write_state = WRITE_IDLE;
                end
            end
            default: begin end
        endcase

        case (state)
            IDLE: begin
                if (flush) begin // flush command takes priority
                    next_active = 0;
                    next_old_active = active;
                    next_state = FLUSH;

                end else if (read_pending) begin // Read command is pending
                    entry = oldest_entry; // default to oldest

                    // check for a cache line that was written but never read (ie only partially valid)
                    handled = 0;
                    for (int i = 0; i < ENTRIES; i++) begin
                        if (!handled && active[i] && valid[i][read_addr_word] && (address[i] == 25'(read_addr[ADDR_SIZE-1:SUB_ADDR_BITS]))) begin
                            handled = 1;
                            entry = entry_id_t'(i);
                        end
                    end

                    // save the entry
                    next_active_entry = entry;

                    // if entry is active and not our address
                    if (active[entry] && address[entry] != 25'(read_addr[ADDR_SIZE-1:SUB_ADDR_BITS])) begin
                        // need to mark inactive then wait for any potential writes
                        next_active[entry] = 0;
                        next_state = PREP_READ_ENTRY;
                    end else begin
                        next_state = READ_CMD;
                        next_address[entry] = {1'b0, read_addr[ADDR_SIZE-1:SUB_ADDR_BITS]};
                        if (address[entry] != 25'(read_addr[ADDR_SIZE-1:SUB_ADDR_BITS]))
                            next_valid[entry] = 0;
                    end

                end else if (write_pending) begin // Write command is pending
                    // if oldest entry is active
                    if (active[oldest_entry]) begin
                        // need to mark inactive then wait for any potential writes
                        next_active[oldest_entry] = 0;
                        next_active_entry = oldest_entry;
                        next_state = PREP_WRITE_ENTRY;
                    end else begin // oldest entry can be cleared
                        // prep the new entry
                        next_written[oldest_entry] = 0;
                        next_valid[oldest_entry] = 0;
                        next_address[oldest_entry] = {1'b0, write_addr[ADDR_SIZE-1:SUB_ADDR_BITS]};
                        next_age[oldest_entry] = 0;
                        next_active[oldest_entry] = 1;
                        next_write_pending = 0;
                    end
                end

            end
            PREP_WRITE_ENTRY: begin
                // if entry was written to
                if (written[active_entry]) begin
                    // write the data out
                    next_return_state = PREP_WRITE_ENTRY;
                    next_state = WRITE_DATA;
                end else begin
                    // prep the new entry
                    next_written[active_entry] = 0;
                    next_valid[active_entry] = 0;
                    next_address[active_entry] = {1'b0, write_addr[ADDR_SIZE-1:SUB_ADDR_BITS]};
                    next_age[active_entry] = 0;
                    next_active[active_entry] = 1;
                    next_state = IDLE;
                    next_write_pending = 0;
                end

            end
            PREP_READ_ENTRY: begin
                if (written[active_entry]) begin
                    // write the data out
                    next_return_state = PREP_READ_ENTRY;
                    next_state = WRITE_DATA;
                end else begin
                    // read in new active_entry
                    next_state = READ_CMD;
                    next_address[active_entry] = {1'b0, read_addr[ADDR_SIZE-1:SUB_ADDR_BITS]};
                    next_valid[active_entry] = 0;
                end

            end
            FLUSH: begin
                next_state = IDLE; // default to returning if no entries to flush

                handled = 0;
                for (int i = 0; i < ENTRIES; i++) begin
                    // find the first entry that needs to be flushed
                    if (!handled && old_active[i] && written[i]) begin
                        handled = 1;
                        next_active_entry = entry_id_t'(i);
                        next_state = WRITE_DATA;
                        next_old_active[i] = 0;
                        next_return_state = FLUSH;
                    end
                end

            end
            WRITE_DATA: begin
                mem_in.wr_enable = 1;
                if (mem_out.wr_rdy) begin
                    next_state = WRITE_CMD;
                end

            end
            WRITE_CMD: begin
                mem_in.enable = 1;
                mem_in.cmd = 3'd0; // write
                if (mem_out.rdy) begin
                    next_state = return_state;
                    next_written[active_entry] = 0;
                end

            end
            READ_CMD: begin
                mem_in.enable = 1;
                mem_in.cmd = 3'd1; // read
                if (mem_out.rdy) begin
                    next_state = WAIT_READ;
                end

            end
            WAIT_READ: begin
                if (mem_out.rd_valid) begin
                    for (int i = 0; i < WORDS_PER_LINE; i++)
                        if (!valid[active_entry][i]) // only read in unwritten words
                            next_buffer[active_entry][i] = mem_out.rd_data[WORD_SIZE*i+:WORD_SIZE];

                    // prep the new entry
                    next_active[active_entry] = 1;
                    next_valid[active_entry] = '1; // everything valid
                    next_age[active_entry] = 0;
                    next_read_pending = 0;
                    next_written[active_entry] = 0;

                    next_state = IDLE;
                end
            end
            default: begin end
        endcase
    end
endmodule
