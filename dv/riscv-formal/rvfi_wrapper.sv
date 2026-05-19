module rvfi_wrapper
  (input clock
  ,input reset
  ,output logic [0 : 0] rvfi_valid
  ,output logic [64 - 1 : 0] rvfi_order
  ,output logic [31: 0] rvfi_insn
  ,output logic [0 : 0] rvfi_trap
  ,output logic [0 : 0] rvfi_halt
  ,output logic [0 : 0] rvfi_intr
  ,output logic [1 : 0] rvfi_mode
  ,output logic [1 : 0] rvfi_ixl
  ,output logic [4 : 0] rvfi_rs1_addr
  ,output logic [4 : 0] rvfi_rs2_addr
  ,output logic [63 : 0] rvfi_rs1_rdata
  ,output logic [63 : 0] rvfi_rs2_rdata
  ,output logic [4 : 0] rvfi_rd_addr
  ,output logic [63 : 0] rvfi_rd_wdata
  ,output logic [63 : 0] rvfi_pc_rdata
  ,output logic [63 : 0] rvfi_pc_wdata
  ,output logic [63 : 0] rvfi_mem_addr
  ,output logic [7 : 0] rvfi_mem_rmask
  ,output logic [7 : 0] rvfi_mem_wmask
  ,output logic [63 : 0] rvfi_mem_rdata
  ,output logic [63 : 0] rvfi_mem_wdata
  );
  (* keep *) logic clk_i, rst_ni;
  assign clk_i = clock;
  assign rst_ni = !reset;

  localparam Xlen = 64;
  localparam Ilen = 32;
  localparam MaskBits = Xlen / 8;

  (* keep *) `rvformal_rand_reg              instmem_ready_i;
  (* keep *) logic                           instmem_valid_o;
  (* keep *) logic [Xlen - 1:0]              instmem_addr_o;
  (* keep *) logic [Xlen - 1:0]              instmem_wdata_o;
  (* keep *) logic [MaskBits - 1:0]          instmem_wmask_o;
  (* keep *) `rvformal_rand_reg [Xlen - 1:0] instmem_rdata_i;
  (* keep *) `rvformal_rand_reg              instmem_rvalid_i;

  (* keep *) `rvformal_rand_reg              datamem_ready_i;
  (* keep *) logic                           datamem_valid_o;
  (* keep *) logic [Xlen - 1:0]              datamem_addr_o;
  (* keep *) logic [Xlen - 1:0]              datamem_wdata_o;
  (* keep *) logic [MaskBits - 1:0]          datamem_wmask_o;
  (* keep *) `rvformal_rand_reg [Xlen - 1:0] datamem_rdata_i;
  (* keep *) `rvformal_rand_reg              datamem_rvalid_i;

  (* keep *) `rvformal_rand_reg              msip_i;
  (* keep *) `rvformal_rand_reg              mtip_i;
  (* keep *) `rvformal_rand_reg [Xlen - 1:0] mtime_i;

  core c (.*);
endmodule
