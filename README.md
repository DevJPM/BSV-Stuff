# BSV-Stuff
This is a repository I shall use to toy around with Bluespec-SystemVerilog.

It may contain solutions to exercises you are doing. Don't look at the code if you don't want to get spoiled.

This also contains the compiled verilog code, so everyone can run this code on their Basys3 boards or adapt it run on $FPGA.

# Current Functionality
 - [master (old)](https://github.com/DevJPM/BSV-Stuff/tree/aa26a14cd9494569059049a45d8e7c668ab5e458):
   - Echoes Data coming in over the serial connection (9600 Baud, no parity, both can be changed easily at the module instantiation)
   - The 8 right leds will display the current status of the switch right next to them
   - The 8 left leds will display the binary encoded value of the last data frame received over UART
   - The 7 segment display will display integers streamed in as characters via the serial connection
     - It supports negative integers (and mulitple negations), support for negative integers can be turned off at module instantiation
     - It supports hex (prefix `x`,`X`,`h`,`H`), binary (prefix `b`,`B`), octal (`o`,`O`) and decimal (prefix `d`,`D` or no prefix) decoding of the data, inputs need to be followed by a carriage-return or a line-feed
     - If the integer is too big to be displayed (ie bigger than 3 decimal digits) then the display will show all-dashes
     - The conversion logic may overflow on too big inputs
 - master (current):
   - Provides basic modules for other branches / projects
   - Does nothing except indicating which switches are active using the LEDs
 - ALU:
   - interprets the left 8 switches and the right 8 switches as 8-bit integers each
   - based on the last button press, it computes a function (either addition, subtraction, power, multiplication or static return "1" instead of division, because inline-division sucks on real HW)
   - The 7-segment display cycles through the following states "off, left operand, right operand, result"
 - Pipeline:
   - implements a 5-step pipeline
   - makes extensive use of vectors
   - Generates rules using for-loops
   - Makes use of higher-order programming to instantiate modules with functions
   - Makes use of `CReg`s to for speed-ups in the pipeline steps
   - Verifies the functional equality of the fast and slow pipeline steps using BlueCheck
   - This branch is not meant to synthesized into a real FPGA right now
 - BlueCheck:
   - uses [blueCheck](https://github.com/CTSRD-CHERI/bluecheck) to verify some basic arithmetic properties using invariant-based randomized testing
   - uses blueCheck to verify that a toy 16-element sized register-based FIFO behaves the same as the built-in `mkSizedFIFO(16)`
   - _may_ be used to develop a module that translates between BlueCheck's UART interface and the simpler interface used by the Basys3
   - This branch is not meant to be synthesized into a real FPGA right now

# How to build

Simply call `make verilog` on the top level of the cloned repository, this will re-generate the `mkTopModule.v` and `mkTopModule.sched` (the rule schedule).

Then feed `wrapper.v` into your Verilog compiler as the top-level module and be sure to also give it `mkTopModule.v` and the contents of the `Verilog/` subdirectory of your bluespec distribution. 

You will also need to add a constraints file which maps the physical package pins (and the clock) to `wrapper`'s I/O ports. I may or may not provide this file for the Basys3 in the future, for now it is left as an exercise to the user to get the file from the internet and adapt it to work with this code.
