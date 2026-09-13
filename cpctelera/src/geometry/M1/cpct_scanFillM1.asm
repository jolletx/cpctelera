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
.globl cpct_getScreenPtr_asm


STACK_SIZE = 30
;;-------------------------------------------------------------------------------
;; DATA SECTION
;;-------------------------------------------------------------------------------
.area _DATA
right_adress:   .dw 0          ;; Screen Adress of right pixel on line
right_subpixel: .db 0          ;; Sub Pixel offset of right pixel on line
new_color:      .ds 4          ;; new color values for sub pixel 0..3
new_color_full: .db 0          ;; new color full octet for quick checks of octet
old_color:      .ds 4          ;; old color values for sub pixel 0..3
old_color_full: .db 0          ;; old color full octet for quick fill of octet
stack_idx:      .db 0          ;; Stack index
stack_adress:   .dw pt_stack   ;; Last Stack Adress
pt_stack:                      ;; Stack of points found
            .rept STACK_SIZE   ;; Prepare a fixed size stack of points 
                .ds 2          ;; Screen Adress
                .db 0          ;; Sub pixel offset
            .endm

;;-------------------------------------------------------------------------------
;; CODE SECTION
;;-------------------------------------------------------------------------------
.area _CODE

   ;  HL = VMEM start ptr
   ;  DE = X
   ;  C  = Y
   ;  B  = New Color
   push  ix                   ;; Preserve ix for several needs

   ;; Compute new color values for sub pixel 0..3
   ;; compute sub pixel 0
   xor   a                    ;; A = 0
   rr    b                    ;; B = New Color >> 1 , Carry = low bit of New Color
   rra                        ;; Bit 7 of A = Low bit of New_color
   sla   b                    ;; B = High bit of new color in bit 1
   sla   b                    ;; B = High bit of new color in bit 2
   sla   b                    ;; B = High bit of new color in bit 3
   or    b                    ;; A = New Color for sub pixel 0   
   
   push  hl                   ;; Save HL = Screen Adress
   ld    hl,#new_color        ;; HL = new_color table / A = new color for sub pixel 0
   call  storeColor           ;; Store old color values for sub pixel 0..3 and a = full octet
   pop   hl                   ;; Restore HL = Screen Adress

   ;; Compute Screen adress and sub pixel offset from X,Y
   ld    a,e                   ;; A = low byte X
   and   #3                    ;; A = Sub Pixel offset
   push  af  
   srl   d                      ;; d can only be 1 or 0 (319 is < 512), so one shift right to carry is enough
   rr    e                      ;; rotate e once with carry from d
   srl   e                      ;; Now e is the byte offset in the line (0-79)   
   ld    b, c                   ;; b = Y
   ld    c, e                   ;; c = X in bytes
   ex    de,hl                  ;; de = VMEM_START_ADRESS
   call  cpct_getScreenPtr_asm  ;; HL = Current adress
   pop   af                     ;; retrieve subpixel in a
   ld    d,a                    ;; D = Sub Pixel offset

   ;; Get old color from adress HL and sub pixel offset D
   ld   (l_tableOffset),a ;; SMC: Change IX indexation with sub pixel offset
   ld    ix,#cpct_plotColorTable_M1+12 ; Point to pixel table
