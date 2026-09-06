module core
  import core_pkg::*;
  import csr_pkg::*;
  import pipeline_pkg::*;
  #(parameter logic [Xlen - 1:0] BootAddr = '0)
  (input logic clk_i
  ,input logic rst_ni

  ,input  logic                    instmem_ready_i
  ,output logic                    instmem_valid_o
  ,output logic [Xlen - 1:0]       instmem_addr_o
  ,output logic [Xlen - 1:0]       instmem_wdata_o
  ,output logic [MaskBits - 1:0]   instmem_wmask_o
  ,input  mem_resp_e               instmem_resp_i
  ,input  logic [Xlen - 1:0]       instmem_rdata_i
  ,input  logic                    instmem_rvalid_i

  ,input  logic                    datamem_ready_i
  ,output logic                    datamem_valid_o
  ,output logic [Xlen - 1:0]       datamem_addr_o
  ,output logic [Xlen - 1:0]       datamem_wdata_o
  ,output logic [MaskBits - 1:0]   datamem_wmask_o
  ,input  mem_resp_e               datamem_resp_i
  ,input  logic [Xlen - 1:0]       datamem_rdata_i
  ,input  logic                    datamem_rvalid_i

  ,input  logic              msip_i
  ,input  logic              mtip_i
  ,input  logic [Xlen - 1:0] mtime_i

`ifdef RISCV_FORMAL
  ,output logic [Nret        - 1 : 0] rvfi_valid
  ,output logic [Nret *   64 - 1 : 0] rvfi_order
  ,output logic [Nret * Ilen - 1 : 0] rvfi_insn
  ,output logic [Nret        - 1 : 0] rvfi_trap
  ,output logic [Nret        - 1 : 0] rvfi_halt
  ,output logic [Nret        - 1 : 0] rvfi_intr
  ,output logic [Nret * 2    - 1 : 0] rvfi_mode
  ,output logic [Nret * 2    - 1 : 0] rvfi_ixl
  ,output logic [Nret *    5 - 1 : 0] rvfi_rs1_addr
  ,output logic [Nret *    5 - 1 : 0] rvfi_rs2_addr
  ,output logic [Nret * Xlen - 1 : 0] rvfi_rs1_rdata
  ,output logic [Nret * Xlen - 1 : 0] rvfi_rs2_rdata
  ,output logic [Nret *    5 - 1 : 0] rvfi_rd_addr
  ,output logic [Nret * Xlen - 1 : 0] rvfi_rd_wdata
  ,output logic [Nret * Xlen - 1 : 0] rvfi_pc_rdata
  ,output logic [Nret * Xlen - 1 : 0] rvfi_pc_wdata
  ,output logic [Nret * Xlen   - 1 : 0] rvfi_mem_addr
  ,output logic [Nret * Xlen/8 - 1 : 0] rvfi_mem_rmask
  ,output logic [Nret * Xlen/8 - 1 : 0] rvfi_mem_wmask
  ,output logic [Nret * Xlen   - 1 : 0] rvfi_mem_rdata
  ,output logic [Nret * Xlen   - 1 : 0] rvfi_mem_wdata
`endif
  );

  logic idex_wr_valid, idex_wr_ready, idex_rd_ready, idex_rd_valid;
  idex_reg_t idex_d, idex_q;

  logic exmem_wr_valid, exmem_wr_ready, exmem_rd_ready, exmem_rd_valid;
  exmem_reg_t exmem_d, exmem_q;

  logic memwb_wr_valid, memwb_rd_valid;
  memwb_reg_t memwb_d, memwb_q;

  /* Instruction fetch signals */
  logic [Xlen - 1:0] ifs_inst_pc;
  logic [Ilen - 1:0] ifs_inst_data;
  logic ifs_inst_fault;
  assign instmem_wmask_o = '0;
  assign instmem_wdata_o = 'x;

  /* Register signals */
  logic [Xlen - 1:0] exs_rs1_data, exs_rs2_data;
  logic [Xlen - 1:0] wbs_rd_data;

  /* Mem stage jump signals */
  logic [Xlen - 1:0] mems_pc_target;
  logic mems_control_hazard, pipeline_rst;
  assign pipeline_rst = rst_ni && !mems_control_hazard;

  /* Forwarding control */
  logic mems_is_wb, wbs_is_wb;
  assign mems_is_wb = exmem_rd_valid && exmem_q.reg_wb_src != WbNone;
  assign wbs_is_wb  = memwb_rd_valid && memwb_q.reg_wb_src != WbNone;

  /* Signals for cocotb */
  /* verilator lint_off UNUSEDSIGNAL */
  logic test_mems_valid, test_mems_busy;
  assign test_mems_valid = exmem_rd_valid;
  assign test_mems_busy = !exmem_rd_ready;
  logic [Xlen - 1:0] test_mems_pc;
  assign test_mems_pc = exmem_q.inst_pc;
  logic test_mems_ebreak;
  assign test_mems_ebreak = (exmem_q.csr_op == OpEbreak);
  /* verilator lint_on UNUSEDSIGNAL */

  fetch #(
    .BootAddr(BootAddr)
  ) fetch_inst (
    .clk_i            (clk_i),
    .rst_ni           (rst_ni),
    .control_hazard_i (mems_control_hazard),
    .pc_target_i      (mems_pc_target),
    .mem_ready_i      (instmem_ready_i),
    .mem_valid_o      (instmem_valid_o),
    .mem_addr_o       (instmem_addr_o),
    .mem_resp_i       (instmem_resp_i),
    .mem_rdata_i      (instmem_rdata_i),
    .mem_rvalid_i     (instmem_rvalid_i),
    .inst_ready_i     (idex_wr_ready),
    .inst_pc_o        (ifs_inst_pc),
    .inst_data_o      (ifs_inst_data),
    .inst_valid_o     (idex_wr_valid),
    .inst_fault_o     (ifs_inst_fault)
  );

  /* ===== [IF -> ID] ===== */
  /* The fifo is integrated inside of the fetch module */

  decode #() decode_inst (
    .inst_i        (ifs_inst_data),
    .pc_i          (ifs_inst_pc),
    .fault_i       (ifs_inst_fault),
    .imm_o         (idex_d.inst_imm),
    .inst_type_o   (idex_d.inst_type),
    .jump_type_o   (idex_d.jump_type),
    .reg_wb_src_o  (idex_d.reg_wb_src),
    .alu_op_o      (idex_d.alu_op),
    .mem_type_o    (idex_d.mem_type),
    .rs1_addr_o    (idex_d.rs1_addr),
    .rs2_addr_o    (idex_d.rs2_addr),
    .rd_addr_o     (idex_d.rd_addr),
    .csr_op_o      (idex_d.csr_op),
    .csr_imm_o     (idex_d.csr_use_imm),
    .csr_addr_o    (idex_d.csr_addr),
    .expt_valid_o  (idex_d.expt_valid),
    .expt_cause_o  (idex_d.expt_cause),
    .expt_value_o  (idex_d.expt_value),
    .is_fencei_o   (idex_d.is_fencei)
  );

  assign idex_d.inst_pc = ifs_inst_pc;
  assign idex_d.funct3 = ifs_inst_data[14:12];

  pipeline_reg #(.Width($bits(idex_reg_t))) pipeline_idex (
    .clk_i      (clk_i),
    .rst_ni     (pipeline_rst),
    .wr_valid_i (idex_wr_valid),
    .wr_data_i  (idex_d),
    .wr_ready_o (idex_wr_ready),
    .rd_ready_i (idex_rd_ready),
    .rd_data_o  (idex_q),
    .rd_valid_o (idex_rd_valid)
  );

  /* ===== [ID -> EX] ===== */

  logic [Xlen - 1:0] alu_a, alu_b;
  logic [Xlen - 1:0] alu_imm, alu_pc;
  inst_type_e alu_inst_type;
  assign alu_imm = idex_q.inst_imm;
  assign alu_pc = idex_q.inst_pc;
  assign alu_inst_type = idex_q.inst_type;

  /* Frowarding control */
  logic exs_mem_rs1_fwd, exs_mem_rs2_fwd, exs_wb_rs1_fwd, exs_wb_rs2_fwd;
  assign exs_mem_rs1_fwd = mems_is_wb && idex_q.rs1_addr != '0 &&
    idex_q.rs1_addr == exmem_q.rd_addr;
  assign exs_mem_rs2_fwd = mems_is_wb && idex_q.rs2_addr != '0 &&
    idex_q.rs2_addr == exmem_q.rd_addr;
  assign exs_wb_rs1_fwd  = wbs_is_wb  && idex_q.rs1_addr != '0 &&
    idex_q.rs1_addr == memwb_q.rd_addr;
  assign exs_wb_rs2_fwd  = wbs_is_wb  && idex_q.rs2_addr != '0 &&
    idex_q.rs2_addr == memwb_q.rd_addr;

  logic [Xlen - 1:0] exs_rs1_fwd, exs_rs2_fwd, mems_rd_data;
  assign exs_rs1_fwd = exs_mem_rs1_fwd ? mems_rd_data :
                       exs_wb_rs1_fwd ? wbs_rd_data :
                       exs_rs1_data;
  assign exs_rs2_fwd = exs_mem_rs2_fwd ? mems_rd_data :
                       exs_wb_rs2_fwd ? wbs_rd_data :
                       exs_rs2_data;

  always_comb begin
    case (alu_inst_type)
      Rtype, Btype: begin alu_a = exs_rs1_fwd; alu_b = exs_rs2_fwd; end
      Itype, Stype: begin alu_a = exs_rs1_fwd; alu_b = alu_imm;     end
      Utype:        begin alu_a = alu_pc;      alu_b = alu_imm;    end
      default:      begin alu_a = 'x;          alu_b = 'x;         end
    endcase
  end

  alu #() alu_inst (
    .alu_op_i      (idex_q.alu_op),
    .a_i           (alu_a),
    .b_i           (alu_b),
    .res_o         (exmem_d.alu_res),
    .branch_take_o (exmem_d.branch_take)
  );

  assign idex_rd_ready  = exmem_wr_ready;
  assign exmem_wr_valid = idex_rd_valid;

  /* To Mem, Wb */
  assign exmem_d.inst_pc     = idex_q.inst_pc;
  assign exmem_d.inst_imm    = idex_q.inst_imm;

  /* To Mem */
  assign exmem_d.rs1_addr    = idex_q.rs1_addr;
  assign exmem_d.rs2_addr    = idex_q.rs2_addr;
  assign exmem_d.rs1_data    = exs_rs1_fwd;
  assign exmem_d.rs2_data    = exs_rs2_fwd;

  assign exmem_d.mem_type    = idex_q.mem_type;
  assign exmem_d.funct3      = idex_q.funct3;

  assign exmem_d.csr_op      = idex_q.csr_op;
  assign exmem_d.csr_addr    = idex_q.csr_addr;
  assign exmem_d.csr_use_imm = idex_q.csr_use_imm;

  assign exmem_d.expt_valid  = idex_q.expt_valid;
  assign exmem_d.expt_cause  = idex_q.expt_cause;
  assign exmem_d.expt_value  = idex_q.expt_value;

  assign exmem_d.jump_type   = idex_q.jump_type;

  assign exmem_d.is_fencei   = idex_q.is_fencei;

  /* To Wb */
  assign exmem_d.reg_wb_src  = idex_q.reg_wb_src;
  assign exmem_d.rd_addr     = idex_q.rd_addr;

  pipeline_reg #(.Width($bits(exmem_reg_t))) pipeline_exmem (
    .clk_i      (clk_i),
    .rst_ni     (pipeline_rst),
    .wr_valid_i (exmem_wr_valid),
    .wr_data_i  (exmem_d),
    .wr_ready_o (exmem_wr_ready),
    .rd_ready_i (exmem_rd_ready),
    .rd_data_o  (exmem_q),
    .rd_valid_o (exmem_rd_valid)
  );

  /* ===== [EX -> MEM] ===== */

  logic mems_busy, mems_csr_busy, mems_lsu_misalign;
  logic [Xlen - 1:0] mems_load_data;

  logic mems_is_new_q;
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      mems_is_new_q <= 1'b0;
    end else begin
      mems_is_new_q <= (exmem_rd_valid) ? exmem_rd_ready : 1'b1;
    end
  end

  /* Forwarding control */
  logic [4:0] mems_rs1_addr, mems_rs2_addr;
  assign mems_rs1_addr = exmem_q.rs1_addr;
  assign mems_rs2_addr = exmem_q.rs2_addr;
  logic mems_wbs_rs1_fwd, mems_wbs_rs2_fwd;
  assign mems_wbs_rs1_fwd = wbs_is_wb && mems_rs1_addr != '0 &&
    exmem_q.rs1_addr == memwb_q.rd_addr;
  assign mems_wbs_rs2_fwd = wbs_is_wb && mems_rs2_addr != '0 &&
    exmem_q.rs2_addr == memwb_q.rd_addr;

  logic [Xlen - 1:0] mems_rs1_fwd, mems_rs2_fwd;
  assign mems_rs1_fwd = mems_wbs_rs1_fwd ? wbs_rd_data : exmem_q.rs1_data;
  assign mems_rs2_fwd = mems_wbs_rs2_fwd ? wbs_rd_data : exmem_q.rs2_data;

  /* Mux csr data in */
  logic [Xlen - 1:0] mems_csr_rs1_data, mems_csr_trap_vector;
  assign mems_csr_rs1_data = exmem_q.csr_use_imm ?
    exmem_q.inst_imm : mems_rs1_fwd;
  logic mems_csr_raise_trap;

  /* Compute jump target */
  logic [Xlen - 1:0] mems_jump_target, mems_inst_pc, mems_inst_imm;
  logic mems_jump, mems_inst_misalign;
  assign mems_inst_pc = exmem_q.inst_pc;
  assign mems_inst_imm = exmem_q.inst_imm;

  assign mems_jump = exmem_rd_valid && (
    (exmem_q.jump_type == JmpJal || exmem_q.jump_type == JmpJalr) ||
    (exmem_q.jump_type == JmpBr && exmem_q.branch_take));
  assign mems_control_hazard = mems_jump || mems_csr_raise_trap || exmem_q.is_fencei;

  assign mems_jump_target = (exmem_q.jump_type == JmpJalr) ?
    {exmem_q.alu_res[Xlen - 1:1], 1'b0} :
    (mems_inst_pc + (exmem_q.is_fencei ? 'h4 : mems_inst_imm));
  assign mems_pc_target = mems_csr_raise_trap ? mems_csr_trap_vector : mems_jump_target;
  assign mems_inst_misalign = mems_jump && mems_jump_target[1:0] != 2'b00;

  /* LSU access fault */
  logic mems_lsu_fault;

  /* LSU misaligned access */
  logic [2:0] mems_lsu_bits_dword;
  logic [1:0] mems_lsu_bits_word;
  logic mems_lsu_bits_half;
  logic [1:0] mems_lsuop;
  assign mems_lsu_bits_dword = exmem_q.alu_res[2:0];
  assign mems_lsu_bits_word = exmem_q.alu_res[1:0];
  assign mems_lsu_bits_half = exmem_q.alu_res[0];
  assign mems_lsuop = exmem_q.funct3[1:0];
  always_comb begin
    case (mems_lsuop)
      1: mems_lsu_misalign = mems_lsu_bits_half  != 1'h0;
      2: mems_lsu_misalign = mems_lsu_bits_word  != 2'h0;
      3: mems_lsu_misalign = mems_lsu_bits_dword != 3'h0;
      default: mems_lsu_misalign = '0;
    endcase
  end

  logic [Xlen - 1:0] mems_csr_rd_data, mems_alu_res;
  reg_wb_src_e mems_reg_wb_src;
  assign mems_csr_rd_data = memwb_d.csr_rd_data;
  assign mems_alu_res     = exmem_q.alu_res;
  assign mems_reg_wb_src  = exmem_q.reg_wb_src;

  logic [Xlen - 1:0] mems_expt_cause, mems_expt_value, exmem_expt_cause, exmem_expt_value;
  logic exmem_expt_valid, mems_expt_valid;
  mem_type_e mems_mem_type;
  assign mems_mem_type = exmem_q.mem_type;
  assign exmem_expt_cause = exmem_q.expt_cause;
  assign exmem_expt_value = exmem_q.expt_value;
  assign exmem_expt_valid = exmem_q.expt_valid;
  always_comb begin
    mems_expt_valid = exmem_expt_valid;
    mems_expt_cause = exmem_expt_cause;
    mems_expt_value = exmem_expt_value;

    // See pg. 50 of the privileged ISA document ver. 20251003 for the
    // mcause priority order
    if (!exmem_rd_valid || !exmem_expt_valid) begin
      if (mems_inst_misalign) begin
        mems_expt_valid = 1'b1;
        mems_expt_cause = InstAddrMisaligned;
        mems_expt_value = mems_jump_target;
      end else if (mems_lsu_fault) begin
        mems_expt_valid = 1'b1;
        mems_expt_cause = (mems_mem_type == MemLoad) ? LdAccessFault : StAccessFault;
        mems_expt_value = mems_alu_res;
      end else if (mems_lsu_misalign && mems_mem_type != MemNone) begin
        mems_expt_valid = 1'b1;
        mems_expt_cause = (mems_mem_type == MemLoad) ? LdAddrMisaligned : StAddrMisaligned;
        mems_expt_value = mems_alu_res;
      end
    end
  end

  csr #(.MHartId('h0)) csr_inst (
    .clk_i         (clk_i),
    .rst_ni        (rst_ni),
    .valid_i       (exmem_rd_valid),
    .csr_op_i      (exmem_q.csr_op),
    .expt_valid_i  (mems_expt_valid),
    .expt_cause_i  (mems_expt_cause),
    .expt_value_i  (mems_expt_value),
    .inst_ret_i    (memwb_rd_valid && !memwb_q.expt_valid),
    .rs1_data_i    (mems_csr_rs1_data),
    .csr_addr_i    (exmem_q.csr_addr),
    .rd_data_o     (memwb_d.csr_rd_data),
    .msip_i        (msip_i),
    .mtip_i        (mtip_i),
    .mtime_i       (mtime_i),
    .can_intr_i    (mems_is_new_q),
    .pc_i          (exmem_q.inst_pc),
    .raise_trap_o  (mems_csr_raise_trap),
    .trap_vector_o (mems_csr_trap_vector),
    .wfi_busy_o    (mems_csr_busy)
  );

  mem_lsu #() lsu_inst (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),

    .valid_inst_i (exmem_rd_valid && !mems_csr_raise_trap),
    .mem_type_i   (exmem_q.mem_type),
    .addr_i       (exmem_q.alu_res),
    .wdata_i      (mems_rs2_fwd),
    .funct3_i     (exmem_q.funct3),
    .rdata_o      (mems_load_data),
    .mem_busy_o   (mems_busy),
    .mem_expt_o   (mems_lsu_fault),

    .mem_ready_i  (datamem_ready_i),
    .mem_valid_o  (datamem_valid_o),
    .mem_addr_o   (datamem_addr_o),
    .mem_wdata_o  (datamem_wdata_o),
    .mem_wmask_o  (datamem_wmask_o),
    .mem_resp_i   (datamem_resp_i),
    .mem_rdata_i  (datamem_rdata_i),
    .mem_rvalid_i (datamem_rvalid_i)
  );

  always_comb begin
    case (mems_reg_wb_src)
      WbLsu: mems_rd_data   = mems_load_data;
      WbCsr: mems_rd_data   = mems_csr_rd_data;
      WbLui: mems_rd_data   = mems_inst_imm;
      WbJmp: mems_rd_data   = mems_inst_pc + 4;
      default: mems_rd_data = mems_alu_res;
    endcase
  end

  assign exmem_rd_ready = !(mems_busy || mems_csr_busy);
  assign memwb_wr_valid = exmem_rd_valid && !(mems_busy || mems_csr_busy);

  /* To Wb */
  assign memwb_d.reg_wb_src = exmem_q.reg_wb_src;
  assign memwb_d.load_data  = mems_load_data;
  assign memwb_d.inst_imm   = exmem_q.inst_imm;
  assign memwb_d.inst_pc    = exmem_q.inst_pc;
  assign memwb_d.alu_res    = exmem_q.alu_res;
  assign memwb_d.rd_addr    = exmem_q.rd_addr;
  assign memwb_d.expt_valid = mems_expt_valid;

  // wb is always ready to accept rd_data
  pipeline_reg #(.Width($bits(memwb_reg_t))) pipeline_memwb (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .wr_valid_i (memwb_wr_valid),
    .wr_data_i  (memwb_d),
    .wr_ready_o (),
    .rd_ready_i (1'b1),
    .rd_data_o  (memwb_q),
    .rd_valid_o (memwb_rd_valid)
  );

  /* ===== [MEM -> WB] ===== */

  logic wbs_reg_wb_en;
  logic [4:0] wbs_rd_addr;
  assign wbs_rd_addr = memwb_q.rd_addr;

  logic [Xlen - 1:0] wbs_load_data, wbs_csr_rd_data,
    wbs_inst_imm, wbs_inst_pc, wbs_alu_res;
  reg_wb_src_e wbs_reg_wb_src;
  assign wbs_load_data   = memwb_q.load_data;
  assign wbs_csr_rd_data = memwb_q.csr_rd_data;
  assign wbs_inst_imm    = memwb_q.inst_imm;
  assign wbs_inst_pc     = memwb_q.inst_pc;
  assign wbs_alu_res     = memwb_q.alu_res;
  assign wbs_reg_wb_src  = memwb_q.reg_wb_src;

  always_comb begin
    case (wbs_reg_wb_src)
      WbLsu: wbs_rd_data   = wbs_load_data;
      WbCsr: wbs_rd_data   = wbs_csr_rd_data;
      WbLui: wbs_rd_data   = wbs_inst_imm;
      WbJmp: wbs_rd_data   = wbs_inst_pc + 4;
      default: wbs_rd_data = wbs_alu_res;
    endcase
  end

  assign wbs_reg_wb_en = (memwb_q.reg_wb_src != WbNone) && memwb_rd_valid && !memwb_q.expt_valid;

  register #(.RegWidth(Xlen)) reg_inst (
    .clk_i         (clk_i),
    .rs1_addr_i    (idex_q.rs1_addr),
    .rs2_addr_i    (idex_q.rs2_addr),
    .rd_addr_i     (wbs_rd_addr),
    .rd_data_i     (wbs_rd_data),
    .rd_write_en_i (wbs_reg_wb_en),
    .rs1_data_o    (exs_rs1_data),
    .rs2_data_o    (exs_rs2_data)
  );

