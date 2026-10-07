`ifndef MAT_VEC_ENGINE_SV
`define MAT_VEC_ENGINE_SV

module MatVecEngine#(
parameter int DATA_W = 18,
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
    input logic isend_vec,
    input logic isend_mat,

    // Matrix/Vector Inputs
    input logic signed [DATA_W - 1 : 0] matrix_in[0:3][0:3],
    input logic signed [DATA_W - 1 : 0] vector_in[0:3],
    output logic signed [DATA_W - 1: 0] vector_out[0:3],
    output logic signed [DATA_W - 1 : 0] matrix_out[0:3][0:3]

    );

    // ---------------------SIGNALS TO BE FILLED----------------------------//
    // in_matrix_en -> high if out val/rdy for the lastand we dont want to keep the matrix
    // resident
    //
    // vector_en -> on if the input is valid
    // ---------------------Load Stage Control-----------------------------//
    logic col_en;
    logic vector_en;
    logic in_mat_en;
    localparam MAT_INPUT = 1'b0;
    localparam MAT_OUTPUT = 1'b1;
    logic stalled;

    assign stalled = (vec_out_val && !vec_out_rdy) || (mat_out_val && !mat_out_rdy);
    assign vec_in_rdy = !stalled;
    assign mat_in_rdy = !stalled;   
    assign vector_en = vec_in_rdy && vec_in_val;
    assign in_mat_en = (isend_vec || isend_mat) && mat_in_rdy && mat_in_val;
    assign col_en = is_matrix_col && vector_en;

    // --------------------Load Stage Data-path---------------------------//
    logic signed [DATA_W - 1 : 0] in_matrix_reg_out [0:3][0:3];
    logic signed [DATA_W - 1 : 0] vector_reg_out[0:3];
    
    logic [1:0] upcol_mul = '0;
    logic vend_mul;
    logic mend_mul;


    // Counter for column updates
    always_ff @(posedge clk) begin

        if (rst) begin
            upcol_mul <= 2'b0;

        end
        else if (col_en) begin
            upcol_mul <= upcol_mul + 1;
        end

    end

    // Pipeline Registers
    always_ff @(posedge clk) begin

        if (rst) begin
            in_matrix_reg_out <= '0;
        end
        else if (in_mat_en) begin
            in_matrix_reg_out <= matrix_in;
        end

        if (rst) begin
            for (int n = 0; n < 4; n++) begin
                vector_reg_out <= '0;
                vend_mul <= 1'b0;
                mend_mul <= 1'b0;
            end
        end
        else if (vector_en) begin
            vector_reg_out <= vector_in;
            vend_mul <= isend_vec;
            mend_mul <= isend_mat;
        end
        
    end

    // Multiply Stage
    // ----------------------SIGNALS TO FILL IN-----------------------//
    // matrix sel explained below
    // ----------------------Multiply Stage Control------------------------//
    
    logic signed [DATA_W - 1 : 0] active_matrix [0:3][0:3];

    // ----------------------Multiply Stage Data-path---------------------//
    assign active_matrix = in_matrix_reg_out;
 
    // Get all products
    logic signed [2 * DATA_W - 1 : 0] prod [0:3][0:3];
    genvar i;
    genvar j;
    generate begin
        for (i = 0; i < 4; i++) begin GEN_ROW
            for (j = 0; j < 4; j++) begin GEN_COL
                assign prod[i][j] = active_matrix[i][j] * vector_reg_out[j]; 
            end
        end
    endgenerate

    logic signed [2 * DATA_W - 1 : 0] prod_reg_out[0:3][0:3];
    logic [1:0] upcol_acc;
    logic vend_acc;
    logic mend_acc;

    assign mult_en = !stalled;

    assign acc_col_en = !stalled;

    // Pipeline Registers
    always_ff @(posedge clk) begin
        
        if (rst) begin
            prod_reg_out <= '0;
        end
        else if (mult_en) begin
            prod_reg_out <= prod;
        end

        if (rst) begin
            upcol_acc <= 2'b0;
            vend_acc <= 1'b0;
            mend_acc <= 1'b0;
        end
        else if (acc_col_en) begin
            upcol_acc <= upcol_mul;
            vend_acc <= vend_mul;
            mend_acc <= mend_mul;
        end

    end

    // Sum Stage 
    //-------------------------Sum Stage Control----------------------//
    logic signed [2 * DATA_W + 2 : 0] acc_vector[0:3];

    //-------------------------Sum Stage Data-path--------------------//
    always_comb begin
        for (int i = 0; i < 4; i++) begin
            acc_vector[i] =
                prod_reg_out[i][0] +
                prod_reg_out[i][1] +
                prod_reg_out[i][2] +
                prod_reg_out[i][3];
        end
    end

    logic signed [2 * DATA_W + 2 : 0] acc_vector_reg_out[0:3];
    logic [1:0] upcol_wb;
    logic vend_wb;
    logic mend_wb;

    assign wb_col_en = !stalled;

    // Pipeline registers
    always_ff @(posedge clk) begin

        if (rst) begin
            acc_vector_reg_out <= '0;
        end
        else if (wb_col_en) begin
            acc_vector_reg_out <= acc_vector; 
        end

        if (rst) begin
            upcol_wb <= 2'b0;
            vend_wb <= 1'b0;
            mend_wb <= 1'b0;
        end
        else if (wb_col_en) begin
            upcol_wb <= upcol_acc;
            vend_wb <= vend_acc;
            mend_wb <= mend_acc;
        end
        
    end

    // Writeback Stage

    logic signed [DATA_W - 1 : 0] writeback_matrix_reg_out [4][4];
    
    assign wb_matrix_reg_enable = 1'b1;

    always_ff @(posedge clk) begin

        if (rst) begin
            writeback_matrix_reg_out <= '0;
        end

        else if (wb_matrix_reg_enable) begin
            for (int k = 0; k < 4; k++) begin
                wb_matrix_reg_out[k][upcol_wb] <= (acc_vector_reg_out[k] >>> (DATA_W / 2));
            end
        end

    end

    generate
    for (genvar i = 0; i < 4; i++) begin
        assign vector_out[i] =
            acc_vector_reg_out[i] >>> (DATA_W / 2);
    end
    endgenerate

    assign mat_out_val = mend_wb;
    assign vec_out_val = vend_wb;
    assign matrix_out = wb_matrix_reg_out;

`endif // MATRIX_VEC_ENGINE_SV
