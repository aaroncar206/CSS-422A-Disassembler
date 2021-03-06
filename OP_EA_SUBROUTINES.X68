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
*-------ESTABLISH STACK - MOVE TO IO LATER--------
            MOVEA.L #$00100000,SP

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
    JSR EA_SRC
    JSR EA_DEST
    
    SIMHALT * Done printing move
MOVE_W    
    *Print .W (word)
    JSR PRINT_W
    *Proceed to EA Subroutine
    JSR EA_SRC 
    JSR EA_DEST

    SIMHALT
MOVE_L
    *Print .L (long)
    JSR PRINT_L
    *Proceed to EA Subroutine
    JSR EA_SRC
    JSR EA_DEST

    SIMHALT

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
    
    ** Print # in front
    
    LEA     PRNT_Q,A1
    MOVE.B  #14,D0
    TRAP    #15
    
    MOVE.L  D4,D1
    MOVE.B  #3,D0
    TRAP    #15
    
    *** Move reg. bits into a bitfield for EA
    MOVE.W  D3,D4
    AND.W   #%0000111000000000,D4
    LSR.W   #3,D4
    LSR.W   #6,D4
    MOVE.B  D4,D6
    
    MOVEM.L D0-D7,-(SP)
    
    JSR     EA_SUB
    
    MOVEM.L (SP)+,D0-D7
    
    SIMHALT ** Back to IO
    
   
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
    
    * Is LEA
    LEA     PRNT_LEA,A1
    MOVE.B  #14,D0
    TRAP    #15
    * HANDLE OPERANDS
    MOVE.B  #3,D5 * Size operation is always longword for LEA, so set here.
    
    JSR EA_SRC * Handle the source EA
    
    MOVE.W  D3,D4
    AND.W   #%0000111000000000,D4 * Isolate Register #
    LSR.W   #3,D4
    LSR.W   #6,D4
    MOVE.B  D4,D6   * Prime D6 register
    OR.B    #%00001000,D6 * Add the An mode to D6
    
    MOVEM.L D0-D7,-(SP) * Move register contents to stack
    
    JSR     EA_SUB * Handle the destination EA (last 6 bits of D6)
    
    * MOVEM RETURN
    MOVEM.L (SP)+,D0-D7
        
    SIMHALT * Return to IO



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
    BRA NOT_EA  
NOT_W
    JSR PRINT_W
    *Proceed to EA Subroutine
    BRA NOT_EA    
NOT_L
    JSR PRINT_L 
    *Proceed to EA Subroutine
    
NOT_EA * DEALING W/ NOT EA HERE (May need to save registers...) *************
    
    JSR EA_SRC
    SIMHALT *** Return to IO ***
    
    
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
    LEA     PRNT_Q,A1
    MOVE.B  #14,D0
    TRAP    #15
    
    MOVE.W  D4,D1
    MOVE.B  #3,D0
    TRAP    #15
    
    * Handle EA
    JSR     EA_SRC
    
    SIMHALT * Return to IO
    
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

DISP *8 bit displacement field
    MOVE.L  D3,D4
    LSL.W   #8,D4
    LSR.W   #8,D4   *Holds displacement value
    AND.W   #$00FF,D4
    
    CMP.W   #$00,D4
    BEQ     DISP_16
    CMP.W   #$FF,D4
    BEQ     DISP_32

    MOVEA.W A0,A5
    MOVE.W  A5,D6 *Holds next instruction address
    NOT.B   D4
    ADD.B   #%01,D4
    
    SUB.W   D4,D6
    MOVE.W  D6,D1
    MOVE.B  #3,D0
    TRAP    #15
    SIMHALT    
DISP_16
    MOVE.W  (A0)+,D4
    MOVEA.L A0,A5
    MOVE.W  A5,D6 *Holds next instruction address
    NOT.B   D4
    ADD.B   #%01,D4
    
    SUB.W   D4,D6
    MOVE.W  D6,D1
    MOVE.B  #3,D0
    TRAP    #15
    SIMHALT
