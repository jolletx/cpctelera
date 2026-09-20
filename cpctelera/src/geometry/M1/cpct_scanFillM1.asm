;;-----------------------------LICENSE NOTICE------------------------------------
;;  This file is part of CPCtelera: An Amstrad CPC Game Engine 
;;  Copyright (C) 2026 Xavier Jollet (@SagaDS)
;;  Copyright (C) 2015 ronaldo / Fremos / Cheesetea / ByteRealms (@FranGallegoBR)
;;
;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU Lesser General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.
;;
;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU Lesser General Public License for more details.
;;
;;  You should have received a copy of the GNU Lesser General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;-------------------------------------------------------------------------------

;; Algorythm: Scanline Fill
;; Starting from a point, it will fill the area with the color specified in B register.
;; It will stop when it finds a pixel with a different color than the one specified in B

;; COMMENTS
;; Init algo: Get current color under X,Y and push X,Y into stack
;; Main loop entry - Exit IF Stack is empty else Pop next X,Y
;;     Loop to find X left value of line to draw
;;     Init SubLoop, Keep left X value and init flags found 
;;     above or below (FU/FB), FL used to draw a line 
;;     (more than one pixel)
;;          SubLoop Entry point - exit SubLoop if end of line
;;          Get Above DY=1 and Below DY=-1 pixel if possible,
;;          default NewColor so tests on oldcolor will failed
;;          Deal with Above then Below lines to see if a new 
;;          pixel should be pushed (minimizing the number of 
;;          push with FU/FB)
;;          Next pixel for SubLoop


.globl cpct_plotColorTable_M1
.globl cpct_plotMasksTable_M1
.globl cpct_getScreenPtr_asm

;; Special values 
STACK_SIZE = 30               ;; Max number of elements in points stack
maxX       = 79               ;; X byte limit
maxY       = 199              ;; Y limit

;;-------------------------------------------------------------------------------
;; DATA SECTION
;;-------------------------------------------------------------------------------
.area _DATA
screen_start:    .dw 0          ;; Screen start from inputs

;; Keep cur values ordered like this for easy incremental access
cur_byte_offset: .db 0          ;; Current byte offset
cur_subpixel:    .db 0          ;; Current subpixel
cur_y_val:       .db 0          ;; Current y coordinate
cur_adress:      .dw 0          ;; Current screen adress

left_byte_offset:.db 0          ;; Left byte offset
left_subpixel:   .db 0          ;; Left subpixel
left_adress:     .dw 0          ;; Left screen adress

; Flags
searchFlag:      .db 0          ;; Flag to check if looking for old color or not
; Color buffers
new_color:       .ds 4          ;; new color values for sub pixel 0..3
new_color_full:  .db 0          ;; new color full octet for quick checks of octet
old_color:       .ds 4          ;; old color values for sub pixel 0..3
old_color_full:  .db 0          ;; old color full octet for quick fill of octet
; Stack
stack_idx:       .db 0          ;; Stack index
stack_adress:    .dw pt_stack   ;; Current Stack Adress to use
pt_stack:                       ;; Stack of points to fill horizontaly
            .rept STACK_SIZE    ;; Allocate a fixed size stack of points 
                .db 0           ;; X Octet from left (0..79)
                .db 0           ;; Sub pixel offset  (0..3)
                .db 0           ;; Y coordinates from top (0..199)
            .endm