l_tableOffset=.+2
   ld    a,(ix+#0)              ;; get mask for the pixel
   and  (hl)                    ;; get the masked pixel value
   ld    b,d                    ;; b = sub pixel offset
   inc   b                      ;; b = subPixel offset + 1 (1..4)   
   rrca                         ;; Rotate right for djnz
loop_getOldColor:
   rlca                       ;; Rotate until a = subpixel 0 of old color   
   djnz  loop_getOldColor

   push  hl                   ;; Save HL = Screen Adress
   ld    hl,#old_color        ;; HL = old_color table / A = old color for sub pixel 0
   call  storeColor           ;; Store old color values for sub pixel 0..3 and a = full octet
   ld    hl,#new_color_full   ;; HL = new_color_full table
   cp    (hl)                 ;; Check if old_color == new_color
   pop   hl                   ;; Restore HL = Screen Adress
   jp    z,endScanFill        ;; If equal, end : nothing to replace

initALgo:
   call  pushPoint            ;; Push current point HL,D into stack
   ;; Init Stack
   xor   a                    ;; A = 0
   ld    (stack_idx),a        ;; Stack index = 0
   ld    a,<#pt_stack         ;; A = low byte of Stack Adress
   ld    (stack_adress),a     ;; Init low Stack Adress
   ld    a,>#pt_stack         ;; A = high byte of Stack Adress
   ld    (stack_adress+1),a   ;; Init high Stack Adress   


mainLoop:
   call  popPoint                  ;; Pop next point from stack into HL,D
   jp    z,endScanFill           ;; If stack is empty, return

   ld    a,d
   ld    (right_subpixel),a         ;; Save sub pixel offset of right pixel on line
   ld    (right_adress),hl         ;; Save screen adress of right pixel on line

drawLeft:




endScanFill:
   pop   ix                   ;; Restore ix
   ret

storeColor:                   ;; Store color subpixels into HL - a = color of subpixel 
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

checkNewColor:                ;; Returns Z if color of the pixel at (HL),A is a new_color
   ld    (n_tableOffset),a         ;; SMC: Change IX indexation
   ld    (n_colorAdressOffset),a   ;; SMC: Change IX indexation
   ld    ix,#cpct_plotColorTable_M1+12 ; Point to pixel table
n_tableOffset=.+2
   ld    a,(ix+#0)            ;; get mask for the pixel
   and   (hl)                 ;; get the masked pixel value
   ld    ix,#old_color        ;; Points to either old or new color table
n_colorAdressOffset=.+2
   xor   (ix+#0)              ;; a = actual pixel xor old or new color pixel 
   ret                        ;; Z Flag is true if color found

checkOldColor:                   ;; Returns Z if color of the pixel at (HL),A is an old_color
   ld    (o_tableOffset),a         ;; SMC: Change IX indexation
   ld    (o_colorAdressOffset),a   ;; SMC: Change IX indexation
   ld    ix,#cpct_plotColorTable_M1+12 ; Point to pixel table
o_tableOffset=.+2
   ld    a,(ix+#0)            ;; get mask for the pixel
   and   (hl)                 ;; get the masked pixel value
   ld    ix,#old_color        ;; Points to either old or new color table
o_colorAdressOffset=.+2
   xor   (ix+#0)              ;; a = actual pixel xor old or new color pixel 
   ret                        ;; Z Flag is true if color found

pushPoint:                    ;; Push point HL,D into stack - FZ not set
   ld    a,(stack_idx)        ;; Get current stack index
   cp    #STACK_SIZE          ;; Check if stack is full
   ret   z                    ;; Return if full

   ld    a,d                  ;; A = Sub Pixel offset
   ex    de,hl                ;; DE = Screen Adress

   ld    hl,(stack_adress)    ;; HL = Stack Adress
   ld    (hl),e               ;; Save Screen Adress Low byte
   inc   hl                   ;; Move down   
   ld    (hl),d               ;; Save Screen Adress High byte
   inc   hl                   ;; Move down   
   ld    (hl),a               ;; Save Sub Pixel offset
   inc   hl                   ;; Move down   
	ld    (stack_adress),hl    ;; Save new stack address
   ld    hl,#stack_idx        ;; Get stack index adress
   inc   (hl)                 ;; Increase stack index
   ex    de,hl                ;; HL = Screen Adress
   ld    d,a                  ;; D = Sub Pixel offset

   ret                        ;; Going back

popPoint:                     ;; Pop point into HL and D from stack - FC not set 
   ld    a,(stack_idx)        ;; Get current stack index
   or    a                    ;; Check if stack is empty
   ret   z                    ;; If not empty, continue

	ld    hl,(stack_adress)    ;; Points to last 
   dec   hl                   ;; Move up
   ld    a,(hl)               ;; Get sub pixel offset
   dec   hl                   ;; Move up
   ld    d,(hl)               ;; Get screen address High byte
   dec   hl                   ;; Move up   
   ld    e,(hl)               ;; Get screen address Low byte
	ld    (stack_adress),hl    ;; Save new stack address
   ld    hl,#stack_idx        ;; Get stack index adress
   dec   (hl)                 ;; Decrease stack index
   ex    de,hl                ;; HL = Screen Adress
   ld    d,a                  ;; D = Sub Pixel offset

   ret