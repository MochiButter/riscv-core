module axil_aclint
  import axil_pkg::*;
  #(parameter BusWidth = 64
  ,localparam MaskBits = BusWidth / 8
  )
  (input  logic clk_i
  ,input  logic rst_ni

  ,input  logic timer_clk_i

  ,output logic                  msip_o
  ,output logic                  mtip_o
  ,output logic [63:0]           mtime_o

  ,axil_if.s s_axil
  );

  // both write channels must be valid at the same time to be granted a write
  // reads have priority over writes
  parameter AddrWidth = 16;
  localparam ShiftBits = $clog2(MaskBits);
  localparam AddrWidthWord = AddrWidth - ShiftBits;

  logic [BusWidth - 1:0] saved_wdata;
  logic [AddrWidthWord - 1:0] mem_addr_w, mem_addr_r,
    saved_addr_w, saved_addr_r, mem_addr;
  logic [MaskBits - 1:0] saved_wmask;
  logic skid_addr_w_ready, saved_addr_w_valid, saved_addr_r_valid, wr_en, rd_en,
    req_is_write, write_ready, bvalid_d, rvalid_d, error;

  assign mem_addr_w = s_axil.awaddr[AddrWidthWord + ShiftBits - 1:ShiftBits];
  assign mem_addr_r = s_axil.araddr[AddrWidthWord + ShiftBits - 1:ShiftBits];

  assign wr_en = saved_addr_w_valid && (!s_axil.bvalid || s_axil.bready);
  assign rd_en = saved_addr_r_valid && (!s_axil.rvalid || s_axil.rready);

  assign s_axil.bresp = error ? axil_pkg::SLVERR : axil_pkg::OKAY;
  assign s_axil.rresp = error ? axil_pkg::SLVERR : axil_pkg::OKAY;

  assign write_ready = skid_addr_w_ready && req_is_write;
  assign req_is_write = !s_axil.arvalid && s_axil.awvalid && s_axil.wvalid;
  assign mem_addr = req_is_write ? saved_addr_w : saved_addr_r;

  assign s_axil.awready = write_ready;
  assign s_axil.wready  = write_ready;

  assign bvalid_d = wr_en ? 1'b1 :
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
    .Width(AddrWidthWord + BusWidth + MaskBits)
  ) save_write (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .wr_valid_i (req_is_write),
    .wr_data_i  ({mem_addr_w, s_axil.wdata, s_axil.wstrb}),
    .wr_ready_o (skid_addr_w_ready),
    .rd_ready_i (wr_en),
    .rd_data_o  ({saved_addr_w, saved_wdata, saved_wmask}),
    .rd_valid_o (saved_addr_w_valid)
  );

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

  aclint u_aclint (
    .clk_i       (clk_i),
    .rst_ni      (rst_ni),
    .timer_clk_i (timer_clk_i),
    .valid_i     (wr_en | rd_en),
    .addr_i      (mem_addr),
    .wr_en_i     (wr_en),
    .wdata_i     (saved_wdata),
    .wstrb_i     (saved_wmask),
    .rdata_o     (s_axil.rdata),
    .error_o     (error),
    .msip_o      (msip_o),
    .mtip_o      (mtip_o),
    .mtime_o     (mtime_o)
  );

  logic [BusWidth - AddrWidthWord - 1:0] __unused_waddr, __unused_raddr;
  axil_prot_t __unused_prot [0:1];
  assign __unused_waddr =
    {s_axil.awaddr[BusWidth - 1:AddrWidthWord + ShiftBits],
    s_axil.awaddr[ShiftBits - 1:0]};
  assign __unused_raddr =
    {s_axil.araddr[BusWidth - 1:AddrWidthWord + ShiftBits],
    s_axil.araddr[ShiftBits - 1:0]};
  assign __unused_prot = {s_axil.awprot, s_axil.arprot};
endmodule
