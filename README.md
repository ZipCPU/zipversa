## Accelerator Architecture Demonstration

This repository contains a demonstration of an accelerator architecture.  The
architecture is built around and to support the [ECP5 Versa board](https://www.latticestore.com/products/tabid/417/categoryid/59/productid/22434/default.aspx).
It contains support for one Gb Ethernet interface, Flash, a block RAM device,
and an internal FFT.  The [ffttest](sw/host/ffttest.cpp) program can be used
to send FFT data to the design, which will be received by the [fftmain](sw/rv32/fftmain.c) RISC-V program, and sent to the internal accelerator.  Once the
FFT has been accomplished, the data will be returned back to the host that
requested the processing.

As of this posting, all of these components now work to include the FFT
accelerator itself.

The design does not (yet) have support for either the second network port,
the PCIe connector, or the SDRAM on board.

## Pre-Requisites

To build this design, you will need to first install:

- [RISC-V GNU toolchain](https://github.com/riscv/riscv-gnu-toolchain), to include binutils, GCC, and newlib support
- [Yosys](https://github.com/YosysHQ/yosys)
- [Project Trellis](https://github.com/SymbiFlow/prjtrellis)
- [NextPNR](https://github.com/YosysHQ/nextpnr) for the ECP5
- [Verilator](https://www.veripool.org/wiki/verilator)
- [AutoFPGA](https://github.com/ZipCPU/autofpga)
- [libELF](https://sourceware.org/elfutils)
- [NCurses](https://invisible-island.net/ncurses)
- [OpenOCD](https://openocd.org)

## Build

To adjust the peripherals attached to the design, run `make autodata`.  (This
is not necessary in general.)

Then, to build the design, run `make` from the main directory.

To load the design onto the device once it has been built, run

```bash
% openocd -f ecp5-versa.cfg -c "transport select jtag; init; svf rtl/zipversa.svf; exit"
```

You may need to use sudo to run this command.

Once the design has been loaded onto the board, you may then load software
on the board using `zipload`, such as:

```bash
% cd sw/host
% zipload ../rv32/fftmain
```

You can also interact with the board using the software in the `sw/host`
directory.  For example, to run the FFT demo, run:

```bash
% ./testfft
```

## License

This project is licensed under the GPL.

