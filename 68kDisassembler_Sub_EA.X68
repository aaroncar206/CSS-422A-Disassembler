*-----------------------------------------------------------
* Title      : 68k Disassembler EA Decoding Subroutine
* Written by : Zach Hanneman
* Date       : 11/24/21
* Description: This subroutine aims to handle the EA decoding
* portion of the 68k disassembler program. It expects the 
* data detailed below this description as parameters in order
* to handle the decoding of the Effective Address Mode portion
* of the instruction currently being disassembled by the program.
*
* PRECONDITIONS:
* D5: A number representing the size of the instruction, as follows: (Needed for #<data> case, since we don't know how much data to grab otherwise!)
*   * Not Set = 0
*   * .B = 1
*   * .W = 2
*   * .L = 3
* D6: The 6-bit <ea> field (two most significant bits cleared to 0s)
* A5: Address of next word to decode (Assumed already at position after opcode word being decoded)
* A6: Print Buffer at next available space (If we end up using this...)
*
* POSTCONDITIONS: 
* D7: Good/Bad flag; Remains the same unless error occurred (e.g. invalid mode)
* A5: Memory pointer at the next opcode word (only modified if operation involved data or absolute address modes)
* A6: Pointer to next free space in print buffer (if we end up using it...)
*-----------------------------------------------------------
START       ORG		$1000 * TEMP: REMOVE ON INTEGRATION ****
*-------------------TESTING CODE----------------------------

    * Define anything I need for unit testing in here:
        * 6-bit <ea> field (FORMAT: MODE, then REG)
        * Sample current memory address word location in A5
        * Sample print buffer (? - May not be using, we'll see during integration)
        
    MOVE.B  #%00011111,D6 * TEST: <ea> BITFIELD AT D6

*-------------------Program Code----------------------------
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
            
            CMP.B   #%00000111,D3   * TEST FOR 111: #<data>, (xxx).W, or (xxx).L
            BEQ     DATA_MODE
            
            BRA     UNSUPP_MODE *** If we made it here, assume an unsupported mode! ***
            
            
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
            
* NEED TO HANDLE INCREMENTING A5 WORD FOR THIS: In these cases, A5 points to data, not an opcode word! *******
    * Need to print the data/absolute addresses as needed & increment A5 after so that its on the next opcode word to decode!
DATA_MODE   LEA     PRNT_DT,A1 * DEBUG: Different behavior needed! (Keep for now until I handle this case...)
            MOVE.B  #14,D0
            TRAP    #15
            
            BRA     REG_P_DAT
            
            * 3: Process the REGISTER BITS: (IN D4)
REG_P       MOVE.B     D4,D1   * Load the register value into D1 for display. (Could also convert to string...)
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

REG_P_DAT   * May move this handling to exclusively under the datamode section above; For now does nothing.
            
            BRA     FINISH  * If we reached here, we are done processing this EA field
      
            * 4: UNSUPPORTED BRANCH:
UNSUPP_MODE LEA     PRNT_ER,A1
            MOVE.B  #14,D0
            TRAP    #15 * Continue directly onto finishing up from here
            
            * 5: Finishing up:
FINISH

	 	    SIMHALT * TEMP: REMOVE ON INTEGRATION **********
*------------------Vars and Consts--------------------------

    * Define any constants/vars besides registers I need here.

*------------------Messages for Printing -------------------
CR      EQU     $0D
LF      EQU     $0A

PRNT_D  DC.B    'D',0
PRNT_A  DC.B    'A',0
PRNT_AI DC.B    '(A',0
PRNT_CL DC.B    ')',0
PRNT_IN DC.B    ')+',0
PRNT_DC DC.B    '-(A',0

PRNT_DT DC.B    '#$',0
PRNT_HX DC.B    '$',0

PRNT_ER DC.B    'ERROR: Unsupported effective address mode!',0
*-----------------------------------------------------------
            END    START * TEMP: REMOVE ON INTEGRATION *****






*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
