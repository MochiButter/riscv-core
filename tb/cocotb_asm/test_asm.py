import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.types import LogicArray
from cocotb.clock import Clock
from cocotb_tools.runner import get_runner
import os
import random
import math
import logging

logger = logging.getLogger("core_test")
logger.setLevel(logging.INFO)

class Mem():
    bytes_per_word = 4
    mem = None
    maxint = 0
    addr_shamt = 2

    def __init__(self, datawidth, path=None):
        self.mem = [0] * 2048
        self.bytes_per_word = int(datawidth / 8)
        self.addr_shamt = int(math.log2(self.bytes_per_word))
        self.maxint = (1 << datawidth) - 1
        if not path:
            return
        program = open(path, "rb")
        word = program.read(self.bytes_per_word)
        cnt = 0
        while (word):
            data = int.from_bytes(word, "little")
            self.mem[cnt] = data
            cnt += 1
            word = program.read(self.bytes_per_word)
        program.close()

    def dump_mem(self):
        logger.debug("Mem dump")
        cnt = 0
        skip = False
        for i in self.mem:
            if i == 0:
                if not skip:
                    logger.debug("...")
                skip = True
                cnt += self.bytes_per_word
                continue
            logger.debug(f"[0x{cnt:016x}] 0x{i:016x}")
            cnt += self.bytes_per_word
            skip = False

    def read_word(self, addr):
        word = self.mem[addr >> self.addr_shamt]
        return word

    def write_word(self, addr, data, mask):
        old_data = self.mem[addr >> self.addr_shamt]
        tmp_data = 0
        for i in reversed(range(self.bytes_per_word)):
            mask_bit = (mask & (1 << i)) >> i
            data_byte = ((data if mask_bit else old_data) >> (i * 8)) & 0xff
            tmp_data = tmp_data | (data_byte << (i * 8))
        logger.info(f"Wrote [0x{addr:016x}] 0b{mask:08b} 0x{tmp_data:016x}")
        self.mem[addr >> self.addr_shamt] = tmp_data

    async def run_instmem(self, dut):
        dut.instmem_ready_i.value = 1;
        while True:
            dut.instmem_ready_i.value = 1;
            await dut.clk_i.rising_edge
            dut.instmem_rvalid_i.value = 0
            if dut.rst_ni.value and dut.instmem_valid_o.value == 1:
                req_addr = int(dut.instmem_addr_o.value)
                dut.instmem_ready_i.value = 0;
                # for i in range(random.randint(0,2)):
                #     await dut.clk_i.rising_edge
                dut.instmem_rdata_i.value = self.read_word(req_addr)
                dut.instmem_rvalid_i.value = 1
            else:
                dut.instmem_rvalid_i.value = 0

    async def run_datamem(self, dut):
        dut.datamem_ready_i.value = 1;
        while True:
            await dut.clk_i.rising_edge
            if dut.datamem_valid_o.value == 1:
                req_addr = int(dut.datamem_addr_o.value)
                if req_addr == 0x10000000 and dut.datamem_wmask_o.value != 0:
                    tmp_buf = ""
                    data = int(dut.datamem_wdata_o.value)
                    mask = int(dut.datamem_wmask_o.value)
                    for i in reversed(range(self.bytes_per_word)):
                        mask_bit = (mask & (1 << i)) >> i
                        if mask_bit:
                            data_byte = (data >> (i * 8)) & (0xff if mask_bit else 0x00)
                            tmp_buf += chr(data_byte)
                    logger.info(f"core says: {tmp_buf}")
                    logger.info(f"Wrote [0x{req_addr:016x}] 0b{mask:08b} 0x{data:016x}")
                else:
                    dut.datamem_rdata_i.value = self.read_word(req_addr)
                    if dut.datamem_wmask_o.value != 0:
                        wdata = int(dut.datamem_wdata_o.value)
                        mask = int(dut.datamem_wmask_o.value)
                        self.write_word(req_addr, wdata, mask)
                dut.datamem_rvalid_i.value = 1
            else:
                dut.datamem_rvalid_i.value = 0