;;-------------------------------------------------------------------------------
;; CODE SECTION
;;-------------------------------------------------------------------------------
.area _CODE

   ;  HL = VMEM start ptr
   ;  DE = X
   ;  C  = Y
   ;  B  = New Color

   ld    (screen_start),hl    ;; Store VMem start
   ld    a,c                  ;; A = Y coord
   ld    (cur_y_val),a        ;; Store Y value

   ;; Compute new color values for sub pixel 0..3
   ;; compute sub pixel 0
   xor   a                    ;; A = 0
   rr    b                    ;; B = New Color >> 1 , Carry = low bit of New Color
   rra                        ;; Bit 7 of A = Low bit of New_color
   sla   b                    ;; B = High bit of new color in bit 1
   sla   b                    ;; B = High bit of new color in bit 2
   sla   b                    ;; B = High bit of new color in bit 3
   or    b                    ;; A = New Color for sub pixel 0   
   ld    hl,#new_color        ;; HL = new_color table / A = new color for sub pixel 0
   call  storeColor           ;; Store old color values for sub pixel 0..3 and a = full octet

   ;; Compute Screen adress and sub pixel offset from X,Y
   ld    a,e                   ;; A = low byte X
   and   #3                    ;; A = Sub Pixel offset
   ld    (cur_subpixel),a      ;; Store current subpixel
   srl   d                      ;; d can only be 1 or 0 (319 is < 512), so one shift right to carry is enough
   rr    e                      ;; rotate e once with carry from d
   srl   e                      ;; Now e is the byte offset in the line (0-79)   
   ld    a,e                     
   ld    (cur_byte_offset),a    ;; Store current byte offset
   ld    b, c                   ;; b = Y
   ld    c, e                   ;; c = X in bytes
   ld    de,(screen_start)      ;; de = VMEM_START_ADRESS
   call  cpct_getScreenPtr_asm  ;; HL = Current adress

   ;; Get old color from adress HL and sub pixel offset
   ld    a,(cur_subpixel)       ;; A = Subpixel
   ld    d,a                    ;; put back subpixel in d

   ld    (l_tableOffset),a      ;; SMC: Change jmp indexation with sub pixel offset
   ld    e,(hl)                 ;; Get current screen octet
   ld    hl,#cpct_plotColorTable_M1+15 ;; Points to individual pixel table from right subpixel
l_tableOffset=.+1
   jr    #0                     ;; jumps over necessary dec to points correct hl 
   dec   hl
   dec   hl
   dec   hl

   ld    a,(hl)                 ;; get mask for the pixel
   and   e                      ;; masked pixel of screen octet
   ld    b,d                    ;; b = sub pixel offset
   inc   b                      ;; b = subPixel offset + 1 (1..4)   
   rrca                         ;; Rotate right for first djnz
loop_getOldColor:
   rlca                         ;; Rotate until a = subpixel 0 of old color   
   djnz  loop_getOldColor

   ld    hl,#old_color        ;; HL = old_color table  / A = old color for sub pixel 0
   call  storeColor           ;; Store old color values and a = full octet old color
   ld    hl,#new_color_full   ;; 
   cp    (hl)                 ;; Check if old_color == new_color
   ret   z                    ;; If equal old_color==new_color, end : nothing to replace
initALgo:
   ;; Init Stack
   xor   a                    ;; A = 0
   ld    (stack_idx),a        ;; Stack index = 0
   ld    a,<#pt_stack         ;; A = low byte of Stack Adress
   ld    (stack_adress),a     ;; Init low Stack Adress
   ld    a,>#pt_stack         ;; A = high byte of Stack Adress
   ld    (stack_adress+1),a   ;; Init high Stack Adress

   ld    de,(cur_byte_offset) ;; Retrieve current values for init
   ld    a,(cur_y_val)        ;; Retrieve Y value
   ld    c,a                  ;; c = y val

   call  pushPoint            ;; Push current point DE, C into stack

   ;; During loop, D = subpixel, E = X-octet, C = Y, HL = compute adress based on E/C 
