module mem_to_axil
  import axil_pkg::*;
  #(parameter BusWidth = 64
  ,localparam MaskBits = BusWidth / 8)
  (input  logic clk_i
  ,input  logic rst_ni

  ,output logic                  mem_ready_o
  ,input  logic                  mem_valid_i
  ,input  logic [BusWidth - 1:0] mem_addr_i
  ,input  logic [BusWidth - 1:0] mem_wdata_i
  ,input  logic [MaskBits - 1:0] mem_wmask_i
  ,output axil_resp_e            mem_resp_o
  ,output logic [BusWidth - 1:0] mem_rdata_o
  ,output logic                  mem_rvalid_o

  ,axil_if.m m_axil
  );

  typedef enum logic [2:0] {
    Reset, Idle, WaitRvalid, WaitAwready, WaitWready, WaitBvalid
  } axil_state_e;

  axil_state_e state_d, state_q;

  always_comb begin
    state_d = state_q;

    m_axil.arvalid = 1'b0;
    m_axil.awvalid = 1'b0;
    m_axil.wvalid  = 1'b0;
    m_axil.rready  = 1'b0;
    m_axil.bready  = 1'b0;

    mem_ready_o = 1'b0;

    case (state_q)
      // A reset state to guarantee that the valid signals stay low for one
      // cycle after a reset
      Reset: state_d = Idle;
      Idle, WaitRvalid, WaitBvalid: begin
        if (state_q == WaitRvalid) begin
          m_axil.rready = 1'b1;
          state_d = axil_state_e'(m_axil.rvalid ? Idle : WaitRvalid);
        end else if (state_q == WaitBvalid) begin
          m_axil.bready = 1'b1;
          state_d = axil_state_e'(m_axil.bvalid ? Idle : WaitBvalid);
        end
        if (mem_valid_i && (state_q == Idle ||
          (state_q == WaitRvalid && m_axil.rvalid) ||
          (state_q == WaitBvalid && m_axil.bvalid))) begin
          if (mem_wmask_i == '0) begin
            m_axil.arvalid = 1'b1;
            if (m_axil.arready) begin
              state_d     = WaitRvalid;
              mem_ready_o = 1'b1;
            end
          end else begin
            m_axil.awvalid = 1'b1;
            m_axil.wvalid  = 1'b1;
            case ({m_axil.awready, m_axil.wready})
              2'b01: state_d = WaitAwready;
              2'b10: state_d = WaitWready;
              2'b11: begin
                state_d     = WaitBvalid;
                mem_ready_o = 1'b1;
              end
              default: ;
            endcase
          end
        end
      end
      WaitAwready: begin
        m_axil.awvalid = 1'b1;
        if (m_axil.awready) begin
          state_d     = WaitBvalid;
          mem_ready_o = 1'b1;
        end
      end
      WaitWready: begin
        m_axil.wvalid  = 1'b1;
        if (m_axil.wready) begin
          state_d     = WaitBvalid;
          mem_ready_o = 1'b1;
        end
      end
      default: state_d = Reset;
    endcase
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      state_q <= Reset;
    end else begin
      state_q <= state_d;
    end
  end

  assign m_axil.awaddr  = mem_addr_i;
  assign m_axil.awprot  = '0;
  assign m_axil.wdata   = mem_wdata_i;
  assign m_axil.wstrb   = mem_wmask_i;
  assign m_axil.araddr  = mem_addr_i;
  assign m_axil.arprot  = '0;

  assign mem_rdata_o = m_axil.rdata;
  assign mem_resp_o = m_axil.bready ? m_axil.bresp : m_axil.rresp;
  assign mem_rvalid_o = (m_axil.bready && m_axil.bvalid) ||
    (m_axil.rready && m_axil.rvalid);

  axil_resp_e __unused_resp[0:1];
  assign __unused_resp = {m_axil.bresp, m_axil.rresp};
endmodule