async def run_program(dut, filepath, check_mem=None):
    filepath = os.path.abspath(os.path.join(os.path.dirname(__file__), "sim_build", filepath))
    instmem = Mem(64, filepath)
    instmem.dump_mem()

    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    cocotb.start_soon(instmem.run_instmem(dut))
    cocotb.start_soon(instmem.run_datamem(dut))

    dut.mtip_i.value = 0
    dut.msip_i.value = 0
    dut.mtime_i.value = 0

    dut.rst_ni.value = 0
    for _ in range(3):
        await dut.clk_i.rising_edge
    dut.rst_ni.value = 1

    inst = 0
    count = 0
    ebreak = 0
    #while inst != 0x00100073:
    while ebreak != 1:
        if dut.test_mems_valid.value and not dut.test_mems_busy.value:
            pc = int(dut.test_mems_pc.value)
            #inst = int(dut.inst_data.value)
            ebreak = dut.test_mems_ebreak.value
            #logger.info(f"[0x{pc:016x}] 0x{inst:08x}")
            instruction = instmem.mem[pc >> 3] & 0xffffffff if pc % 8 == 0 else instmem.mem[pc >> 3] >> 32
            logger.info(f"[0x{pc:016x}] 0x{instruction:08x}")
        await dut.clk_i.rising_edge
        count += 1
        if count > 500:
            logger.error("Timeout reached")
            assert(0)
            break
    cycles = dut.csr_inst.mcycle_q.get().to_unsigned()
    instret = dut.csr_inst.minstret_q.get().to_unsigned()
    logger.info(f"Completed at {cycles / instret} cpi")
    instmem.dump_mem()
    if check_mem:
        check_mem(instmem.mem)

@cocotb.test()
async def test_arith(dut):
    await run_program(dut, "arithmetic.bin")
    assert dut.reg_inst.regs_q[1].get().to_unsigned()  == 0x96
    assert dut.reg_inst.regs_q[2].get().to_unsigned()  == 0xffffffffffffffce
    assert dut.reg_inst.regs_q[3].get().to_unsigned()  == 0x56
    assert dut.reg_inst.regs_q[4].get().to_unsigned()  == 0x76
    assert dut.reg_inst.regs_q[5].get().to_unsigned()  == 0x20
    assert dut.reg_inst.regs_q[6].get().to_unsigned()  == 0xfffffffcba000000
    assert dut.reg_inst.regs_q[7].get().to_unsigned()  == 0x1ffffffff7dde000
    assert dut.reg_inst.regs_q[8].get().to_unsigned()  == 0xfffffffff7dde000
    assert dut.reg_inst.regs_q[9].get().to_unsigned()  == 0x1
    assert dut.reg_inst.regs_q[10].get().to_unsigned() == 0x1
    assert dut.reg_inst.regs_q[11].get().to_unsigned() == 0x0
    assert dut.reg_inst.regs_q[12].get().to_unsigned() == 0x1

@cocotb.test()
async def test_jump(dut):
    await run_program(dut, "jump.bin")
    assert dut.reg_inst.regs_q[1].value == 0x1c
    assert dut.reg_inst.regs_q[2].value == 0x2c
    assert dut.reg_inst.regs_q[6].value == 0x0
    assert dut.reg_inst.regs_q[7].value == 0x2
    assert dut.reg_inst.regs_q[8].value == 0x4
    assert dut.reg_inst.regs_q[9].value == 0x0
    assert dut.reg_inst.regs_q[10].value == 0x0
    assert dut.reg_inst.regs_q[11].value == 0x32

@cocotb.test()
async def test_load(dut):
    await run_program(dut, "load.bin")
    assert dut.reg_inst.regs_q[2].get().to_unsigned() == 0xffffffff87654321
    assert dut.reg_inst.regs_q[3].get().to_unsigned() == 0x00000021
    assert dut.reg_inst.regs_q[4].get().to_unsigned() == 0xffffffffffffff87
    assert dut.reg_inst.regs_q[5].get().to_unsigned() == 0x00004321
    assert dut.reg_inst.regs_q[6].get().to_unsigned() == 0xffffffffffff8765
    assert dut.reg_inst.regs_q[7].get().to_unsigned() == 0x00000087
    assert dut.reg_inst.regs_q[8].get().to_unsigned() == 0x00008765

@cocotb.test()
async def test_store(dut):
    def check_mem(mem):
        base_addr = int(dut.reg_inst.regs_q[2].get().to_unsigned() / 8)
        assert mem[base_addr + 0] == 0xdeadbeef
        assert mem[base_addr + 1] == 0x0000beef
        assert mem[base_addr + 2] == 0xbeef0000
        assert mem[base_addr + 3] == 0x000000ef
        assert mem[base_addr + 4] == 0x0000ef00
        assert mem[base_addr + 5] == 0x00ef0000
        assert mem[base_addr + 6] == 0xef000000
    await run_program(dut, "store.bin", check_mem)

