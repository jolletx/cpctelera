;;-----------------------------LICENSE NOTICE------------------------------------
;;  This file is part of CPCtelera: An Amstrad CPC Game Engine 
;;  Copyright (C) 2026 Arnaud Bouche (@Arnaud6128)
;;  Copyright (C) 2026 ronaldo / Fremos / Cheesetea / ByteRealms (@FranGallegoBR)
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

;; .globl cpct_plotColorTable_M1
;; .globl cpct_plotMasksTable_M1
.globl cpct_getScreenPtr_asm
.globl cpct_subPixelHorizontalMask_M1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Function: cpct_geometryLineM1
;;
;;    Draws an arbitrary straight line between two points (X0, Y0) and (X1, Y1)
;;    in Mode 1 (320x200, 4 colors) using Bresenham's line algorithm.
;;
;; Required memory:
;;    TODO bytes (TODO bytes core routine + TODO bytes binding wrapper)
;;
;; Time Measures (Includes TODO us / TODO cycles binding wrapper overhead):
;;    Horizontal    (0,0)   to (100,0)         | 101    | 11250          | 45000
;; (end code)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; parameters
;;      (2B HL) = VMEM start adress
;;      (2B DE) = X0
;;      (2B BC) = X1
;;      (2B IX) = ixh INK Color  / ixl = Y
;; Destroyed Register values:
;;      AF, BC, DE, HL, IX
;;
;;
;; Timing of draw preparation
;;     xxx Microseonds   53 Bytes
;; 
;; exchange X0 / X1 if needed to draw from left to right
    ld  a,b                 ;; a = X1 high
    cp  d                   ;; compare with X0 high
    jr  c,exchangeX		    ;; d>b   ==> exchange
    jr  nz,decodeAdresses	;; d!=b  ==> d<b
    ld  a,c				    ;; here d=b   ==> a = x1 low
    cp  e                   ;; compare with X0 low
    jr  nc,decodeAdresses	;; e<=c so de<bc
;; exchange de and bc / X0 and X1
exchangeX:   ;; Note: Is push push pop pop better?         
   	ld  a,e
	ld  e,c
	ld  c,a
	ld  a,d
	ld  d,b
	ld  b,a  

decodeAdresses:
    ;; Compute subPixels and line octet (left and right)
    ld  a,e                 ;; a= low X0
    and #0x03	            ;; Keep only the 2 least significant bits of X0 : subPixel

    sra d                   ;; d can only be 1 or 0 (319 is < 512), so one shift right to carry is enough
    rr  e                   ;; rotate e once with carry from d
    srl e                   ;; Now e is the left byte offset in the line (0-39)

    ld  d,a                 ;; Store left sub pixel in d for the moment

    ld  a,c                 ;; a= low X1
    and #0x03	            ;; Keep only the 2 least significant bits of X1 : subPixel

    sra b                   ;; b can only be 1 or 0 (319 is < 512), so one shift right to carry is enough
    rr  c                   ;; rotate c once with carry from b
    srl c                   ;; Now c is the Right byte offset in the line (0-39)

    ld  b,a                 ;; Store Rigth sub pixel in b for the moment

    ;; Compute left adress in HL
    push bc                 ;; save Right info
    push de                 ;; save Left info

    ld__b_ixl               ;; b = Y
    ld  c,e                 ;; c = left octet

    ex  de,hl               ;; de = SCREEN ADRESS

    call cpct_getScreenPtr_asm    ;; HL = Left Adress

    pop de                  ;; d = Left subpixel  / e = left octect
    pop bc                  ;; b = right subpixel / c = right octet
                            ;; HL = Left Adress 

    ;; Compute nbOctet to print
    ld  a,c                 ;; a = right octet
    sub e                   ;; a = right octet - left octet = nbOctet 
    ld  e,a                 ;; e = nbOctet

    ;; Rearrange registers so B= LeftSubpixel and C = RightSubPixel
    ld  a,b                 ;; a = right subpixel
    ld  b,d                 ;; b = left subPixel
    ld  c,a                 ;; c = right subpixel

    ld__a_ixh               ;; Put INK Color in a

    ;; We are ready for fast entry
    ;; Ok let's start drawing the line now, we have all the information we need
    ;; Here HL = Left pixel adress
    ;;      B  = left subpixel
    ;;      C  = right subpixel
    ;;      E  = Nb OCtet difference between right and left (positif) so from 0 to 79
    ;;      A  = INK Color

    ;;  Computing full 4 pixels with INK inside d
    ld  d,#0                    ;; d will contain the full octet color to use
    rra                         ;; Put bit0 of INK in Carry
    jr  nc,testHightBitColor
    ld  d,#0xF0                 ;; d = full pixel of INK 1
testHightBitColor:    
    rra                         ;; put bit 1 of INK in carry
    jr  nc,noHightBitColor
    ld  a,#0x0F                 ;; a = full pixel of INK 2  
    or  d                       ;; merge on d
    ld  d,a                      
