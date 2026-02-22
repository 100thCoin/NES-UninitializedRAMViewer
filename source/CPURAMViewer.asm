	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;             CPU RAM Viewer              ;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
	; This ROM will print $100 bytes on screen at a time, allowing you to see the uninitialized RAM on your console.
	; NOTE: This will not work on an Everdrive N8 Pro, as that initializes RAM before booting the game.

	;;;; HEADER AND COMPILER STUFF ;;;;
	.inesprg 1  ; 2 banks
	.ineschr 1  ; 
	.inesmap 0  ; mapper 0 = NROM
	.inesmir 0  ; background mirroring, horizontal
	;;;; CONSTANTS ;;;;	

	.bank 0
	.org $8000
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;        Power On / Reset Behavior        ;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
RESET:
	            ; Okay, here's the challenge. Throughout this entire ROM, I am not allowed to use a single byte of CPU RAM, including the stack.
	SEI         ; Typical power on checks, like setting the CPU's "interrupt suppression" flag.
	LDA #$40
	STA $4017   ; Disable the APU Frame Counter IRQ.
	LDA #0
	STA $2000   ; The NMI pushes data to the stack, which we are not allowed to do. (In theory, this is disabled by default though.)
	            ; wait for 2 frames.
	LDY #$FF
	LDA $2002   ; This is a pretty traditional VBlank loop.
VblLoop:
	LDA $2002   ; The PPU Registers on some consoles are forcefully set to $00 until the end of the first VBlank.
	BPL VblLoop ; So most programs written for the NES stall for 2 frames via reads of address $2002.
	INY         ; Then I'll increment Y, and if Y just went from $FF to $00, we run this loop a second time.
	BEQ VblLoop ; Otherwise, we have waited a minimum of two frames, and we can continue.
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;              Palette RAM                ;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                            ; Now that the ppu registers are active, let's start writing to them. Beginning with Palette RAM, while we're still in vblank.
	JMP SetUpDefaultPalette ; Jump around this table.
DefaultPalette:
	.byte $2D,$2D,$30,$30,$0F,$00,$30,$0F,$0F,$0F,$0F,$0F,$0F,$2D,$2D,$0F
	.byte $2D,$0F,$0F,$30,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F	
SetUpDefaultPalette: 
	LDA #$3F
	STA $2006
	LDA #$00
	STA $2006               ; Palette RAM exists at address $3F00 on the PPU Address Space.
	LDY #0
SetUpPaletteLoop:
	LDA DefaultPalette,Y    ; Load the color from the above table.
	STA $2007
	INY
	CPY #32                 ; Loop until we get all 32 colors.
	BNE SetUpPaletteLoop
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;        Nametable Initialization         ;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
	LDA #$20
	STA $2006
	LDA #$00
	STA $2006  ; Move v to $2000
	LDA #$24   ; Empty CHR.
	LDX #$04   ; $400 bytes.
	LDY #$00
NTLoop:
	STA $2007  ; Write $24 to the nametable, clearing that byte.
	DEY
	BNE NTLoop ; decrement Y until Y=0.
	DEX
	BPL NTLoop ; Decrement X until X underflows.
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;            Attribute Tables             ;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
	LDA #$23
	STA $2006
	LDA #$C0
	STA $2006          ; Move v to 23C0 (the attribute table for nametable 0.)
	LDA #$FF           ; Palette 3 for every tile.
	LDY #$18           ; The first $18 attribute bytes will be zero.
AttributeLoop1:	
	STA $2007          ; Store 0 in PPUDATA.	
	DEY                ; Decrement Y	
	BNE AttributeLoop1 ; Loop until Y = 0. 		
	LDA #%00010100     ; Checkerboard pattern.
	LDY #$10           ; The next $10 attribute bytes will be using a checkerboard pattern.
AttributeLoop2:	
	STA $2007          ; Store the checkboard pattern in PPUDATA.	
	DEY                ; Decrement Y	
	BNE AttributeLoop2 ; Loop until Y = 0. 		
	LDA #$FF           ; Palette 3 for every tile.
	LDY #$18           ; The final $18 attribute bytes will be zero.
