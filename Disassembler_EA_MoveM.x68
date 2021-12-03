*-----------------------------------------------------------
* Title      : 68K Disassembler EA Decoding Subroutine (MOVEM)
* Written by : Timothy Kozlov
* Date       : 11/30
* Description: Given the following registers, this subroutine prints
* out the EA/data portion of the MOVEM instruction.
*
* PRECONDITIONS:
* D6: The 16 bits for the MOVEM instruction
*-----------------------------------------------------------
* TESTING
*-----------------------------------------------------------
CR              EQU         $0D
LF              EQU         $0A
AD_MASK         EQU         $500
AD_MODE         EQU         $502
AD_REG          EQU         $504

*                MOVEM.L     A0-A7/D0-D7, (A0)             48D0 FFFF
*                MOVEM.L     A0-A1/D1/D3/D5, -(A1)         48E1 54C0
*                MOVEM.L     D1-D4/D7, $100                48F8 009E 0100


START           ORG         $1000
                MOVE.L      #$48F8009E,D6
                MOVE.W      #$0100,(A5)

                
*------------BEGIN DECODING---------------------------------------------

PARSE_MOVEM_EA  MOVE.L      D6,D5
                ANDI.L      #$0000FFFF,D5
                MOVE.W      D5,AD_MASK      Store mask <data> in AD_MASK
                
                MOVE.L      D6,D5
                MOVE.B      #16,D4          
                ASR.L       D4,D5           Filter out <data>
                ANDI.W      #$003F,D5       Filter out non-<ea> bits
                
                MOVE.W      D5,D4
                ASR.L       #3,D4           
                MOVE.W      D4,AD_MODE      Store mode in D4
                
                ANDI.W      #$7,D5          
                MOVE.W      D5,AD_REG       Store register in D5
                
*-------------------MASK, MODE, AND REGISTER ARE STORED-----------------

                LEA         PRNT_MOVEM,A1
                MOVE.B      #14,D0
                TRAP        #15             Print MOVEM prefix (just for test purposes)

                MOVE.L      D6,D5
                ROL.L       #6,D5          
                ANDI.L      #1,D5           Get the direction bit
                
                CMP.B       #0,D5           
                BEQ         REG_TO_MEM      Print register to memory
                
                JSR         PRINT_EA        Else memory to register
                LEA         PRNT_CMMA,A1
                MOVE.B      #14,D0
                TRAP        #15             Print comma
                JSR         PRINT_MASK
                SIMHALT


REG_TO_MEM      JSR         PRINT_MASK
                LEA         PRNT_CMMA,A1
                MOVE.B      #14,D0
                TRAP        #15             Print comma
                JSR         PRINT_EA
                SIMHALT

*------------------SUBROUTINE TO PRINT EA TO CONSOLE--------------------

PRINT_EA        MOVE.W      AD_MODE,D3      Move mode bits to d3
                MOVE.W      AD_REG,D4       Move reg bits to d4
                
*------------------LET ZACHS CODE HANDLE THE REST-----------------------
                
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
UNSUPP_MODE
FINISH      

*-----------------------END ZACHS CODE -------------------------------


PRINT_EA_DONE   RTS


*------------------SUBROUTINE TO PRINT MASK TO CONSOLE------------------

PRINT_MASK      MOVE.B      #0,D3           Flag=0
PRINT_MASK_A    MOVE.B      #8,D5           Loop D5=8
PRINT_MASK_A_LP CMP.B       #0,D5           Loop D5>0
                BEQ         PRINT_MASK_D                    

                MOVE.W      AD_MASK,D4           
                ROL.W       D5,D4
                ANDI.W      #1,D4           Store the D5th A-register in D4
                SUBI.B      #1,D5           Loop D5--
                
                CMP.B       #0,D4
                BEQ         PRINT_MASK_A_LP Do nothing if bit is zero
                
                CMP.B       #0,D3           First print? Skip!
                BEQ         SKIP_SLASH_A
                LEA         PRNT_SLASH,A1
                MOVE.B      #14,D0
                TRAP        #15             Print slash
                
                
SKIP_SLASH_A    LEA         PRNT_A,A1
                MOVE.B      #14,D0
                TRAP        #15             Print 'A'
                
                MOVE.B      #3,D0
                MOVE.B      #7,D1
                SUB.B       D5,D1
                TRAP        #15             Print register
                MOVE.B      #1,D3           Flag=True (we printed something)
                
                BRA         PRINT_MASK_A_LP

    
PRINT_MASK_D    MOVE.B      #0,D5           Loop D5=0
PRINT_MASK_D_LP CMP.B       #8,D5           Loop D5<8
                BEQ         PRINT_MASK_DONE
                
                MOVE.W      AD_MASK,D4
                ROR.W       D5,D4
                ANDI.W      #1,D4           Store the D5th D-register in D4
                ADDI.B      #1,D5           Loop D5++

                CMP.B       #0,D4
                BEQ         PRINT_MASK_D_LP Do nothing if bit is zero

                CMP.B       #0,D3           First D-register AND never printed before? Skip!
                BEQ         SKIP_SLASH_D
                LEA         PRNT_SLASH,A1
                MOVE.B      #14,D0
                TRAP        #15
                
SKIP_SLASH_D    LEA         PRNT_D,A1
                MOVE.B      #14,D0
                TRAP        #15             Print 'D'
                
                MOVE.B      #3,D0
                MOVE.B      D5,D1
                SUB.B       #1,D1
                TRAP        #15             Print register
                MOVE.B      #1,D3           Flag = true
                
                BRA         PRINT_MASK_D_LP

PRINT_MASK_DONE RTS

PRNT_A          DC.B        'A',0
PRNT_D          DC.B        'D',0
PRNT_AI         DC.B        '(A',0
PRNT_CL         DC.B        ')',0
PRNT_IN         DC.B        ')+',0
PRNT_DC         DC.B        '-(A',0

PRNT_DT         DC.B        '#$',0
PRNT_HX         DC.B        '$',0
PRNT_SLASH      DC.B        '/',0
PRNT_CMMA       DC.B        ', ',0
PRNT_MOVEM      DC.B        'MOVEM.X ',0
                END         START

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
