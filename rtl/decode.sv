module decode
  import core_pkg::*;
  import csr_pkg::*;
  (input  logic [Ilen - 1:0] inst_i
  ,input  logic [Xlen - 1:0] pc_i
  ,output logic [Xlen - 1:0] imm_o
  ,output inst_type_e        inst_type_o
  ,output jump_type_e        jump_type_o
  ,output reg_wb_src_e       reg_wb_src_o

  ,output alu_op_e           alu_op_o
  ,output mem_type_e         mem_type_o

  ,output logic [4:0]        rs1_addr_o
  ,output logic [4:0]        rs2_addr_o
  ,output logic [4:0]        rd_addr_o

  ,output csr_op_e           csr_op_o
  ,output logic              csr_imm_o
  ,output logic [11:0]       csr_addr_o

  ,output logic              expt_valid_o
  ,output csr_mcause_e       expt_cause_o
  ,output logic [Xlen - 1:0] expt_value_o

  ,output logic              is_fencei_o
  );

  typedef enum logic [6:0] {
    OpALU    = 7'b0110011,
    OpALUImm = 7'b0010011,
    OpALU32  = 7'b0111011,
    OpALU32I = 7'b0011011,
    OpLoad   = 7'b0000011,
    OpStore  = 7'b0100011,
    OpBranch = 7'b1100011,
    OpJal    = 7'b1101111,
    OpJalr   = 7'b1100111,
    OpLui    = 7'b0110111,
    OpAuipc  = 7'b0010111,
    OpSys    = 7'b1110011,
    OpMisc   = 7'b0001111
  } opcode_e;

  logic illegal_inst, ex_ecall, ex_ebreak;

  logic [9:0] funct10;
  logic [6:0] opcode, funct7;
  logic [5:0] funct6;
  logic [2:0] funct3;
  assign opcode = inst_i[6:0];
  assign funct10 = {funct7, funct3};
  assign funct7 = inst_i[31:25];
  assign funct6 = funct7[6:1];
  assign funct3 = inst_i[14:12];

  logic [4:0] rs1_bits, rs2_bits;
  assign rs1_bits = inst_i[19:15];
  assign rs2_bits = inst_i[24:20];
  assign rd_addr_o = inst_i[11:7];

  logic csr_addr_rdonly;
  assign csr_addr_rdonly = (inst_i[31:30] == 2'b11);
  assign csr_addr_o = inst_i[31:20];
  assign csr_imm_o = funct3[2];

  logic [Xlen - 1:0] imm_i, imm_s, imm_b, imm_u, imm_j, imm_sys;
  assign imm_i = {{Xlen - 12{inst_i[31]}}, inst_i[31:20]};
  assign imm_s = {{Xlen - 12{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
  assign imm_b = {{Xlen - 13{inst_i[31]}}, inst_i[31], inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
  assign imm_u = {{Xlen - 32{inst_i[31]}}, inst_i[31:12], 12'b0};
  assign imm_j = {{Xlen - 21{inst_i[31]}}, inst_i[31], inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
  assign imm_sys = {{Xlen - 5{1'b0}}, inst_i[19:15]};

  always_comb begin
    imm_o = 'x;
    inst_type_o = Rtype;
    jump_type_o = JmpNone;
    reg_wb_src_o = WbNone;
    alu_op_o = OpAdd;
    mem_type_o = MemNone;
    csr_op_o = OpCSRNone;
    expt_valid_o = 1'b0;
    expt_cause_o = InstAddrMisaligned;
    expt_value_o = '0;
    illegal_inst = 1'b0;
    ex_ecall = 1'b0;
    ex_ebreak = 1'b0;
    is_fencei_o = 1'b0;

    case (opcode)
      OpALU: begin
        case (funct10)
          10'h000: alu_op_o = OpAdd;
          10'h100: alu_op_o = OpSub;
          10'h004: alu_op_o = OpXor;
          10'h006: alu_op_o = OpOr;
          10'h007: alu_op_o = OpAnd;
          10'h001: alu_op_o = OpSll;
          10'h005: alu_op_o = OpSrl;
          10'h105: alu_op_o = OpSra;
          10'h002: alu_op_o = OpSlt;
          10'h003: alu_op_o = OpSltu;
          default: illegal_inst = 1'b1;
        endcase

        inst_type_o = Rtype;
        reg_wb_src_o = WbAlu;
      end
      OpALUImm: begin
        case (funct3)
          3'h0: alu_op_o = OpAdd;
          3'h4: alu_op_o = OpXor;
          3'h6: alu_op_o = OpOr;
          3'h7: alu_op_o = OpAnd;
          3'h1: alu_op_o = OpSll;
          3'h5: begin
            if (funct6 == 6'h00) begin
              alu_op_o = OpSrl;
            end else if (funct6 == 6'h10) begin
              alu_op_o = OpSra;
            end else begin
              illegal_inst = 1'b1;
            end
          end
          3'h2: alu_op_o = OpSlt;
          3'h3: alu_op_o = OpSltu;
        endcase

        inst_type_o = Itype;
        reg_wb_src_o = WbAlu;
        imm_o = imm_i;
      end
      OpALU32: begin
        case (funct10)
          10'h000: alu_op_o = OpAddw;
          10'h100: alu_op_o = OpSubw;
          10'h001: alu_op_o = OpSllw;
          10'h005: alu_op_o = OpSrlw;
          10'h105: alu_op_o = OpSraw;
          default: illegal_inst = 1'b1;
        endcase

        inst_type_o = Rtype;
        reg_wb_src_o = WbAlu;
      end
      OpALU32I: begin
        case (funct3)
          3'h0: alu_op_o = OpAddw;
          3'h1: alu_op_o = OpSllw;
          3'h5: begin
            if (funct7 == 7'h00) begin
              alu_op_o = OpSrlw;
            end else if (funct7 == 7'h20) begin
              alu_op_o = OpSraw;
            end else begin
              illegal_inst = 1'b1;
            end
          end
          default: illegal_inst = 1'b1;
        endcase

        inst_type_o = Itype;
        reg_wb_src_o = WbAlu;
        imm_o = imm_i;
      end
      OpLoad: begin
        illegal_inst = (funct3 == 3'h7);
        mem_type_o = mem_type_e'((funct3 == 3'h7) ? MemNone : MemLoad);
        reg_wb_src_o = WbLsu;
        inst_type_o = Itype;
        imm_o = imm_i;
      end
      OpStore: begin
        case (funct3)
          3'h0, 3'h1, 3'h2, 3'h3: mem_type_o = MemStore;
          default: illegal_inst = 1'b1;
        endcase
        inst_type_o = Stype;
        imm_o = imm_s;
      end
      OpBranch: begin
        case (funct3)
          3'h0: alu_op_o = OpBeq;
          3'h1: alu_op_o = OpBne;
          3'h4: alu_op_o = OpBlt;
          3'h5: alu_op_o = OpBge;
          3'h6: alu_op_o = OpBltu;
          3'h7: alu_op_o = OpBgeu;
          default: illegal_inst = 1'b1;
        endcase

        if (!illegal_inst) begin
          jump_type_o = JmpBr;
        end

        inst_type_o = Btype;
        imm_o = imm_b;
      end
      OpJal: begin
        inst_type_o = Jtype;
        jump_type_o = JmpJal;
        reg_wb_src_o = WbJmp;
        imm_o = imm_j;
      end
      OpJalr: begin
        illegal_inst = (funct3 != 3'h0);
        jump_type_o = jump_type_e'((funct3 != 3'h0) ? JmpNone : JmpJalr);
        reg_wb_src_o = WbJmp;
        inst_type_o = Itype;
        imm_o = imm_i;
      end
      OpLui: begin
        inst_type_o = Utype;
        reg_wb_src_o = WbLui;
        imm_o = imm_u;
      end
      OpAuipc: begin
        inst_type_o = Utype;
        reg_wb_src_o = WbAlu;
        imm_o = imm_u;
      end
      OpSys: begin
        inst_type_o = Itype;
        case (funct3)
          3'h0: begin
            if (rs1_bits != '0 || rd_addr_o != '0) begin
              illegal_inst = 1'b1;
              // invalid instruction
              // Not the case for SFENCE.VM
            end
            case (csr_addr_o)
              12'h000: begin
                csr_op_o = OpEcall;
                ex_ecall = 1'b1;
              end
              12'h001: begin
                csr_op_o = OpEbreak;
                ex_ebreak = 1'b1;
              end
              12'h105: csr_op_o = OpWfi;
              12'h302: csr_op_o = OpMret;
              // 12'h002, 12'h102, 12'h202, 12'h7b2, 12'h104: ;
              default: illegal_inst = 1'b1;
            endcase
          end
          3'h1, 3'h5: begin
            csr_op_o = OpCSRRW;
            illegal_inst = csr_addr_rdonly;
          end
          3'h2, 3'h6: begin
            if (rs1_bits == '0) begin
              csr_op_o = OpCSRRdonly;
            end else begin
              csr_op_o = OpCSRRS;
              illegal_inst = csr_addr_rdonly;
            end
          end
          3'h3, 3'h7: begin
            if (rs1_bits == '0) begin
              csr_op_o = OpCSRRdonly;
            end else begin
              csr_op_o = OpCSRRC;
              illegal_inst = csr_addr_rdonly;
            end
          end
          default: illegal_inst = 1'b1;
        endcase
        reg_wb_src_o = WbCsr;
        imm_o = imm_sys;
      end
      OpMisc: begin
        case (funct3)
          3'h0: illegal_inst = (rs1_bits != '0 || rd_addr_o != '0);
          3'h1: begin
            if (rs1_bits != '0 || rs2_bits != '0 ||
              rd_addr_o != '0 || funct7 != '0) begin
              illegal_inst = 1'b1;
            end else begin
              is_fencei_o = 1'b1;
            end
          end
          default: illegal_inst = 1'b1;
        endcase
      end
      default: illegal_inst = 1'b1;
    endcase

    if (illegal_inst) begin
      expt_valid_o = 1'b1;
      expt_cause_o = IllegalInst;
      expt_value_o = {{Xlen - Ilen{1'b0}}, inst_i};;
    end else if (ex_ecall) begin
      expt_valid_o = 1'b1;
      expt_cause_o = EcallM;
      expt_value_o = '0;
    end else if (ex_ebreak) begin
      expt_valid_o = 1'b1;
      expt_cause_o = Breakpoint;
      expt_value_o = pc_i;
    end

    case (inst_type_o)
      Rtype, Btype, Stype: begin rs1_addr_o = rs1_bits; rs2_addr_o = rs2_bits; end
      Itype:               begin rs1_addr_o = rs1_bits; rs2_addr_o = '0;       end
      default:             begin rs1_addr_o = '0;       rs2_addr_o = '0;       end
    endcase
  end
endmodule