@cocotb.test()
async def test_branch(dut):
    await run_program(dut, "branch.bin")
    assert dut.reg_inst.regs_q[3].get().to_unsigned()  == 0
    assert dut.reg_inst.regs_q[4].get().to_unsigned()  == 2
    assert dut.reg_inst.regs_q[5].get().to_unsigned()  == 3
    assert dut.reg_inst.regs_q[6].get().to_unsigned()  == 4

@cocotb.test()
async def test_extra(dut):
    await run_program(dut, "extra.bin")
    assert dut.reg_inst.regs_q[1].get().to_unsigned()  == 0x12345000
    assert dut.reg_inst.regs_q[2].get().to_unsigned()  == 0x12345004

@cocotb.test()
async def test_loop(dut):
    def check_mem(mem):
        base_addr = int(dut.reg_inst.regs_q[4].get().to_unsigned() / 8)
        assert mem[base_addr] == 0xdeadbeef
    await run_program(dut, "loop.bin", check_mem)
    assert dut.reg_inst.regs_q[1].get().to_unsigned()  == 0x00000072
    assert dut.reg_inst.regs_q[2].get().to_unsigned()  == 0x00000064
    assert dut.reg_inst.regs_q[3].get().to_unsigned()  == 0xdeadbeef

@cocotb.test()
async def test_forward(dut):
    def check_mem(mem):
        assert mem[6] == 0x42
    await run_program(dut, "forward.bin", check_mem)
    #assert dut.reg_inst.regs_q[2].get().to_unsigned()  == 0xeef000
    assert dut.reg_inst.regs_q[2].get().to_unsigned()  == 0x42
    # assert dut.reg_inst.regs_q[3].get().to_unsigned()  == 0x42

@cocotb.test()
async def test_csr(dut):
    await run_program(dut, "csr.bin")
    assert dut.reg_inst.regs_q[2].get() == 0b010101
    assert dut.reg_inst.regs_q[3].get() == 0x15
    assert dut.reg_inst.regs_q[4].get() == 0xb # Environment call from M-mode
    ecall_addr = dut.reg_inst.regs_q[5].get().to_unsigned()
    ecall_label = dut.reg_inst.regs_q[7].get().to_unsigned()
    assert ecall_addr == ecall_label
    misa = dut.reg_inst.regs_q[8].get()
    assert misa[63:62] == 2
    assert misa[8]

@cocotb.test()
async def test_rv64(dut):
    def check_mem(mem):
        assert mem[12] == 0x200000001
        assert mem[13] == 0x200000001
    await run_program(dut, "rv64.bin", check_mem)
    assert dut.reg_inst.regs_q[5].get().to_unsigned() == 0xffffffffdeadbeef
    assert dut.reg_inst.regs_q[6].get() == 0x1
    assert dut.reg_inst.regs_q[7].get() == 0xffffffffffffffff
    assert dut.reg_inst.regs_q[8].get() == 0x200000001

@cocotb.test()
async def test_trap_illegal(dut):
    await run_program(dut, "trap_illegal.bin")
    assert dut.reg_inst.regs_q[8].get() == 0x2
    assert dut.reg_inst.regs_q[9].get() == 0x87654321
    illegal_addr = dut.reg_inst.regs_q[4].get().to_unsigned()
    assert dut.reg_inst.regs_q[10].get() == illegal_addr + 4

@cocotb.test()
async def test_misalign(dut):
    def check_mem(mem):
        base_addr = int(dut.reg_inst.regs_q[5].get().to_unsigned() / 8)
        assert mem[base_addr + 0] == 0
        assert mem[base_addr + 1] == 4
        assert mem[base_addr + 2] == 6
    await run_program(dut, "misalign.bin", check_mem)
    assert dut.reg_inst.regs_q[31].get() == 2

@cocotb.test()
async def test_fencei(dut):
    await run_program(dut, "fencei.bin")
    assert dut.reg_inst.regs_q[1].get() == 0x42

@cocotb.test()
async def test_zicnt(dut):
    await run_program(dut, "zicnt.bin")
    assert dut.reg_inst.regs_q[1].get() == 16
    assert dut.reg_inst.regs_q[2].get() != 16
    assert dut.reg_inst.regs_q[3].get() != 16
    assert dut.reg_inst.regs_q[4].get() == 16

@cocotb.test()
async def test_c(dut):
    def check_mem(mem):
        assert mem[64] == 0x42
    await run_program(dut, "test.bin", check_mem)
