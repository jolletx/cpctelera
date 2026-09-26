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

.globl cpct_getScreenPtr_asm

;;          HL = Screen start Adress
;;          DE = X
;;          C  = Y

    ld      a,e                     ;; [1] a = low X
    and     #0x03                   ;; [2] Keep only the 2 least significant bits of X0 : subPixel

    push    af                      ;; [4] save subpixel
    srl     d                       ;; [2] d can only be 1 or 0 (319 is < 512), so one shift right to carry is enough
    rr      e                       ;; [2] rotate e once with carry from d
    srl     e                       ;; [2] Now e is the byte offset in the line (0-79)
    ld      b, c                    ;; [1] b = Y
    ld      c, e                    ;; [1] c = X in bytes
    ex      de,hl                   ;; [1] de = SCREEN_ADRESS
    call    cpct_getScreenPtr_asm   ;; [5] HL = Current adress
    pop     af                      ;; [3] retrieve subpixel in a

    ld      c,(hl)                  ;; [2] Get screen octet
    or      a                       ;; [2] Check if subpixel is 0, if so start the check
    jr      z,computeColor          ;; [3-2] if last, jump

    ld      b,a                     ;; [1] for loop
subpixel_loop:
    sla     c                       ;; [2] shift screen octet to the left
    djnz    subpixel_loop           ;; [3-2] until last subpixel on left
computeColor:
    ld      a,c                     ;; [1] let's decode screen value
    and     #0x88                   ;; [2] and 0b10001000 to mask subpixel 0

    ld      l,#0                    ;; [2] Future color
    rla                             ;; [1] Get Low bit of color from bit 7 in carry - a = 000x0000 (x is the high bit of subpixel)
                                    ;; (after the AND #88 Carry=0 so bit 0 = 0)
    rl      l                       ;; [2] Set bit 0 of l using carry (carry = 0 after)
                                    ;; l = low bit of color (0 or 1, don't care)
;; Check high bit of color
    or      a                       ;; [2] if a != 0 add 2 to current color
    ld      a,l                     ;; [1] a = 0 or a=1
    jr      z,end_getColorAt        ;; [3-2] Jump over increase if no high bit found with 'or a'
    inc     a                       ;; [1] a += 2 to set high bit of INK
    inc     a                       ;; [1]
end_getColorAt:                     ;; a = output color
    ret                             ;; [2] returns
