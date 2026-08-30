module ram_sync_axil_harness
  import axil_pkg::*;
  import axil_formal_pkg::*;
  #(parameter BusWidth = 64
  ,localparam MaskBits = BusWidth / 8
  ,parameter  AddrWidth = 16
  ,parameter  DualPort = 1'b1)
  (input  logic clk_i
  ,input  logic rst_ni
  `S_AXIL_PORTS
  );

  `S_AXIL_ASSIGN_TO_IF

  ram_sync_axil #(
    .BusWidth    (BusWidth),
    .AddrWidth   (AddrWidth),
    .DualPort    (DualPort)
  ) u_axil_ram (
    .clk_i       (clk_i),
    .rst_ni      (rst_ni),
    .s_axil      (s_axil)
  );
endmodule
