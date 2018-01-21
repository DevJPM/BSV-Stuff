package Basys3_Interfaces;

(*always_enabled,always_ready*)
interface ButtonInputs;
    method Action buttonL(Bit#(1) left_input);
    method Action buttonR(Bit#(1) right_input);
    method Action buttonU(Bit#(1) upper_input);
    method Action buttonD(Bit#(1) down_input);
    method Action buttonC(Bit#(1) center_input);
endinterface

(*always_enabled,always_ready*)
interface SwitchInputs;
    method Action switches(Bit#(16) switch_status);
endinterface

(*always_enabled,always_ready*)
interface LEDOutputs;
    method Bit#(16) leds;
endinterface

(*always_enabled,always_ready*)
interface SerialIO;
    method Bit#(1) serialOut;
    method Action serialIn(Bit#(1) serial_input);
endinterface

(*always_enabled,always_ready*)
interface DisplayOutput;
    method Bit#(7) disableSegmentsDisplay;
    method Bit#(1) disableDotDisplay;
    method Bit#(4) disableDigitDisplay;
endinterface

endpackage