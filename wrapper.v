module wrapper(CLK,sw,sI,led,seg,dp,an,sO);
input CLK;
input [15:0] sw;
input sI;
output [15:0] led;
output [6:0] seg;
output dp;
output [3:0] an;
output sO;

wire rst;
mkTopModule main(.CLK(CLK),
.leds(led),
.switches_switch_status(sw),
.RST_N(rst),
.disableSegmentsDisplay(seg),
.disableDotDisplay(dp),
.disableDigitDisplay(an),
.serialOut(sO),
.serialIn_serial_input(sI)
);

assign rst=1;
endmodule