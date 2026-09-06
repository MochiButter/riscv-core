module mem_lsu import core_pkg::*;
  (input logic clk_i
  ,input logic rst_ni

  ,input  logic valid_inst_i
  ,input  logic [1:0] mem_type_i
  ,input  logic [Xlen - 1:0] addr_i
  ,input  logic [Xlen - 1:0] wdata_i
  ,input  logic [2:0] funct3_i
  ,output logic [Xlen - 1:0] rdata_o
  ,output logic mem_busy_o
  ,output logic mem_expt_o

  ,input  logic mem_ready_i
  ,output logic mem_valid_o
  ,output logic [Xlen - 1:0] mem_addr_o
  ,output logic [Xlen - 1:0] mem_wdata_o
  ,output logic [MaskBits - 1:0] mem_wmask_o
  ,input  mem_resp_e mem_resp_i
  ,input  logic [Xlen - 1:0] mem_rdata_i
  ,input  logic mem_rvalid_i
  );

  typedef enum logic [1:0] {
    Idle, WaitForReady, WaitForValid
  } mem_state_e;

  mem_state_e state_d, state_q;

  localparam bytesel_bits = $clog2(Xlen / 8);

  logic [Xlen - 1:0] addr_q, wdata_d, wdata_q;
  logic [MaskBits - 1:0] wmask_d, wmask_q;
  logic req_ff_en;

  logic [Xlen - 1:0] rdata_shifted;
  logic [Xlen - 1:0] rdata_byte, rdata_half;

  logic [bytesel_bits - 1:0] addr_i_byte, addr_q_byte;
  logic sign_extend;

  assign sign_extend = !funct3_i[2];

  localparam byte_rep_bits = Xlen - 8;
  localparam half_rep_bits = Xlen - 16;

  assign addr_i_byte = addr_i[bytesel_bits - 1:0];
  assign addr_q_byte = addr_q[bytesel_bits - 1:0];

  assign wdata_d = wdata_i << {addr_i_byte, 3'b0};
  assign rdata_shifted = mem_rdata_i >> {addr_q_byte, 3'b0};

  assign rdata_byte = {{byte_rep_bits{sign_extend && rdata_shifted[7]}},  rdata_shifted[7:0]};
  assign rdata_half = {{half_rep_bits{sign_extend && rdata_shifted[15]}}, rdata_shifted[15:0]};

  logic [Xlen - 1:0] rdata_word;
  localparam word_rep_bits = Xlen - 32;
  assign rdata_word = {{word_rep_bits{sign_extend && rdata_shifted[31]}}, rdata_shifted[31:0]};

  always_comb begin
    if (mem_type_i === MemLoad) begin
      wmask_d = '0;
    end else begin
      case (funct3_i)
        3'h0: wmask_d = 8'b1 << addr_i_byte;
        3'h1: begin
          case (addr_i_byte)
            3'h0: wmask_d = 8'b0000_0011;
            3'h2: wmask_d = 8'b0000_1100;
            3'h4: wmask_d = 8'b0011_0000;
            3'h6: wmask_d = 8'b1100_0000;
            default: wmask_d = 'x;
          endcase
        end
        3'h2: begin
          case (addr_i_byte)
            3'h0: wmask_d = 8'b0000_1111;
            3'h4: wmask_d = 8'b1111_0000;
            default: wmask_d = 'x;
          endcase
        end
        3'h3: wmask_d = 8'b1111_1111;
        default: wmask_d = 'x;
      endcase
    end
    case (funct3_i)
      3'h0, 3'h4: rdata_o = rdata_byte;
      3'h1, 3'h5: begin
        case (addr_q_byte)
          3'h0, 3'h2, 3'h4, 3'h6: rdata_o = rdata_half;
          default: rdata_o = 'x;
        endcase
      end
      3'h2, 3'h6: begin
        case (addr_q_byte)
          3'h0, 3'h4: rdata_o = rdata_word;
          default: rdata_o = 'x;
        endcase
      end
      3'h3: rdata_o = rdata_shifted;
      default: rdata_o = 'x;
    endcase
  end

  always_comb begin
    state_d = state_q;

    mem_busy_o = 1'b0;
    mem_expt_o = 1'b0;
    req_ff_en = 1'b0;

    case (state_q)
      Idle: begin
        if (valid_inst_i && (mem_type_i != MemNone)) begin
          mem_busy_o = 1'b1;
          req_ff_en = 1'b1;
          state_d = WaitForReady;
        end
      end
      WaitForReady: begin
        mem_busy_o = 1'b1;
        if (mem_ready_i) begin
          state_d = WaitForValid;
        end
      end
      WaitForValid: begin
        if (mem_rvalid_i) begin
          mem_expt_o = (mem_resp_i == DECERR || mem_resp_i == SLVERR);
          state_d = Idle;
        end else begin
          mem_busy_o = 1'b1;
        end
      end
      default: state_d = Idle;
    endcase
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      state_q <= Idle;
    end else begin
      state_q <= state_d;
    end
  end

  always_ff @(posedge clk_i) begin
    if (req_ff_en) begin
      addr_q <= addr_i;
      wdata_q <= wdata_d;
      wmask_q <= wmask_d;
    end
  end

  assign mem_addr_o = addr_q;
  assign mem_wdata_o = wdata_q;
  assign mem_wmask_o = wmask_q;
  assign mem_valid_o = state_q == WaitForReady;
endmodule