AttributeLoop3:	
	STA $2007          ; Store 0 in PPUDATA.	
	DEY                ; Decrement Y	
	BNE AttributeLoop3 ; Loop until Y = 0. 	
	
	LDX #0
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;     Printing RAM to the Nametables      ;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
DrawPageX:	
	LDY #$FF
VblLoop2:
	LDA $2002 	
	BPL VblLoop2        ; Wait for Vblank.
	INY
	BEQ VblLoop2        ; Wait for Vblank again.
	
	LDA #0
	STA $2001           ; Disable ppu rendering.	
	                    ; Move v to $2180
	LDA #$21
	STA $2006
	LDA #$80
	STA $2006 
	LDY #0              ; Initialize Y for the upcoming loop.
	                    ; We cannot use indirect addressing, since that would overwrite bytes in RAM. 
	                    ; The only way to choose what page in RAM we're reading is to have an ugly series of branches.
	CPX #0              ; Check if X equals zero.
	BNE DPX1            ; If X does not equal zero, check if X equals 1.
DrawPage0Loop:
	LDA $0000,Y         ; if X does equal zero, load a byte form the zero page, with offset Y. Y increments with each iteration of this loop.
	STA $2007           ; Write to PPUDATA
	INY                 ; Increment Y	
	BNE DrawPage0Loop   ; Loop until Y overflows.
	JMP DoneDrawingPage ; And jump ahead.
	
DPX1:
	CPX #1              ; Check if X equals one.
	BNE DPX2            ; If X does not equal one, check if X equals 2.
DrawPage1Loop:
	LDA $0100,Y         ; if X does equal one, load a byte form page one, with offset Y. Y increments with each iteration of this loop.
	STA $2007           ; Write to PPUDATA
	INY                 ; Increment Y	
	BNE DrawPage1Loop   ; Loop until Y overflows.
	JMP DoneDrawingPage ; And jump ahead.
	
DPX2:
	CPX #2              ; The pattern repeats for pages 2 through 7.
	BNE DPX3
DrawPage2Loop:
	LDA $0200,Y
	STA $2007
	INY
	BNE DrawPage2Loop
	JMP DoneDrawingPage
	
DPX3:
	CPX #3
	BNE DPX4
DrawPage3Loop:
	LDA $0300,Y
	STA $2007
	INY
	BNE DrawPage3Loop
	JMP DoneDrawingPage
	
DPX4:
	CPX #4
	BNE DPX5
DrawPage4Loop:
	LDA $0400,Y
	STA $2007
	INY
	BNE DrawPage4Loop
	JMP DoneDrawingPage

DPX5:
	CPX #5
	BNE DPX6
DrawPage5Loop:
	LDA $0500,Y
	STA $2007
	INY
	BNE DrawPage5Loop
	JMP DoneDrawingPage
	
DPX6:
	CPX #6
	BNE DrawPage7Loop
DrawPage6Loop:
	LDA $0600,Y
	STA $2007
	INY
	BNE DrawPage6Loop
	JMP DoneDrawingPage

DrawPage7Loop:
	LDA $0700,Y
	STA $2007
	INY
	BNE DrawPage7Loop
	JMP DoneDrawingPage

DoneDrawingPage:
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;            Enable Rendering             ;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
	LDY #$FF
VblLoop3:
	LDA $2002 	
	BPL VblLoop3 ; Wait for Vblank.
	INY
	BEQ VblLoop3 ; Wait for Vblank again.
	
	TXA
	CLC
	ADC #$90     ; A = X+90
	
	STA $4014    ; Run an OAM DMA with the hard-coded OAM tables.
	
	LDA #$00
	STA $2006
	STA $2006
	
	LDA #$1E
	STA $2001    ; Enable rendering both the background and sprites.
	LDA #$10
	STA $2000    ; The background uses pattern table 1.
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;          Wait For No User Input         ;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

UserStopInputLoop:
	LDA #1                ; Wait for the player to stop holding left or right.
	STA $4016             ; Strobe the controller.
	LSR A
	STA $4016             ; Finish the strobe of the controller.
	LDA $4016             ; A
	LDA $4016             ; B
	LDA $4016             ; Start
	LDA $4016             ; Select
	LDA $4016             ; Up
	LDA $4016             ; Down
	LDA $4016             ; Left
	AND #1                ; Check if the left button is still being pressed from the previous loop.
	BNE UserStopInputLoop ; If so, loop.
	LDA $4016             ; Right
	AND #1                ; Check if the Right button is still being pressed from the previous loop.
	BNE UserStopInputLoop ; If so, loop.

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;           Wait For User Input           ;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

