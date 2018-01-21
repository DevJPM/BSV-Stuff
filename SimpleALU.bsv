package SimpleALU;

import GetPut:: *;
import StmtFSM::*;

typedef enum {Mul, Div, Sub, Add, And, Or, Pow} AluOp deriving(Bits,Eq);
typedef union tagged {UInt#(32) Unsigned; Int#(32) Signed;} SignedOrUnsigned deriving(Bits,Eq);

interface SimpleALU;
    method Action setupCalculation(AluOp op, SignedOrUnsigned left, SignedOrUnsigned right);
    method ActionValue#(SignedOrUnsigned) getResult;
endinterface

module mkSimpleAlu(SimpleALU);
    Reg#(SignedOrUnsigned) leftOp <- mkRegU;
    Reg#(SignedOrUnsigned) rightOp <- mkRegU;
    Reg#(Maybe#(AluOp)) op <- mkReg(tagged Invalid);
    Reg#(SignedOrUnsigned) result <- mkRegU;
    Reg#(Bool) isDone <- mkReg(False);
    Reg#(Bool) isQueued <- mkReg(False);

    SimpleALU powerModule <- mkSimplePower;

    function simpleComp(currentOp, left, right);
        case(currentOp)
        Mul: return left * right;
        Sub: return left - right;
        Add: return left + right;
        And: return left & right;
        Or : return left | right;
        endcase
    endfunction

    rule signedOperation (leftOp matches tagged Signed .l &&& rightOp matches tagged Signed .r &&& op matches tagged Valid .op &&& op != Pow && !isDone && op != Div);
        result <= tagged Signed simpleComp(op,l,r);
        isDone <= True;
    endrule

    rule unsignedOperation (leftOp matches tagged Unsigned .l &&& rightOp matches tagged Unsigned .r &&& op matches tagged Valid .op &&& op != Pow && !isDone && op != Div);
        result <= tagged Unsigned simpleComp(op,l,r);
        isDone <= True;
    endrule

    rule signedOperationDiv (leftOp matches tagged Signed .l &&& rightOp matches tagged Signed .r &&& op matches tagged Valid .op &&& !isDone && op == Div);
        result <= tagged Signed 1;
        isDone <= True;
    endrule

    rule unsignedOperationDiv (leftOp matches tagged Unsigned .l &&& rightOp matches tagged Unsigned .r &&& op matches tagged Valid .op &&& !isDone && op == Div);
        result <= tagged Unsigned 1;
        isDone <= True;
    endrule

    rule startComputePower (op matches tagged Valid .op &&& op == Pow && !isDone && !isQueued);
        powerModule.setupCalculation(Pow,leftOp,rightOp);
        isQueued <= True;
    endrule

    (*descending_urgency="startComputePower,fetchComputedPower"*)
    rule fetchComputedPower (op matches tagged Valid .op &&& op == Pow && isQueued);
        SignedOrUnsigned computedPower <- powerModule.getResult;
        result <= computedPower;
        isDone <= True;
        isQueued <= False;
    endrule

    method Action setupCalculation(AluOp opIn, SignedOrUnsigned left, SignedOrUnsigned right) if (!isDone);
        op <= tagged Valid opIn;
        // ensure both are signed / unsigned
        if(left matches tagged Signed .l &&& right matches tagged Signed .r) begin
            leftOp <= left;
            rightOp <= right;
        end else if(left matches tagged Unsigned .l &&& right matches tagged Unsigned .r) begin
            leftOp <= left;
            rightOp <= right;
        end
        $display(opIn);
        $display(left);
        $display(right);
        $display(isDone);
    endmethod 

    method ActionValue#(SignedOrUnsigned) getResult if (isDone);
        isDone <= False;
        op <= tagged Invalid;
        return result;
    endmethod
endmodule

module mkSimplePower(SimpleALU);
    Reg#(SignedOrUnsigned) result <- mkRegU;
    Reg#(UInt#(32)) currentExponent <- mkRegU;
    Reg#(SignedOrUnsigned) currentBase <- mkRegU;

    rule unsignedStep (result matches tagged Unsigned .r &&& currentBase matches tagged Unsigned .cB &&& currentExponent>0);
        if(lsb(currentExponent)==1)
            result <= tagged Unsigned (r * cB);
        currentExponent <= currentExponent >> 1;
        currentBase <= tagged Unsigned (cB * cB);
    endrule

    rule signedStep (result matches tagged Signed .r &&& currentBase matches tagged Signed .cB &&& currentExponent>0);
        if(lsb(currentExponent)==1)
            result <= tagged Signed (r * cB);
        currentExponent <= (currentExponent >> 1);
        currentBase <= tagged Signed (cB * cB);
        /*$display("currentExponent: ",currentExponent);
        $display("currentResult: ",r);
        $display("currentBase: ",cB);*/
    endrule

    method Action setupCalculation(AluOp opIn, SignedOrUnsigned left, SignedOrUnsigned right);
        case (right) matches
        tagged Signed .r &&& (r > 0): currentExponent <= unpack(pack(r));
        tagged Signed .r &&& (r <= 0): currentExponent <= 0;
        tagged Unsigned .r: currentExponent <= r;
        endcase
        case (left) matches
        tagged Signed .l: result <= tagged Signed 1;
        tagged Unsigned .l: result <= tagged Unsigned 1;
        endcase
        currentBase <= left;
    endmethod 

    method ActionValue#(SignedOrUnsigned) getResult if (currentExponent==0);
        return result;
    endmethod
endmodule

module mkALUTestBench(Empty);
    SimpleALU dut <- mkSimpleAlu;

    Stmt testRun = 
    seq
        $display("launched");
        action
            dut.setupCalculation(Add,tagged Signed 5,tagged Signed 3);
            $display("setup addition");
        endaction
        action
            SignedOrUnsigned result <- dut.getResult;
            if(result matches tagged Signed .r)
                $display("Added 5+3=%d",r);
        endaction
        action
            dut.setupCalculation(Sub,tagged Signed 5,tagged Signed 7);
        endaction
        action
            SignedOrUnsigned result <- dut.getResult;
            if(result matches tagged Signed .r)
                $display("Added 5-7=%d",r);
        endaction
        action
            dut.setupCalculation(Pow,tagged Signed -5,tagged Signed 7);
        endaction
        action
            SignedOrUnsigned result <- dut.getResult;
            if(result matches tagged Signed .r)
                $display("Added -5^7=%d",r);
        endaction
    endseq;

    mkAutoFSM(testRun);
endmodule

endpackage