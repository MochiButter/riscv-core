class core_base_test #(int AddrWidth, int DataWidth) extends uvm_test;

  core_env #(AddrWidth, DataWidth) env;
  bus_resp_seq_base #(AddrWidth, DataWidth) inst_seq;
  bus_resp_seq_base #(AddrWidth, DataWidth) data_seq;
  mem_model #(AddrWidth, DataWidth) system_mem;

  uvm_tlm_analysis_fifo #(bus_seq_item #(AddrWidth, DataWidth)) watch_datamem_port;
  uvm_tlm_analysis_fifo #(bus_seq_item #(AddrWidth, DataWidth)) watch_instmem_port;

  string prog_hex_path;

  `uvm_component_param_utils(core_base_test #(AddrWidth, DataWidth))
  `uvm_comp_new

  function void build_phase (uvm_phase phase);
    super.build_phase(phase);
    watch_datamem_port = new("watch_datamem_port", this);
    watch_instmem_port = new("watch_instmem_port", this);
    env = core_env #(AddrWidth, DataWidth)::type_id::create("env", this);
    inst_seq = bus_resp_seq_base #(AddrWidth, DataWidth)::type_id::create("inst_seq", this);
    data_seq = bus_resp_seq_base #(AddrWidth, DataWidth)::type_id::create("data_seq", this);
    system_mem = mem_model #(AddrWidth, DataWidth)::type_id::create("system_mem", this);
  endfunction : build_phase

  function void connect_phase (uvm_phase phase);
    env.data_if_resp_agent.monitor.item_collected_port.connect(this.watch_datamem_port.analysis_export);
    env.inst_if_resp_agent.monitor.item_collected_port.connect(this.watch_instmem_port.analysis_export);
    inst_seq.mem = system_mem;
    data_seq.mem = system_mem;
  endfunction : connect_phase

  virtual task run_phase (uvm_phase phase);
    phase.raise_objection(this);
    init_mem();
    watch_bus_event('h1000, 'hdeadbeef, watch_datamem_port);
    phase.drop_objection(this);
  endtask

  task init_mem ();
    if ($value$plusargs("PROG_HEX=%s", prog_hex_path)) begin
      system_mem.load_program(prog_hex_path);
    end else begin
      $error("Need test hex");
    end

    fork
      inst_seq.start(env.inst_if_resp_agent.sequencer);
      data_seq.start(env.data_if_resp_agent.sequencer);
    join_none
  endtask : init_mem

  virtual task watch_bus_event(
    input bit [AddrWidth - 1:0] ref_addr,
    input bit [DataWidth - 1:0] ref_data,
    uvm_tlm_analysis_fifo #(bus_seq_item #(AddrWidth, DataWidth)) txn_port
  );
    bus_seq_item #(AddrWidth, DataWidth) item;
    forever begin
      txn_port.get(item);
      if (item.addr == ref_addr && item.data == ref_data) begin
        return;
      end
    end
  endtask : watch_bus_event

endclass : core_base_test