UserInputLoop:
	LDA #1
	STA $4016         ; Strobe the controller.
	LSR A
	STA $4016         ; Finish the strobe of the controller.
	LDA $4016         ; A
	LDA $4016         ; B
	LDA $4016         ; Start
	LDA $4016         ; Select
	LDA $4016         ; Up
	LDA $4016         ; Down
	LDA $4016         ; Left
	AND #1            ; Check if the left button was being pressed.
	BEQ CHKR          ; If not, check if the right button was being pressed.
	DEX               ; We're pressing left, so decrement X.
	BPL XIsReady      ; If X didn't underflow, branch ahead.
	LDX #7            ; If X did underflow, initialize X to 7.
	BNE XIsReady      ; This branch is always taken.
	
CHKR:
	LDA $4016         ; Right
	AND #1            ; Check if the right button was being pressed.
	BEQ UserInputLoop ; If not, loop.
	INX               ; If we're pressing right, increment X.
	CPX #8            ; Check if X "overflowed"
	BNE XIsReady      ; If X didn't overflow, branch ahead.
	LDX #0            ; if X did overflow, initialize X to 0.
	
XIsReady:

	JMP DrawPageX     ; And now we draw the next page.	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;          Hard-Coded OAM Tables          ;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	.org $9000
	.byte $50, $19, $00, $68 ; P	
	.byte $50, $0A, $00, $70 ; A
	.byte $50, $10, $00, $78 ; G
	.byte $50, $0E, $00, $80 ; E
	.byte $50, $00, $00, $90 ; 0

	.org $9100
	.byte $50, $19, $00, $68 ; P
	.byte $50, $0A, $00, $70 ; A
	.byte $50, $10, $00, $78 ; G
	.byte $50, $0E, $00, $80 ; E
	.byte $50, $01, $00, $90 ; 1
	
	.org $9200
	.byte $50, $19, $00, $68 ; P
	.byte $50, $0A, $00, $70 ; A
	.byte $50, $10, $00, $78 ; G
	.byte $50, $0E, $00, $80 ; E
	.byte $50, $02, $00, $90 ; 2
	
	.org $9300
	.byte $50, $19, $00, $68 ; P
	.byte $50, $0A, $00, $70 ; A
	.byte $50, $10, $00, $78 ; G
	.byte $50, $0E, $00, $80 ; E
	.byte $50, $03, $00, $90 ; 3
	
	.org $9400
	.byte $50, $19, $00, $68 ; P
	.byte $50, $0A, $00, $70 ; A
	.byte $50, $10, $00, $78 ; G
	.byte $50, $0E, $00, $80 ; E
	.byte $50, $04, $00, $90 ; 4
	
	.org $9500
	.byte $50, $19, $00, $68 ; P
	.byte $50, $0A, $00, $70 ; A
	.byte $50, $10, $00, $78 ; G
	.byte $50, $0E, $00, $80 ; E
	.byte $50, $05, $00, $90 ; 5
	
	.org $9600
	.byte $50, $19, $00, $68 ; P	
	.byte $50, $0A, $00, $70 ; A
	.byte $50, $10, $00, $78 ; G
	.byte $50, $0E, $00, $80 ; E
	.byte $50, $06, $00, $90 ; 6
	
	.org $9700
	.byte $50, $19, $00, $68 ; P	
	.byte $50, $0A, $00, $70 ; A
	.byte $50, $10, $00, $78 ; G
	.byte $50, $0E, $00, $80 ; E
	.byte $50, $07, $00, $90 ; 7
                             ; Undeclared bytes are assembled into $FF's with the nesasm compiler.


;;;;;;;
	.bank 1
	.org $BFFA	; Interrupt vectors go here:
	.word $0000 ; NMI
	.word RESET ; Reset
	.word $0000 ; IRQ

	;;;; NESASM COMPILER STUFF, ADDING THE PATTERN DATA ;;;;

	.incchr "Font.pcx"
	.incchr "Bytes.pcx"