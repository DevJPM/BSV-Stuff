package DisplayInt7Seg;

import GetPut::*;
import Vector::*;
import ClockDiv::*;

typedef union tagged {
    UInt#(14) UnsignedInt;
    Int#(11) SignedInt;
} DisplayableInt deriving(Bits,Eq);

interface DisplayInterface;
    interface Put#(DisplayableInt) inputIntegerToDisplay;
    method Bit#(7) segmentOutput;
    method Bit#(1) dotOutput;
    method Bit#(4) digitOutput;
endinterface

module mkDisplayDigit(DisplayInterface);
    Reg#(Bool) readyToDisplay <- mkReg(False);
    Reg#(Bool) isNegative <- mkReg(False);
    Reg#(UInt#(14)) toDisplay <- mkRegU;
    Reg#(UInt#(2)) currentDigitIndex <- mkReg(0);
    Reg#(UInt#(4)) bcdDecodedInput[4];
    Reg#(UInt#(4)) doubleDabbleCtr <- mkRegU;
    for(Integer i=0;i<4;i=i+1)
        bcdDecodedInput[i] <- mkReg(15);
    ClockDiv#(UInt#(19)) clockDiv <- mkClockDivSimple;

    function Bit#(7) bcd_to_7seg(UInt#(4) in);
        return case(in)
            //           gfedbca
            0:return  7'b1000000;
            1:return  7'b1111001;
            2:return  7'b0100100;
            3:return  7'b0110000;
            4:return  7'b0011001;
            5:return  7'b0010010;
            6:return  7'b0000010;
            7:return  7'b1111000;
            8:return  7'b0000000;
            9:return  7'b0010000;
            10:return 7'b0111111; // dash = minus sign
            default: return 7'b1111111;
        endcase;
    endfunction

    rule iterateDigits (readyToDisplay && clockDiv.runNow);
        currentDigitIndex <= currentDigitIndex+1;
        $display("BCD digit %d: %d",currentDigitIndex,bcdDecodedInput[currentDigitIndex]);
        if(currentDigitIndex==3)
            $finish;
    endrule

    function UInt#(4)[] lshiftBCD(UInt#(4) previousBCD[],UInt#(14) rightInt,Integer numRegs);
        UInt#(4) toReturn[numRegs];
        if(!isNegative)
            toReturn[numRegs-1]=(previousBCD[numRegs-1]<<1) + zeroExtend(unpack(msb(previousBCD[numRegs-2])));
        else
            toReturn[numRegs-1]=previousBCD[numRegs-1];
        for(Integer j=numRegs-2;j>0;j=j-1)
            toReturn[j]=(previousBCD[j]<<1) + zeroExtend(unpack(msb(previousBCD[j-1])));
        toReturn[0]=(previousBCD[0]<<1)+zeroExtend(unpack(msb(rightInt)));
        return toReturn;
    endfunction

    rule doubleDabble (doubleDabbleCtr < 14 && !readyToDisplay);
        $display("current i:%o",toDisplay);
        $display("readyToDisplay?:%d",readyToDisplay);
        for(Integer j=0;j<4;j=j+1)
            $display("current bcd digit #%d: %d",j,bcdDecodedInput[j]);
        UInt#(4) potentiallyIncrementedCopy[4];
        if(!isNegative)
            potentiallyIncrementedCopy[3]=(bcdDecodedInput[3]>4)?bcdDecodedInput[3]+3:bcdDecodedInput[3];
        else
            potentiallyIncrementedCopy[3]=bcdDecodedInput[3];
        for(Integer j=0;j<3;j=j+1)
            potentiallyIncrementedCopy[j]=(bcdDecodedInput[j]>4)?bcdDecodedInput[j]+3:bcdDecodedInput[j];

        UInt#(4) writeBack[4] = lshiftBCD(potentiallyIncrementedCopy,toDisplay,4);

        $display("right int:%d",toDisplay);
        $display("msb:%d",msb(toDisplay));
        for(Integer j=0;j<4;j=j+1)
            bcdDecodedInput[j] <= writeBack[j];
        toDisplay <= (toDisplay<<1);
        doubleDabbleCtr <= doubleDabbleCtr+1;
        readyToDisplay <= doubleDabbleCtr==13;
    endrule   

    function ActionValue#(Bool) initError;
    actionvalue
        for(Integer j=0;j<4;j=j+1)
                bcdDecodedInput[j]<=10;
        doubleDabbleCtr<=14;
        readyToDisplay<=True;
        return True;
    endactionvalue
    endfunction

    function ActionValue#(Bool) initCorrect;
    actionvalue
        for(Integer j=0;j<3;j=j+1) // leave register[3] to the sign-handler
                bcdDecodedInput[j]<=0;
        doubleDabbleCtr<=0;
        readyToDisplay<=False;
        return False;
    endactionvalue
    endfunction

    function ActionValue#(Bool) handleOOBandInit(DisplayableInt toDisplayArg);
        actionvalue
        Bool toReturn;
        if(toDisplayArg matches tagged SignedInt .i &&& abs(i)>999)
            toReturn <- initError;
        else if(toDisplayArg matches tagged UnsignedInt .i &&& i>9999)
            toReturn <- initError;
        else
            toReturn <- initCorrect;
        return toReturn;
        endactionvalue
    endfunction

    function Action handleNegativeInts(DisplayableInt toDisplayArg);
        action
            if(toDisplayArg matches tagged UnsignedInt .i)
                toDisplay <= i;
            else if(toDisplayArg matches tagged SignedInt .i)
                toDisplay <= zeroExtend(unpack(pack(abs(i))));

            if(toDisplayArg matches tagged SignedInt .i &&& i<0)
            begin
                isNegative <= True;
                bcdDecodedInput[3]<=10;
            end
            else
            begin
                isNegative <= False;
                bcdDecodedInput[3]<=0;
            end
        endaction
    endfunction

    interface Put inputIntegerToDisplay;
    method Action put(DisplayableInt toDisplayArg);
        //$display("input:",toDisplayArg);
        Bool oob <- handleOOBandInit(toDisplayArg);
        if(!oob)
            handleNegativeInts(toDisplayArg);
    endmethod
    endinterface

    method Bit#(7) segmentOutput;
        return bcd_to_7seg(bcdDecodedInput[currentDigitIndex]);
    endmethod

    method Bit#(4) digitOutput;
        if (readyToDisplay)
            return ~(1 << currentDigitIndex);
        else
            return 1;
    endmethod

    method Bit#(1) dotOutput;
        return 1;
    endmethod
endmodule
endpackage