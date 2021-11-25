*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
CR      EQU     $0D
LF      EQU     $0A
START_ADDR  EQU $01A
    ORG    $1000
START:                  ; first instruction of program
*-------Code for Output------
            LEA     INPUT_MSG, A1
            MOVE.B  #14,D0
            TRAP    #15     *Displays message
        
*-------Code for Intput------
            MOVEA.L INPUT,A1
            MOVE.B  #2,D0
            TRAP    #15
            
            MOVEA.L #START_ADDR,A2
            MOVE.B  D1,D2
        *Convert user input from str to hex
LOOP_CONV            
            CMP.B   #0,D2
            BEQ     CONV_DONE
            
            MOVE.B  (A1)+,D3    *Move curr byte (8 bits) to D3
            SUB.B   #1,D2       *decrement counter 
            
            CMP.B   #$39,D3
            BLE     CONV_NUM
            
            CMP.B   #$41,D3
            BGE     CONV_LETTER
            
CONV_LETTER
            SUB.B   #$37,D3
            MOVE.B  D3,(A2)+    *Store converted bits in A2
            BRA     LOOP_CONV 
            
CONV_NUM
            SUB.B   #$30,D3
            MOVE.B  D3,(A2)+
            BRA     LOOP_CONV
            
CONV_DONE   
            MOVEA.L #START_ADDR,A2
            CLR.B   D2
            MOVE.B  #4,D2
CONCAT_BITS  
            CMP.B   #0,D2
            BEQ     START_OP
            
            *Concatenate bits             
            MOVE.B  (A2)+,D4
            LSL.L   #4,D4       *(Source 1) Shift 4 bits
            
            ADD.B   (A2)+,D4    *(Source 1) Add next hex digit
            
            LSL.L   #8,D3       *clear 8 bits
            ADD.B   D4,D3       *concat
            
            SUB.B   #1,D2   *decrement counter
            BRA     CONCAT_BITS


* OP CODE SUBROUTINE
START_OP

NOP
    MOVE.W  #$4E71,D4
    CMP.W   D4,D3
    BNE     RTS
    *Print instruction to output
    LEA     PRNT_NOP,A1
    MOVE.B  #14,D0
    TRAP    #15
    SIMHALT
    *RTS *Return to I/O subroutine to find next instruction
RTS
    MOVE.W  #$4E75,D4
    CMP.W   D4,D3
    BNE     FIND_OP
    *Print instruction
    LEA     PRNT_RTS,A1
    MOVE.B  #14,D0
    TRAP    #15
    SIMHALT
    *RTS

FIND_OP *determine op code based on first 2 bits
    MOVE.B  #14,D6
    MOVE.W  D3,D4
    LSR.W   D6,D4
    
    CMP.B   #%00,D4 *MOVE,MOVEA
    BEQ     OP_00
    
    CMP.B   #%01,D4 *MOVEQ, MOVEM, ADDQ, LEA, NOT, BGT/BLE/BEQ, JSR, BRA
    BEQ     OP_01
    
    CMP.B   #%10,D4 *OR,SUB
    BEQ     OP_10
    
    CMP.B   #%11,D4 *ADD,AND,LSL,LSR,ROL,ROR,ASL,ASR
    BEQ     OP_11
    
OP_00 *Determine if MOVE or MOVEA op code
*Isolate bits 6,7,8
    MOVE.W  D3,D4
    LSL.W   #7,D4   *Remove first 7 bits
    MOVE.B  #13,D6
    LSR.W   D6,D4   *Remove last 6 bits
    CMP.W   #%001,D4
    BEQ     IS_MOVEA
IS_MOVE
    *Print MOVE
    LEA     PRNT_MOVE,A1
    MOVE.B  #14,D0
    TRAP    #15

    BRA     MOVE_SIZE

IS_MOVEA
    *Print MOVEA
    LEA     PRNT_MOVEA,A1
    MOVE.B  #14,D0
    TRAP    #15
