*-----------------------------------------------------------
* Title      : Dissassembler IO Subroutine
* Written by : Aaron Carbonell
* Date       : 11/22/2020
* Description: This program scans memory from starting address 
*              to ending address inputted by user and displays 
*              mock contents to screen.
*-----------------------------------------------------------
CR EQU $0D
LF EQU $0A


*----- PRECONDITIONS ------*
* - Instruction addresses must be properly formatted hex values
* - Opcode must be properly formatted hex values ready to be read in memory
*    - D6: good/bad opcode flag (0 = good, 1 = bad)(NOTE** OPCODE SUBROUTINE SETS THIS FLAG UPON OPCODE PROCESSING) 
* - Operands must be be properly formatted hex values ready to be read in memory
*    - D7: good/bad operand1 flag (0 = good, 1 = bad) (NOTE** EA SUBROUTINE SETS THESE FLAGS UPON OPCODE PROCESSING) 
*    - D5: good/bad operand2 flag(0 = good, 1 = bad), (set to 6 if operand2 is actually needed)

*---- POSTCONDITIONS -----*
* - Output memory words to console

    ORG    $1000
START:                  ; first instruction of program


* --Prompt user for starting address--
PROMPT_FOR_START
    LEA PROMPT_START,A1 
    MOVE.B #14,D0 
    TRAP #15 
    MOVEA.L #0,A1
    
    MOVE.W #2,D0 
    TRAP #15 Read a string from the keyboard into D1.L
    BRA CONV_STRING


* --Prompt user for ending address--
PROMPT_FOR_END
    LEA PROMPT_END,A1 
    MOVE.B #14,D0 
    TRAP #15 
    MOVEA.L #0,A1
    
    MOVE.W #2,D0 
    TRAP #15 Read a string from the keyboard into D1.L
    BRA CONV_STRING
     
    
*-- Converts ASCII string to Hex equivalent --  
CONV_STRING
    MOVE.B (A1)+,D0 Get individual char in input string
    CMP.B #$46,D0 Check if char is more than F, the last valid hex value
    BGT DISPLAY_INVALID_HEX 
    CMP.B #$41,D0 Check if char is a number or letter
    BLT CONV_NUM
    
    **--Convert ASCII char to hex equivalent --
    SUB.B #$37, D0 
    ADD.L D0,D3
    SUBI #1,D1 
    CMP.B #0,D1
    BEQ DONE_START_CONV
    LSL.L #4,D3
    BRA CONV_STRING


* --Display invalid hex error upon invalid input--
DISPLAY_INVALID_HEX
    LEA INVALID_HEX,A1
    MOVE.B #14,D0 
    TRAP #15 
    
    LEA LINE_BREAK,A1
    MOVE.B #14,D0 
    TRAP #15 
    CLR D3
    CLR D4

    BRA PROMPT_FOR_START


* --Converts ASCII num char into hex equivalent--   
CONV_NUM 
    CMP.B #$30,D0 
    BLT DISPLAY_INVALID_HEX *check if char is less than 30, first valid hex num
    CMP.B #$39,D0
    BGT DISPLAY_INVALID_HEX *check if char is less than 30, last valid hex num
    SUB.B #$30,D0
    ADD.L D0,D3
    SUBI #1,D1
    CMP.B #0,D1 
    BEQ DONE_START_CONV
    LSL.L #4,D3
    BRA CONV_STRING
    

* --Move converted starting address into A3--
DONE_START_CONV
   CMP #1,D4
   BEQ DONE_END_CONV
   ADDI #1,D4
   
   MOVEA.L D3,A3
   CLR D3
   
   BRA PROMPT_FOR_END
  
* --Move converted ending address into A4 and prepare for opcodes--
DONE_END_CONV
    CLR.W D4
    MOVEA.L D3,A4
    CLR D3
    
    BRA PREPARE_DISPLAY_BUFFER
    *-- op code person takes over from here--
    *-- derive opcodes starting from start address --*

* Prepare display buffer (these variables will be filled with real memory upon integration)
PREPARE_DISPLAY_BUFFER 
    MOVE.W INSTRUCTION_ADDR_MESSAGE, INSTRUCTION_ADDR  *-- make placeholder for instruction address
    MOVE.W OPCODE_MESSAGE, OPCODE *-- make placeholder for opcode
    
    MOVE.W #OPERAND1_MESSAGE, OPERAND1 *-- make placeholder for first operand 
    MOVE.W #OPERAND2_MESSAGE, OPERAND2 *-- make placeholder for second operand 
        