`ifdef RISCV_FORMAL
  /* A mini-pipeline that uses the main pipeline's signal, but contains data
   * that would be useless for the write-back stage outside of the rvfi trace.
   */
  logic [Ilen - 1:0] inst_data_q [0:2];
  logic [Xlen - 1:0] inst_pc_next_q, mem_addr_q, mem_rdata_q, mem_wdata_q,
    rs1_data_q, rs2_data_q;
  logic [MaskBits - 1:0] mem_wmask_q;
  logic [4:0] rs1_addr_q, rs2_addr_q;
  logic intr_q [0:1];
  logic jump_q;
  mem_type_e mem_type_q;

  // rvfi asks addresses to always be aligned to the 4/8 byte boundary
  localparam logic [Xlen - 1:0] AddrMask =
    {{Xlen - $clog2(MaskBits){1'b1}}, $clog2(MaskBits)'(0)};

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      for (int i = 0; i < 3; i ++) begin
        inst_data_q[i] <= '0;
      end
      for (int i = 0; i < 2; i ++) begin
        intr_q[i] <= '0;
      end
      rs1_addr_q <= '0;
      rs2_addr_q <= '0;
      rs1_data_q <= '0;
      rs2_data_q <= '0;
      inst_pc_next_q <= '0;
      jump_q <= '0;
      mem_type_q <= MemNone;
      mem_wdata_q <= '0;
      mem_rdata_q <= '0;
    end else begin
      if (idex_wr_valid && idex_wr_ready) begin
        inst_data_q[0] <= ifs_inst_data;
      end
      if (exmem_wr_valid && exmem_wr_ready) begin
        inst_data_q[1] <= inst_data_q[0];
      end
      if (memwb_wr_valid) begin
        inst_data_q[2] <= inst_data_q[1];
        intr_q[0] <= mems_csr_raise_trap;
        rs1_addr_q <= mems_rs1_addr;
        rs2_addr_q <= mems_rs2_addr;
        rs1_data_q <= mems_rs1_fwd;
        rs2_data_q <= mems_rs2_fwd;
        inst_pc_next_q <= mems_jump_target;
        jump_q <= mems_jump;
        mem_type_q <= mems_mem_type;
        mem_addr_q <= (datamem_addr_o & AddrMask);
        mem_rdata_q <= datamem_rdata_i;
        mem_wdata_q <= datamem_wdata_o;
        mem_wmask_q <= datamem_wmask_o;
      end
      if (memwb_rd_valid) begin
        intr_q[1] <= intr_q[0];
      end
    end
  end

  assign rvfi_valid = memwb_rd_valid;

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      rvfi_order <= '0;
    end else if (memwb_rd_valid) begin
      rvfi_order <= rvfi_order + 64'd1;
    end
  end

  assign rvfi_insn = inst_data_q[2];
  assign rvfi_trap = memwb_q.expt_valid;
  assign rvfi_halt = 1'b0;
  assign rvfi_intr = intr_q[1];
  assign rvfi_mode = 2'h3;
  assign rvfi_ixl  = 2'h2;

  assign rvfi_rs1_addr  = rs1_addr_q;
  assign rvfi_rs2_addr  = rs2_addr_q;
  assign rvfi_rs1_rdata = rs1_data_q;
  assign rvfi_rs2_rdata = rs2_data_q;

  assign rvfi_rd_addr  = wbs_reg_wb_en ? wbs_rd_addr : '0;
  assign rvfi_rd_wdata = (wbs_reg_wb_en && wbs_rd_addr != '0) ? wbs_rd_data : '0;

  assign rvfi_pc_rdata = wbs_inst_pc;
  // does not take into account intr/expt/dbg
  assign rvfi_pc_wdata = jump_q ? inst_pc_next_q : (wbs_inst_pc + 'h4);

  assign rvfi_mem_addr  = (mem_type_q != MemNone)  ?   mem_addr_q : '0;
  assign rvfi_mem_rmask = (mem_type_q == MemLoad)  ? ~mem_wmask_q : '0;
  assign rvfi_mem_wmask = (mem_type_q == MemStore) ?  mem_wmask_q : '0;
  assign rvfi_mem_rdata = (mem_type_q == MemLoad)  ?  mem_rdata_q : '0;
  assign rvfi_mem_wdata = (mem_type_q == MemStore) ?  mem_wdata_q : '0;
`endif
endmodule
