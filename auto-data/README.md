## AutoFPGA Configuration directory

This directory contains the various files used by AutoFPGA to configure this
design into a functioning design with working and connected components.  In
general, AutoFPGA is a text-based processing program that copies data from these
configuration files into their various sources--whether design or software.
(The copy actually takes place in the [master Makefile](../Makefile).)  Within
this directory, AutoFPGA is called from the [local Makefile](Makefile) to
create connected design components.   These components include:

- [allclocks](allclocks.txt): Contains a description of all of the clocks used
  in the design and their various configurations.
- [bkram](bkram.txt): Block RAM configuration.  Block RAM is an internal RAM
  provided within the ECP5 chip.  The size of the block RAM may be adjusted
  within this file up to however much is available on chip.
- [buserr](buserr.txt): This design contains a peripheral whose purpose is
  nothing more than to capture the address of the last bus error.  That
  peripheral is described here.
- [bustimer](bustimer.txt): The bus timer is the basic ZipTimer used for this
  design.  It provides either a one-shot or interrupt timer capability for the
  CPU.
- [dlyarbiter](dlyarbiter.txt): Arbitrates between either the CPU or the
  external UART debugging (WBUBUS) bus bus having access to the internal
  Wishbone bus connecting all peripherals together.  Due to the logic cost, this
  also induces a delay as well.
- [enet](enet.txt): Ethernet packet controller description.  A related
  configuration file, [enetscope](enetscope.txt) contains information for
  debugging the ethernet, as well as [mdio](mdio.txt) and [mdio1](mdio1.txt)
  for controlling the ethernet management interface.
- [flash](flash.txt): Describes the flash controller to AutoFPGA.  A separate
  file, [flashscope](flashscope.txt) describes a WB Scope used to debug this
  controller.
- [global](global.txt): Contains some global variable tags for AutoFPGA that
  apply across the whole project.
- [gpio](gpio.txt): Information describing the GPIO core used by the design
- [mem_bkram_only](mem_bkram_only.txt) and [mem_flash_only](mem_flash_only.txt)
  are both used to describe a linker script for AutoFPGA to create based upon
  the memory regions present in the design.  This script is not fixed, but
  moves based upon where AutoFPGA places the memories in the address space.

- [picorv](picorv.txt): Describes how to connect the PicoRV as a bus master to
  the design.  Also includes minor peripheral descriptions for the minimal
  bus peripherals used to control the PicoRV or recover its status from the
  serial port.

- [pic](pic.txt): Programmable Interrupt Controller.  This is connected to both
  the bus and the PicoRV to create and manage up to 15 interrupts as necessary
  for the design.

- [pwrcount](pwrcount.txt): Describes a simple/basic peripheral for AutoFPGA
  that just counts up from power-up, and returns the value.

- [rtccount](rtccount.txt): Similar to [pwrcount](pwrcount.txt), this simple
  peripheral counts sub-seconds from power up and rolls over each second.
  This peripheral is not currently part of the design.

- [rtclight](rtclight.txt): A real time clock core, providing access to both
  a clock, stopwatch, timer, and alarm.  A similar core, [rtcdate](rtcdate.txt),
  provides access to the current date.  All times/dates/etc are kept in BCD
  format.  These cores are also not currently part of the design.

- [version](version.txt): Describes two bus-based peripherals used to return
  fixed constants: the date when the design was last built, and the time when
  it was last built.  These peripherals are often used to double check connectivity with the design in general.

- [spio](spio.txt): Special-Purpose board I/O support.  Provides access to
  read from switches and buttons, as well as to set the LEDs.  While the design
  contains debouncing logic, it's not currently used and so the CPU will need
  to debounce any buttons or switches that it interacts with.

- [wbfft](wbfft.txt): Describes the FFT bus connections for AutoFPGA.

- [wbuconsole](wbuconsole.txt): Describes the debugging bus, and console hidden
  within it, to AutoFPGA.

- [zipmaster](zipmaster.txt): Describes the ZipCPU to AutoFPGA.  The ZipCPU
  is not currently part of the design.  Ideally, it should be possible to swap
  the [picorv](picorv.txt) file with the [zipmaster](zipmaster.txt) file to
  switch CPUs within the design back to the ZipCPU design that this was
  originally copied from.  Other than switching to the PicoRV design in general,
  this has only been tried in one direction.  (The
  [ZipCPU](https://github.com/ZipCPU/zipcpu) [software](../sw/board) is not
  expected to work or run on the PicoRV, so this applies to design files only.)