mainLoop::
   call  popPoint             ;; Pop next point from stack into DE, C
   ret    z                   ;; If stack is empty, algo is finished

   call  computeAdress        ;; Retrieve HL adress based on E,C (untouched)
   ld    a,c                  ;; a = y value
   ld    (cur_adress),hl      ;; Save cur adress
   ld    (cur_byte_offset),de ;; and byte offset / subpixel
   ld    (cur_y_val),a        ;; and Y value

	ld    a,(new_color_full)  	  ;; A = new_color full 
   ld    b,a                    ;; b = full octet new color

   call  searchAndDrawLeft      ;; Find first left pixel which is not an old color

   ld    (left_adress),hl       ;; Store last old color left adress
   ld    (left_byte_offset),de  ;; Store last old color Left byte and subpixel

   ld    hl, (cur_adress)       ;; Retrieve starting values
   ld    de, (cur_byte_offset)  ;;      "       "      "
   call  searchAndDrawRight     ;; Find first right pixel which is not an old color

   ld    (cur_adress),hl        ;; Store last right adress for above and below boundaries checks
   ld    (cur_byte_offset),de   ;; Store last right byte and subpixel
secondaryLoop::                  ;; Check lines above and below for new points

   ld    hl, (left_adress)      ;; Retrieve left values
   ld    de, (left_byte_offset) ;; 

   ;; Move along upper line to check if new points should be stacked
   call  changeYUp              ;; Compute a new HL and C, z if top of screen reached
   jr    z,checkBelow           ;; Cannot move up, check other line
   call  searchNewPoints        ;; Push new points inside stack if old_color found above drawn line 
checkBelow::
   ld    hl, (left_adress)      ;; Retrieve left values
   ld    de, (left_byte_offset) ;;
   call  changeYDown            ;; Compute a new HL and C
   call  changeYDown            ;; Compute a new HL and C, z if top of screen reached
   jr    z,continue             ;; Cannot move up, check other line
   call  searchNewPoints        ;; Push new points inside stack if old_color found above drawn line 

continue:
   jr    mainLoop                ;; Check new point in stack

searchAndDrawLeft::                 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Move HL / DE / B until a pixel which is not old_color or left of screen
;; First pixel is set here
sdl_loopSubpixel:
   call  plotPixel             ;; set new color of d subpixel at HL, first pixel is drawn here
   call  decreaseSubpixel
   ret   z                     ;; if ZFLag, we have reach left line boundary

   ld    a,d                   ;; a = subpixel
   cp    #0x03                 ;; check if right subpixel (so we reached a new octet)
   jr    nz, sdl_checkSubpixel ;; No ?  Let's check individual subpixel

   ld    a,(new_color_full)    ;; a = new color full octet
   ld    b,a                   ;; c = new color full octet
   ld    a,(old_color_full)    ;; a = old color full octet
sdl_loopFullOctet:
   cp    (hl)                  ;; check with screen octet
   jr    nz,sdl_checkSubpixel  ;; if not full octet let's do it one subpixel by one subpixel
   ld    (hl),b                ;; Set full octet to new color
   dec   hl                    ;; decrease adress
   dec   e                     ;; decrease X OCtet
   jp    p, sdl_loopFullOctet  ;; if positif or 0 loop
   ld    d,#0                  ;; d = left subpixel 
   inc   hl                    ;; move back to last adress
   inc   e                     ;; set e = 0, so ZFlag is set
   ret                         ;; ret with ZFlag set
sdl_checkSubpixel::
   call  checkOldColor         ;; is subpixel of old color
   jr    z,sdl_loopSubpixel    ;; if old color draw it and continue

   call  increaseSubpixel      ;; if not, last subpixel was the last one
   ret                         ;; return

searchAndDrawRight::            ;; Move HL / DE until a pixel which is not old_color or Right of screen - b = full octet new_color
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Move and draw HL / DE  until a pixel which is not old_color or right of screen
;; First pixel is skipped here (because leftDraw has already done it)
sdr_loopSubpixel:
   call  increaseSubpixel
   ret   z                     ;; if ZFLag, we have reach left line boundary

   ld    a,d                   ;; a = subpixel
   or    a                     ;; check if left subpixel (so we reached a new octet)
   jr    nz, sdr_checkSubpixel ;; No ?  Let's print it and move to another one

   ld    a,(new_color_full)    ;; a = new color full octet
   ld    b,a                   ;; c = new color full octet