MOVE_SIZE
    MOVE.W  D3,D4
    MOVE.B  #14,D6
    LSL.W   #2,D4   *Remove first 2 bits
    LSR.W   D6,D4   *Remove last 12 bits to find size code
    
    CMP.B   #%01,D4
    BEQ     MOVE_B
    
    CMP.B   #%11,D4
    BEQ     MOVE_W
    
    CMP.B   #%10,D4
    BEQ     MOVE_L
    BRA     INVALID_OP   
MOVE_B    
    *Print .B (byte)
    JSR PRINT_B
    *Proceed to EA Subroutine    
MOVE_W    
    *Print .W (word)
    JSR PRINT_W
    *Proceed to EA Subroutine    
MOVE_L
    *Print .L (long)
    JSR PRINT_L
    
    *Proceed to EA Subroutine

OP_01 *MOVEQ, MOVEM, ADDQ, LEA, NOT, BGT/BLE/BEQ, JSR, BRA
    MOVE.W  D3,D4
    MOVE.B  #12,D6
    LSR.W   D6,D4   *get first 4 bits
    
    CMP.B   #%0111,D4   *MOVEQ
    BEQ     OP_0111
    CMP.B   #%0100,D4   *MOVEM, LEA, NOT, JSR
    BEQ     OP_0100
    CMP.B   #%0101,D4   *ADDQ
    BEQ     OP_0101
    CMP.B   #%0110,D4   *Bcc, BRA
    BEQ     OP_0110
    
OP_0111 *MOVEQ
    *Check bit 8 to validate
    MOVE.L  D3,D4
    LSL.W   #7,D4
    MOVE.B  #15,D6
    LSR.W   D6,D4
    CMP.B   #%0,D4
    BNE     INVALID_OP

    *Print MOVEQ
    LEA     PRNT_MOVEQ,A1
    MOVE.B  #14,D0
    TRAP    #15
    
    MOVE.L  D3,D4
    LSL.W   #8,D4
    LSR.W   #8,D4
    *Print data
    MOVE.L  D4,D1
    MOVE.B  #3,D0
    TRAP    #15
    SIMHALT
    *Proceed to EA Subroutine

OP_0100 *MOVEM, LEA, NOT, JSR
    MOVE.L  D3,D4
    MOVE.B  #11,D6
    LSR.W   D6,D4
    CMP.B   #%01001,D4  *MOVEM or JSR
    BEQ     OP_01001
    
    *Check if LEA
    MOVE.L  D3,D4
    LSL.W   #7,D4
    MOVE.B  #13,D6
    LSR.W   D6,D4
    CMP.B   #%111,D4    *Check bits 8,7,6
    BNE     IS_NOT
    
    LEA     PRNT_LEA,A1
    MOVE.B  #14,D0
    TRAP    #15
    SIMHALT
    *Proceed to EA Subroutine
IS_NOT    
    MOVE.L  D3,D4
    LSR.W   #8,D4
    CMP.W   #%01000110,D4
    BNE     INVALID_OP
    
    LEA     PRNT_NOT,A1
    MOVE.B  #14,D0
    TRAP    #15
    
    MOVE.L  D3,D4
    LSL.W   #8,D4
    MOVE.B  #14,D6
    LSR.W   D6,D4 
    CMP.B   #%00,D4
    BEQ     NOT_B
    CMP.B   #%01,D4
    BEQ     NOT_W
    CMP.B   #%10,D4
    BEQ     NOT_L

    BRA     INVALID_OP    
NOT_B
    JSR PRINT_B
    *Proceed to EA Subroutine    
NOT_W
    JSR PRINT_W
    *Proceed to EA Subroutine    
NOT_L
    JSR PRINT_L 
    *Proceed to EA Subroutine       
OP_01001    
    MOVE.L  D3,D4
    LSR.W   #6,D4
    CMP.W   #%0100111010,D4 *Check if JSR
    BNE     IS_MOVEM
    LEA     PRNT_JSR,A1
    MOVE.B  #14,D0
    TRAP    #15
    SIMHALT
    *Proceed to EA Subroutine    
