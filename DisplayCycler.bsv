package DisplayCycler;

import GetPut::*;
import Basys3_Interfaces::*;
import DisplayInt7Seg::*;
import BRAMFIFO::*;
import ClockDiv::*;
import FIFO::*;

interface CyclingDisplay;
    interface Put#(DisplayableInt) addEntry;
    method Action resetCycle;
    interface DisplayOutput physical;
endinterface

module mkCyclingDisplay#(Integer bufferSize,UInt#(32) clockDivisor)(CyclingDisplay);
    DisplayInterface displayer <- mkDisplayDigit;
    FIFO#(DisplayableInt) cyclingFIFO <- mkSizedBRAMFIFO(bufferSize);//mkSizedFIFO(bufferSize);//mkSizedBRAMFIFO(bufferSize);
    ClockDiv#(UInt#(32)) clockDiv <- mkClockDiv(clockDivisor);

    rule cycle (clockDiv.runNow);
        displayer.inputIntegerToDisplay.put(cyclingFIFO.first);
        $display("displaying ",cyclingFIFO.first," now");
        cyclingFIFO.deq;
        cyclingFIFO.enq(cyclingFIFO.first);
    endrule

    method Action resetCycle;
        cyclingFIFO.clear;
    endmethod

    interface Put addEntry;
    method Action put(DisplayableInt toEnq);
        $display("enqued ",toEnq);
        cyclingFIFO.enq(toEnq);
    endmethod
    endinterface// = toPut (cyclingFIFO);

    interface DisplayOutput physical = displayer.physical;
endmodule
endpackage