*-- Traverse through mock data in memory and print out until ending address
*-- NOTE** displays random YY's which is okay for now. Intent is to demonstrate 
*-- the essence of I/O behavior for assembler. 
PRINT_INSTRUCTIONS  
    JSR NEEDS_NEW_SCREEN
    
    CMPA.L A3,A4 *-- check if at end address 
    BLE DONE
 
    MOVE.W (A3)+,INSTRUCTION_ADDR *get first word in mem
    LEA INSTRUCTION_ADDR, A1
    MOVE.B #14,D0 
    TRAP #15 
    
    LEA SPACE, A1
    MOVE.B #14,D0 
    TRAP #15 
    
    CMP.B #1, D6 *-- check for valid opcode
    BEQ DISPLAY_INVALID_INSTRUCTION
    
    MOVE.W (A3)+,OPCODE *get next word in mem
    LEA OPCODE, A1
    MOVE.B #14,D0 
    TRAP #15 
    
    LEA SPACE, A1
    MOVE.B #14,D0 
    TRAP #15 
    
    CMP.B #1, D7 *-- check for valid operand1
    BEQ DISPLAY_INVALID_INSTRUCTION
    
    MOVE.W (A3)+,OPERAND1 *get next word in mem
    LEA OPERAND1, A1
    MOVE.B #14,D0 
    TRAP #15 
    
    MOVE.B #6, D5
    CMP.B #6,D5 *-- check if another operand is needed
    BEQ PRINT_SECOND_OPERAND
    
    LEA LINE_BREAK,A1
    MOVE.B #14,D0 
    TRAP #15
    
    BRA PRINT_INSTRUCTIONS
    
*-- Print second operand if needed
PRINT_SECOND_OPERAND
    CMP.B #1, D5 *-- check for valid operand2
    BEQ DISPLAY_INVALID_INSTRUCTION
    
    LEA COMMA, A1
    MOVE.B #14,D0 
    TRAP #15
    
    MOVE.W (A3)+,OPERAND2 *get next word in mem
    LEA OPERAND2, A1
    MOVE.B #14,D0 
    TRAP #15 

    LEA LINE_BREAK,A1
    MOVE.B #14,D0 
    TRAP #15
    
    BRA PRINT_INSTRUCTIONS
    
*Display XXXXXXXX DATA YYYY if memory cannot be decoded to legitimate instruction   
DISPLAY_INVALID_INSTRUCTION 
    MOVE.W (A3),INVALID_MEM_ADDR *get invalid word in mem
    LEA INVALID_MEM_ADDR, A1
    MOVE.B #14,D0 
    TRAP #15 

    LEA DATA, A1
    MOVE.B #14,D0 
    TRAP #15 
    
    MOVE.W (A3),INVALID_HEX_VAL *get next word in mem
    LEA INVALID_HEX_VAL, A1
    MOVE.B #14,D0 
    TRAP #15 
    
    BRA PRINT_INSTRUCTIONS
         
*--Check if output reaches the end of screen 
NEEDS_NEW_SCREEN
    ADD      #1,D4					 
    CMP      #26,D4 check if output reaches 25 lines																								
    BEQ      PROMPT_USER_FOR_ENTER
    LEA      SPACE,A1			
    MOVE     #14,D0					
    TRAP     #15						
    RTS	
    
*--Prompt user to press enter when display reaches line limit    
PROMPT_USER_FOR_ENTER
    LEA    SPACE,A1 
    MOVE.B #13,D0   
    TRAP   #15

    LEA ENTER_MESSAGE, A1 *Prompt user to press enter to display new screen
    MOVE.B #14, D0
    TRAP #15
    
    CLR      D4	
    MOVE.B   #5,D0			
    TRAP     #15			
    RTS	
    

* Put variables and constants here
PROMPT_START DC.B 'Please enter a starting address in hexadecimal: ' ,0
PROMPT_END DC.B 'Please enter an ending address in hexadecimal: ' ,0
INVALID_HEX DC.W 'Error: Address must be in valid hexadecimal' ,CR,LF,0
DONE_MESSAGE DC.B 'Done printing instructions' ,CR,LF,0
ENTER_MESSAGE DC.W 'Please press enter to display new screen ' ,CR,LF,0
INVALID_MEM_ADDR DS.W 1
DATA DC.W ' DATA ',CR,LF,0
INVALID_HEX_VAL DS.W 1 
LINE_BREAK DC.B ' ',CR,LF,0
SPACE DC.W ' ',0
COMMA DC.W ',',0
INSTRUCTION_ADDR DS.B 1
INSTRUCTION_ADDR_MESSAGE DC.W 'INSTRUCTION ADDR',0
OPCODE DS.W 1
OPCODE_MESSAGE DC.W 'OPCODE',0
OPERAND1 DS.W 1
OPERAND1_MESSAGE DC.W 'OPERAND1',0
OPERAND2 DS.W 1
OPERAND2_MESSAGE DC.W 'OPERAND2',0

GOOD_BAD_FLAG DS.B 1

START_ADDR DS.W 4
END_ADDR DS.W 4

DONE
    LEA DONE_MESSAGE, A1
    MOVE.B #14,D0 
    TRAP #15 
    END    START        ; last line of source













*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
