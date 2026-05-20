OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
  rom (rxa) : ORIGIN = 0x80000000, LENGTH = 64K
  ram (wxa) : ORIGIN = 0x80000000 + 64K, LENGTH = 64K
}

SECTIONS
{
  . = 0x80000000;
  .text.init : { *(.text.init) } >rom AT>rom
  .text : { *(.text*) } >rom AT>rom
  .rodata : { *(.rodata) } >rom AT>rom
  .data : { *(.data*) } >ram AT>rom
  .bss : {
    _bss_start = .;
    *(.bss*)
    _bss_end = .;
  } >ram AT>rom
  .stack : {
    . = ALIGN(0x10);
    _stack_bottom = .;
    . += 16K;
    _stack_top = .;
  } >ram AT>ram
  _end = .;
}
