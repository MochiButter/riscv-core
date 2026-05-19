//`include "axil_macros.svh"
module soc
  import axil_pkg::*;
  #()
  (input  logic clk_i
  ,input  logic rst_ni
  );

  parameter BusWidth = 64;
  localparam MaskBits = BusWidth / 8;

  logic [BusWidth - 1:0] i_addr, i_rdata;
  logic i_ready, i_valid, i_rvalid;

  logic [BusWidth - 1:0] d_addr, d_wdata, d_rdata;
  logic [MaskBits - 1:0] d_wmask;
  logic d_ready, d_valid, d_rvalid;

  logic [BusWidth - 1:0] bus_addr, bus_wdata, bus_rdata;
  logic [MaskBits - 1:0] bus_wmask;
  logic bus_ready, bus_valid, bus_rvalid;

  logic [63:0] mtime;
  logic msip, mtip;

  `AXIL_LOGIC(core)
  `AXIL_LOGIC(ram)
  `AXIL_LOGIC(rom)
  `AXIL_LOGIC(aclint)

`ifdef RISCV_FORMAL
  // To be used in the soc level test bench
  /* verilator lint_off UNUSEDSIGNAL */
  localparam Nret = 1;
  localparam Xlen = 64;
  localparam Ilen = 32;
  logic [Nret        - 1 : 0] rvfi_valid;
  logic [Nret *   64 - 1 : 0] rvfi_order;
  logic [Nret * Ilen - 1 : 0] rvfi_insn;
  logic [Nret        - 1 : 0] rvfi_trap;
  logic [Nret        - 1 : 0] rvfi_halt;
  logic [Nret        - 1 : 0] rvfi_intr;
  logic [Nret * 2    - 1 : 0] rvfi_mode;
  logic [Nret * 2    - 1 : 0] rvfi_ixl;
  logic [Nret *    5 - 1 : 0] rvfi_rs1_addr;
  logic [Nret *    5 - 1 : 0] rvfi_rs2_addr;
  logic [Nret * Xlen - 1 : 0] rvfi_rs1_rdata;
  logic [Nret * Xlen - 1 : 0] rvfi_rs2_rdata;
  logic [Nret *    5 - 1 : 0] rvfi_rd_addr;
  logic [Nret * Xlen - 1 : 0] rvfi_rd_wdata;
  logic [Nret * Xlen - 1 : 0] rvfi_pc_rdata;
  logic [Nret * Xlen - 1 : 0] rvfi_pc_wdata;
  logic [Nret * Xlen   - 1 : 0] rvfi_mem_addr;
  logic [Nret * Xlen/8 - 1 : 0] rvfi_mem_rmask;
  logic [Nret * Xlen/8 - 1 : 0] rvfi_mem_wmask;
  logic [Nret * Xlen   - 1 : 0] rvfi_mem_rdata;
  logic [Nret * Xlen   - 1 : 0] rvfi_mem_wdata;
  /* verilator lint_on UNUSEDSIGNAL */
`endif

  core #(
    .BootAddr(64'h80000000)
  ) u_core (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .instmem_ready_i (i_ready),
    .instmem_valid_o (i_valid),
    .instmem_addr_o  (i_addr),
    .instmem_wdata_o (),
    .instmem_wmask_o (),
    .instmem_rdata_i (i_rdata),
    .instmem_rvalid_i(i_rvalid),
    .datamem_ready_i (d_ready),
    .datamem_valid_o (d_valid),
    .datamem_addr_o  (d_addr),
    .datamem_wdata_o (d_wdata),
    .datamem_wmask_o (d_wmask),
    .datamem_rdata_i (d_rdata),
    .datamem_rvalid_i(d_rvalid),
    .msip_i          (msip),
    .mtip_i          (mtip),
    .mtime_i         (mtime)
`ifdef RISCV_FORMAL
    ,
    .rvfi_valid(rvfi_valid),
    .rvfi_order(rvfi_order),
    .rvfi_insn(rvfi_insn),
    .rvfi_trap(rvfi_trap),
    .rvfi_halt(rvfi_halt),
    .rvfi_intr(rvfi_intr),
    .rvfi_mode(rvfi_mode),
    .rvfi_ixl(rvfi_ixl),
    .rvfi_rs1_addr(rvfi_rs1_addr),
    .rvfi_rs2_addr(rvfi_rs2_addr),
    .rvfi_rs1_rdata(rvfi_rs1_rdata),
    .rvfi_rs2_rdata(rvfi_rs2_rdata),
    .rvfi_rd_addr(rvfi_rd_addr),
    .rvfi_rd_wdata(rvfi_rd_wdata),
    .rvfi_pc_rdata(rvfi_pc_rdata),
    .rvfi_pc_wdata(rvfi_pc_wdata),
    .rvfi_mem_addr(rvfi_mem_addr),
    .rvfi_mem_rmask(rvfi_mem_rmask),
    .rvfi_mem_wmask(rvfi_mem_wmask),
    .rvfi_mem_rdata(rvfi_mem_rdata),
    .rvfi_mem_wdata(rvfi_mem_wdata)
`endif
  );

  arbiter #(
    .BusWidth(64)
  ) u_arb_axil  (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .i_ready_o    (i_ready),
    .i_valid_i    (i_valid),
    .i_addr_i     (i_addr),
    .i_rdata_o    (i_rdata),
    .i_rvalid_o   (i_rvalid),

    .d_ready_o    (d_ready),
    .d_valid_i    (d_valid),
    .d_addr_i     (d_addr),
    .d_wdata_i    (d_wdata),
    .d_wmask_i    (d_wmask),
    .d_rdata_o    (d_rdata),
    .d_rvalid_o   (d_rvalid),

    .bus_ready_i  (bus_ready),
    .bus_valid_o  (bus_valid),
    .bus_addr_o   (bus_addr),
    .bus_wdata_o  (bus_wdata),
    .bus_wmask_o  (bus_wmask),
    .bus_rdata_i  (bus_rdata),
    .bus_rvalid_i (bus_rvalid)
  );

  mem_to_axil #(
    .BusWidth(64)
  ) u_bus_to_axil (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .mem_ready_o  (bus_ready),
    .mem_valid_i  (bus_valid),
    .mem_addr_i   (bus_addr),
    .mem_wdata_i  (bus_wdata),
    .mem_wmask_i  (bus_wmask),
    .mem_rdata_o  (bus_rdata),
    .mem_rvalid_o (bus_rvalid),
    `M_AXIL_CONN(core)
  );

  axil_interconnect #(
    .BusWidth (64),
    .NumS     (3)
  ) axil_interconnect (
    .clk_i (clk_i),
    .rst_ni (rst_ni),
    `S_AXIL_CONN(core)
    ,
    .m_axil_awvalid ({ram_awvalid, rom_awvalid, aclint_awvalid}),
    .m_axil_awready ({ram_awready, rom_awready, aclint_awready}),
    .m_axil_awaddr  ({ram_awaddr,  rom_awaddr,  aclint_awaddr }),
    .m_axil_wvalid  ({ram_wvalid,  rom_wvalid,  aclint_wvalid }),
    .m_axil_wready  ({ram_wready,  rom_wready,  aclint_wready }),
    .m_axil_wdata   ({ram_wdata,   rom_wdata,   aclint_wdata  }),
    .m_axil_wstrb   ({ram_wstrb,   rom_wstrb,   aclint_wstrb  }),
    .m_axil_bvalid  ({ram_bvalid,  rom_bvalid,  aclint_bvalid }),
    .m_axil_bready  ({ram_bready,  rom_bready,  aclint_bready }),
    .m_axil_arvalid ({ram_arvalid, rom_arvalid, aclint_arvalid}),
    .m_axil_arready ({ram_arready, rom_arready, aclint_arready}),
    .m_axil_araddr  ({ram_araddr,  rom_araddr,  aclint_araddr }),
    .m_axil_rvalid  ({ram_rvalid,  rom_rvalid,  aclint_rvalid }),
    .m_axil_rready  ({ram_rready,  rom_rready,  aclint_rready }),
    .m_axil_rdata   ({ram_rdata,   rom_rdata,   aclint_rdata  }),
    .m_axil_awprot  ({ram_awprot,  rom_awprot,  aclint_awprot }),
    .m_axil_bresp   ({ram_bresp,   rom_bresp,   aclint_bresp  }),
    .m_axil_arprot  ({ram_arprot,  rom_arprot,  aclint_arprot }),
    .m_axil_rresp   ({ram_rresp,   rom_rresp,   aclint_rresp  })
  );

  ram_sync_axil #(
    .BusWidth    (64),
    .AddrWidth   (15),
    .DualPort    (1'b1)
  ) u_axil_ram (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),
    `S_AXIL_CONN(ram)
  );

  rom_sync_axil #(
    .BusWidth    (64),
    .AddrWidth   (16)
  ) u_axil_rom (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),
    `S_AXIL_CONN(rom)
  );

  axil_aclint #(
    .BusWidth (64)
  ) u_axil_aclint (
    .clk_i   (clk_i),
    .rst_ni  (rst_ni),
    .msip_o  (msip),
    .mtip_o  (mtip),
    .mtime_o (mtime),
    `S_AXIL_CONN(aclint)
  );
endmodule
