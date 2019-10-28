## This directory contains the various Verilog designs used in the project

The design really centers around the [main.v](main.v) design, even though
[main.v](main.v) is only a sub-component of [toplevel.v](toplevel.v).  In full
[AutoFPGA](https://github.com/ZipCPU/autofpga) fashion, [main.v](main.v) is the
top-level simulatable file, whereas device specific or difficult to simulate
constructs are left in the [toplevel.v](toplevel.v) file.  Of particular
interest is the fact that [main.v](main.v) contains all of the bus logic used
to connect various components of the design together.

Other particular cores that may be of interest here include the [QSPI flash
controller](qflexpress.v), the [GPIO core](wbgpio.v), the [special-purpose
(8LEDs, 8Switches, 1Btn) I/O core](spio.v), and the [Management (MDIO)
controller for the ethernet interface](enetcontrol.v).  Both the
[wbscope](wbscope.v) ([Wishbone scope](https://github.com/ZipCPU/wbscope)) and
[wbscopc.v](wbscopc.v) (Compressed wishbone scope) are here as well, where
they've been used for any debug-in-hardware needs.

Subdirectories include:
- [cpu/](cpu): This is a legacy directory, containing a copy of the
  [ZipCPU](https://github.com/ZipCPU/zipcpu) and some bus helper designs.
- [enet/](enet/): Contains the Gb Ethernet related cores.
- [fft/](fft/): Contains both the FFT, and the [FFT wrapper](fft/wbfft.v) that
  gives it a Wishbone bus-based interface.
- [helloworld/](helloworld/): The directory contains a [very simple, although
  complete, design](helloworld/speechfifo.v) to verify that the serial port
  and the clock rate work as desired.  Since the serial port is used extensively
  for control and debugging, this is a minimum of what needs to take place in
  any design using this pattern.

- [picorv/](picorv/): Although the design began as a copy of a
  [ZipCPU](https://github.com/ZipCPU/zipcpu) design, it is now a RISC-V design
  centered around the [picorv32](picorv/) CPU.  In particular, you'll find a
  copy of not only  the [picorv32](picorv/picorv32.v) CPU itself, but you'll
  also find a copy of the [Wishbone wrapper](picorv/wb_picorv32.v) that connects
  the [picorv32](picorv/) CPU to the Wishbone bus used within this design.

- [rtc/](rtc/): Contains a real-time clock design.  This design component is
  not currently used.
- [wbuart/](wbuart/): Contains a series of serial-port cores drawn from [the
  WBUART32](https://github.com/ZipCPU/wbuart32) repository.

- [wbubus/](wbubus/): The Wishbone to Uart bridge connects an incoming serial
  port (i.e. UART) to the Wishbone bus in order to make it possible to write
  values to or read values from the main Wishbone bus within the design.  In
  this fashion, memory can be read or written, devices controlled, flash
  written, etc., from external control.

  This particular version of the Wishbone to UART bridge is unique for it's
  ability to offer a code-word based compression to the words being transferred.
  This greatly speeds up any flash control.

## Building the design

Running `make` within this directory will build two designs: 1) a simulation based design library using Verilator for use with a Verilator [C++ simulation script](../sim/verilated/automaster_tb.cpp), and 2) a configuration file which can be loaded onto the Versa board.  While the former requires that `verilator` be installed, the latter requires that [yosys](https://github.com/YosysHQ/yosys), [nextpnr-ecp5](https://github.com/YosysHQ/nextpnr), and [project trellis](https://github.com/SymbiFlow/prjtrellis) be installed.
