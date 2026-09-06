.text
.global _start, after_fence, load_inst, trap_handler, success
_start:
la x1, trap_handler
csrw mtvec, x1

la x1, load_inst
la x2, after_fence
lw x1, 0(x1)
sw x1, 0(x2)
fence.i
after_fence:
# unlike the fencei example in cocotb_asm, this will cause an
# SLVERR exception due to the attempted write to rom
nop
li x1, 1
ebreak

success:
# use fence.i anyways
fence.i
li x1, 2
ebreak

trap_handler:
la x1, success
csrw mepc, x1
mret

.section .rodata
.align 8
load_inst:
addi x1, x0, 0x42
