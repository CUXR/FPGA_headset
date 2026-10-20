`include "CameraInterface.sv"
`include "MatVecEngine.sv"

module HeadsetTop #(
  parameter int H_RES = 1280,
  parameter int V_RES = 720
) (
  
  MatVecEngine #(
    DATA_W = 18,
    NUM_COLS = 4
  ) matvec_engine_inst (
    .clk           (clk),
    .rst           (rst),

    .mat_in_val    (mat_in_val),
    .mat_in_rdy    (mat_in_rdy),
    .vec_in_val    (vec_in_val),
    .vec_in_rdy    (vec_in_rdy),

    .vec_out_val   (vec_out_val),
    .vec_out_rdy   (vec_out_rdy),
    .mat_out_val   (mat_out_val),
    .mat_out_rdy   (mat_out_rdy),

    .is_matrix_col (is_matrix_col),
    .isend_vec     (isend_vec),
    .isend_mat     (isend_mat),

    .matrix_in     (matrix_in),
    .vector_in     (vector_in),
    .vector_out    (vector_out),
    .matrix_out    (matrix_out)
  );
);

endmodule