DISP_32    
    MOVE.L  (A0)+,D4
    MOVEA.L A0,A5
    MOVE.W  A5,D6 *Holds next instruction address
    NOT.B   D4
    ADD.B   #%01,D4
    
    SUB.W   D4,D6
    MOVE.W  D6,D1
    MOVE.B  #3,D0
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
    
    * Destination is Dn
    CMP.B   #%000,D4
    BEQ     OR_B_D
    CMP.B   #%001,D4
    BEQ     OR_W_D
    CMP.B   #%010,D4
    BEQ     OR_L_D
    
    CMP.B   #%100,D4
    BEQ     OR_B
    CMP.B   #%101,D4
    BEQ     OR_W
    CMP.B   #%110,D4
    BEQ     OR_L
    
    BRA     INVALID_OP




* For these, handle EA first, then Data reg.
OR_B_D
    JSR PRINT_B
    *Proceed to EA Subroutine
    JSR     ADDFORMAT_DATA_DEST_EA
    
    SIMHALT * Return to IO
    
OR_W_D
    JSR PRINT_W
    *Proceed to EA Subroutine
    JSR     ADDFORMAT_DATA_DEST_EA
    
    SIMHALT * Return to IO    
OR_L_D
    JSR PRINT_L
    *Proceed to EA Subroutine
    JSR     ADDFORMAT_DATA_DEST_EA
    
    SIMHALT * Return to IO


* For these, handle Data reg first, then EA    
OR_B
    JSR PRINT_B
    *Proceed to EA Subroutine
    JSR     ADDFORMAT_EA_DEST_EA
    SIMHALT * Return to IO 
    
OR_W
    JSR PRINT_W
    *Proceed to EA Subroutine
    JSR     ADDFORMAT_EA_DEST_EA
    SIMHALT * Return to IO 
    
OR_L
    JSR PRINT_L
    *Proceed to EA Subroutine
    JSR     ADDFORMAT_EA_DEST_EA
    SIMHALT * Return to IO 
    
IS_SUB
    LEA     PRNT_SUB,A1
    MOVE.B  #14,D0
    TRAP    #15

    MOVE.L  D3,D4
    LSL.W   #7,D4
    MOVE.B  #13,D6
    LSR.W   D6,D4
    
    * Data register as destination;
    CMP.B   #%000,D4
    BEQ     SUB_B_D
    CMP.B   #%001,D4
    BEQ     SUB_W_D
    CMP.B   #%010,D4
    BEQ     SUB_L_D

    * EA as destination;
    CMP.B   #%100,D4
    BEQ     SUB_B
    CMP.B   #%101,D4
    BEQ     SUB_W
    CMP.B   #%110,D4
    BEQ     SUB_L


* Handle EA, then Data Reg.
SUB_B_D
    JSR PRINT_B
    *Proceed to EA Subroutine
    JSR     ADDFORMAT_DATA_DEST_EA
    
    SIMHALT * Return to IO    
SUB_W_D
    JSR PRINT_W
    *Proceed to EA Subroutine
    JSR     ADDFORMAT_DATA_DEST_EA
    
    SIMHALT * Return to IO    
SUB_L_D
    JSR PRINT_L
    *Proceed to EA Subroutine 
    JSR     ADDFORMAT_DATA_DEST_EA
    
    SIMHALT * Return to IO


* Handle Data reg, then EA    
SUB_B
    JSR PRINT_B
    *Proceed to EA Subroutine
    JSR     ADDFORMAT_EA_DEST_EA
    SIMHALT * Return to IO     
SUB_W
    JSR PRINT_W
    *Proceed to EA Subroutine    
    JSR     ADDFORMAT_EA_DEST_EA
    SIMHALT * Return to IO 
