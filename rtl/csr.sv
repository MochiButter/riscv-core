module csr
  import core_pkg::*;
  import csr_pkg::*;
  #(parameter logic [Xlen - 1:0] MHartId = 0)
  (input  logic clk_i
  ,input  logic rst_ni

  ,input  logic              valid_i
  ,input  csr_op_e           csr_op_i

  ,input  logic              expt_valid_i
  ,input  csr_mcause_e       expt_cause_i
  ,input  logic [Xlen - 1:0] expt_value_i

  ,input  logic              inst_ret_i

  ,input  logic [Xlen - 1:0] rs1_data_i
  ,input  logic [11:0]       csr_addr_i
  ,output logic [Xlen - 1:0] rd_data_o

  ,input  logic              msip_i
  ,input  logic              mtip_i
  ,input  logic [Xlen - 1:0] mtime_i
  ,input  logic              can_intr_i

  ,input  logic [Xlen - 1:0] pc_i
  ,output logic              raise_trap_o
  ,output logic [Xlen - 1:0] trap_vector_o

  ,output logic              wfi_busy_o
  );

  logic [Xlen - 1:0] csr_wdata;

  csr_mstatus_t mstatus_d, mstatus_q;
  localparam logic [Xlen - 1:0] MstatusMask =
    64'h0000_0000_0000_0088;

  localparam logic [Xlen - 1:0] Misa =
    (Xlen'(1) << 8) |         // I - RV32I/64I base ISA
    (Xlen'(2) << (Xlen - 2)); // MXLEN - 2 for 64 bits

  logic [Xlen - 1:0] mie_d, mie_q;
  localparam logic [Xlen - 1:0] MieMask =
    64'h0000_0000_0000_0088;

  logic [Xlen - 1:0] mtvec_d, mtvec_q;
  localparam logic [Xlen - 1:0] MtvecMask =
    64'hffff_ffff_ffff_fffd;

  logic [Xlen - 1:0] mscratch_d, mscratch_q;

  logic [Xlen - 1:0] mepc_d, mepc_q;
  localparam PcClearBits = Ilen / 16;
  localparam logic [Xlen - 1:0] MepcMask =
    {{Xlen - PcClearBits{1'b1}}, PcClearBits'(0)};

  logic [Xlen - 1:0] mcause_d, mcause_q;
  logic [Xlen - 1:0] mtval_d, mtval_q;

  logic [Xlen - 1:0] mip_full;
  logic [Xlen - 1:16] mip_d, mip_q;
  logic [15:0] mip_lower;
  // the lower 16 bits of mip are not writeable
  assign mip_lower = {
    2'h0,   // 0
    1'b0,   // lcofip
    1'b0,   // 0
    1'b0,   // meip
    1'b0,   // 0
    1'b0,   // seip
    1'b0,   // 0
    mtip_i, // mtip
    1'b0,   // 0
    1'b0,   // stip
    1'b0,   // 0
    msip_i, // msip
    1'b0,   // 0
    1'b0,   // ssip
    1'b0    // 0
  };
  assign mip_full = {mip_q, mip_lower};

  logic [Xlen - 1:0] mcycle_d, mcycle_q, minstret_d, minstret_q;

  // only the bits 2 and 0 are implemented, the rest are hard-coded zeros
  logic [1:0] mcntinhib_d, mcntinhib_q;

  logic csr_wsc, csr_mret, csr_wfi;
  assign csr_wsc = csr_op_i == OpCSRRW ||
    csr_op_i == OpCSRRS || csr_op_i == OpCSRRC;
  assign csr_mret = csr_op_i == OpMret;
  assign csr_wfi = csr_op_i == OpWfi;

  logic [Xlen - 1:0] mtvec_direct, intr_vector, intr_cause, intr_pending;
  logic raise_expt, raise_intr, trap_return, raise_intr_pending;
  assign intr_pending = mip_full & mie_q;
  assign raise_expt = valid_i && expt_valid_i;
  assign raise_intr_pending = valid_i &&
    mstatus_q.mie && (intr_pending != '0);
  assign raise_intr = raise_intr_pending && (can_intr_i || csr_wfi);
  assign trap_return = valid_i && csr_mret;
  assign raise_trap_o = raise_expt || raise_intr || trap_return;
  assign intr_cause = csr_mcause_e'(intr_pending[3] ? MSoftInt :
    csr_mcause_e'(intr_pending[7] ? MTimerInt : '0));
  assign mtvec_direct = {mtvec_q[Xlen - 1:2], 2'b0};
  assign intr_vector = (mtvec_q[0]) ?
    {mtvec_q[Xlen - 1:2] + intr_cause[Xlen - 3:0], 2'b0} : mtvec_direct;
  assign trap_vector_o = raise_expt ? mtvec_direct :
                         raise_intr ? intr_vector :
                         trap_return ? mepc_q : '0;

  assign wfi_busy_o = (csr_op_i == OpWfi) && !raise_intr_pending;

  always_comb begin
    case (csr_addr_i)
      CSRmhartid:       rd_data_o = MHartId;
      CSRmstatus:       rd_data_o = mstatus_q;
      CSRmisa:          rd_data_o = Misa;
      CSRmie:           rd_data_o = mie_q;
      CSRmtvec:         rd_data_o = mtvec_q;
      CSRmcountinhibit: rd_data_o = {61'd0, mcntinhib_q[1], 1'b0, mcntinhib_q[0]};
      CSRmscratch:      rd_data_o = mscratch_q;
      CSRmepc:          rd_data_o = mepc_q;
      CSRmcause:        rd_data_o = mcause_q;
      CSRmtval:         rd_data_o = mtval_q;
      CSRmip:           rd_data_o = mip_full;
      CSRmcycle:        rd_data_o = mcycle_q;
      CSRminstret:      rd_data_o = minstret_q;
      // Unprivilledged read-only
      CSRcycle:         rd_data_o = mcycle_q;
      CSRtime:          rd_data_o = mtime_i;
      CSRinstret:       rd_data_o = minstret_q;
      // unimplemented csrs should read 0
      // for forwards compatibility
      default: rd_data_o = '0;
    endcase

    case (csr_op_i)
      OpCSRRW: csr_wdata = rs1_data_i;
      OpCSRRS: csr_wdata = rs1_data_i | rd_data_o;
      OpCSRRC: csr_wdata = ~rs1_data_i & rd_data_o;
      default: csr_wdata = 'x;
    endcase

    mstatus_d   = mstatus_q;
    mie_d       = mie_q;
    mtvec_d     = mtvec_q;
    mcntinhib_d = mcntinhib_q;
    mscratch_d  = mscratch_q;
    mepc_d      = mepc_q;
    mcause_d    = mcause_q;
    mtval_d     = mtval_q;
    mip_d       = mip_q;
    mcycle_d    = mcycle_q + (Xlen)'(!mcntinhib_q[0]);
    minstret_d  = inst_ret_i ? minstret_q + (Xlen)'(!mcntinhib_q[1]) : minstret_q;

    if (raise_expt || raise_intr) begin
      mepc_d   = (raise_intr && csr_wfi) ? pc_i + 4 : pc_i;
      mcause_d = csr_mcause_e'(raise_expt ? expt_cause_i : intr_cause);
      mtval_d  = raise_expt ? expt_value_i : '0;
      mstatus_d.mpie = mstatus_q.mie;
      mstatus_d.mie  = 1'b0;
    end else if (trap_return) begin
      mstatus_d.mie  = mstatus_q.mpie;
      mstatus_d.mpie = 1'b1;
    end else if (valid_i && csr_wsc) begin
      case (csr_addr_i)
        CSRmstatus:       mstatus_d   = csr_wdata & MstatusMask;
        CSRmie:           mie_d       = csr_wdata & MieMask;
        CSRmtvec:         mtvec_d     = csr_wdata & MtvecMask;
        CSRmcountinhibit: mcntinhib_d = {csr_wdata[2], csr_wdata[0]};
        CSRmscratch:      mscratch_d  = csr_wdata;
        CSRmepc:          mepc_d      = csr_wdata & MepcMask;
        CSRmcause:        mcause_d    = csr_wdata;
        CSRmtval:         mtval_d     = csr_wdata;
        CSRmip:           mip_d       = csr_wdata[Xlen - 1:16];
        CSRmcycle:        mcycle_d    = csr_wdata;
        CSRminstret:      minstret_d  = csr_wdata;
        default: ;
      endcase
    end
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      mstatus_q   <= '0;
      mie_q       <= '0;
      mtvec_q     <= '0;
      mcntinhib_q <= '0;
      mscratch_q  <= '0;
      mepc_q      <= '0;
      mcause_q    <= '0;
      mtval_q     <= '0;
      mip_q       <= '0;
      mcycle_q    <= '0;
      minstret_q  <= '0;
    end else begin
      mstatus_q   <= mstatus_d;
      mie_q       <= mie_d;
      mtvec_q     <= mtvec_d;
      mcntinhib_q <= mcntinhib_d;
      mscratch_q  <= mscratch_d;
      mepc_q      <= mepc_d;
      mcause_q    <= mcause_d;
      mtval_q     <= mtval_d;
      mip_q       <= mip_d;
      mcycle_q    <= mcycle_d;
      minstret_q  <= minstret_d;
    end
  end
endmodule
