module wrapper(CLK,sw,sI,btnL,btnR,btnU,btnD,btnC,led,seg,dp,an,sO);
input CLK;
input [15:0] sw;
input sI;
input btnL;
input btnR;
input btnU;
input btnD;
input btnC;
output [15:0] led;
output [6:0] seg;
output dp;
output [3:0] an;
output sO;

wire rst;
mkTopModule main(.CLK(CLK),
.led_ifc_leds(led),
.switch_ifc_switches_switch_status(sw),
.RST_N(rst),
.display_ifc_disableSegmentsDisplay(seg),
.display_ifc_disableDotDisplay(dp),
.display_ifc_disableDigitDisplay(an),
.serial_ifc_serialOut(sO),
.serial_ifc_serialIn_serial_input(sI),
.buttons_ifc_buttonL_left_input(btnL),
.buttons_ifc_buttonR_right_input(btnR),
.buttons_ifc_buttonU_upper_input(btnU),
.buttons_ifc_buttonD_down_input(btnD),
.buttons_ifc_buttonC_center_input(btnC)
);

assign rst=1;
endmodule