SUB_L
    JSR PRINT_L
    *Proceed to EA Subroutine 
    JSR     ADDFORMAT_EA_DEST_EA
    SIMHALT * Return to IO     

   
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
    *< ea > Dn -> Dn (Data reg destination)
    CMP.B   #%000,D4
    BEQ     AND_B_D
    CMP.B   #%001,D4
    BEQ     AND_W_D
    CMP.B   #%010,D4
    BEQ     AND_L_D
    *Dn < ea > -> < ea > (EA destination)
    CMP.B   #%100,D4
    BEQ     AND_B
    CMP.B   #%101,D4
    BEQ     AND_W
    CMP.B   #%110,D4
    BEQ     AND_L
    
    BRA     INVALID_OP
   
* Handle EA, then Data Reg.
AND_B_D
    JSR PRINT_B
    *Proceed to EA Subroutine
    JSR     ADDFORMAT_DATA_DEST_EA
    
    SIMHALT * Return to IO
    
AND_W_D
    JSR PRINT_W
    *Proceed to EA Subroutine    
    JSR     ADDFORMAT_DATA_DEST_EA
    
    SIMHALT * Return to IO

AND_L_D  
    JSR PRINT_L
    *Proceed to EA Subroutine    
    JSR     ADDFORMAT_DATA_DEST_EA
    
    SIMHALT * Return to IO

    
* Handle data reg, then EA     
AND_B
    JSR PRINT_B
    *Proceed to EA Subroutine
    JSR     ADDFORMAT_EA_DEST_EA
    SIMHALT * Return to IO 
    
AND_W
    JSR PRINT_W
    *Proceed to EA Subroutine    
    JSR     ADDFORMAT_EA_DEST_EA
    SIMHALT * Return to IO 

AND_L    
    JSR PRINT_L
    *Proceed to EA Subroutine  
    JSR     ADDFORMAT_EA_DEST_EA
    SIMHALT * Return to IO 

    
    
OP_1101 *ADD,ADDA
    MOVE.L  D3,D4
    LSL.W   #7,D4
    MOVE.B  #13,D6
    LSR.W   D6,D4 *Get Opmode
    
    *ADD Opmodes
    *< ea > Dn -> Dn (Dn is the destination; Print <ea> first, then data register)
        * Added new branches to differentiate between orders.
    CMP.B   #%000,D4
    BEQ     ADD_B_D
    CMP.B   #%001,D4
    BEQ     ADD_W_D
    CMP.B   #%010,D4
    BEQ     ADD_L_D
    
    
    *Dn < ea > -> < ea > (EA is the destination; Print data reg first, then <ea>)
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

* For these, handle EA first, then Data reg.
ADD_B_D
    JSR     IS_ADD
    JSR     PRINT_B
    * Handle operands
    JSR     ADDFORMAT_DATA_DEST_EA
    
    SIMHALT * Return to IO
    
ADD_W_D
    JSR     IS_ADD
    JSR     PRINT_W
    * Handle operands
    JSR     ADDFORMAT_DATA_DEST_EA
    
    SIMHALT * Return to IO    
ADD_L_D
    JSR     IS_ADD
    JSR     PRINT_L
    * Handle operands
    JSR     ADDFORMAT_DATA_DEST_EA
    
    SIMHALT * Return to IO


* For these, handle data reg first, then EA.
ADD_B
    JSR     IS_ADD
    JSR     PRINT_B
    *Proceed to EA Subroutine
    JSR     ADDFORMAT_EA_DEST_EA
    SIMHALT * Return to IO 
    
ADD_W
    JSR     IS_ADD
    JSR     PRINT_W
    *Proceed to EA Subroutine    
    JSR     ADDFORMAT_EA_DEST_EA
    SIMHALT * Return to IO 
    
ADD_L
    JSR     IS_ADD
    JSR     PRINT_L
    *Proceed to EA Subroutine
    JSR     ADDFORMAT_EA_DEST_EA
    SIMHALT * Return to IO 


