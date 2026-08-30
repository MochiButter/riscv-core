module axil_interconnect
  import axil_pkg::*;
  #(parameter BusWidth = 64
  ,localparam MaskBits = BusWidth / 8
  ,parameter NumS = 1
  ,localparam IdWidth = $clog2(NumS))
  (input  logic clk_i
  ,input  logic rst_ni

  ,axil_if.s s_axil
  ,axil_if.m m_axil[0:NumS - 1]
  );

  /* Interfaces can't be accessed with non-const indices
   * The interface signals are assigned to/from logic instead */
  logic                  m_axil_awvalid [0:NumS - 1];
  logic                  m_axil_awready [0:NumS - 1];
  logic [BusWidth - 1:0] m_axil_awaddr  [0:NumS - 1];
  axil_prot_t            m_axil_awprot  [0:NumS - 1];

  logic                  m_axil_wvalid  [0:NumS - 1];
  logic                  m_axil_wready  [0:NumS - 1];
  logic [BusWidth - 1:0] m_axil_wdata   [0:NumS - 1];
  logic [MaskBits - 1:0] m_axil_wstrb   [0:NumS - 1];

  logic                  m_axil_bvalid  [0:NumS - 1];
  logic                  m_axil_bready  [0:NumS - 1];
  axil_resp_e            m_axil_bresp   [0:NumS - 1];

  logic                  m_axil_arvalid [0:NumS - 1];
  logic                  m_axil_arready [0:NumS - 1];
  logic [BusWidth - 1:0] m_axil_araddr  [0:NumS - 1];
  axil_prot_t            m_axil_arprot  [0:NumS - 1];

  logic                  m_axil_rvalid  [0:NumS - 1];
  logic                  m_axil_rready  [0:NumS - 1];
  logic [BusWidth - 1:0] m_axil_rdata   [0:NumS - 1];
  axil_resp_e            m_axil_rresp   [0:NumS - 1];

  for (genvar i = 0; i < NumS; i ++) begin : l_if_assign
    assign m_axil[i].awvalid = m_axil_awvalid[i];
    assign m_axil_awready[i] = m_axil[i].awready;
    assign m_axil[i].awaddr  = m_axil_awaddr[i];
    assign m_axil[i].awprot  = m_axil_awprot[i];

    assign m_axil[i].wvalid  = m_axil_wvalid[i];
    assign m_axil_wready[i]  = m_axil[i].wready;
    assign m_axil[i].wdata   = m_axil_wdata[i];
    assign m_axil[i].wstrb   = m_axil_wstrb[i];

    assign m_axil_bvalid[i]  = m_axil[i].bvalid;
    assign m_axil[i].bready  = m_axil_bready[i];
    assign m_axil_bresp[i]   = m_axil[i].bresp;

    assign m_axil[i].arvalid = m_axil_arvalid[i];
    assign m_axil_arready[i] = m_axil[i].arready;
    assign m_axil[i].araddr  = m_axil_araddr[i];
    assign m_axil[i].arprot  = m_axil_arprot[i];

    assign m_axil_rvalid[i]  = m_axil[i].rvalid;
    assign m_axil[i].rready  = m_axil_rready[i];
    assign m_axil_rdata[i]   = m_axil[i].rdata;
    assign m_axil_rresp[i]   = m_axil[i].rresp;
  end

  /* write signals */
  logic [BusWidth - 1:0] wr_req_addr, wr_req_data;
  logic [MaskBits - 1:0] wr_req_strb;
  logic [IdWidth - 1:0] wr_req_id, wr_resp_id;
  axil_resp_e sel_bresp;
  logic aw_req_valid, w_req_valid, wr_req_ready,
    wr_can_req, wr_is_requesting, sel_bvalid, sel_bready,
    wr_req_ack, wr_resp_ack;

  assign wr_req_ready = wr_can_req &&
    m_axil_awready[wr_req_id] && m_axil_wready[wr_req_id];
  assign wr_req_ack = aw_req_valid && w_req_valid && wr_req_ready;
  assign wr_resp_ack = sel_bvalid && sel_bready;

  always_comb begin
    sel_bresp = axil_pkg::OKAY;
    sel_bvalid = 1'b0;
    if (wr_is_requesting) begin
      sel_bresp = m_axil_bresp[wr_resp_id];
      sel_bvalid = m_axil_bvalid[wr_resp_id];
    end
  end

  skid_buffer #(
    .Width(BusWidth)
  ) aw_incoming (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .wr_valid_i (s_axil.awvalid),
    .wr_data_i  (s_axil.awaddr),
    .wr_ready_o (s_axil.awready),
    .rd_ready_i (wr_req_ready),
    .rd_data_o  (wr_req_addr),
    .rd_valid_o (aw_req_valid)
  );

  skid_buffer #(
    .Width(BusWidth + MaskBits)
  ) w_incoming (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .wr_valid_i (s_axil.wvalid),
    .wr_data_i  ({s_axil.wdata, s_axil.wstrb}),
    .wr_ready_o (s_axil.wready),
    .rd_ready_i (wr_req_ready),
    .rd_data_o  ({wr_req_data, wr_req_strb}),
    .rd_valid_o (w_req_valid)
  );

  addr_decode #(
    .BusWidth (BusWidth),
    .NumS     (NumS)
  ) wr_addr_dec (
    .addr_i       (wr_req_addr),
    .decerr_o     (),
    .request_id_o (wr_req_id)
  );

  pipeline_reg #(
    .Width(IdWidth)
  ) wr_req_buf (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .wr_valid_i (wr_req_ack),
    .wr_data_i  (wr_req_id),
    .wr_ready_o (wr_can_req),
    .rd_ready_i (wr_resp_ack),
    .rd_data_o  (wr_resp_id),
    .rd_valid_o (wr_is_requesting)
  );

  skid_buffer #(
    .Width($bits(axil_resp_e))
  ) wr_return (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .wr_valid_i (sel_bvalid),
    .wr_data_i  (sel_bresp),
    .wr_ready_o (sel_bready),
    .rd_ready_i (s_axil.bready),
    .rd_data_o  (s_axil.bresp),
    .rd_valid_o (s_axil.bvalid)
  );

  /* read signals */
  logic [BusWidth - 1:0] rd_req_addr, sel_rdata;
  logic [IdWidth - 1:0] rd_req_id, rd_resp_id;
  axil_resp_e sel_rresp;
  logic rd_req_ready, rd_req_valid, rd_can_req, rd_is_requesting,
    sel_rvalid, sel_rready, rd_req_ack, rd_resp_ack;

  assign rd_req_ready = rd_can_req && m_axil_arready[rd_req_id];
  assign rd_req_ack = rd_req_ready && rd_req_valid;
  assign rd_resp_ack = sel_rvalid && sel_rready;

  always_comb begin
    sel_rdata = '0;
    sel_rresp = axil_pkg::OKAY;
    sel_rvalid = 1'b0;
    if (rd_is_requesting) begin
      sel_rdata = m_axil_rdata[rd_resp_id];
      sel_rresp = m_axil_rresp[rd_resp_id];
      sel_rvalid = m_axil_rvalid[rd_resp_id];
    end
  end

  skid_buffer #(
    .Width(BusWidth)
  ) rd_incoming (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .wr_valid_i (s_axil.arvalid),
    .wr_data_i  (s_axil.araddr),
    .wr_ready_o (s_axil.arready),
    .rd_ready_i (rd_req_ready),
    .rd_data_o  (rd_req_addr),
    .rd_valid_o (rd_req_valid)
  );

  addr_decode #(
    .BusWidth (BusWidth),
    .NumS     (NumS)
  ) rd_addr_dec (
    .addr_i       (rd_req_addr),
    .decerr_o     (),
    .request_id_o (rd_req_id)
  );

  pipeline_reg #(
    .Width(IdWidth)
  ) rd_req_buf (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .wr_valid_i (rd_req_ack),
    .wr_data_i  (rd_req_id),
    .wr_ready_o (rd_can_req),
    .rd_ready_i (rd_resp_ack),
    .rd_data_o  (rd_resp_id),
    .rd_valid_o (rd_is_requesting)
  );

  skid_buffer #(
    .Width(BusWidth + $bits(axil_resp_e))
  ) rd_return (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .wr_valid_i (sel_rvalid),
    .wr_data_i  ({sel_rdata, sel_rresp}),
    .wr_ready_o (sel_rready),
    .rd_ready_i (s_axil.rready),
    .rd_data_o  ({s_axil.rdata, s_axil.rresp}),
    .rd_valid_o (s_axil.rvalid)
  );

  always_comb begin
    for (int i = 0; i < NumS; i ++) begin
      m_axil_awvalid[i] = 1'b0;
      m_axil_awaddr[i]  = '0;
      m_axil_awprot[i]  = '0;
      m_axil_wvalid[i]  = 1'b0;
      m_axil_wdata[i]   = '0;
      m_axil_wstrb[i]   = '0;
      m_axil_bready[i]  = 1'b0;
      m_axil_arvalid[i] = 1'b0;
      m_axil_araddr[i]  = '0;
      m_axil_arprot[i]  = '0;
      m_axil_rready[i]  = 1'b0;

      if (wr_can_req && aw_req_valid && w_req_valid && wr_req_id == IdWidth'(i)) begin
        m_axil_awvalid[i] = 1'b1;
        m_axil_awaddr[i]  = wr_req_addr;
        m_axil_wvalid[i]  = 1'b1;
        m_axil_wdata[i]   = wr_req_data;
        m_axil_wstrb[i]   = wr_req_strb;
      end
      if (wr_is_requesting && sel_bvalid && wr_resp_id == IdWidth'(i)) begin
        m_axil_bready[i] = 1'b1;
      end
      if (rd_can_req && rd_req_valid && rd_req_id == IdWidth'(i)) begin
        m_axil_arvalid[i] = 1'b1;
        m_axil_araddr[i]  = rd_req_addr;
      end
      if (rd_is_requesting && sel_rvalid && rd_resp_id == IdWidth'(i)) begin
        m_axil_rready[i] = 1'b1;
      end
    end
  end

  axil_prot_t __unused_prot [0:1];
  assign __unused_prot = {s_axil.awprot, s_axil.arprot};
endmodule
