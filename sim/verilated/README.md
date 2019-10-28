## Verilator-based Simulation Scripts

This directory contains not only the [master Verilator script](automaster_tb.cpp), but also a series of support files as well as sub-component emulators.  Emulators include [dbluartsim](dbluartsim.cpp), a network/IP accessable serial port emulator allowing access to both console and WB ports, [flashsim](flashsim.cpp), a flash (ROM) emulator, and [enetctrlsim](enetctrlsim.cpp), a network management device emulator.  The Gb Ethernet has no true simulator, but an ability to forward the output from the transmitter directly to the receiver.

To build the simulation, first run `make` in the `rtl` directory, and then again in this directory.  Alternatively, running `make` in the master directory should build this simulator.

To run the simulation , first kill any `netuart`s that might be running, and then run `main_tb`.  `main_tb` may also be given an argument, which is the name of any (ELF) program to run within the CPU within.  This program will then be loaded into design memory, and the design will begin as though it were already loaded at startup.  For example, `main_tb ../../sw/rv32/fftsimtest` will run a simulated-based test of the internal FFT.  A `-d` flag may also be used to generate a `.vcd` trace file as well for debugging purposes.  Do be aware, this trace faile can become quite large.  (I usually kill the simulation before it gets to 20GB.)

While it is much faster to run the design on a hardware board, the simulator offers the unique feature of being able to capture every wire internal to the design as it is running.  Although the WBSCOPE can also be used to capture data from a design running in hardware, it is limited to only ever capturing 32-bits per clock.  As a result, the debugging experience with the WBSCOPE is not nearly as rich as that using the simulator found in this directory.  

## Unused

The [memsim.cpp](memsim.cpp) file is present, should the design ever need to
emulate an SDRAM.
