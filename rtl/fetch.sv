module fetch import core_pkg::*;
  #(parameter logic [Xlen - 1:0] BootAddr = '0)
  (input logic clk_i
  ,input logic rst_ni

  ,input logic control_hazard_i
  ,input logic [Xlen - 1:0] pc_target_i

  ,input  logic mem_ready_i
  ,output logic mem_valid_o
  ,output logic [Xlen - 1:0] mem_addr_o
  ,input  mem_resp_e mem_resp_i
  ,input  logic [Xlen - 1:0] mem_rdata_i
  ,input  logic mem_rvalid_i

  ,input  logic inst_ready_i
  ,output logic [Xlen - 1:0] inst_pc_o
  ,output logic [Ilen - 1:0] inst_data_o
  ,output logic inst_valid_o
  ,output logic inst_fault_o
  );

  logic [Xlen - 1:0] req_addr_d, req_addr_q, resp_addr_d, resp_addr_q,
    next_addr, inc_next_addr;
  logic fifo_rst, fifo_wr_valid, fifo_wr_ready,
    wait_resp_d, wait_resp_q, req_valid, resp_fault;

  assign mem_valid_o = fifo_wr_ready;
  assign mem_addr_o = control_hazard_i ? pc_target_i : req_addr_q;
  assign fifo_rst = !rst_ni || control_hazard_i;
  assign fifo_wr_valid = (mem_rvalid_i && wait_resp_q);
  assign resp_fault = mem_resp_i == DECERR || mem_resp_i == SLVERR;

  always_comb begin
    wait_resp_d = wait_resp_q;
    req_addr_d = req_addr_q;
    resp_addr_d = resp_addr_q;

    req_valid = mem_ready_i && mem_valid_o;
    next_addr = control_hazard_i ? pc_target_i : req_addr_q;
    inc_next_addr = req_valid ? next_addr + 'h4 : next_addr;

    if (wait_resp_q) begin : wait_resp_valid
      if (control_hazard_i) begin
        wait_resp_d = req_valid;
        req_addr_d = inc_next_addr;
        resp_addr_d = pc_target_i;
      end else if (mem_rvalid_i) begin
        wait_resp_d = req_valid;
        if (req_valid) begin
          req_addr_d = inc_next_addr;
          resp_addr_d = req_addr_q;
        end
      end
    end else begin : wait_req_valid
      wait_resp_d = req_valid;
      if (control_hazard_i) begin
        req_addr_d = inc_next_addr;
        resp_addr_d = pc_target_i;
      end else if (req_valid) begin
        req_addr_d = inc_next_addr;
        resp_addr_d = req_addr_q;
      end
    end
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      wait_resp_q <= 1'b0;
      req_addr_q <= BootAddr;
    end else begin
      wait_resp_q <= wait_resp_d;
      req_addr_q <= req_addr_d;
      resp_addr_q <= resp_addr_d;
    end
  end

  logic [31:0] instmem_high, instmem_low, fetch_rdata;
  assign instmem_high = mem_rdata_i[63:32];
  assign instmem_low  = mem_rdata_i[31:00];
  assign fetch_rdata = resp_addr_q[2] == 1'b0 ? instmem_low : instmem_high;

  fifo #(.DepthLog2(2), .Width(Xlen + Ilen + 1)) fifo_inst (
    .clk_i(clk_i),
    .rst_ni(!fifo_rst),
    .wr_valid_i(fifo_wr_valid),
    .wr_data_i({resp_addr_q, fetch_rdata, resp_fault}),
    .wr_ready_o(),
    .wr_ready_two_o(fifo_wr_ready),
    .rd_ready_i(inst_ready_i),
    .rd_data_o({inst_pc_o, inst_data_o, inst_fault_o}),
    .rd_valid_o(inst_valid_o)
  );

endmodule