* Destination must be An, so do data reg first, then EA
ADDA_W
    JSR     IS_ADDA
    JSR     PRINT_W
    *Proceed to EA Subroutine
    JSR     ADDFORMAT_EA_DEST_EA
    SIMHALT * Return to IO 
    
ADDA_L  
    JSR     IS_ADDA  
    JSR     PRINT_L
    *Proceed to EA Subroutine
    JSR     ADDFORMAT_EA_DEST_EA
    SIMHALT * Return to IO 

    
    
OP_1110 *LSL/LSR,ASL/ASR,ROL/ROR (ADDED: Using D2 to track Mem/Reg state (0 = Reg, 1 = Mem) (D2 only used in hex input tester, so good to use))

    *Memory Shift Check bits 6,7
    MOVE.L  D3,D4
    LSL.W   #8,D4
    MOVE.L  #14,D6
    LSR.W   D6,D4
    
    CMP.B   #%11,D4
    BNE     REG
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
    
    *Register Shift check bits 4,3
REG MOVE.L  D3,D4
    MOVE.B  #11,D6
    LSL.W   D6,D4
    MOVE.B  #14,D6
    LSR.W   D6,D4
    
    CMP.B   #%00,D4 *ASL/ASR
    BEQ     A_REG
    CMP.B   #%01,D4 *LSL/LSR
    BEQ     L_REG
    CMP.B   #%11,D4 *ROL/ROR
    BEQ     R_REG
    
    
    BRA     INVALID_OP
    
    *Check bit 8 to determine L/R shift
A_REG
    JSR     RGHT_LFT
    
    MOVE.B  #0,D2 * SET D2 TO 0 TO KNOW IS REG
    
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
    
    MOVE.B  #1,D2 * SET D2 TO 1 TO KNOW IS MEM
    
    CLR.L   D6
    MOVE.B  #02,D6
    CMP.B   #%0,D4
    BEQ     IS_ASR
    CMP.B   #%1,D4
    BEQ     IS_ASL    

    SIMHALT
    
    
IS_ASR
    LEA     PRNT_ASR,A1
    MOVE.B  #14,D0
    TRAP    #15
    CMP.B   #01,D6
    BEQ     A_SIZE

    BRA     DO_SHIFT_EA * FOR MEM ONES WITH NO SIZE ATTRIBUTE.

    SIMHALT
IS_ASL
    LEA     PRNT_ASL,A1
    MOVE.B  #14,D0
    TRAP    #15
    CMP.B   #01,D6
    BEQ     A_SIZE

    BRA     DO_SHIFT_EA * FOR MEM ONES WITH NO SIZE ATTRIBUTE.

    SIMHALT
    
L_REG
    JSR     RGHT_LFT
    
    MOVE.B  #0,D2 * SET D2 TO 0 TO KNOW IS REG
    
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
    
    MOVE.B  #1,D2 * SET D2 TO 1 TO KNOW IS MEM
    
    CLR.L   D6
    MOVE.B  #02,D6
    CMP.B   #%0,D4
    BEQ     IS_LSR
    CMP.B   #%1,D4
    BEQ     IS_LSL    
    SIMHALT * Not needed; Should go to LSR/LSL?
    
IS_LSR
    LEA     PRNT_LSR,A1
    MOVE.B  #14,D0
    TRAP    #15
    CMP.B   #01,D6
    BEQ     L_SIZE
    
    BRA     DO_SHIFT_EA * FOR MEM ONES WITH NO SIZE ATTRIBUTE.
    
    SIMHALT
IS_LSL
    LEA     PRNT_LSL,A1
    MOVE.B  #14,D0
    TRAP    #15
    CMP.B   #01,D6
    BEQ     L_SIZE 
    
    BRA     DO_SHIFT_EA * FOR MEM ONES WITH NO SIZE ATTRIBUTE.
    
    SIMHALT
    
    