IS_MOVEM
    *Check bits 9,8,7 to validate   
    MOVE.L  D3,D4
    LSL.W   #6,D4
    MOVE.B  #13,D6
    LSR.W   D6,D4
    CMP.B   #%001,D4
    BNE     INVALID_OP
    
    LEA     PRNT_MOVEM,A1
    MOVE.B  #14,D0
    TRAP    #15
    
    MOVE.L  D3,D4
    MOVE.B  #9,D6
    LSL.W   D6,D4
    MOVE.B  #15,D6
    LSR.W   D6,D4
    
    CMP.B   #0,D4
    BEQ     MOVEM_W
    CMP.B   #1,D4
    BEQ     MOVEM_L    
    BRA     INVALID_OP   
MOVEM_W
    JSR PRINT_W
    *Proceed to EA Subroutine    
MOVEM_L
    JSR PRINT_L
    *Proceed to EA Subroutine    
OP_0101 *ADDQ
    *Check bit 8 to validate
    MOVE.L  D3,D4
    LSL.W   #7,D4
    MOVE.B  #15,D6
    LSR.W   D6,D4
    CMP.B   #%0,D4
    BNE     INVALID_OP

    *Print ADDQ
    LEA     PRNT_ADDQ,A1
    MOVE.B  #14,D0
    TRAP    #15
    
    MOVE.L  D3,D4
    LSL.W   #8,D4   *Remove first 8 bits
    MOVE.B  #14,D6
    LSR.W   D6,D4   *and last 6 bits to get size
    
    CMP.B   #%00,D4
    BEQ     ADDQ_B
    CMP.B   #%01,D4
    BEQ     ADDQ_W
    CMP.B   #%10,D4
    BEQ     ADDQ_L
    
ADDQ_B    
    *Print .B
    JSR PRINT_B
    BRA     ADDQ_DATA
    
ADDQ_W     
    *Print .W
    JSR PRINT_W
    BRA     ADDQ_DATA
    
ADDQ_L     
    *Print .L
    JSR PRINT_L
    BRA     ADDQ_DATA
ADDQ_DATA    
    MOVE.L  D3,D4
    LSL.W   #4,D4   *Remove first 4 bits
    MOVE.B  #13,D6
    LSR.W   D6,D4
    
    *Print data
    MOVE.W  D4,D1
    MOVE.B  #3,D0
    TRAP    #15
    SIMHALT
    
    *Proceed to EA Subroutine
OP_0110    
    MOVE.L  D3,D4
    MOVE.B  #12,D6
    LSL.W   #4,D4
    LSR.W   D6,D4
    
    CMP.W   #%0000,D4
    BEQ     IS_BRA
    
    CMP.W   #%1110,D4
    BEQ     IS_BGT
    
    CMP.W   #%1111,D4
    BEQ     IS_BLE
    
    CMP.W   #%0111,D4
    BEQ     IS_BEQ
    
    BRA     INVALID_OP
IS_BRA
    LEA     PRNT_BRA,A1
    MOVE.B  #14,D0
    TRAP    #15
    SIMHALT
    
IS_BGT
    LEA     PRNT_BGT,A1
    MOVE.B  #14,D0
    TRAP    #15
    SIMHALT
IS_BLE
    LEA     PRNT_BLE,A1
    MOVE.B  #14,D0
    TRAP    #15
    SIMHALT
IS_BEQ  
    LEA     PRNT_BEQ,A1
    MOVE.B  #14,D0
    TRAP    #15
    SIMHALT  

OP_10   *OR,SUB
    MOVE.L  D3,D4
    LSL.W   #2,D4
    MOVE.B  #14,D6
    LSR.W   D6,D4
    CMP.B   #%00,D4 *Check bits 13 and 12
    BEQ     IS_OR
    
    CMP.B   #%01,D4
    BEQ     IS_SUB
    
    BRA     INVALID_OP
IS_OR
    LEA     PRNT_OR,A1
    MOVE.B  #14,D0
    TRAP    #15
    
    MOVE.L  D3,D4
    LSL.W   #7,D4
    MOVE.B  #13,D6
    LSR.W   D6,D4
    
    CMP.B   #%000,D4
    BEQ     OR_B
    CMP.B   #%001,D4
    BEQ     OR_W
    CMP.B   #%010,D4
    BEQ     OR_L
    
    CMP.B   #%100,D4
    BEQ     OR_B
    CMP.B   #%101,D4
    BEQ     OR_W
    CMP.B   #%110,D4
    BEQ     OR_L
    
    BRA     INVALID_OP
    