sdr_loopFullOctet:
   ld    a,(old_color_full)    ;; a = old color full octet
   cp    (hl)                  ;; check with screen octet
   jr    nz,sdr_checkSubpixel  ;; if not full octet let's do it one subpixel by one subpixel
   ld    (hl),b                ;; Set full octet to new color
   ld    a,e                   ;; a = X OCtet
   cp    #maxX                 ;; Compare with maxX (79)
   jr    z,sdr_lastOctet       ;; we reached end of line
   inc   hl                    ;; if not move to next adress
   inc   e                     ;; e = X + 1
   jp    sdr_loopFullOctet     ;; loop
sdr_lastOctet::
   ld    d,#0x03               ;; set subpixel to right one
   ret                         ;; ZFlag is still set here
sdr_checkSubpixel::
   call  checkOldColor         ;; is subpixel of old color
   jr    nz,sdr_lastSubpixel   ;; if old color draw it and continue
   call  plotPixel             ;; chenge color of subpixel
   jr    sdr_loopSubpixel      ;; continue
sdr_lastSubpixel::
   call  decreaseSubpixel      ;; if not, last subpixel was the last one
	ret                         ;; return



searchNewPoints::
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; check and push points which are old_color (wait for end of old_color to add another one found)
;; and move to the right until end of previously draw Line 
   ;; Init
   xor   a                      ;; a = 0
   ld    (searchFlag),a         ;; reset search flag insertion

   ;; Alternate between searching old_color and jumping above old_color on current line
   ;; Stops when end of right drawn line reached
snp_mainLoop::
   ld    a,(searchFlag)
   or    a
   jr    nz,snp_searchOldColorEnd

;; searchOldColor
   call  checkOldColor           ;; Do we have an old_color here?
   jr    nz,snp_nextSearchSP     ;; no, move to next subpixel or end of line
   
   call  pushPoint               ;; We have a hit, push it and switch flag 
   or    a,#0x01                ;; set a = jr z, opcode
   ld    (searchFlag),a         ;; SMC: And modify jump
   jr    snp_searchOldColorEnd

snp_searchOldColorEnd::
   call  checkOldColor
   jr    z,snp_nextSearchSP      ;; Still old color, wait for another color
   xor   a                       ;; set a = 0
   ld    (searchFlag),a          ;; Reset flag : search for old color again
   ; and continue to next
snp_nextSearchSP::
   call  increaseSubpixel         ;; move to right one subpixel
   ret   z                        ;; stop if already at end
   call  checkEndOfDrawnLine      ;; Check if end of draw line
   ret   z                        ;; stop if reached
   jr    snp_mainLoop             ;; next subpixel

checkEndOfDrawnLine::
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ld    a,(cur_byte_offset)     ;;
   cp    e                       ;;
   ret   nz                      ;; not on last octet
   ld    a,(cur_subpixel)        ;;
   cp    d                       ;; 
   ret                           ;; ret ZFlag if de == cur byte offset/ cur_subpixel
   

plotPixel::                            ;; Plot pixel D at (hl) in new_color
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   push  de                            ;; Preserve DE
   push  hl                            ;; Preserve HL = screen adress
   ld    e,d                           ;; e = subpixel
   ld    d,#0                          ;; de = subpixel offset 16 bits
   ld    hl,#cpct_plotMasksTable_M1    ;; hl = masktable
   add   hl,de                         ;; hl = masktable + subpixel offset
   ld    a,(hl)                        ;; a = subpixel mask
   ld    hl,#new_color                 ;; de = new color table
   add   hl,de                         ;; hl = new color table + subpixel offset
   ld    e,(hl)                        ;; e = new_color subpixel
   pop   hl                            ;; retrieve screen adress
   and   (hl)                          ;; a = subpixel reset of screen octet 
   or    e                             ;; a = merge reset screen octet with new_color subpixel
   ld    (hl),a                        ;; Set screen octet
   pop   de                            ;; Retrieve DE
   ret                                 ;; return
