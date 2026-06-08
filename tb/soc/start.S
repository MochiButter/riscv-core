.section .init
.global _start

_start:
# set all locations in .bss to zero
la x3, _bss_start
la x4, _bss_end
bgeu a0, a1, _bss_clear_end
_bss_clear_loop:
sd zero, 0(a0)
addi a0, a0, 8
bltu a0, a1, _bss_clear_loop
_bss_clear_end:

addi x1, x0, 0
# set the stack pointer
la x2, _stack_top
addi x3, x0, 0
addi x4, x0, 0
addi x5, x0, 0
addi x6, x0, 0
addi x7, x0, 0
addi x8, x0, 0
addi x9, x0, 0
addi x10, x0, 0
addi x11, x0, 0
addi x12, x0, 0
addi x13, x0, 0
addi x14, x0, 0
addi x15, x0, 0
addi x16, x0, 0
addi x17, x0, 0
addi x18, x0, 0
addi x19, x0, 0
addi x20, x0, 0
addi x21, x0, 0
addi x22, x0, 0
addi x23, x0, 0
addi x24, x0, 0
addi x25, x0, 0
addi x26, x0, 0
addi x27, x0, 0
addi x28, x0, 0
addi x29, x0, 0
addi x30, x0, 0
addi x31, x0, 0
call main