R_REG
    JSR     RGHT_LFT
    
    MOVE.B  #0,D2 * SET D2 TO 0 TO KNOW IS REG
    
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
    
    MOVE.B  #1,D2 * SET D2 TO 1 TO KNOW IS MEM
    
    CLR.L   D6
    MOVE.B  #02,D6
    CMP.B   #%0,D4
    BEQ     IS_ROR
    CMP.B   #%1,D4
    BEQ     IS_ROL    
    SIMHALT * Not needed; Should branch to either ROR/ROL?
    
    
IS_ROR
    LEA     PRNT_ROR,A1
    MOVE.B  #14,D0
    TRAP    #15
    CMP.B   #01,D6
    BEQ     R_SIZE  

    BRA     DO_SHIFT_EA * FOR MEM ONES WITH NO SIZE ATTRIBUTE.
  
    SIMHALT
IS_ROL
    LEA     PRNT_ROL,A1
    MOVE.B  #14,D0
    TRAP    #15
    CMP.B   #01,D6
    BEQ     R_SIZE 

    BRA     DO_SHIFT_EA * FOR MEM ONES WITH NO SIZE ATTRIBUTE.
   
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
    BEQ     PRINT_B_SHIFT
    CMP.B   #%01,D4    *W
    BEQ     PRINT_W_SHIFT
    CMP.B   #%10,D4    *L
    BEQ     PRINT_L_SHIFT
    

    
PRINT_B_SHIFT
    MOVE.B  #$1,D5 * For EA subroutine's size handling
    LEA     PRNT_B,A1
    MOVE.B  #14,D0
    TRAP    #15
    BRA     DO_SHIFT_EA
PRINT_W_SHIFT
    MOVE.B  #$2,D5 * For EA subroutine's size handling
    LEA     PRNT_W,A1
    MOVE.B  #14,D0
    TRAP    #15
    BRA     DO_SHIFT_EA
PRINT_L_SHIFT
    MOVE.B  #$3,D5 * For EA subroutine's size handling
    LEA     PRNT_L,A1
    MOVE.B  #14,D0
    TRAP    #15
    BRA     DO_SHIFT_EA

DO_SHIFT_EA
    
    
    *Proceed to EA Subroutine (ALL SHIFT OPS END UP HERE; USE TO GENERALIZE THE EA HANDLING FOR ALL)
    * Check D2 for status on MEM/REG for these.
    CMP.B   #0,D2
    BEQ     REG_EA

    JSR     EA_SRC * MEM mode, so just need to print single EA field.
    BRA     SHIFT_EA_DONE

REG_EA
    JSR     REGSHIFTFORMAT_EA
    
    MOVE.W  D3,D4
    AND.W   #%0000000000000111,D4
    MOVE.B  D4,D6
    
    MOVEM.L D0-D7,-(SP)
    JSR     EA_SUB
    MOVEM.L (SP)+,D0-D7

SHIFT_EA_DONE
    SIMHALT * GO TO IO; SHIFT INSTR DONE.    
 
PRINT_B
    MOVE.B  #$1,D5 * For EA subroutine's size handling
    LEA     PRNT_B,A1
    MOVE.B  #14,D0
    TRAP    #15
    RTS
PRINT_W
    MOVE.B  #$2,D5 * For EA subroutine's size handling
    LEA     PRNT_W,A1
    MOVE.B  #14,D0
    TRAP    #15
    RTS
PRINT_L
    MOVE.B  #$3,D5 * For EA subroutine's size handling
    LEA     PRNT_L,A1
    MOVE.B  #14,D0
    TRAP    #15
    RTS
INVALID_OP
    LEA     INVALID_MSG,A1
    MOVE.B  #14,D0
    TRAP    #15
    SIMHALT
