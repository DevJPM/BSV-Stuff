package UART;

import FIFO::*;
import GetPut::*;
import ClockDiv::*;
import BRAMFIFO::*;
import Clocks::*;

typedef Bit#(8) Byte;
typedef enum{WAITING_FOR_BYTE, RECEIVING_BITS, ENQUEUEING_BYTE} ReceivementState deriving(Bits,Eq);

interface UART;
    interface Put#(Byte) sendbuf;
    interface Get#(Byte) recvbuf;
    method Action serialIn(Bit#(1) incomingSignal);
    method Bit#(1) serialOut;
endinterface

module mkUARTController#(UInt#(27) baudRate,Bool enableParity)(UART);
    Reset currentReset <- exposeCurrentReset;
    FIFO#(Byte) inputFIFO <- mkSizedBRAMFIFO(512); // using BRAM FIFOs because normal FIFOs somehow didn't work that well
    FIFO#(Byte) outputFIFO <- mkSizedBRAMFIFO(512);
    Reg#(Bit#(1)) currentReceivedBit <- mkReg(1);
    Reg#(ReceivementState) receivingData <- mkReg(WAITING_FOR_BYTE);
    Reg#(Bit#(9)) receivedBits <- mkRegU;
    Reg#(Maybe#(Bit#(11))) toSendBits <- mkReg(tagged Invalid); 
    ClockDiv#(UInt#(27)) clockDiv <- mkClockDiv(100000000 / baudRate);// 10416); // 100e6 / 9600, assumes 100e6 base clock rate
    Reg#(UInt#(4)) currentSendIndex <- mkRegU;
    Reg#(UInt#(4)) currentRecvIndex <- mkRegU;
    

    rule prepareForOut (toSendBits matches tagged Invalid &&& clockDiv.runNow);
        Bit#(11) toSend;
        //toSend[8:1] = 8'd65; // test value
        toSend[8:1]=inputFIFO.first;
        inputFIFO.deq;
        toSend[0]=0;
        if(enableParity)
            toSend[9]=reduceXor(toSend[8:1]); // parity bit
        else
            toSend[9]=1;
        toSend[10]=1;
        toSendBits <= tagged Valid toSend;
        currentSendIndex <= 0;
    endrule

    rule advanceSend (toSendBits matches tagged Valid .t &&& clockDiv.runNow);
        currentSendIndex <= currentSendIndex+1;
        if(currentSendIndex==10)
            toSendBits<=tagged Invalid;
    endrule

    rule startReceiving (currentReceivedBit==0 && receivingData == WAITING_FOR_BYTE && clockDiv.runNow);
        receivingData<=RECEIVING_BITS;
        currentRecvIndex <= 0;
        // also implicitely skips the initiating 0 bit
    endrule

    rule writeReceivedBit (receivingData == RECEIVING_BITS && clockDiv.runNow);
        if(currentRecvIndex==(enableParity?8:7))
            receivingData <= ENQUEUEING_BYTE;
        currentRecvIndex<=currentRecvIndex+1;
        receivedBits[currentRecvIndex]<=currentReceivedBit;
    endrule

    rule enterIntoFIFO (receivingData == ENQUEUEING_BYTE && clockDiv.runNow);
        receivingData <= WAITING_FOR_BYTE;
        if(!enableParity || reduceXor(receivedBits[7:0])==receivedBits[8])
            outputFIFO.enq(receivedBits[7:0]);
    endrule

    interface sendbuf = toPut(inputFIFO);
    interface recvbuf = toGet(outputFIFO);

    method Action serialIn(Bit#(1) incomingSignal);
        currentReceivedBit <= incomingSignal;
    endmethod

    method Bit#(1) serialOut;
        if(toSendBits matches tagged Valid .b)
            return b[currentSendIndex];
        else
            return 1;
    endmethod

endmodule

endpackage