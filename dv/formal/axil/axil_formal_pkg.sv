package axil_formal_pkg;
`ifndef S_AXIL_PORTS
  `define S_AXIL_PORTS \
    ,input  logic                  s_axil_awvalid   \
    ,output logic                  s_axil_awready   \
    ,input  logic [BusWidth - 1:0] s_axil_awaddr    \
    ,input  logic                  s_axil_wvalid    \
    ,output logic                  s_axil_wready    \
    ,input  logic [BusWidth - 1:0] s_axil_wdata     \
    ,input  logic [MaskBits - 1:0] s_axil_wstrb     \
    ,output logic                  s_axil_bvalid    \
    ,input  logic                  s_axil_bready    \
    ,input  logic                  s_axil_arvalid   \
    ,output logic                  s_axil_arready   \
    ,input  logic [BusWidth - 1:0] s_axil_araddr    \
    ,output logic                  s_axil_rvalid    \
    ,input  logic                  s_axil_rready    \
    ,output logic [BusWidth - 1:0] s_axil_rdata     \
    /* verilator lint_off UNUSEDSIGNAL */           \
    ,input  axil_prot_t            s_axil_awprot    \
    ,output axil_resp_e            s_axil_bresp     \
    ,input  axil_prot_t            s_axil_arprot    \
    ,output axil_resp_e            s_axil_rresp     \
    /* verilator lint_on UNUSEDSIGNAL */
`endif

`ifndef S_AXIL_ASSIGN_TO_IF
  `define S_AXIL_ASSIGN_TO_IF \
    axil_if #(.BusWidth(BusWidth)) s_axil(); \
    assign s_axil.awvalid = s_axil_awvalid;  \
    assign s_axil_awready = s_axil.awready;  \
    assign s_axil.awaddr  = s_axil_awaddr;   \
    assign s_axil.awprot  = s_axil_awprot;   \
    assign s_axil.wvalid  = s_axil_wvalid;   \
    assign s_axil_wready  = s_axil.wready;   \
    assign s_axil.wdata   = s_axil_wdata;    \
    assign s_axil.wstrb   = s_axil_wstrb;    \
    assign s_axil_bvalid  = s_axil.bvalid;   \
    assign s_axil.bready  = s_axil_bready;   \
    assign s_axil_bresp   = s_axil.bresp;    \
    assign s_axil.arvalid = s_axil_arvalid;  \
    assign s_axil_arready = s_axil.arready;  \
    assign s_axil.araddr  = s_axil_araddr;   \
    assign s_axil.arprot  = s_axil_arprot;   \
    assign s_axil_rvalid  = s_axil.rvalid;   \
    assign s_axil.rready  = s_axil_rready;   \
    assign s_axil_rdata   = s_axil.rdata;    \
    assign s_axil_rresp   = s_axil.rresp;
`endif

`ifndef M_AXIL_PORTS
  `define M_AXIL_PORTS \
    ,output logic                  m_axil_awvalid   \
    ,input  logic                  m_axil_awready   \
    ,output logic [BusWidth - 1:0] m_axil_awaddr    \
    ,output logic                  m_axil_wvalid    \
    ,input  logic                  m_axil_wready    \
    ,output logic [BusWidth - 1:0] m_axil_wdata     \
    ,output logic [MaskBits - 1:0] m_axil_wstrb     \
    ,input  logic                  m_axil_bvalid    \
    ,output logic                  m_axil_bready    \
    ,output logic                  m_axil_arvalid   \
    ,input  logic                  m_axil_arready   \
    ,output logic [BusWidth - 1:0] m_axil_araddr    \
    ,input  logic                  m_axil_rvalid    \
    ,output logic                  m_axil_rready    \
    ,input  logic [BusWidth - 1:0] m_axil_rdata     \
    /* verilator lint_off UNUSEDSIGNAL */           \
    ,output axil_prot_t            m_axil_awprot    \
    ,input  axil_resp_e            m_axil_bresp     \
    ,output axil_prot_t            m_axil_arprot    \
    ,input  axil_resp_e            m_axil_rresp     \
    /* verilator lint_on UNUSEDSIGNAL */
`endif
endpackage
