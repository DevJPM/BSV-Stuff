package CNReg;

import GetPut::*;

// Change-Notifying register
interface CNReg#(type t);
    interface Get#(t) readValue;
    method Bool hasChanged;
    interface Put#(t) putValue;
endinterface

module mkCNReg#(t defaultVal)(CNReg#(t)) provisos(Eq#(t),Bits#(t,ts));
    Reg#(t) valueHolder <- mkReg(defaultVal);
    Reg#(Bool) holdsNewValue <- mkReg(False);

    interface Get readValue;
    method ActionValue#(t) get;
        holdsNewValue <= False;
        return valueHolder;
    endmethod
    endinterface

    method Bool hasChanged;
        return holdsNewValue;
    endmethod

    interface Put putValue;
    method Action put(t newValue);
        if(newValue != valueHolder) begin
            valueHolder <= newValue;
            holdsNewValue <= True;
        end
    endmethod
    endinterface

endmodule
endpackage