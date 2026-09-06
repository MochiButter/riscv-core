package csr_pkg;
  import core_pkg::Xlen;

  typedef enum logic[11:0] {
    CSRmhartid       = 12'hf14,
    CSRmstatus       = 12'h300,
    CSRmisa          = 12'h301,
    CSRmie           = 12'h304,
    CSRmtvec         = 12'h305,
    CSRmcounteren    = 12'h306,
    CSRmcountinhibit = 12'h320,
    CSRmscratch      = 12'h340,
    CSRmepc          = 12'h341,
    CSRmcause        = 12'h342,
    CSRmtval         = 12'h343,
    CSRmip           = 12'h344,
    CSRmcycle        = 12'hB00,
    CSRminstret      = 12'hB02,
    // Unprivilledged read-only
    CSRcycle         = 12'hc00,
    CSRtime          = 12'hc01,
    CSRinstret       = 12'hc02
  } csr_addrs_e;

  typedef enum logic [Xlen - 1:0] {
    SSoftInt  = {1'b1, 63'd1},
    MSoftInt  = {1'b1, 63'd3},
    STimerInt = {1'b1, 63'd5},
    MTimerInt = {1'b1, 63'd7},
    SExtInt   = {1'b1, 63'd9},
    MExtInt   = {1'b1, 63'd11},
    CntOfInt  = {1'b1, 63'd13},
    InstAddrMisaligned = 0,
    InstAccessFault    = 1,
    IllegalInst        = 2,
    Breakpoint         = 3,
    LdAddrMisaligned   = 4,
    LdAccessFault      = 5,
    StAddrMisaligned   = 6,
    StAccessFault      = 7,
    EcallU             = 8,
    EcallS             = 9,
    EcallM             = 11,
    InstPageFault      = 12,
    LdPageFault        = 13,
    StPageFault        = 15,
    DoubleTrap         = 16,
    SoftwareCheck      = 18,
    HardwareError      = 19
  } csr_mcause_e;

  typedef struct packed {
    logic sd;
    logic [62:43] wpri0;
    logic mdt;
    logic mpelp;
    logic wpri1;
    logic mpv;
    logic gva;
    logic mbe;
    logic sbe;
    logic [1:0] sxl;
    logic [1:0] uxl;
    logic [31:25] wpri2;
    logic sdt;
    logic spelp;
    logic tsr;
    logic tw;
    logic tvm;
    logic mxr;
    logic sum;
    logic mprv;
    logic [1:0] xs;
    logic [1:0] fs;
    logic [1:0] mpp;
    logic [1:0] vs;
    logic spp;
    logic mpie;
    logic ube;
    logic spie;
    logic wpri3;
    logic mie;
    logic wpri4;
    logic sie;
    logic wpri5;
  } csr_mstatus_t;

  localparam MipMTimer = (1 << 7);
  localparam MipMSoft  = (1 << 3);
endpackage