computeAdress::                ;; Compute HL = VMemStart + c mod 7 * &800 + 80 * (c % 7) + E  - From cpct_getScreenPtr_asm
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   push  bc                   ;; Preserve BC
   ld    a, c                 ;; [1] rA = Y-Coordinate
   and   #0x07                ;; [2] /
   ld    h, a                 ;; [1] \ rH = Y % 8      ;; << rH contains Line number [0-7] inside character Row
   xor   c                    ;; [1] / rA = ( rB and #0x07 ) xor rB  =  rB and #0xF8
   ld    l, a                 ;; [1] \ rL = 8*int(Y/8) ;; << L contains Screen Character Row multiplied by 8
   rrca                       ;; [1] / 
   rrca                       ;; [1] \ rA' = rA / 4 = 2*int(Y/8)
   add   a, l                 ;; [1] /
   ld    l, a                 ;; [1] \ rL = rL + rA' = 8*int(Y/8) + 2*int(Y/8) = 10*int(Y/8) 
   add   hl, hl               ;; [3] /
   add   hl, hl               ;; [3] |
   add   hl, hl               ;; [3] \ rHL' = 8*rHL = 2048*L + 80*R 
   ld    b,#0                 ;; Reset b
   ld    c,e                  ;; c = byte offset
   add   hl, bc               ;; [3] rHL' = rHL + x octet
   ld    bc,(screen_start)    ;; BC = VMEM start
   add   hl, bc               ;; [3] rHL' = rHL + screen_start
   pop   bc                   ;; retrieve BC
   ret                        ;; return

checkOldColor::               ;; Returns ZFlag ON if color of the pixel at (HL),D is an old_color
   ld    b,(hl)               ;; b = screen octet
   ld    a,(old_color_full)   ;; A = full octet old color 
   xor   b                    ;; check if A == B
   ret   z                    ;; If full octet is old_color ret ZFlag
   push  hl                   ;; save screen adress
   push  de                   ;; save de
   ld    e,d                  ;; e = subpixel
   ld    d,#0                 ;; de = subpixel 16 bit
   ld    hl,#cpct_plotColorTable_M1+12 ;; Point to pixel table
   add   hl,de                ;; hl = subpixel mask adress in pixel table
   ld    a,(hl)               ;; get mask for the subpixel
   and   b                    ;; a = get the subpixel value of screen octet
   ld    hl,#old_color        ;; hl = old color table
   add   hl,de                ;; hl = old color subpixel adress
   xor   (hl)                 ;; a = actual subpixel xor oldcolor pixel- ZFlag is set if A == (HL) 
   pop   de                   ;; retrieve de
   pop   hl                   ;; retrieve screen adress
   ret                        ;; Z Flag is true if color found in pixel
pushPoint::                    ;; Push point DE and C into stack - FZ not set : OK - FZ set : no more room
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ld    a,(stack_idx)        ;; Get current stack index
   cp    #STACK_SIZE          ;; Check if stack is full
   ret   z                    ;; Return if full

   inc   a                    ;; a = stack_idx + 1
   ld    (stack_idx),a        ;; store stack_idx

   push  hl
   ld    hl,(stack_adress)    ;; HL = Stack Adress

   ld    (hl),e               ;; Save X byte offset
   inc   hl                   ;; Move down   
   ld    (hl),d               ;; Save subpixel
   inc   hl                   ;; Move down   
   ld    (hl),c               ;; Save Y Coordinates
   inc   hl                   ;; Move down   
	ld    (stack_adress),hl    ;; Save new stack address
   pop   hl

   ret                        ;; Going back

popPoint::                     ;; Pop point into DE and C from stack - FZ not set : OK - FZ set : empty stack
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ld    a,(stack_idx)        ;; Get current stack index
   or    a                    ;; Check if stack is empty
   ret   z                    ;; If not empty, continue

   dec   a                    ;; a = stck_idx - 1
   ld    (stack_idx),a        ;; store stack_idx

	ld    hl,(stack_adress)    ;; Points to last stack adress - no need to preserve, will be recomputed
   dec   hl                   ;; Move up
   ld    c,(hl)               ;; Get Y coordinates
   dec   hl                   ;; Move up
   ld    d,(hl)               ;; Get subpixel
   dec   hl                   ;; Move up   
   ld    e,(hl)               ;; Get X byte offset
	ld    (stack_adress),hl    ;; Save new stack address
   or    #0x01                ;; reset Z flag

   ret

storeColor:                   ;; Store color subpixels into HL - a = color of subpixel 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ld    b,a                  ;; b = color for sub pixel 0
   ld   (hl),b                ;; Save color for sub pixel 0
   inc   hl                   ;; next octet
   rrc   b                    ;; Rotate B right to get color for sub pixel 1
   or    b                    ;; A = A + color for sub pixel 1      
   ld   (hl),b                ;; Save color for sub pixel 1
   inc   hl                   ;; next octet
   rrc   b                    ;; Rotate B right to get color for sub pixel 2
   or    b                    ;; A = A + color for sub pixel 2      
   ld   (hl),b                ;; Save color for sub pixel 2
   inc   hl                   ;; next octet
   rrc   b                    ;; Rotate B right to get color for sub pixel 3
   or    b                    ;; A = A + color for sub pixel 3      
   ld   (hl),b                ;; Save color for sub pixel 3
   inc   hl                   ;; next octet (Full_octet)
   ld   (hl),a                ;; Save color full octet
   ret                        ;; A contains full octet color

changeYUp::
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ld    a,c                  ;; a = c = Y value
   or    a                    ;; Check if 0
   ret   z                    ;; Top of screen reached, return ZFlag ON
   dec   c
   call  computeAdress        ;; Compute new adress
   or    #0x01                ;; make sure ZFlag is OFF because of previous call
   ret

changeYDown::
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ld    a,c                  ;; a = c = Y value
   cp    #maxY                ;; 
   ret   z                    ;; Top of screen reached, return ZFlag ON
   inc   c
   call  computeAdress        ;; Compute new adress
   or    #0x01                ;; make sure ZFlag is OFF because of previous call
   ret

decreaseSubpixel::
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ld    a,d                           ;; a = subpixel
   or    a                             ;; check a == 0
   jr    z,dsp_changeXOffset           ;; Subpixel == 0, move to previous octet
   dec   d                             ;; decrease subpixel
   or    a                             ;; To reset Z Flag if d == 0
   ret                                 ;;  return
dsp_changeXOffset:
   ld    a,e                           ;; a = X octet in line
   or    a                             ;; Check a == 0
   ret   z                             ;; Z flag is set : cannot move before sub pixel 0 of X-Offset 0
   ld    d,#0x03                       ;; d = last subpixel
   dec   hl                            ;; decrease screen adress
   dec   e                             ;; decrease X Octet
   or    a                             ;; to reset ZFlag if e = 0
   ret                                 ;; return

increaseSubpixel::
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ld    a,#0x03                       ;; a = 3
   cp    d                             ;; Compare subpixel with 3
   jr    z,isp_changeXOffset           ;; subpixel == 3, move to next octet
   inc   d                             ;; increase subpixel (ZFlag cannot be set)
   ret                                 ;; return 
isp_changeXOffset:
   ld    a,e                           ;; a = X Octet in line   
   cp    #maxX                          ;; compare with end of line
   ret   z                             ;; Z flag is set : cannot move after sub pixel 3 of X-Offset maxX
   ld    d,#0x00                       ;; d = left subpixel
   inc   hl                            ;; increase screen adress
   inc   e                             ;; increase X (ZFlag cannot be set)
   ret                                 ;; return
