package FASTComparator;

import ClientServer::*;
import Vector::*;
import FIFO::*;
import GetPut::*;
import BlueCheck::*;

typedef 8 GrayDepth;
typedef Bit#(GrayDepth) Grayscale;
interface FASTComparator#(numeric type n);
    interface Get#(Bool) response;
    interface Put#(Tuple2#(Grayscale,Vector#(n,Grayscale))) request;
endinterface

/*instance FShow#(Get#(any_type)) provisos(FShow#(any_type));
    function Fmt fshow(Get#(any_type) value);
        return $format("Get(")+fshow(value)+$format(")");
    endfunction
endinstance*/

// parametrize by number of comparators (maybe only with numComps < n?)!
// but do it as a separate module, so we can blueCheck it!
module mkParallelComparator#(Integer threshold)(FASTComparator#(n));
    FIFO#(Bool) outQueue <- mkFIFO;
    FIFO#(Tuple2#(Grayscale,Vector#(n,Grayscale))) inQueue <- mkFIFO;

    rule compare;
        inQueue.deq;
        case (inQueue.first) matches
        {.middle, .surroundingVector}: begin

        Grayscale incrementedMiddle = middle + fromInteger(threshold);
        Grayscale decrementedMiddle = middle - fromInteger(threshold);

        Bool result = True;
        for(Integer i=0;i<valueOf(n);i=i+1)
            result = result && surroundingVector[i] > incrementedMiddle;

        Bool result2 = True;
        for(Integer i=0;i<valueOf(n);i=i+1)
            result2 = result2 && surroundingVector[i] < decrementedMiddle;
        
        outQueue.enq(result||result2);
        end
        endcase
    endrule

    interface request = toPut (inQueue);
    interface response = toGet (outQueue);
endmodule

module mkPartiallySerialComparator#(Integer threshold, Integer numComparators)(FASTComparator#(n)) provisos (Log#(n,nsize),Add#(nsize,1,ctrSize));
    FIFO#(Tuple2#(Grayscale,Vector#(n,Grayscale))) inQueue <- mkFIFO;
    FIFO#(Bool) outQueue <- mkFIFO;
    Reg#(Grayscale) middle[2] <- mkCRegU(2);
    Reg#(Vector#(n,Grayscale)) surroundingPixels[2]<- mkCRegU(2);
    Reg#(UInt#(ctrSize)) numProcessedPixels[2] <- mkCReg(2,fromInteger(valueOf(n))); 
    Vector#(2,Reg#(Bool)) accumulator <- replicateM(mkRegU);

    rule fetch(numProcessedPixels[0] >= fromInteger(valueOf(n)));
        inQueue.deq;
        case (inQueue.first) matches
            {.m, .sP}: begin
                middle[0] <= m;
                surroundingPixels[0] <= sP;
            end
        endcase
        numProcessedPixels[0] <= 0;
        accumulator[0] <= True;
        accumulator[1] <= True;
    endrule

    rule process (numProcessedPixels[1] < fromInteger(valueOf(n)));
        Grayscale incrementedMiddle = middle[1] + fromInteger(threshold);
        Grayscale decrementedMiddle = middle[1] - fromInteger(threshold);

        Bool resultUpper = numProcessedPixels[1]==0 ? True : accumulator[0]; // to avoid CRegs in a vector
        Bool resultLower = numProcessedPixels[1]==0 ? True : accumulator[1];
    
        for(Integer i=0;i<numComparators;i=i+1)
            if(fromInteger(i)+numProcessedPixels[1] < fromInteger(valueOf(n))) begin
                UInt#(ctrSize) index = fromInteger(i)+numProcessedPixels[1];
                resultUpper = resultUpper && surroundingPixels[1][index] > incrementedMiddle;
                resultLower = resultLower && surroundingPixels[1][index] < decrementedMiddle;
            end              

        accumulator[0] <= resultUpper;
        accumulator[1] <= resultLower;

        if(!resultLower && !resultUpper) begin
            outQueue.enq(False);
            numProcessedPixels[1] <= fromInteger(valueOf(n));
        end else begin
            numProcessedPixels[1] <= numProcessedPixels[1] + fromInteger(numComparators);
            if (numProcessedPixels[1] + fromInteger(numComparators) >= fromInteger(valueOf(n)))
                outQueue.enq(True);
        end
    endrule

    interface request = toPut(inQueue);
    interface response = toGet(outQueue);

endmodule

module [BlueCheck] checkFASTComparators#(Integer numComps)(Empty);
    FASTComparator#(12) reference <- mkParallelComparator(0);
    FASTComparator#(12) dut <- mkPartiallySerialComparator(0,numComps);

    equiv("request",dut.request.put,reference.request.put);
    equiv("response",dut.response.get,reference.response.get);
endmodule

(*synthesize*)
module [Module] testFastComparators(Empty);
    blueCheck(checkFASTComparators(12));
endmodule

endpackage