*-----------HANDLE BIT SHIFTING EA SOURCE -------------------------
REGSHIFTFORMAT_EA
    MOVE.W  D3,D4 * Refresh D4 with our opcode word to analyze
     
    AND.W   #%0000111000000000,D4 * Isolate the register number
    LSR.W   #3,D4   * Shift reg/count to far right
    LSR.W   #6,D4
    MOVE.B  D4,D6   * D6 now contains either our register number or amount to shift by
    
    MOVE.W  D3,D4
    BTST    #5,D4 * Test bit 5 to tell if specified as a register or immediate value (Doesn't modify D4)
    BEQ     S_IMM   * Bit was 0, need to do immediate value process.
    * If here, do data register contains count process (D6 already prepared)
    
    MOVEM.L D0-D7,-(SP)
    
    JSR     EA_SUB * Print the source operand
    
    MOVEM.L (SP)+,D0-D7
    
    RTS * Go back to process the destination
    
S_IMM
    LEA     PRNT_Q,A1 * To print hash for immediate data.
    MOVE.B  #14,D0
    TRAP    #15
    
    CMP.B   #0,D6 * Test to see if D6 is equal to zero.
    BEQ     S_EIGHT * Convert value to 8.
    
    MOVE.B  D6,D1 * Print the value.
    MOVE.B  #3,D0
    TRAP    #15
    
    RTS

S_EIGHT
    MOVE.B  #8,D6
    
    MOVE.B  D6,D1 * Print the value.
    MOVE.B  #3,D0
    TRAP    #15

    RTS
    
*------------------------------------------------------------
*-----------HANDLE ADD FORMAT DATA DESTINATION EA -----------
ADDFORMAT_DATA_DEST_EA
    JSR     EA_SRC * Handle source EA
    
    
    
    MOVE.W  D3,D4
    AND.W   #%0000111000000000,D4 * Isolate Register #
    LSR.W   #3,D4
    LSR.W   #6,D4
    MOVE.B  D4,D6   * Prime D6 register
    
    MOVEM.L D0-D7,-(SP) * Move register contents to stack
    
    JSR     EA_SUB * Handle the destination EA (last 6 bits of D6)
    
    * MOVEM RETURN
    MOVEM.L (SP)+,D0-D7
    
    RTS
*------------------------------------------------------------
*-----------HANDLE ADD FORMAT EA DESTINATION EA -------------
ADDFORMAT_EA_DEST_EA
    
    MOVE.W  D3,D4
    AND.W   #%0000111000000000,D4 * Isolate Register #
    LSR.W   #3,D4
    LSR.W   #6,D4
    MOVE.B  D4,D6   * Prime D6 register
    
    MOVEM.L D0-D7,-(SP) * Move register contents to stack
    
    JSR     EA_SUB * Handle the source EA
    
    * MOVEM RETURN
    MOVEM.L (SP)+,D0-D7
    
    MOVE.W  D3,D4  * Refresh opcode
    
    JSR     EA_SRC * Handle destination EA

    RTS

*------------------------------------------------------------
*-------------------HANDLE SOURCE EA (last 6 bits)-----------
EA_SRC
    MOVEM.L D0-D7,-(SP) * Move register contents to stack

    MOVE.W  D3,D4
    AND.W   #%0000000000111111,D4
    MOVE.B  D4,D6
    
    JSR EA_SUB ** Print source EA bits from bits in D6
    
    * MOVEM RETURN
    MOVEM.L (SP)+,D0-D7
    RTS
