## Software

Software for this project is kept in one of four subdirectories:

- [host/](host/):  The "host" is the off-board CPU that is interacting with
  the FPGA and the CPU within it.  This directory contains software used by
  the host for interacting with the FPGA.

- [rv32/](rv32/): This contains software that will be run on the PicoRV32
  RISC-V CPU within the design.  This includes both application programs as well
  as any newlib library components used to support them.

- [zlib/](zlib/): This is a legacy directory, used to describe the newlib
  library components used to support the original CPU--a [ZipCPU](https://zipcpu.com/about/zipcpu.html).

- [board/](board/): This is a second legacy directory containing application
  programs for the [ZipCPU](https://zipcpu.com/about/zipcpu.html).
