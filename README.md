This repository contains a [PicoRV](rtl/picorv/picorv.v) RISC-V cpu design for an [ECP5 Versa board](https://www.latticestore.com/products/tabid/417/categoryid/59/productid/22434/default.aspx).

As of this posting, [LEDs](rtl/spio.v), [flash](rtl/qflexpress.v), and
[network](rtl/enet/enetpackets.v) interfaces are all working.  The
[pingtest.c](sw/rv32/pingtest.c) core can be used implement ARP processing
and ICMP packet processing.
