package TopModule;

typedef enum {LEFT = 0, RIGHT = 1, UP = 2, DOWN = 3, CENTER = 4} ButtonVectorIndex deriving(Eq,Bits,Bounded);

import GetPut::*;
import DisplayInt7Seg :: *;
import ClockDiv::*;
import UART::*;
import FIFOF::*;
import FIFO::*;
import TextToInt :: *;
import SimpleALU :: *;
import Basys3_Interfaces::*;
import DisplayCycler::*;
import StmtFSM::*;
import Vector::*;
import CNReg::*;

interface BasysBoardIO;
    interface ButtonInputs buttons_ifc;
    interface SwitchInputs switch_ifc;
    interface LEDOutputs led_ifc;
    interface SerialIO serial_ifc;
    interface DisplayOutput display_ifc;
endinterface

(*synthesize,always_ready,always_enabled*)
module mkTopModule(BasysBoardIO);

    Reg#(UInt#(2)) currentDigitIndex <- mkReg(0);
    Reg#(UInt#(4)) currentNumberU <- mkReg(0);
    Reg#(Int#(11)) currentNumberS <- mkReg(0);
    Reg#(Bool) currentIsSigned <- mkReg(False);
    CNReg#(UInt#(32)) leftInt <- mkCNReg(0);
    CNReg#(UInt#(32)) rightInt <- mkCNReg(0);
    ClockDiv#(UInt#(28)) clockDiv <- mkClockDivSimple;
    
    DisplayInterface displayModule <- mkDisplayDigit;
    SimpleALU alu <- mkSimpleAlu;
    CNReg#(AluOp) toCompute <- mkCNReg(Add);
    Vector#(5,Reg#(Bit#(1))) buttonStatus <- replicateM(mkReg(0)); // LRUDC

    CyclingDisplay cycler <- mkCyclingDisplay(128,1<<25);

    // use this code-block to test the cycler in isolation
    /*function feedVal(toCycle);
        action
            cycler.addEntry.put(toCycle);
        endaction
    endfunction
    Stmt demoFeeder =
    seq
        action
        cycler.resetCycle;
        endaction
        feedVal(tagged SignedInt -127);
        feedVal(tagged UnsignedInt 1337);
        feedVal(tagged AllSpecialState Underscore);
        feedVal(tagged IndividualSpecialStates replicate(Off));
        feedVal(tagged AllSpecialState Dash);
    endseq;
    FSM cyclerFeeder <- mkFSM(demoFeeder);
    Reg#(Bool) firstFSMRun <- mkReg(True);
    ClockDiv#(UInt#(128)) requeueCLockDiv <- mkClockDivSimple; // essentially infinite

    rule testCycler (requeueCLockDiv.runNow);
        cyclerFeeder.start;
    endrule*/


    // the following rule display characters received via UART to the 7 segment display
    /*rule fetch;
        Byte result <- uartHandler.recvbuf.get;
        uartBuf <= result;
        displayModule.inputIntegerToDisplay.put(tagged UnsignedInt zeroExtend(unpack(result)));
    endrule*/

    /*rule displayTato (clockDiv.runNow);
        displayModule.inputIntegerToDisplay.put(tagged AllSpecialState Underscore);
    endrule*/

    rule decideOp;
        if(buttonStatus[0]==1)
            toCompute.putValue.put(Add);
        else if(buttonStatus[1]==1)
            toCompute.putValue.put(Sub);
        else if(buttonStatus[2]==1)
            toCompute.putValue.put(Mul);
        else if(buttonStatus[3]==1)
            toCompute.putValue.put(Div);
        else if(buttonStatus[4]==1)
            toCompute.putValue.put(Pow);
    endrule

    function feedVal(toCycle);
        action
            cycler.addEntry.put(toCycle);
        endaction
    endfunction

    function feedCNVal(toBeRead);
        action
            UInt#(32) val <- toBeRead.readValue.get;
            feedVal(tagged UnsignedInt truncate(val));
        endaction
    endfunction

    Reg#(SignedOrUnsigned) computeBuf <- mkRegU;
    Stmt computeAndFeed =
    seq
        action
            UInt#(32) leftVal <- leftInt.readValue.get;
            UInt#(32) rightVal <- rightInt.readValue.get;
            AluOp toBeComputed <- toCompute.readValue.get;
            alu.setupCalculation(toBeComputed,tagged Unsigned leftVal,tagged Unsigned rightVal);
        endaction
        action
            cycler.resetCycle;
        endaction
        feedVal(tagged AllSpecialState Off);
        feedCNVal(leftInt);
        feedCNVal(rightInt);
        action
            SignedOrUnsigned computeResult <- alu.getResult;
            computeBuf <= computeResult;
        endaction
        action
            if(computeBuf matches tagged Unsigned .cR)
                if(cR > 9999)
                    feedVal(tagged AllSpecialState Dash);
                else
                    feedVal(tagged UnsignedInt truncate(cR));
            else if(computeBuf matches tagged Signed .cR)
                if(abs(cR) > 999)
                    feedVal(tagged AllSpecialState Dash);
                else
                    feedVal(tagged SignedInt truncate(cR));
        endaction
    endseq;
    FSM cyclerFeeder <- mkFSM(computeAndFeed);

    rule computeAndDisplay(toCompute.hasChanged || leftInt.hasChanged || rightInt.hasChanged);
        cyclerFeeder.start;     
        //displayModule.inputIntegerToDisplay.put(tagged UnsignedInt 128);
    endrule

    Reg#(Bit#(16)) ledStatus <- mkReg(0);
    interface SwitchInputs switch_ifc;
    method Action switches(Bit#(16) switch_status); 
        ledStatus<= switch_status;
        leftInt.putValue.put(zeroExtend(unpack(switch_status[15:8])));
        rightInt.putValue.put(zeroExtend(unpack(switch_status[7:0])));
    endmethod
    endinterface

    interface LEDOutputs led_ifc;
    method Bit#(16) leds;
        // output the ascii code of the last received character (from UART) on the left 8 leds
        return ledStatus;
    endmethod
    endinterface

    interface display_ifc = cycler.physical;

    interface SerialIO serial_ifc;
    method Bit#(1) serialOut;
        return 1;
    endmethod
    
    method Action serialIn(Bit#(1) serial_input);
        //uartHandler.serialIn(serial_input);
    endmethod
    endinterface

    interface ButtonInputs buttons_ifc;
    method Action buttonL(Bit#(1) left_input);
        buttonStatus[0] <= left_input;
    endmethod

    method Action buttonR(Bit#(1) right_input);
        buttonStatus[1] <= right_input;
    endmethod

    method Action buttonU(Bit#(1) upper_input);
        buttonStatus[2] <= upper_input;
    endmethod

    method Action buttonD(Bit#(1) down_input);
        buttonStatus[3] <= down_input;
    endmethod

    method Action buttonC(Bit#(1) center_input);
        buttonStatus[4] <= center_input;
    endmethod
    endinterface
endmodule

module mkTb(Empty);
BasysBoardIO dut <- mkTopModule;
ClockDiv#(UInt#(30)) clockDiv <- mkClockDivSimple;
Reg#(Bool) firstTime <- mkReg(True);

rule lightEmUp;
    dut.switch_ifc.switches(0);
    dut.serial_ifc.serialIn(1);
    dut.buttons_ifc.buttonC(0);
    dut.buttons_ifc.buttonD(0);
    dut.buttons_ifc.buttonU(0);
    dut.buttons_ifc.buttonL(0);
    dut.buttons_ifc.buttonR(0);
endrule

rule counter (clockDiv.runNow);
    if(firstTime)
        firstTime <= False;
    else
        $finish;
endrule
endmodule

endpackage