*------------------------------------------------------------
*------HANDLE DESTINATION EA(6 bits before last 6 bits)------
EA_DEST
    MOVEM.L D0-D7,-(SP) * Move register contents to stack

    MOVE.W  D3,D4
    AND.W #%0000111111000000,D4
    LSR.W #6,D4
    MOVE.B  D4,D0
    AND.W #%0000000000000111,D0 * D0 contains mode bits
    MOVE.B  D0,D1   *MODE (D1) (Curr state: 000 001 in D1)
    MOVE.L  D4,D0 * D0 contains 6 bit field out of order
    LSR.W   #3,D0 * D0 contains reg bits (Curr State: 000 010 in D0)
    MOVE.B  D0,D2   *REG (D2) (Curr State: 000 010 in D2 and D0)
    
    LSL.B   #3,D1 * Shift mode into position
    
    OR.B    D1,D2   
    MOVE.B  D2,D6 *
    
    JSR     EA_SUB
    
    * MOVEM RETURN
    MOVEM.L (SP)+,D0-D7
    
    RTS
*------------------------------------------------------------ 
    
*-------------------EA Subroutine----------------------------

EA_SUB

            * 1: Process the 6-bit field into D3 (Register bits) and D4 (Mode bits)
            MOVE.B  D6,D4 * Prime D4 with the full 6-bit field
            AND.B   #%00000111,D4 * Clear everything but the register bits (BITS READY)
            
            MOVE.B  D6,D3 * Prime D3 with the full 6-bit field
            LSR.B   #3,D3 * Shift out the register bits to isolate the mode bits (BITS READY)
                
            * 2: Process the MODE BITS:
MODE_P      CMP.B   #%00000000,D3   * TEST FOR 000: Dn
            BEQ     DN_MODE
            
            CMP.B   #%00000001,D3   * TEST FOR 001: An
            BEQ     AN_MODE
            
            CMP.B   #%00000010,D3   * TEST FOR 010: (An)
            BEQ     ANIND_MODE
            
            CMP.B   #%00000011,D3   * TEST FOR 011: (An)+
            BEQ     ANINC_MODE
            
            CMP.B   #%00000100,D3   * TEST FOR 100: -(An)
            BEQ     ANDEC_MODE
            
            CMP.B   #%00000111,D3   * TEST FOR 111: #<data>, (xxx).W, or (xxx).L (or unsupported!)
            BEQ     ABSDAT_MODE
            
            BRA     UNSUPP_MODE     * If we made it here, assume an unsupported mode!
            
            
DN_MODE     LEA     PRNT_D,A1
            MOVE.B  #14,D0
            TRAP    #15
            
            BRA     REG_P
            
AN_MODE     LEA     PRNT_A,A1
            MOVE.B  #14,D0
            TRAP    #15
            
            BRA     REG_P

ANIND_MODE  LEA     PRNT_AI,A1
            MOVE.B  #14,D0
            TRAP    #15
            
            BRA     REG_P

ANINC_MODE  LEA     PRNT_AI,A1  * As of now this is the same as indirect, postdec added after register
            MOVE.B  #14,D0
            TRAP    #15
            
            BRA     REG_P

ANDEC_MODE  LEA     PRNT_DC,A1
            MOVE.B  #14,D0
            TRAP    #15
            
            BRA     REG_P
            

* DATA / ABSOLUTE ADDRESSING HANDLING (Mode was 111 in D3; need to chk. D4 reg bits for behavior)
ABSDAT_MODE CMP.B   #%00000100,D4 * TEST FOR 100: #<data>
            BEQ     DATA_MODE
            
            CMP.B   #%00000000,D4 * TEST FOR 000: (xxx).W
            BEQ     ABSW_MODE
            
            CMP.B   #%00000001,D4 * TEST FOR 001: (xxx).L
            BEQ     ABSL_MODE
            
            BRA     UNSUPP_MODE   * If the register is some other val, unsupported!
            
            * 3: Process the REGISTER BITS: (IN D4)
REG_P       MOVE.B  D4,D1   * Load the register value into D1 for display.
            MOVE.B  #3,D0
            TRAP    #15
            
            CMP.B   #%00000010,D3
            BEQ     END_ONE
            
            CMP.B   #%00000100,D3
            BEQ     END_ONE
            
            CMP.B   #%00000011,D3
            BEQ     END_TWO
            
            BRA     FINISH  * Additional char after register unnecessary, branch to finish
            
