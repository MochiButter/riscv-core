package axil_pkg;
  typedef enum logic [1:0] {
    OKAY   = 2'b00,
    EXOKAY = 2'b01,
    SLVERR = 2'b10,
    DECERR = 2'b11
  } axil_resp_e;

  typedef struct packed {
    logic privilege;
    logic secure;
    logic instruction;
  } axil_prot_t;
endpackage
