# BSV-Stuff
This is a repository I shall use to toy around with Bluespec-SystemVerilog.

It may contain solutions to exercises you are doing. Don't look at the code if you don't want to get spoiled.

This also contains the compiled verilog code, so everyone can run this code on their Basys3 boards or adapt it run on $FPGA.

# Current Functionality
 - master:
   - Echoes Data coming in over the serial connection (9600 Baud, no parity, both can be changed easily at the module instantiation)
   - The 8 right leds will display the current status of the switch right next to them
   - The 8 left leds will display the binary encoded value of the last data frame received over UART
   - The 7 segment display will display integers streamed in as characters via the serial connection
     - It supports negative integers (and mulitple negations), support for negative integers can be turned off at module instantiation
     - It supports hex (prefix `x`,`X`,`h`,`H`), binary (prefix `b`,`B`), octal (`o`,`O`) and decimal (prefix `d`,`D` or no prefix) decoding of the data, inputs need to be followed by a carriage-return or a line-feed
     - If the integer is too big to be displayed (ie bigger than 3 decimal digits) then the display will show all-dashes
     - The conversion logic may overflow on too big inputs

# How to build

Simply call `make verilog` on the top level of the cloned repository, this will re-generate the `mkTopModule.v` and `mkTopModule.sched` (the rule schedule).

Then feed `wrapper.v` into your Verilog compiler as the top-level module and be sure to also give it `mkTopModule.v` and the contents of the `Verilog/` subdirectory of your bluespec distribution. 

You will also need to add a constraints file which maps the physical package pins (and the clock) to `wrapper`'s I/O ports. I may or may not provide this file for the Basys3 in the future, for now it is left as an exercise to the user to get the file from the internet and adapt it to work with this code.
