module arbiter
  import axil_pkg::*;
  #(parameter BusWidth = 64
  ,localparam MaskBits = BusWidth / 8)
  (input  logic clk_i
  ,input  logic rst_ni

  ,output logic                  i_ready_o
  ,input  logic                  i_valid_i
  ,input  logic [BusWidth - 1:0] i_addr_i
  ,output axil_resp_e            i_resp_o
  ,output logic [BusWidth - 1:0] i_rdata_o
  ,output logic                  i_rvalid_o

  ,output logic                  d_ready_o
  ,input  logic                  d_valid_i
  ,input  logic [BusWidth - 1:0] d_addr_i
  ,input  logic [BusWidth - 1:0] d_wdata_i
  ,input  logic [MaskBits - 1:0] d_wmask_i
  ,output axil_resp_e            d_resp_o
  ,output logic [BusWidth - 1:0] d_rdata_o
  ,output logic                  d_rvalid_o

  ,input  logic                  bus_ready_i
  ,output logic                  bus_valid_o
  ,output logic [BusWidth - 1:0] bus_addr_o
  ,output logic [BusWidth - 1:0] bus_wdata_o
  ,output logic [MaskBits - 1:0] bus_wmask_o
  ,input  axil_resp_e            bus_resp_i
  ,input  logic [BusWidth - 1:0] bus_rdata_i
  ,input  logic                  bus_rvalid_i
  );

  logic req_is_inst, res_is_inst_q, can_request, is_requesting_q, res_is_valid;

  always_comb begin
    req_is_inst = !d_valid_i;
    res_is_valid = bus_rvalid_i && is_requesting_q;

    bus_valid_o = i_valid_i || d_valid_i;

    i_ready_o = bus_ready_i && ((can_request && i_valid_i && !d_valid_i));
    i_rvalid_o = res_is_valid && res_is_inst_q;
    i_rdata_o = bus_rdata_i;
    i_resp_o = bus_resp_i;

    d_ready_o = bus_ready_i && ((can_request && d_valid_i));
    d_rvalid_o = res_is_valid && !res_is_inst_q;
    d_rdata_o = bus_rdata_i;
    d_resp_o = bus_resp_i;

    if (can_request && d_valid_i) begin
      bus_addr_o  = d_addr_i;
      bus_wmask_o = d_wmask_i;
      bus_wdata_o = d_wdata_i;
    end else begin
      bus_addr_o  = i_addr_i;
      bus_wmask_o = '0;
      bus_wdata_o = '0;
    end
  end

  pipeline_reg #(
    .Width(1)
  ) save_req (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .wr_valid_i (bus_valid_o),
    .wr_data_i  (req_is_inst),
    .wr_ready_o (can_request),
    .rd_ready_i (bus_rvalid_i),
    .rd_data_o  (res_is_inst_q),
    .rd_valid_o (is_requesting_q)
  );
endmodule
