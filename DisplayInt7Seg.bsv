package DisplayInt7Seg;

import GetPut::*;
import Vector::*;
import ClockDiv::*;
import Basys3_Interfaces::*;

typedef enum {Underscore,Dash,Off} SpecialDisplayState deriving(Eq,Bits,FShow);

typedef union tagged {
    UInt#(14) UnsignedInt;
    Int#(11) SignedInt;
    SpecialDisplayState AllSpecialState;
    Vector#(4,SpecialDisplayState) IndividualSpecialStates;
} DisplayableInt deriving(Bits,Eq,FShow);

interface DisplayInterface;
    interface Put#(DisplayableInt) inputIntegerToDisplay;
    interface DisplayOutput physical;
endinterface

module mkDisplayDigit(DisplayInterface);
    Reg#(Bool) readyToDisplay <- mkReg(False);
    Reg#(Bool) isNegative <- mkReg(False);
    Reg#(UInt#(14)) toDisplay <- mkRegU;
    Reg#(UInt#(2)) currentDigitIndex <- mkReg(0);
    Vector#(4,Reg#(UInt#(4))) bcdDecodedInput <- replicateM(mkReg(15));
    Reg#(UInt#(4)) doubleDabbleCtr <- mkRegU;
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
            11:return 7'b1110111; // underscore
            default: return 7'b1111111;
        endcase;
    endfunction

    rule iterateDigits (readyToDisplay && clockDiv.runNow);
        currentDigitIndex <= currentDigitIndex+1;
        $display("displayed digit: ",bcdDecodedInput[currentDigitIndex]);
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
        UInt#(4) potentiallyIncrementedCopy[4];
        if(!isNegative)
            potentiallyIncrementedCopy[3]=(bcdDecodedInput[3]>4)?bcdDecodedInput[3]+3:bcdDecodedInput[3];
        else
            potentiallyIncrementedCopy[3]=bcdDecodedInput[3];
        for(Integer j=0;j<3;j=j+1)
            potentiallyIncrementedCopy[j]=(bcdDecodedInput[j]>4)?bcdDecodedInput[j]+3:bcdDecodedInput[j];

        UInt#(4) writeBack[4] = lshiftBCD(potentiallyIncrementedCopy,toDisplay,4);

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

    function Action initializeFromInteger(DisplayableInt toDisplayArg);
    action
        Bool oob <- handleOOBandInit(toDisplayArg);
        if(!oob)
            handleNegativeInts(toDisplayArg);
    endaction
    endfunction

    function Action initializeDigit(SpecialDisplayState state, Integer index);
    action
        case(state)
        Dash: bcdDecodedInput[index] <= 10;
        Underscore: bcdDecodedInput[index] <= 11;
        Off: bcdDecodedInput[index] <= 15;
        endcase
    endaction
    endfunction

    function Action initializeSpecialDigits(Vector#(4,SpecialDisplayState) specialStates);
    action
        for(Integer j=0;j<4;j=j+1)
            initializeDigit(specialStates[j],j);
        readyToDisplay <= True;
    endaction
    endfunction

    function Action initializeAllSpecial(SpecialDisplayState specialState);
    action
        for(Integer j=0;j<4;j=j+1)
            initializeDigit(specialState,j);
        readyToDisplay <= True;
    endaction
    endfunction

    interface Put inputIntegerToDisplay;
    method Action put(DisplayableInt toDisplayArg);
        case (toDisplayArg) matches
        tagged UnsignedInt .ui: initializeFromInteger(toDisplayArg);
        tagged SignedInt .si: initializeFromInteger(toDisplayArg);
        tagged AllSpecialState  .as: initializeAllSpecial(as);
        tagged IndividualSpecialStates .iss: initializeSpecialDigits(iss);
        endcase
    endmethod
    endinterface

    interface DisplayOutput physical;
    method Bit#(7) disableSegmentsDisplay;
        return bcd_to_7seg(bcdDecodedInput[currentDigitIndex]);
    endmethod

    method Bit#(4) disableDigitDisplay;
        if (readyToDisplay)
            return ~(1 << currentDigitIndex);
        else
            return 1;
    endmethod

    method Bit#(1) disableDotDisplay;
        return 1;
    endmethod
    endinterface
endmodule
endpackage