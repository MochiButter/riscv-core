`ifndef BINPATH
  `define BINPATH ""
`endif

module rom_sync_axil
  import axil_pkg::*;
  #(parameter BusWidth = 64
  ,localparam MaskBits = BusWidth / 8
  ,parameter AddrWidth = 8
  ,parameter UseInitFile = 0
  ,parameter InitFile = {`BINPATH, "soc/arithmetic.hex"}
  )
  (input  logic clk_i
  ,input  logic rst_ni
  ,axil_if.s s_axil
  );

  localparam ShiftBits = $clog2(MaskBits);
  localparam AddrWidthWord = AddrWidth - ShiftBits;

  logic [AddrWidthWord - 1:0] mem_addr_r, saved_addr_r;
  logic saved_addr_r_valid, rd_en, bvalid_d, rvalid_d;

  assign mem_addr_r = s_axil.araddr[AddrWidthWord + ShiftBits - 1:ShiftBits];

  assign rd_en = saved_addr_r_valid && (!s_axil.rvalid || s_axil.rready);

  assign s_axil.bresp = axil_pkg::SLVERR;
  assign s_axil.rresp = axil_pkg::OKAY;

  assign bvalid_d = (s_axil.awvalid && s_axil.wvalid) ? 1'b1 :
                    s_axil.bready ? 1'b0 :
                    s_axil.bvalid;

  assign rvalid_d = rd_en ? 1'b1 :
                    s_axil.rready ? 1'b0 :
                    s_axil.rvalid;

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      s_axil.bvalid <= 1'b0;
      s_axil.rvalid <= 1'b0;
    end else begin
      s_axil.bvalid <= bvalid_d;
      s_axil.rvalid <= rvalid_d;
    end
  end

  skid_buffer #(
    .Width(AddrWidthWord)
  ) save_raddr (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .wr_valid_i (s_axil.arvalid),
    .wr_data_i  (mem_addr_r),
    .wr_ready_o (s_axil.arready),
    .rd_ready_i (rd_en),
    .rd_data_o  (saved_addr_r),
    .rd_valid_o (saved_addr_r_valid)
  );

  // always return an error on a wtrite request
  assign s_axil.awready = 1'b1;
  assign s_axil.wready  = 1'b1;

  rom_1r_sync #(
    .DataWidth   (BusWidth),
    .AddrWidth   (AddrWidthWord),
    .UseInitFile (UseInitFile),
    .InitFile    (InitFile)
  ) u_mem (
    .clk_i   (clk_i),
    .valid_i (rd_en),
    .addr_i  (saved_addr_r),
    .rdata_o (s_axil.rdata)
  );

  logic [BusWidth - 1:0] __unused_waddr, __unused_wdata;
  logic [MaskBits - 1:0] __unused_wstrb;
  logic [BusWidth - AddrWidthWord - 1:0] __unused_raddr;
  axil_prot_t __unused_prot [0:1];
  assign __unused_waddr = s_axil.awaddr;
  assign __unused_wdata = s_axil.wdata;
  assign __unused_wstrb = s_axil.wstrb;
  assign __unused_raddr =
    {s_axil.araddr[BusWidth - 1:AddrWidthWord + ShiftBits],
    s_axil.araddr[ShiftBits - 1:0]};
  assign __unused_prot = {s_axil.awprot, s_axil.arprot};
endmodule
