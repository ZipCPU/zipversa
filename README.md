This repository contains a full-featued [ZipCPU](https://zipcpu.com/about/zipcpu.html) design for an [ECP5 Versa board](https://www.latticestore.com/products/tabid/417/categoryid/59/productid/22434/default.aspx).

As of this posting, [LEDs](rtl/spio.v), [flash](rtl/qflexpress.v), and
[network](rtl/enet/enetpackets.v) interfaces are all working.
My intent is to implement a DDR3 SDRAM interface as well, before placing
application software onto this design.

For now, all the work is taking place in the [dev branch](https://github.com/ZipCPU/zipversa/tree/dev).
