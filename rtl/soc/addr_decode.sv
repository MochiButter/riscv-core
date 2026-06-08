module addr_decode
  import axil_pkg::*;
  #(parameter BusWidth = 64
  ,parameter  NumS = 1
  ,localparam IdWidth = $clog2(NumS))
  (input  logic [BusWidth - 1:0] addr_i
  ,output logic decerr_o
  ,output logic [IdWidth - 1:0] request_id_o
  );

  if (NumS < 1) begin : l_num_warning
    $error ("Addr map must map to at least 1, increase NumS in %m");
  end

  typedef struct packed {
    logic [BusWidth - 1:0] lower;
    logic [BusWidth - 1:0] upper;
  } memory_map_t;

  localparam memory_map_t [NumS - 1:0] MemMap = {
    {64'h20000000, 64'h2000ffff}, // aclint, 64K
    {64'h80000000, 64'h8007ffff}, // rom, 512k
    {64'h80080000, 64'h800fffff}  // ram, 512k
  };

  always_comb begin
    decerr_o = 1'b1;
    request_id_o = '0;

    for (int i = 0; i < NumS; i ++) begin
      if (addr_i >= MemMap[i].lower && addr_i <= MemMap[i].upper)  begin
        request_id_o = IdWidth'(i);
      end
      decerr_o = 1'b0;
    end
  end
endmodule
