package PotatoFIFO;

import Vector::*;
import FIFO::*;
import GetPut ::*;
import BlueCheck::*;

interface PotatoFIFO;
    method Action put(Int#(16) e);
    method ActionValue#(Int#(16)) get;
endinterface

module mkPotatoFIFO(PotatoFIFO);
    Vector#(16,Reg#(Int#(16))) bufferRegisters <- replicateM(mkRegU);
    Reg#(UInt#(4)) startPtr <- mkReg(0);
    Reg#(UInt#(4)) endPtr <- mkReg(0);

    method Action put(Int#(16) e) if (endPtr + 1 != startPtr);
        bufferRegisters[endPtr] <= e;
        endPtr <= endPtr + 1;
    endmethod

    method ActionValue#(Int#(16)) get if (startPtr != endPtr);
        startPtr <= startPtr + 1;
        return bufferRegisters[startPtr];
    endmethod
endmodule

module [BlueCheck] checkFIFO(Empty);
    PotatoFIFO dut <- mkPotatoFIFO;
    FIFO#(Int#(16)) referenceFIFO <- mkSizedFIFO(16);

    function ActionValue#(Int#(16)) referenceGetter;
        actionvalue
            referenceFIFO.deq;
            return referenceFIFO.first;
        endactionvalue
    endfunction

    equiv("enq",dut.put,referenceFIFO.enq);
    equiv("get",dut.get,referenceGetter);
endmodule

(*synthesize*)
module [Module] testFIFO(Empty);
    blueCheck(checkFIFO);
endmodule

endpackage