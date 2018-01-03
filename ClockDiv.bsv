package ClockDiv;

interface ClockDiv#(type t);
    method Bool runNow;
endinterface

module mkClockDivSimple(ClockDiv#(t)) provisos (Arith#(t),Eq#(t),Bits#(t,ts));
    Reg#(t) ctr <- mkReg(0);

    rule inc;
        ctr <= ctr+1;
    endrule

    method Bool runNow;
        return ctr==0;
    endmethod
endmodule

module mkClockDiv#(t divisor)(ClockDiv#(t)) provisos (Arith#(t),Eq#(t),Bits#(t,ts),Ord#(t));
    Reg#(t) ctr<- mkReg(0);

    rule inc;
        if(ctr<divisor-1)
            ctr <= ctr+1;
        else
            ctr <= 0;
    endrule

    method Bool runNow;
        return ctr==0;
    endmethod
endmodule
endpackage