OR_B
    JSR PRINT_B
    *Proceed to EA Subroutine    
OR_W
    JSR PRINT_W
    *Proceed to EA Subroutine    
OR_L
    JSR PRINT_L
    *Proceed to EA Subroutine    
IS_SUB
    LEA     PRNT_SUB,A1
    MOVE.B  #14,D0
    TRAP    #15

    MOVE.L  D3,D4
    LSL.W   #7,D4
    MOVE.B  #13,D6
    LSR.W   D6,D4
    
    CMP.B   #%000,D4
    BEQ     SUB_B
    CMP.B   #%001,D4
    BEQ     SUB_W
    CMP.B   #%010,D4
    BEQ     SUB_L

    CMP.B   #%100,D4
    BEQ     SUB_B
    CMP.B   #%101,D4
    BEQ     SUB_W
    CMP.B   #%110,D4
    BEQ     SUB_L    
SUB_B
    JSR PRINT_B
    *Proceed to EA Subroutine    
SUB_W
    JSR PRINT_W
    *Proceed to EA Subroutine    
SUB_L
    JSR PRINT_L
    *Proceed to EA Subroutine    
OP_11
    MOVE.L  D3,D4
    MOVE.B  #12,D6
    LSR.W   D6,D4
    
    CMP.B   #%1100,D4   *AND
    BEQ     OP_1100
    
    CMP.B   #%1101,D4   *ADD,ADDA
    BEQ     OP_1101
    
    CMP.B   #%1110,D4   *LSL/LSR,ASL/ASR,ROL/ROR
    BEQ     OP_1110
    
    BRA     INVALID_OP
OP_1100 *AND
    LEA     PRNT_AND,A1
    MOVE.B  #14,D0
    TRAP    #15

    MOVE.L  D3,D4
    LSL.W   #7,D4
    MOVE.B  #13,D6
    LSR.W   D6,D4 *Get Opmode
    *< ea > Dn -> Dn
    CMP.B   #%000,D4
    BEQ     AND_B
    CMP.B   #%001,D4
    BEQ     AND_W
    CMP.B   #%010,D4
    BEQ     AND_L
    *Dn < ea > -> < ea >
    CMP.B   #%100,D4
    BEQ     AND_B
    CMP.B   #%101,D4
    BEQ     AND_W
    CMP.B   #%110,D4
    BEQ     AND_L
    
    BRA     INVALID_OP
AND_B
    JSR PRINT_B
    *Proceed to EA Subroutine    
AND_W
    JSR PRINT_W
    *Proceed to EA Subroutine    
AND_L    
    JSR PRINT_L
    *Proceed to EA Subroutine    
    
OP_1101 *ADD,ADDA
    MOVE.L  D3,D4
    LSL.W   #7,D4
    MOVE.B  #13,D6
    LSR.W   D6,D4 *Get Opmode
    
    *ADD Opmodes
    CMP.B   #%000,D4
    BEQ     ADD_B
    CMP.B   #%001,D4
    BEQ     ADD_W
    CMP.B   #%010,D4
    BEQ     ADD_L
    
    CMP.B   #%100,D4
    BEQ     ADD_B
    CMP.B   #%101,D4
    BEQ     ADD_W
    CMP.B   #%110,D4
    BEQ     ADD_L
    *ADDA Opmodes
    CMP.B   #%011,D4
    BEQ     ADDA_W
    CMP.B   #%111,D4
    BEQ     ADDA_L
    
    BRA     INVALID_OP
IS_ADD
    LEA     PRNT_ADD,A1
    MOVE.B  #14,D0
    TRAP    #15
    RTS
IS_ADDA
    LEA     PRNT_ADDA,A1
    MOVE.B  #14,D0
    TRAP    #15
    RTS
ADD_B
    JSR     IS_ADD
    JSR     PRINT_B
    *Proceed to EA Subroutine    
