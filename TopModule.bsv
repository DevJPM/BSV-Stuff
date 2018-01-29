package TopModule;

typedef enum {LEFT = 0, RIGHT = 1, UP = 2, DOWN = 3, CENTER = 4} ButtonVectorIndex deriving(Eq,Bits,Bounded);

import GetPut::*;
import DisplayInt7Seg :: *;
import ClockDiv::*;
import UART::*;
import FIFOF::*;
import FIFO::*;
import TextToInt :: *;
import Basys3_Interfaces::*;
import DisplayCycler::*;
import StmtFSM::*;
import Vector::*;
import CNReg::*;
import BlueCheckToBasysUARTBridge ::*;
import BlueCheck::*;
import Clocks::*;

interface BasysBoardIO;
    interface ButtonInputs buttons_ifc;
    interface SwitchInputs switch_ifc;
    interface LEDOutputs led_ifc;
    interface SerialIO serial_ifc;
    interface DisplayOutput display_ifc;
endinterface

module [BlueCheck] mkArithSpec ();
    function Bool addComm(Int#(4) x, Int#(4) y) =
      x + y == y + x;
  
    function Bool addAssoc(Int#(4) x, Int#(4) y, Int#(4) z) =
      x + (y + z) == (x + y) + z;
  
    function Bool subComm(Int#(4) x, Int#(4) y) =
      x - y == y - x;
  
    prop("addComm"  , addComm);
    prop("addAssoc" , addAssoc);
endmodule

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
    Vector#(5,Reg#(Bit#(1))) buttonStatus <- replicateM(mkReg(0)); // LRUDC

    CyclingDisplay cycler <- mkCyclingDisplay(128,1<<25);

    Clock clk <- exposeCurrentClock;
    MakeResetIfc r <- mkReset(0, True, clk);

    JtagUart tester <- blueCheckIDSynth(mkArithSpec,r);
    SerialIO bridge <- mkBC2BUB(tester,9600,False);

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


    
    interface SerialIO serial_ifc = bridge;
    /*method Bit#(1) serialOut;
        return 1;
    endmethod
    
    method Action serialIn(Bit#(1) serial_input);
        //uartHandler.serialIn(serial_input);
    endmethod
    endinterface*/

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