END_ONE     LEA     PRNT_CL,A1
            MOVE.B  #14,D0
            TRAP    #15
            
            BRA     FINISH

END_TWO     LEA     PRNT_IN,A1
            MOVE.B  #14,D0
            TRAP    #15
            
            BRA     FINISH

* #<DATA>; RELIES ON D5 CONTAINING SIZE VALUE OF THE INSTRUCTION! (So we know how much data to grab, then what to increment A5 by! (word or long))
    * If this contains 0, this will not work in this state. D5 MUST have val 1-3 at this point!
DATA_MODE   LEA     PRNT_DT,A1 * Print '#$'
            MOVE.B  #14,D0
            TRAP    #15
            
            CMP.B   #1,D5
            BEQ     BYTE
            
            CMP.B   #2,D5
            BEQ     WORD
            
            CMP.B   #3,D5
            BEQ     LONG
            
* (xxx).W;            
ABSW_MODE   LEA     PRNT_HX,A1 * Print '$'
            MOVE.B  #14,D0
            TRAP    #15
            
            BRA     WORD
            
* (xxx).L; Assembler uses this when it sign extends automatically over (xxx).W           
ABSL_MODE   LEA     PRNT_HX,A1 * Print '$'
            MOVE.B  #14,D0
            TRAP    #15
            
            BRA     LONG

* Expects format created by assembled machine code, NOT how it is just pushed to memory by (An)!            
BYTE        MOVE.W  (A5)+,D1    * Move word of data from curr opcode word pointer to D1, then increment pointer a word.
            MOVE.B  #16,D2      * Prepare to display a hex value
            
            AND.W   #%0000000011111111,D1   * Discard potential word part from byte
            MOVE.B  #15,D0      * Set the task to 15
            TRAP    #15         * Print the value.

            BRA     FINISH

WORD        MOVE.W  (A5)+,D1    * Move word of data from curr opcode word pointer to D1, then increment pointer a word.
            MOVE.B  #16,D2      * Prepare to display a hex value
            
            MOVE.B  #15,D0      * Set the task to 15
            TRAP    #15         * Print the value.

            BRA     FINISH

LONG        MOVE.L  (A5)+,D1    * Move longword of data from curr opcode word pointer to D1, then increment pointer a longword.
            MOVE.B  #16,D2      * Prepare to display a hex value
            
            MOVE.B  #15,D0      * Set the task to 15
            TRAP    #15         * Print the value.
            
            BRA     FINISH
      
            * 4: UNSUPPORTED BRANCH:
UNSUPP_MODE LEA     PRNT_ER,A1
            MOVE.B  #14,D0
            TRAP    #15 * Continue directly onto finishing up from here
            
            MOVE.B  #0,D7   * Set Good/Bad flag to Bad state (0 bit)
            
            * 5: Finishing up:
FINISH      
            * Return values stored in stack prior to moving into here into registers.
                * (Will put here on integration...)
            * A5 currently points to the next needed opcode to process, which could be the following:
                * Next opcode word instruction
                * More data corresponding to the next <ea> field for current instruction
            
            RTS



*------------------Vars and Consts--------------------------

    * Define any constants/vars besides registers I need here.

*------------------Messages for Printing -------------------
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

PRNT_D  DC.B    'D',0
PRNT_A  DC.B    'A',0
PRNT_AI DC.B    '(A',0
PRNT_CL DC.B    ')',0
PRNT_IN DC.B    ')+',0
PRNT_DC DC.B    '-(A',0

PRNT_Q  DC.B    '#',0
PRNT_DT DC.B    '#$',0
PRNT_HX DC.B    '$',0

PRNT_ER DC.B    'ERROR: Unsupported EA Mode',0

*D3 = original instruction
*D4 = copy of instruction
*D6 = num of bits to shift
    END    START        ; last line of source








*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
