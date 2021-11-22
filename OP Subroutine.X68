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
    
MOVE_W    
    *Print .W (word)
    JSR PRINT_W
    
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
OR_W
    JSR PRINT_W
OR_L
    JSR PRINT_L
    
IS_SUB
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
SUB_W
    JSR PRINT_W
SUB_L
    JSR PRINT_L
OP_11

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
PRNT_LEA    DC.B    'LEA',0
PRNT_ADDQ   DC.B    'ADDQ',0
*D3 = original instruction
*D4 = copy of instruction
*D6 = num of bits to shift
    END    START        ; last line of source

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
