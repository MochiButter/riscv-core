package core_pkg;
  parameter Xlen = 64;
  parameter Ilen = 32;
  parameter Nret = 1;

  localparam MaskBits = Xlen / 8;

  typedef enum logic [1:0] {
    Add, Op32, Funct
  } aluop_e;

  typedef enum logic [1:0] {
    MemNone, MemLoad, MemStore
  } mem_type_e;

  typedef enum logic [2:0] {
    Rtype, Itype, Stype, Btype, Utype, Jtype, Fence
  } inst_type_e;

  typedef enum logic [1:0] {
    JmpNone, JmpBr, JmpJal, JmpJalr
  } jump_type_e;

  typedef enum logic [4:0] {
    OpAdd, OpSub, OpXor, OpOr, OpAnd, OpSll, OpSrl, OpSra, OpSlt, OpSltu,
    OpBeq, OpBne, OpBlt, OpBge, OpBltu, OpBgeu,
    OpAddw, OpSubw, OpSllw, OpSrlw, OpSraw
  } alu_op_e;

  typedef enum logic [3:0] {
    OpCSRNone,
    OpCSRRW, OpCSRRdonly, OpCSRRS, OpCSRRC,
    OpEcall, OpEbreak,
    OpUret, OpSret, OpHret, OpMret, OpDret,
    OpSfence, OpWfi
  } csr_op_e;

  typedef enum logic [2:0] {
    WbNone, WbAlu, WbLsu, WbCsr, WbLui, WbJmp
  } reg_wb_src_e;

  // an exact copy of the axi response signal
  // a copy is made here to separate the axi interface from the core
  // memory interface as they are separate interfaces
  typedef enum logic [1:0] {
    OKAY   = 2'b00,
    EXOKAY = 2'b01,
    SLVERR = 2'b10,
    DECERR = 2'b11
  } mem_resp_e;
endpackage
