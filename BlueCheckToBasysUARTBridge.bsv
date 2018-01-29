package BlueCheckToBasysUARTBridge;

import BlueCheck::*;
import Basys3_Interfaces::*;
import UART::*;
import GetPut::*;

module mkBC2BUB#(JtagUart blueCheckModule,UInt#(27) baudRate,Bool enableParity)(SerialIO);
    JtagUart toBeTranslated = blueCheckModule;
    UART uartHandler <- mkUARTController(baudRate,enableParity);
    Reg#(Bool) waitRequest <- mkReg(True);

    rule feed (waitRequest);
        $display("enqueued: %h",toBeTranslated.uart_writedata);
        uartHandler.sendbuf.put(truncate(toBeTranslated.uart_writedata));
        waitRequest <= False;
    endrule

    rule letWait (!waitRequest);
        waitRequest <= True;     
    endrule

    rule tellStatus;
        toBeTranslated.uart(waitRequest,~0);
    endrule

    method Bit#(1) serialOut = uartHandler.serialOut;
    method Action serialIn(Bit#(1) serial_input) = uartHandler.serialIn(serial_input);
endmodule

endpackage