ADD_W
    JSR     IS_ADD
    JSR     PRINT_W
    *Proceed to EA Subroutine    
ADD_L
    JSR     IS_ADD
    JSR     PRINT_L
    *Proceed to EA Subroutine
    
ADDA_W
    JSR     IS_ADDA
    JSR     PRINT_W
    *Proceed to EA Subroutine    
ADDA_L  
    JSR     IS_ADDA  
    JSR     PRINT_L
    *Proceed to EA Subroutine    
    
OP_1110 *LSL/LSR,ASL/ASR,ROL/ROR
    MOVE.L  D3,D4
    *Register Shift check bits 4,3
    MOVE.B  #11,D6
    LSL.W   D6,D4
    MOVE.B  #17,D6
    LSR.W   D6,D4
    
    CMP.B   #%00,D4 *ASL/ASR
    BEQ     A_REG
    CMP.B   #%01,D4 *LSL/LSR
    BEQ     L_REG
    CMP.B   #%11,D4 *ROL/ROR
    BEQ     R_REG
    *Memory Shift check bits 11,10,9
    MOVE.L  D3,D4
    LSL.W   #4,D4
    MOVE.B  #13,D6
    LSR.W   D6,D4
    
    CMP.B   #%000,D4 *ASL/ASR
    BEQ     A_MEM
    CMP.B   #%001,D4 *LSL,LSR
    BEQ     L_MEM
    CMP.B   #%011,D4 *ROL/ROR
    BEQ     R_MEM
    
    BRA     INVALID_OP
    
    *Check bit 8 to determine L/R shift
A_REG
    JSR     RGHT_LFT
    CLR.L   D6
    MOVE.B  #01,D6
    CMP.B   #%0,D4
    BEQ     IS_ASR
    CMP.B   #%1,D4
    BEQ     IS_ASL
    
    BRA INVALID_OP
A_SIZE    
    BRA     GET_SHFT_SIZE 

A_MEM
    JSR     RGHT_LFT
    CLR.L   D6
    MOVE.B  #02,D6
    CMP.B   #%0,D4
    BEQ     IS_ASR
    CMP.B   #%1,D4
    BEQ     IS_ASL    
    *Proceed to EA Subroutine
    SIMHALT
IS_ASR
    LEA     PRNT_ASR,A1
    MOVE.B  #14,D0
    TRAP    #15
    CMP.B   #01,D6
    BEQ     A_SIZE
    SIMHALT
IS_ASL
    LEA     PRNT_ASL,A1
    MOVE.B  #14,D0
    TRAP    #15
    CMP.B   #01,D6
    BEQ     A_SIZE
    SIMHALT
    
L_REG
    JSR     RGHT_LFT
    CLR.L   D6
    MOVE.B  #01,D6
    CMP.B   #%0,D4
    BEQ     IS_LSR
    CMP.B   #%1,D4
    BEQ     IS_LSL
    
    BRA INVALID_OP
L_SIZE    
    BRA     GET_SHFT_SIZE 

L_MEM
    JSR     RGHT_LFT
    CLR.L   D6
    MOVE.B  #02,D6
    CMP.B   #%0,D4
    BEQ     IS_LSR
    CMP.B   #%1,D4
    BEQ     IS_LSL    
    *Proceed to EA Subroutine
    SIMHALT
IS_LSR
    LEA     PRNT_LSR,A1
    MOVE.B  #14,D0
    TRAP    #15
    CMP.B   #01,D6
    BEQ     L_SIZE
    SIMHALT
IS_LSL
    LEA     PRNT_LSL,A1
    MOVE.B  #14,D0
    TRAP    #15
    CMP.B   #01,D6
    BEQ     L_SIZE    
    SIMHALT
R_REG
    JSR     RGHT_LFT
    CLR.L   D6
    MOVE.B  #01,D6
    CMP.B   #%0,D4
    BEQ     IS_ROR
    CMP.B   #%1,D4
    BEQ     IS_ROL
    
    BRA INVALID_OP
R_SIZE    
    BRA     GET_SHFT_SIZE 

