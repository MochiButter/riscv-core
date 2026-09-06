.text
.global _start, trap_handler, trap_inst_fault, trap_st_fault, trap_ld_fault, fail
_start:

la x1, trap_handler
csrw mtvec, x1

li x10, 0
li x11, 0
li x12, 0
li x13, 0
li x14, 0
li x15, 0

li x1, 0x80100000
li x2, 0xdeadbeef

sw x2, 0(x1)
nop

lw x2, 0(x1)
nop

jalr x0, x1, 0
nop

# should not run, instead expect the trap handler to jump to success
li x1, 1
ebreak

trap_return:
li x1, 2
ebreak

.align 2
trap_handler:
csrr x7, mepc
addi x7, x7, 4
csrw mepc, x7

csrr x7, mcause
li x8, 0x1
beq x7, x8, trap_inst_fault
li x8, 0x5
beq x7, x8, trap_ld_fault
li x8, 0x7
beq x7, x8, trap_st_fault
j fail

trap_inst_fault:
csrr x10, mtval
csrr x11, mcause
la x7, trap_return
csrw mepc, x7
mret
trap_ld_fault:
csrr x12, mtval
csrr x13, mcause
mret
trap_st_fault:
csrr x14, mtval
csrr x15, mcause
mret

# should not go here
fail:
li x1, 3
ebreak
