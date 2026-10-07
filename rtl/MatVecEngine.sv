`ifndef MAT_VEC_ENGINE_SV
`define MAT_VEC_ENGINE_SV

module MatVecEngine#(
parameter int DATA_W = 18
parameter int NUM_COLS = 4
)
(
    // Clock and Reset
    input logic clk,
    input logic rst,

    // Val/Rdy interface IO
    input logic mat_in_val,
    output logic mat_in_rdy,
    input logic vec_in_val,
    output logic vec_in_rdy,

    output logic vec_out_val,
    input logic vec_out_rdy,
    output logic mat_out_val,
    input logic mat_out_rdy,

    // Input Control Signals
    input logic is_matrix_col,
    input logic reuse,
    input logic isend,

    // Matrix/Vector Inputs
    input logic signed [DATA_W - 1 : 0] matrix_in[0:3][0:3],
    input logic signed [DATA_W - 1 : 0] vector_in[0:3],
    output logic signed [DATA_W - 1: 0] vector_out[0:3],
    input logic signed [DATA_W - 1 : 0] matrix_out[0:3][0:3]

    );

    // ---------------------SIGNALS TO BE FILLED----------------------------//
    // in_matrix_en -> high if out val/rdy for the lastand we dont want to keep the matrix
    // resident
    //
    // vector_en -> on if the input is valid
    // ---------------------Load Stage Control-----------------------------//
    logic col_en;
    logic vector_en;
    logic in_matrix_en;
    localparam MAT_INPUT = 1'b0;
    localparam MAT_OUTPUT = 1'b1;
    always_comb begin

    end


    assign vector_en = (vec_in_val && vec_in_rdy);
    assign in_matrix_en = (mat_in_val && mat_in_rdy); 

    // --------------------Load Stage Data-path---------------------------//
    logic signed [DATA_W - 1 : 0] in_matrix_reg_out [0:3][0:3];
    logic signed [DATA_W - 1 : 0] vector_reg_out[0:3];
    
    logic [1:0] upcol_mul = '0;
    logic in_matrix_en;


    // Counter for column updates
    always_ff @(posedge clk) begin

        if (rst) begin
            upcol_mul <= 1'b0;
        end
        else if (col_en) begin
            upcol_mul <= upcol_mul + 1;
        end

    end

    // Pipeline Registers
    always_ff @(posedge clk) begin

        if (rst) begin
            for (int i = 0; i < 4; i++) begin
                for (int j < 0; j < 4; j++) begin
                    in_matrix_reg_out[i][j] <= '0;
                end
            end
        end
        else if (in_matrix_en) begin
            in_matrix_reg_out <= matrix_in;
        end

        if (rst) begin
            for (int n = 0; n < 4; n++) begin
                vector_reg_out <= '0;
            end
        end
        else if (vector_en) begin
            vector_reg_out <= vector_in;
        end
        
    end

    // Multiply Stage
    // ----------------------SIGNALS TO FILL IN-----------------------//
    // matrix sel explained below
    // ----------------------Multiply Stage Control------------------------//
    
    logic matrix_sel; // chooses whether to use output or input 
    logic signed [DATA_W - 1 : 0] active_matrix [0:3][0:3];

    // ----------------------Multiply Stage Data-path---------------------//
    assign active_matrix = in_matrix_reg_out;
 
    // Get all products
    logic signed [2 * DATA_W - 1 : 0] prod [0:3][0:3];
    genvar i;
    genvar j;
    generate begin
        for (i = 0; i < 4; i++) begin
            for (j = 0; j < 4; j++) begin
                prod[i][j] = active_matrix[i][j] * vector_reg_out[j]; 
            end
        end
    endgenerate

    logic signed [2 * DATA_W - 1 : 0] prod_reg_out[0:3][0:3];
    logic [1:0] upcol_acc;

    assign mult_en = 1'b1;

    assign acc_col_en = 1'b1;

    // Pipeline Registers
    always_ff @(posedge clk) begin
        
        if (rst) begin
            for (int i = 0; i < 4; i++) begin
                for (int j < 0; j < 4; j++) begin
                    prod_reg_out[i][j] <= '0;
                end
            end
        end
        else if (mult_en) begin
            prod_reg_out <= prod;
        end

        if (rst) begin
            upcol_acc <= 2'b0;
        end
        else if (acc_col_en) begin
            upcol_acc <= upcol_mul;
        end

    end


    // Sum Stage 
    //-------------------------Sum Stage Control----------------------//
    logic signed [2 * DATA_W + 2 : 0] acc_vector[0:3];

    //-------------------------Sum Stage Data-path--------------------//
    genvar n;
    genvar l;
    genvar k;
    generate begin
        for (n = 0; n < 4; n++) begin
            acc_vector[n] = '0;
        end

        for (l = 0; l < 4; l++) begin
            for (k = 0; k < 4; k++) begin
                acc_vector[l] = acc_vector[l] + prod_reg_out[l][k];
            end
        end
    endgenerate

    logic signed [2 * DATA_W + 2 : 0] acc_vector_reg_out[0:3];
    logic [1:0] upcol_wb;

    assign wb_col_en = 1'b1;

    // Pipeline registers
    always_ff @(posedge clk) begin

        if (rst) begin

            for (int i = 0; i < 4; i++) begin
                acc_vector_reg_out[i] <= '0;
            end
        end
        else begin
            acc_vector_reg_out <= acc_vector; 
        end

        if (rst) begin
            upcol_wb <= 2'b0;
        end
        else if (wb_col_en) begin
            upcol_wb <= upcol_acc;
        end
        
    end

    // Writeback Stage

    logic signed [DATA_W - 1 : 0] writeback_matrix_reg_out [4][4];
    
    assign wb_matrix_reg_enable = 1'b1;

    always_ff @(posedge clk) begin

        if (rst) begin
            for (int i = 0; i < 4; i++) begin
                for (int j = 0; j < 4; j++) begin
                    writeback_matrix_reg_out <= '0;
                end
            end
        end

        else if (wb_matrix_reg_enable) begin
            for (int k = 0; k < 4; k++) begin
                wb_matrix_reg_out[k][upcol_wb] <= (acc_vector_reg_out[k] >>> DATA_W / 2);
            end
        end

    end

    assign vector_out = acc_vector_reg_out;
    assign matrix_out = wb_matrix_reg_out;

`endif // MATRIX_VEC_ENGINE_SV
