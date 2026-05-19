.equ MSIP_BASE,  0x20000000
.equ RTC_ADDR,   0x2000bff8
.equ TIMER_BASE, 0x20004000
.equ SSIP_BASE,  0x2000c000

.text
.global _start, store, stall, exit, trap_handler, msoft_int, mtimer_int
_start:
li x5, 0
li x24, 0
li x25, 0
li x26, 0
la x27, store
li x28, 0
li x29, 0
li x30, 0
li x31, 0

# set mtvec with vectored mode
la x1, trap_handler
addi x1, x1, 1
csrw mtvec, x1

# set mtimecmp to the max value
li x1, TIMER_BASE
li x2, 1
sub x2, x0, x2
sd x2, 0(x1)

# enable timer and software interrupts
li x1, 0x88
csrw mie, x1
csrw mstatus, 0x8

# get the current time
li x1, RTC_ADDR
ld x2, 0(x1)

# set the timer to expire 64 ticks from the saved time
li x1, TIMER_BASE
li x3, 64
add x2, x2, x3
sd x2, 0(x1)

csrr x4, time

# cause an interrupt
li x1, MSIP_BASE
li x2, 0xff
store:
sb x2, 0(x1)

stall:
li x31, 0x42
wfi
# the pc should land here after the timer interrupt
li x31, 0xff
ebreak

.align 2
trap_handler:
li x5, 1
li x5, 1
li x5, 1
j msoft_int
li x5, 1
li x5, 1
li x5, 1
j mtimer_int
# the rest are not implemented
j stall

msoft_int:
csrr x28, mepc
csrr x29, mcause
csrr x30, mtval
# make sure the interrupt doesn't happen again
li x1, MSIP_BASE
sb x0, 0(x1)
mret

mtimer_int:
csrr x24, mepc
csrr x25, mcause
csrr x26, mtval
# make sure the interrupt doesn't happen again
li x1, TIMER_BASE
li x2, 1
sub x2, x0, x2
sd x2, 0(x1)
mret