R_MEM
    JSR     RGHT_LFT
    CLR.L   D6
    MOVE.B  #02,D6
    CMP.B   #%0,D4
    BEQ     IS_ROR
    CMP.B   #%1,D4
    BEQ     IS_ROL    
    *Proceed to EA Subroutine
    SIMHALT
IS_ROR
    LEA     PRNT_ROR,A1
    MOVE.B  #14,D0
    TRAP    #15
    CMP.B   #01,D6
    BEQ     R_SIZE
    SIMHALT
IS_ROL
    LEA     PRNT_ROL,A1
    MOVE.B  #14,D0
    TRAP    #15
    CMP.B   #01,D6
    BEQ     R_SIZE
    SIMHALT

GET_IR
    MOVE.L  D3,D4
    MOVE.B  #10,D6
    LSL.W   D6,D4
    MOVE.B  #15,D6
    LSR.W   D6,D4
    
    MOVE.W  D4,D1
    MOVE.B  #3,D0
    TRAP    #15
    SIMHALT    

RGHT_LFT    *0 = RIGHT 1 = LEFT
*Determine if right/left shift
    MOVE.L  D3,D4
    MOVE.B  #15,D6
    LSL.W   #7,D4
    LSR.W   D6,D4
    RTS
    
GET_SHFT_SIZE
    MOVE.L  D3,D4
    LSL.W   #8,D4
    MOVE.B  #14,D6
    LSR.W   D6,D4
    
    CMP.B   #%00,D4    *B
    BEQ     PRINT_B
    CMP.B   #%01,D4    *W
    BEQ     PRINT_W
    CMP.B   #%10,D4    *L
    BEQ     PRINT_L
    
    *Proceed to EA Subroutine    
 
PRINT_B
    LEA     PRNT_B,A1
    MOVE.B  #14,D0
    TRAP    #15
    SIMHALT
PRINT_W
    LEA     PRNT_W,A1
    MOVE.B  #14,D0
    TRAP    #15
    SIMHALT
PRINT_L
    LEA     PRNT_L,A1
    MOVE.B  #14,D0
    TRAP    #15
    SIMHALT
INVALID_OP
    LEA     INVALID_MSG,A1
    MOVE.B  #14,D0
    TRAP    #15
    
    SIMHALT             ; halt simulator

* Put variables and constants here
INPUT_MSG   DC.B    'Enter machine code: ',0
INPUT       DS.L    1
INVALID_MSG DC.B    'Invalid Instruction',CR,LF,0

PRNT_B      DC.B    '.B ',0
PRNT_W      DC.B    '.W ',0
PRNT_L      DC.B    '.L ',0

PRNT_NOP    DC.B    'NOP',0
PRNT_RTS    DC.B    'RTS',0
PRNT_MOVE   DC.B    'MOVE',0
PRNT_MOVEA  DC.B    'MOVEA',0
PRNT_MOVEM  DC.B    'MOVEM',0
PRNT_MOVEQ  DC.B    'MOVEQ',0
PRNT_JSR    DC.B    'JSR',0
PRNT_BGT    DC.B    'BGT',0
PRNT_BLE    DC.B    'BLE',0
PRNT_BEQ    DC.B    'BEQ',0
PRNT_BRA    DC.B    'BRA',0
PRNT_NOT    DC.B    'NOT',0
PRNT_OR     DC.B    'OR',0
PRNT_LEA    DC.B    'LEA',0
PRNT_ADDQ   DC.B    'ADDQ',0
PRNT_ADD    DC.B    'ADD',0
PRNT_ADDA   DC.B    'ADDA',0
PRNT_AND    DC.B    'AND',0
PRNT_SUB    DC.B    'SUB',0
PRNT_ASL    DC.B    'ASL',0
PRNT_ASR    DC.B    'ASR',0
PRNT_LSL    DC.B    'LSL',0
PRNT_LSR    DC.B    'LSR',0
PRNT_ROL    DC.B    'ROL',0
PRNT_ROR    DC.B    'ROR',0

*D3 = original instruction
*D4 = copy of instruction
*D6 = num of bits to shift
    END    START        ; last line of source




*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
