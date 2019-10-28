## Host Software Components

In this design, the "host" is the off-board CPU controlling the FPGA.  The
design has been written for an off-board Linux CPU on traditional PC hardware.

## Usage

To load and run a program on the PicoRV on a ZipVersa board:

1. Start[netuart](netuart.cpp) if it isn't already running.  This will [forward the serial port from the physical board to a TCP/IP port that the rest of these programs will interact with](https://zipcpu.com/blog/2017/06/16/why-network-debugging.html).

2. Use the [zipload](zipload.cpp) program and give it the name of the program you wish to run.  This will load the program into the flash memory of the design: using the [flash driver](flashdrvr.cpp) found herein, and encoding bus operations using the [ttybus](ttybus.cpp) [DEVBUS](devbus.h) class, and then sending them over TCP/IP via the [lower-level comms](llcomms.cpp) abstraction layer.

3. At any time, you may interact with the design  using the [wbregs](wbregs.cpp) program.  If given an address or the [name of an address](regdefs.cpp), such as `gpio` for GPIO peripheral, then [wbregs](wbregs.cpp) will read a value from that address over the command line.  If given both address (or address name) and value, then [wbregs](wbregs.cpp) will write the value to the address.

4. This is how the two scripts, [haltcpu.sh](haltcpu.sh) and [resetcpu.sh](resetcpu.sh) work: They use [wbregs](wbregs.cpp) to set a GPIO register that is used to control the reset pin of the CPU.  [haltcpu.sh](haltcpu.sh) sets that pin, whereas [resetcpu.sh](resetcpu.sh) sets and then releases the pin so the PicoRV can now run freely.

## Program list

Useful programs in this directory include:

- [dumpflash](dumpflash.cpp): Used to copy the contents of the flash to a file on the host.  Also useful for verifying and knowing that the connection and compression works.

- [flashid](flashid.cpp): It can be a challenge when switching from one flash chip to another to get the timing right again.  This program reads the flash ID from the flash chip.  If the result is off (i.e. shifted) by a bit or two, it's an indication that the delays in the flash controller aren't quite set right.

  This should not be needed again.

- [readmdio](readmdio.cpp): Reads the network management data from the board's GbE PHY and decodes it for easy reading on the host.  Useful for knowing if the board is connected to the ethernet properly or not.

- [netuart](netuart.cpp): This is an important part of the design, and one without which the design will not run.  To run the design, a user must first run [netuart](netuart.cpp).  [netuart](netuart.cpp) will then connect to the serial port on the host, and forward it to a TCP/IP port described in [port.h](port.h).  The other software in this directory will then connect to that TCP/IP port.  This makes it possible for software to interact with either a simulated design or the actual design--since it doesn't necessarily know what's on the other end of the TCP/IP port--a board or a simulation.

- [wbregs](wbregs.cpp): Used to read or write single registers from or to the FPGA design from the host.

- [zipload](zipload.cpp): Used to load designs into the flash of the CPU.  Originally written for the ZipCPU, here modified to also work with the PicoRV.  Designs can then be run.

- [haltcpu.sh](haltcpu.sh): Halts the PicoRV CPU.

- [resetcpu.sh](resetcpu.sh): Toggles the reset pin of the PicoRV CPU, causing the PicoRV to start executing whatever program is loaded for it into the flash.

All of these programs may be built using a simple `make` command.  This assumes
`libelf` and the presence of a Linux distribution.  Building the [zipdbg](zipdbg.cpp) debugger for the [ZipCPU](https://github.com/ZipCPU/zipcpu) will also require the ncurses library.
