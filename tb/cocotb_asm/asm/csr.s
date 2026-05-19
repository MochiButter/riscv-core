.text
.global _start, _ecall, _1
_start:
csrrwi x1, mtvec, 0b10111
csrrs  x2, mtvec, x0
csrrwi x3, mscratch, 0b10101
csrrwi x3, mscratch, 0b01010
csrrs  x8, misa, x0
la x7, _ecall
nop
nop
la x5, _1
csrrw x0, mtvec, x5
_ecall:
ecall
ebreak
nop
nop
.align 4
_1:
csrrs x4, mcause, x0
csrrs x5, mepc, x0
addi x6, x5, 4
csrrw x31, mepc, x6
mret
