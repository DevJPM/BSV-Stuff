package TextToInt;

import GetPut :: *;
import StmtFSM::*;

typedef enum {READING_PREFIX, READING_DIGITS, AWAITING_FETCH} ParsingStates deriving(Bits,Eq);

interface TextToInt#(type int_type);
    interface Put#(Bit#(8)) feedCharacter;
    interface Get#(int_type) getInteger;   
endinterface

module mkTextToInt#(Bool isSigned)(TextToInt#(Int#(n))) provisos(Add#(t,9,n));
    Reg#(Int#(n)) buffer <- mkReg(0);
    Reg#(ParsingStates) currentState <- mkReg(READING_PREFIX);
    Reg#(UInt#(7)) currentBase <- mkRegU;
    Reg#(Int#(9)) currentChar <- mkRegU;
    Reg#(Bool) processedCurrentChar <- mkReg(True);
    Reg#(Bool) isNegative <- mkReg(False);

    rule parseBinary (currentState == READING_DIGITS && !processedCurrentChar && currentBase == 2);
        processedCurrentChar <= True;

        case (currentChar)
        48, 49: buffer <= (buffer << 1) + (zeroExtend(currentChar)-48); // 48 is '0', 49 is '1'
        endcase
    endrule

    rule parseOctal (currentState == READING_DIGITS && !processedCurrentChar && currentBase == 8);
        processedCurrentChar <= True;

        if (currentChar >= 48 && currentChar <= 55) // 55 is '7'
            buffer <= (buffer << 3) + (zeroExtend(currentChar) - 48);
    endrule

    rule parseHex (currentState == READING_DIGITS && !processedCurrentChar && currentBase == 16);
        processedCurrentChar <= True;

        if(currentChar >= 48 && currentChar <= 57) // 57 is '9'
            buffer <= (buffer << 4) + (zeroExtend(currentChar) - 48);
        else if(currentChar >= 65 && currentChar <= 70) // uppercase hex letters
            buffer <= (buffer << 4) + (zeroExtend(currentChar) - 55); // currentChar - 65 + 10
        else if(currentChar >= 97 && currentChar <= 102) // lowercase hex letters
            buffer <= (buffer << 4) + (zeroExtend(currentChar) - 87); // currentChar - 97 + 10
    endrule

    rule parseDec (currentState == READING_DIGITS && !processedCurrentChar && currentBase == 10);
        processedCurrentChar <= True;

        if(currentChar >= 48 && currentChar <= 57)
            buffer <= (((buffer << 2) + buffer)<<1) + (zeroExtend(currentChar) - 48); // ((x << 2) + x) << 1 == 10 * x
    endrule

    // fires on line-feed or carriage-return
    (*descending_urgency = "parseFinish,parseHex"*)
    (*descending_urgency = "parseFinish,parseOctal"*)
    (*descending_urgency = "parseFinish,parseDec"*)
    (*descending_urgency = "parseFinish,parseBinary"*)
    rule parseFinish (currentState == READING_DIGITS && !processedCurrentChar && (currentChar == 13 || currentChar == 10));
        processedCurrentChar <= True;
        currentState <= AWAITING_FETCH;
    endrule

    rule parsePrefix (currentState == READING_PREFIX && !processedCurrentChar);  
        Bool getNewChar = True;
        Bool parsedPrefix = True;
        case (currentChar)
        120, 88: currentBase <= 16; // 'x' and 'X'
        104, 72: currentBase <= 16; // 'h' and 'H'
        111, 79: currentBase <= 8; //  'o' and 'O'
        98 , 66: currentBase <= 2; //  'b' and 'B'
        100, 68: currentBase <= 10; // 'd' and 'D'
        48: parsedPrefix = False; // '0'
        45: begin // '-'
            parsedPrefix = False;
            isNegative <= isSigned && !isNegative;
        end
        default: begin
            currentBase <= 10;
            getNewChar = False;
        end
        endcase

        processedCurrentChar <= getNewChar; // don't ask for a new char, if we started with a digit

        $display("parsed prefix");

        if(parsedPrefix)
            currentState <= READING_DIGITS;
    endrule

    interface Put feedCharacter;
    method Action put(Bit#(8) readCharacter) if (processedCurrentChar);
        processedCurrentChar <= False;
        currentChar <= unpack(zeroExtend(readCharacter));
    endmethod
    endinterface

    interface Get getInteger;
    method ActionValue#(Int#(n)) get if (currentState==AWAITING_FETCH);
        currentState <= READING_PREFIX;
        isNegative <= False;
        buffer <= 0;
        return isNegative?(-buffer):buffer;
    endmethod
    endinterface

endmodule

module mkTextToIntTB(Empty);
    TextToInt#(int) dut <- mkTextToInt(False);

    Stmt testplan = 
    seq
        $display("running");
        dut.feedCharacter.put(49);
        dut.feedCharacter.put(49);
        dut.feedCharacter.put(13);
        action
        int result <- dut.getInteger.get;
        $display("%d",result);
        endaction
    endseq;

    mkAutoFSM(testplan);
endmodule
endpackage