noHightBitColor:
                                ;; d = full pixel octet color of ink

    ld  a,e                     ;; a = nbOctet
    or  a                       ;; check if nbOct == 0 ==> B and C on same octet
    jr  nz,notSameOctet         ;; Ok, let's do the full process

    ; Specific case : Draw from B to C subPixels inside same octet
    push hl                     ;; Keep adress

    ld  a,b                     ;; a = left subpixel
    rlca                        ;; multiply by 4
    rlca                        ;;  "
    add c                       ;; a = b*4+c : index in mask table
 
    ld  hl, #cpct_subPixelHorizontalMask_M1  ;; mask table
    ld  b,#0     
    ld  c,a                     ;; bc = index in table
    add hl,bc                   ;; hl = adress of mask to use
    ld  a,(hl)                  ;; a = mask to use for reset pixels with new color

    pop hl                      ;; Restore adress

    ld  e,a                     ;; save mask
    and (hl)                    ;; a = current screen pixels with clear pixels from mask 

    ld  b,a                     ;; b = current screen octet (cleared)
    ld  a,e                     ;; retrieve mask
    cpl                         ;; invert mask
    and d                       ;; set requested color to inverted pixels

    or  b                       ;; merge result with current screen octet
    ld  d,a                     ;; use d as new color for next instruction to run

    jp  drawLastOctet           ;; Move to last draw

notSameOctet:
    ; deal with starting subpixel
    ld  a,b                 ;; a = left subpixel
    or  a                   ;; if 0 we can do full pixels, if not we need to mask and move forward 1
    jr  z,drawFullOctets    ;; We can draw octets from there, but we will need to check last octet

    ; Deal from b subpixel to 3 on actual adress, a = left subpixel
    rlca                    ;; multiply by 4
    rlca                    ;;  "

    push hl                 ;; Save Adress
    push de                 ;; Save d = color and e = nbOctet

    ld  hl, #cpct_subPixelHorizontalMask_M1 + 3  ;; mask table with right subPixel = 3
    ld  d,#0                ;;     
    ld  e,a                 ;; de = index in table
    add hl,de               ;; hl = adress of mask to use
    ld  a,(hl)              ;; a = mask to use for reset pixels with new color

    ld  d,a                 ;; save mask
    and (hl)                ;; a = current screen pixels with clear pixels from mask 

    ld  b,a                 ;; b = current screen octet (cleared)
    ld  a,d                 ;; retrieve mask
    cpl                     ;; invert mask

    pop de                  ;; Restore color and nbOctet
    pop hl                  ;; Restore adress

    and d                   ;; set requested color to inverted pixels
    or  b                   ;; merge result with current screen octet

    ld  (hl),a              ;; Set screen octet with preserved pixels around b and c

    inc hl                  ;; We have finished this first octet, increase adress
    dec e                   ;; and decrease nbOctet

drawFullOctets:
    ;; We will now draw needed octets with full octets 
    ;; based on e = nbOctet using a jump table
    ;; e can be 0 so in this case we will jump over everything
    ld  a,#79               ;; a = max jump
    sub e                   ;; a = 79 - nbOctect (so from 0 max lines to 79)
                            ;; jr 0 will use full table
    rla                     ;; a = a * 2 because ld (hl),d inc hl
    ld  (#drawJrOffset),a   ;; SMC to use the correct amount of ld (hl),d inc hl
drawJrOffset=. + 1
    jr  #0          ;; SMC to jump over necessary code - Max code is 79 * 2 so JR works
.rept 79
    ld  (hl),d      ;; Set screen octet with full color
    inc hl          ;; Increase adress
.endm


onLeftSubpixel:
    ; We are on the last octet, deal with C subPixels from left on last adress
    ld  a,c             ;; a = right subpixel    
    cp  #3              ;; if 3 we can do full byte, if not we need to mask
    jr  z,drawLastOctet ;; go for it

    push hl             ;; Save Adress
    ld  hl, #cpct_subPixelHorizontalMask_M1 + 3  ;; mask table with right subPixel = 3
    ld  b,#0     
    ld  c,a             ;; bc = index in table
    add hl,bc           ;; hl = adress of mask to use
    ld  a,(hl)          ;; a = mask to use for reset pixels with new color

    pop hl              ;; Restore adress

    ld  e,a             ;; save mask
    and (hl)            ;; a = current screen pixels with clear pixels from mask 

    ld  b,a             ;; b = current screen octet (cleared)
    ld  a,e             ;; retrieve mask
    cpl                 ;; invert mask
    and d               ;; set requested color to inverted pixels

    or  b               ;; merge result with current screen octet
    ld  d,a             ;; use d as new color for next instruction to run 

drawLastOctet:      
    ld  (hl),d          ;; Computed color in last byte

endDraw:
    ret
