package TopModule;

import GetPut::*;
import DisplayInt7Seg :: *;
import ClockDiv::*;
import UART::*;
import FIFOF::*;
import FIFO::*;
import TextToInt :: *;

interface BasysBoardIO;
    method Bit#(16) leds;
    method Action switches(Bit#(16) switch_status);
    method Bit#(7) disableSegmentsDisplay;
    method Bit#(1) disableDotDisplay;
    method Bit#(4) disableDigitDisplay;
    method Bit#(1) serialOut;
    method Action serialIn(Bit#(1) serial_input);
endinterface

(*synthesize,always_ready,always_enabled*)
module mkTopModule(BasysBoardIO);

    Reg#(UInt#(2)) currentDigitIndex <- mkReg(0);
    Reg#(UInt#(4)) currentNumberU <- mkReg(0);
    Reg#(Int#(11)) currentNumberS <- mkReg(0);
    Reg#(Bool) currentIsSigned <- mkReg(False);
    Reg#(UInt#(18)) leftInt <- mkReg(0);
    Reg#(UInt#(18)) rightInt <- mkReg(0);
    ClockDiv#(UInt#(27)) clockDiv <- mkClockDivSimple;

    Reg#(Bit#(1)) buffer <- mkRegU;
    Reg#(Byte) uartBuf <- mkReg(0);

    UART uartHandler <- mkUARTController(9600,False);
    DisplayInterface displayModule <- mkDisplayDigit;
    TextToInt#(Int#(15)) integerParser <- mkTextToInt(True);

    // the following rule display characters received via UART to the 7 segment display
    /*rule fetch;
        Byte result <- uartHandler.recvbuf.get;
        uartBuf <= result;
        displayModule.inputIntegerToDisplay.put(tagged UnsignedInt zeroExtend(unpack(result)));
    endrule*/

    rule feed;
        Byte result <- uartHandler.recvbuf.get;
        uartBuf <= result;
        integerParser.feedCharacter.put(result);
        uartHandler.sendbuf.put(result);
    endrule

    rule display;
        Int#(15) parseResult <- integerParser.getInteger.get;
        displayModule.inputIntegerToDisplay.put(tagged SignedInt truncate(unpack(pack(parseResult))));
    endrule

    Reg#(Bit#(16)) ledStatus <- mkReg(0);
    method Action switches(Bit#(16) switch_status); 
        ledStatus<= switch_status;
        leftInt <= zeroExtend(unpack(switch_status[15:8]));
        rightInt <= zeroExtend(unpack(switch_status[7:0]));
    endmethod

    method Bit#(16) leds;
        // output the ascii code of the last received character (from UART) on the left 8 leds
        return {uartBuf,ledStatus[7:0]};//ledStatus;
    endmethod

    method Bit#(1) disableDotDisplay;
        return displayModule.dotOutput;
    endmethod

    method Bit#(4) disableDigitDisplay;
        return displayModule.digitOutput;
    endmethod

    method Bit#(7) disableSegmentsDisplay;
        return displayModule.segmentOutput;
    endmethod

    method Bit#(1) serialOut;
        return uartHandler.serialOut;
    endmethod

    method Action serialIn(Bit#(1) serial_input);
        uartHandler.serialIn(serial_input);
    endmethod
endmodule

module mkTb(Empty);
BasysBoardIO dut <- mkTopModule;

rule lightEmUp;
    dut.switches(0);
    dut.serialIn(1);
endrule
endmodule

endpackage