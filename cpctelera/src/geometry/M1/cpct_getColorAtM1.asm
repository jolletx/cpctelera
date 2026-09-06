;;-----------------------------LICENSE NOTICE------------------------------------
;;  This file is part of CPCtelera: An Amstrad CPC Game Engine 
;;  Copyright (C) 2026 Xavier Jollet (@SagaDS)
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

;;          HL = Screen start Adress
;;          DE = X
;;          C  = Y

.globl cpct_getScreenPtr_asm

;; Prepare input of fast entry based on adress and subpixel

    ld  a,e     ;; a = low X
    and #0x03	;; Keep only the 2 least significant bits of X0 : subPixel

    push af     ;; save subpixel

    srl d       ;; d can only be 1 or 0 (319 is < 512), so one shift right to carry is enough
    rr  e       ;; rotate e once with carry from d
    srl e       ;; Now e is the byte offset in the line (0-79)

    ld  b, c     ;; b = Y
    ld  c, e     ;; c = X in bytes

    ex  de,hl    ;; de = SCREEN_ADRESS

    call cpct_getScreenPtr_asm    ;; HL = Current adress

    pop af      ;; retrieve subpixel in a

;; Ready for special entry
;;     HL = Adress of octet to test
;;     A  = SubPixel to test in octet (0..3)
;;

    ld  c,(hl)          ;; Get screen octet

    or  a               ;;; Check if subpixel is 0, if so start the check
    jr  z,computeColor  ;; if last, jump

    ld  b,a             ;; for loop
subpixel_loop:
    sla c               ;; shift screen octet to the left
    djnz subpixel_loop  ;; until last subpixel on left
computeColor:
    ld  a,c             ;; let's decode screen value
    and #0x88           ;; and 0b10001000 to mask left subpixel

    ld  l,#0            ;; Future color
    rla                 ;; Get Low bit of color from bit 7 in carry 
                        ;; (after the AND #88 Carry=0 so bit 0 = 0)
    rl  l               ;; Set bit 0 of l using carry (carry = 0 after)
                        ;; l = low bit of color
;; Check high bit of color
    rla                 ;; a = 0x04 or 0 
    rla                 ;; a = 0x02 or 0
    or l                ;; put back low bit on a

end_getColorAt:         ;; a = output color
    ret
