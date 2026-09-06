SIM ?= verilator
WAVES ?= 1

TOPLEVEL_LANG := verilog
ifeq ($(SIM), verilator)
EXTRA_ARGS = -Wno-fatal --trace --trace-fst --trace-structs -DRISCV_FORMAL
endif

ROOT_DIR := $(PWD)/../..

VERILOG_INCLUDE_DIRS += $(ROOT_DIR)/rtl/soc
VERILATOR_INCDIR := $(addprefix +incdir+,$(VERILOG_INCLUDE_DIRS))

VERILOG_SOURCES += $(ROOT_DIR)/rtl/core_pkg.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/csr_pkg.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/pipeline_pkg.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/alu.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/core.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/decode.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/ram_1r1w_sync.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/ram_1rw_sync.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/rom_1r_sync.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/fifo.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/fetch.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/mem_lsu.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/register.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/csr.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/pipeline_reg.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/skid_buffer.sv

VERILOG_SOURCES += $(ROOT_DIR)/rtl/soc/axil_pkg.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/soc/axil_if.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/soc/arbiter.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/soc/mem_to_axil.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/soc/ram_sync_axil.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/soc/rom_sync_axil.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/soc/addr_decode.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/soc/axil_interconnect.sv

VERILOG_SOURCES += $(ROOT_DIR)/rtl/aclint/aclint.sv
VERILOG_SOURCES += $(ROOT_DIR)/rtl/aclint/axil_aclint.sv

VERILOG_SOURCES += $(ROOT_DIR)/rtl/soc/soc.sv

COCOTB_TOPLEVEL := soc
COCOTB_TEST_MODULES := test_soc

TEST_FILES := load store loop misalign fencei_soc aclint decerr
CUSTOM_SIM_DEPS := $(foreach test,$(TEST_FILES),sim_build/$(test)_rom.bin)
CUSTOM_SIM_DEPS += sim_build/freertos_rom.bin

FREERTOS_DEPS := freertos/main.c freertos/main_blinky.c freertos/Makefile \
								 freertos/FreeRTOSConfig.h freertos/start.S

RISCV_TOOLCHAIN ?= riscv64-unknown-elf-

.PHONY: fullclean lint svlint

include $(shell cocotb-config --makefiles)/Makefile.sim

sim_build/%.elf: ../cocotb_asm/asm/%.s
	$(RISCV_TOOLCHAIN)gcc -march=rv64i_zicsr_zifencei -mabi=lp64 -nostartfiles \
		-nostdlib -mcmodel=medany -T soc.ld $< -o $@

sim_build/%.elf: asm/%.s
	$(RISCV_TOOLCHAIN)gcc -march=rv64i_zicsr_zifencei -mabi=lp64 -nostartfiles \
		-nostdlib -mcmodel=medany -T soc.ld $< -o $@

sim_build/%_rom.bin: sim_build/%.elf
	$(RISCV_TOOLCHAIN)objcopy -O binary $< $@

freertos/build/RTOSDemo64.elf: $(FREERTOS_DEPS)
	$(MAKE) -C freertos

sim_build/freertos_rom.bin: freertos/build/RTOSDemo64.elf
	$(RISCV_TOOLCHAIN)objcopy -O binary $< $@

fullclean: clean
	$(MAKE) -C freertos clean

lint: $(VERILOG_SOURCES)
	verilator $(ROOT_DIR)/tb/verilator.vlt --lint-only --timing \
		-top $(COCOTB_TOPLEVEL) -DRISCV_FORMAL $^ -Wall

svlint: $(VERILOG_SOURCES)
	svlint --config $(ROOT_DIR)/tb/lowrisc_style.toml $^
