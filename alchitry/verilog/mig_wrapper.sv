// Translated from fpgahead/luc/mig_wrapper.luc.
// Compile this file before ddr_arbiter.sv and lru_cache.sv.
package memory_pkg;
    typedef struct packed {
        logic [27:0]  addr;
        logic [2:0]   cmd;
        logic         enable;
        logic [127:0] wr_data;
        logic         wr_enable;
        logic [15:0]  wr_mask;
    } mem_in_t;

    typedef struct packed {
        logic [127:0] rd_data;
        logic         rd_valid;
        logic         rdy;
        logic         wr_rdy;
    } mem_out_t;
endpackage

module mig_wrapper (
    inout  wire [15:0]            ddr3_dq,
    inout  wire [1:0]             ddr3_dqs_n,
    inout  wire [1:0]             ddr3_dqs_p,
    output wire [13:0]            ddr3_addr,
    output wire [2:0]             ddr3_ba,
    output wire                   ddr3_ras_n,
    output wire                   ddr3_cas_n,
    output wire                   ddr3_we_n,
    output wire                   ddr3_reset_n,
    output wire                   ddr3_ck_p,
    output wire                   ddr3_ck_n,
    output wire                   ddr3_cke,
    output wire                   ddr3_cs_n,
    output wire [1:0]             ddr3_dm,
    output wire                   ddr3_odt,
    input  wire                   sys_clk,
    input  wire                   clk_ref,
    input  memory_pkg::mem_in_t   mem_in,
    output memory_pkg::mem_out_t  mem_out,
    output wire                   ui_clk,
    output wire                   sync_rst,
    input  wire                   sys_rst
);
    mig_7series_0 mig (
        .ddr3_dq(ddr3_dq),
        .ddr3_dqs_n(ddr3_dqs_n),
        .ddr3_dqs_p(ddr3_dqs_p),
        .ddr3_addr(ddr3_addr),
        .ddr3_ba(ddr3_ba),
        .ddr3_ras_n(ddr3_ras_n),
        .ddr3_cas_n(ddr3_cas_n),
        .ddr3_we_n(ddr3_we_n),
        .ddr3_reset_n(ddr3_reset_n),
        .ddr3_ck_p(ddr3_ck_p),
        .ddr3_ck_n(ddr3_ck_n),
        .ddr3_cke(ddr3_cke),
        .ddr3_cs_n(ddr3_cs_n),
        .ddr3_dm(ddr3_dm),
        .ddr3_odt(ddr3_odt),
        .app_sr_req(1'b0),
        .app_ref_req(1'b0),
        .app_zq_req(1'b0),
        .app_wdf_data(mem_in.wr_data),
        .app_wdf_end(mem_in.wr_enable),
        .app_wdf_wren(mem_in.wr_enable),
        .app_wdf_mask(mem_in.wr_mask),
        .app_cmd(mem_in.cmd),
        .app_en(mem_in.enable),
        .app_addr(mem_in.addr),
        .app_rd_data(mem_out.rd_data),
        .app_rd_data_valid(mem_out.rd_valid),
        .app_rdy(mem_out.rdy),
        .app_wdf_rdy(mem_out.wr_rdy),
        .sys_clk_i(sys_clk),
        .clk_ref_i(clk_ref),
        .sys_rst(sys_rst),
        .ui_clk_sync_rst(sync_rst),
        .ui_clk(ui_clk)
    );
endmodule
