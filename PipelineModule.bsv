package PipelineModule;

import FIFO::*;
import SpecialFIFOs::*;
import Vector::*;
import ClockDiv::*;
import BlueCheck::*;

typedef enum {WAIT, COMPUTE, FETCH} ComputeState deriving(Bits,Eq);

interface CalcUnit;
    method Action put(Int#(32) v);
    method ActionValue#(Int#(32)) result;
endinterface

interface CalcUnitChangeable;
    interface CalcUnit calc;
    method Action setParameter(Int#(32) param);
endinterface

module mkCalcUnitChangeable#(function Int#(32) f(Int#(32) a, Int#(32) b))(CalcUnitChangeable);
    Reg#(ComputeState) state <- mkReg(WAIT);
    Reg#(Int#(32)) buffer <- mkRegU;
    Reg#(Maybe#(Int#(32))) param <- mkReg(tagged Invalid);

    rule compute(param matches tagged Valid .p &&& state == COMPUTE);
        buffer <= f(buffer, p);
        state <= FETCH;
    endrule

    interface CalcUnit calc;
        method Action put(Int#(32) v) if (state == WAIT);
            buffer <= v;
            state <= COMPUTE;
        endmethod

        method ActionValue#(Int#(32)) result if (state == FETCH);
            state <= WAIT;
            return buffer;
        endmethod
    endinterface

    method Action setParameter(Int#(32) p);
        param <= tagged Valid p;
    endmethod
endmodule

module mkCalcUnitChangeableFast#(function Int#(32) f(Int#(32) a, Int#(32) b))(CalcUnitChangeable);
    FIFO#(Int#(32)) outBuf <- mkPipelineFIFO;
    Reg#(Maybe#(Int#(32))) inBuf[2] <- mkCRegU(2);
    Reg#(Maybe#(Int#(32))) param <- mkReg(tagged Invalid);

    rule compute (param matches tagged Valid .p &&& inBuf[1] matches tagged Valid .in);
        outBuf.enq(f(in,p));
        inBuf[1] <= tagged Invalid;
    endrule

    interface CalcUnit calc;
    method Action put(Int#(32) v);
        inBuf[0] <= tagged Valid v;
    endmethod

    method ActionValue#(Int#(32)) result;
        outBuf.deq;
        return outBuf.first;
    endmethod
    endinterface

    method Action setParameter(Int#(32) p);
        param <= tagged Valid p;
    endmethod
endmodule

module mkCalcUnit#(function Int#(32) f(Int#(32) a))(CalcUnit);
    Reg#(ComputeState) state <- mkReg(WAIT);
    Reg#(Int#(32)) buffer <- mkRegU;

    rule compute(state == COMPUTE);
        buffer <= f(buffer);
        state <= FETCH;
    endrule

    method Action put(Int#(32) v) if (state == WAIT);
        buffer <= v;
        state <= COMPUTE;
    endmethod

    method ActionValue#(Int#(32)) result if (state == FETCH);
        state <= WAIT;
        return buffer;
    endmethod
endmodule

module mkCalcUnitFast#(function Int#(32) f(Int#(32) a))(CalcUnit);
    FIFO#(Int#(32)) outBuf <- mkPipelineFIFO;
    Reg#(Maybe#(Int#(32))) inBuf[2] <- mkCRegU(2);

    rule compute (inBuf[1] matches tagged Valid .in);
        outBuf.enq(f(in));
        inBuf[1] <= tagged Invalid;
    endrule

    method Action put(Int#(32) v);
        inBuf[0] <= tagged Valid v;
    endmethod

    method ActionValue#(Int#(32)) result;
        outBuf.deq;
        return outBuf.first;
    endmethod
endmodule

module mkPipelineCalc(CalcUnit);
    FIFO#(Int#(32)) inFIFO <- mkFIFO;
    FIFO#(Int#(32)) outFIFO <- mkFIFO;
    Vector#(3,Reg#(Int#(32))) parameterVector;
    parameterVector[0] <- mkReg(1);
    parameterVector[1] <- mkReg(2);
    parameterVector[2] <- mkReg(3);

    function mul(x,y) = x * y;
    function add(x,y) = x + y;
    function rshift2(x) = x >> 2;
    function add128(x) = add(x,128);

    Vector#(3,CalcUnitChangeable) changeableStages;
    changeableStages[0] <- mkCalcUnitChangeable(add);
    changeableStages[1] <- mkCalcUnitChangeable(mul);
    changeableStages[2] <- mkCalcUnitChangeable(mul);

    Vector#(5,CalcUnit) pipelineStages;
    for(Integer i=0;i<3;i=i+1)
        pipelineStages[i] = changeableStages[i].calc;
    pipelineStages[3] <- mkCalcUnitFast(rshift2);
    pipelineStages[4] <- mkCalcUnitFast(add128);

    for(Integer i=1;i<5;i=i+1) begin
        rule progressPipeline;
            let r <- pipelineStages[i-1].result;
            pipelineStages[i].put(r);
        endrule
    end

    ClockDiv#(UInt#(64)) clockDiv <- mkClockDivSimple; // synthesizer will kill init logic if it has no chance to repeat
    rule initPipeline(clockDiv.runNow);
        for(Integer i=0;i<3;i=i+1)
            changeableStages[i].setParameter(parameterVector[i]);
    endrule

    rule feedFirstStage;
        inFIFO.deq;
        pipelineStages[0].put(inFIFO.first);
    endrule

    rule drainLastStage;
        let r <- pipelineStages[4].result;
        outFIFO.enq(r);
    endrule

    method Action put(Int#(32) v);
        inFIFO.enq(v);
    endmethod

    method ActionValue#(Int#(32)) result;
        outFIFO.deq;
        return outFIFO.first;
    endmethod
endmodule

(*synthesize*)
module mkTestPipeline(Empty);
    CalcUnit dut <- mkPipelineCalc;
    Reg#(Int#(32)) ctr <- mkReg(0);

    rule display;
        let r <- dut.result;
        $display("(%0d) Result:",$time,r);
    endrule

    rule feed;
        ctr <= ctr +1;
        if(ctr == 41)
            $finish;
        dut.put(ctr);
        $display("(%0d) Put:",$time,ctr);
    endrule
endmodule

module [BlueCheck] checkCalcUnit(Empty);
    function add(x) = x+128;

    CalcUnit reference <- mkCalcUnit(add);
    CalcUnit underTest <- mkCalcUnitFast(add);

    equiv("put", reference.put, underTest.put);
    equiv("result", reference.result, underTest.result);
endmodule

(*synthesize*)
module [Module] testCalcUnit ();
  blueCheck(checkCalcUnit);
endmodule

module [BlueCheck] checkCalcUnitChangeable(Empty);
    function add(x,y) = x+y;

    CalcUnitChangeable reference <- mkCalcUnitChangeable(add);
    CalcUnitChangeable underTest <- mkCalcUnitChangeableFast(add);

    equiv("put", reference.calc.put, underTest.calc.put);
    equiv("result", reference.calc.result, underTest.calc.result);
    equiv("setParameter",reference.setParameter,underTest.setParameter);
endmodule

(*synthesize*)
module [Module] testCalcUnitChangeable ();
  blueCheck(checkCalcUnitChangeable);
endmodule

endpackage