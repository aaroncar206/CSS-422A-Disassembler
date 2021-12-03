*-----------------------------------------------------------
* Title      : 68k Disassembler EA Decoding Subroutine
* Written by : Zach Hanneman
* Date       : 11/27/21
* Description: This subroutine aims to handle the EA decoding
* portion of the 68k disassembler program. It expects the 
* data detailed below this description as parameters in order
* to handle the decoding of the Effective Address Mode portion
* of the instruction currently being disassembled by the program.
* One run of this subroutine corresponds to a single operand to process.
*
* PRECONDITIONS:
* D5: A number representing the size of the instruction, as follows: (Needed for #<data> case, since we don't know how much data to grab otherwise!)
*   * Not Set = 0 (or anything else, really. Always set when possible!)
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
*------------*TESTING CODE: RM ON INTEGRATION*--------------

    * Define anything I need for unit testing in here:
        * 6-bit <ea> field (FORMAT: MODE, then REG)
        * Sample current memory address word location in A5
        * Sample print buffer (? - May not be using, we'll see during integration)
        
    LEA     $1006,A5    * TEST: Dummy "next opcode word" value. (corresponds to opcode after the instruction after this)
    MOVE.W  #$78F0,D0   * TEST: Sample instruction for EA modes needing to incr. A5 (immediate address & abs address)
                        * Otherwise, points to some data corresponding to opcode!
    * Test inserted vals here...
        
    MOVE.B  #%00111100,D6 * TEST: <ea> BITFIELD AT D6
    MOVE.B  #2,D5         * TEST: SIZE VALUE OF INSTRUCTION (see above correspondences; only used for #<data>)

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

PRNT_ER DC.B    'ERROR: Unsupported EA Mode',0
*-----------------------------------------------------------
            END    START * TEMP: REMOVE ON INTEGRATION *****








*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
