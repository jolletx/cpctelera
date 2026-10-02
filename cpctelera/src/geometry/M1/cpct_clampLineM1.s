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

.module cpct_geometry

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; u8 cpct_clampingLineM1 (i16 ioPt1[2],i16 ioPt2[2])
;; This function will clamp the line defined by ioPt1 and ioPt2 to the screen boundaries
;; It will modify the points to be inside the screen boundaries if they are outside
;; It will return 0 if the result line is inside the screen boundaries, 
;;                1 if the line is outside the screen boundaries and should not be drawn
;; cpct_clampingLine_ams
;;    input HL adress of pt1
;;          DE adress of pt2
;;    output A=0 if line is inside screen boundaries
;;           A=1 if line is outside screen boundaries and should not be drawn
;;    modifies AF, BC, DE, HL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.globl      ___mulsint2slong     ;; sdcc 16bit multiplication to 32bit DEHL = HL * DE
.globl      __divslong           ;; sdcc 32 bit division to 16 DE = DEHL / stacked 16 bits

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.include \../cpct_geomConstants.h.s\

.area _DATA
pt1Adress:         .dw   0        ;; Adress of pt1 
pt2Adress :        .dw   0        ;; Adress of pt2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.area _CODE
_cpct_clampLineM1::
cpct_clampLineM1_asm::
   push  ix                      ;; [5] store ix (ix used as pt1 access)
   push  iy                      ;; [5] store iy (iy used as pt2 access)

   ld    (pt1Adress),hl          ;; [5] Store pt1 adress
   ld    (pt2Adress),de          ;; [6] Store pt2 and set hl = pt2

   ld    ix,(pt1Adress)          ;; [6] Keep pt1 adress in IX
   ld    iy,(pt2Adress)          ;; [6] Keep pt2 adress in IY

   ;; Clamping on XMin from iPt1 to iPt2
   ;; Check if pt2.X >= XMin 
   ex    de,hl                   ;; [1] exchange pt1 and pt2 , hl =pt2
   call  checkXMin               ;; [5] Check if pt2.X < XMin
   ld    hl,(pt1Adress)          ;; [5] hl = pt1 for next test
   jr    z,pt2GEXMin             ;; [2/3] if ZF, pt2.x >= XMin

   call  checkXMin               ;; [5] pt1.X > XMin ?
   jp    nz,noDrawLine           ;; [3] Both pt1 and pt2 are outside of screen : no draw and exit
   ;; pt1 is inside but not pt2 - Need to project pt1-pt2 on X=0 and modify pt2
   push  iy                      ;; [5] push pt2 adress
   jr    computeXMin             ;; [3] Move to computation
pt2GEXMin::                      ;; pt2 > XMin, hl contains pt1
   call  checkXMin               ;; [5] pt1.X > XMin ?
   jr    z,checkXMaxAlgo         ;; [2/3] Yes, Nothing to do move to next check
   ;; pt2 is inside but not pt1 - Need to project pt1-pt2 on X=0 and modify pt1
   push  ix                      ;; [5] push pt1 adress
computeXMin::
   ld    bc,#XMinM1              ;; [3] prepare intersect input with XMax
   call   computeXIntersect      ;; [5] launch computation on X intersection of pt1/pt2 with bc, result in hl
   pop   de                      ;; [3] retrieve adress of pt to modify (either pt1 or pt2)
   ex    de,hl                   ;; [1] hl = adress of pt, de = value to put on Y
   ld    (hl),#XMinM1            ;; [3] put XMin LSB in pt.X
   inc   hl                      ;; [2] Move to MSB
   ld    (hl),#0                 ;; [3] puyt XMin MSB in pt.X
   inc   hl                      ;; [2] Move to pt.Y LSB
   ld    (hl),e                  ;; [2] Put computed LSB value in LSB
   inc   hl                      ;; [2] Move to pt.Y MSB
   ld    (hl),d                  ;; [2] Put computed MSB value in MSB

checkXMaxAlgo::
    ld    hl,(pt2Adress)         ;; [5] hl = pt2
    call  checkXMax              ;; [5] Check if pt2.X > XMax
    ld    hl,(pt1Adress)         ;; [5] hl = pt1
    jr    z,pt2LEXMax            ;; [2/3] if ZF, pt2.x <= XMax
    call  checkXMax              ;; [5] pt1.X > XMax
    jp    nz,noDrawLine          ;; [3] Both pt1 and pt2 are outside of screen : no draw and exit
   ;; pt1 is inside but not pt2 - Need to project pt1-pt2 on X=XMax and modify pt2
    push  iy                     ;; [5] push pt2 adress
    jr    computeXMax            ;; [3] Move to computation
pt2LEXMax::                      ;; pt2 in bound of XMax - hl = pt1
    call  checkXMax              ;; [5] pt1.X > XMax
    jr    z,checkYMinAlgo        ;; [2/3] Nothing to do move to next check
   ;; pt2 is inside but not pt1 - Need to project pt1-pt2 on X=XMax and modify pt1
    push  ix                     ;; [5] push pt1 adress
computeXMax::
    ld    bc,#XMaxM1             ;; [3] prepare intersect input with XMax
    call  computeXIntersect      ;; [5] launch computation on X intersection of pt1/pt2 with bc, result in hl
   pop   de                      ;; [3] retrieve adress of pt to modify
   ex    de,hl                   ;; [1] hl = adress of pt, de = value to put on Y
   ld    (hl),#XMaxM1LSB         ;; [3] put XMax LSB in pt.X
   inc   hl                      ;; [2] Move to pt.X MSB
   ld    (hl),#XMaxM1MSB         ;; [3] puyt XMax MSB in pt.X
   inc   hl                      ;; [2] Move to pt.Y LSB
   ld    (hl),e                  ;; [2] Put computed LSB value in LSB
   inc   hl                      ;; [2] Move to pt.Y MSB
   ld    (hl),d                  ;; [2] Put computed MSB value in MSB

checkYMinAlgo::
   ld    hl,(pt2Adress)          ;; [5] hl = pt2
   call  checkYMin               ;; [5] Check if pt2.Y > YMin
   ld    hl,(pt1Adress)          ;; [5] hl = pt1
   jr    z,pt2GEYMin             ;; [2/3] if ZF, pt2.y >= YMin

   call  checkYMin               ;; [5] pt1.Y < YMin
   jr    nz,noDrawLine           ;; [2/3] Both pt1 and pt2 are outside of screen : no draw and exit
   ;; pt1 is inside but not pt2 - Need to project pt1-pt2 on Y=0 and modify pt2
   push  iy                      ;; [5] push pt2 adress
   jr    computeYMin             ;; [3] Move to computation
pt2GEYMin::                      ;; pt2 in bound of YMin
   call  checkYMin               ;; [5] pt1.Y < YMin
   jr    z,checkYMaxAlgo         ;; [2/3] Nothing to do move to next check
   ;; pt2 is inside but not pt1 - Need to project pt1-pt2 on Y=0 and modify pt1
   push  ix                      ;; [5] push pt1 adress
computeYMin::
   ld    bc,#YMin                ;; [3] input = YMin
   call  computeYIntersect       ;; [5] launch computation on Y intersection of pt1/pt2 with bc, result in hl
   pop   de                      ;; [3] de = adress of point to modify
   ex    de,hl                   ;; [1] hl = adress of pt, de = value to put on X
   ld    (hl),e                  ;; [2] put computed LSB in pt.X
   inc   hl                      ;; [2] move to MSB pt.X
   ld    (hl),d                  ;; [2] put computed MSB in pt.X
   inc   hl                      ;; [2] move to LSB of pt.Y
   ld    (hl),#YMin              ;; [3] put YMin LSB in pt.Y
   inc   hl                      ;; [2] move to MSB of pt.Y
   ld    (hl),#0                 ;; [3] put YMin MSB in pt.Y
checkYMaxAlgo::
   ;; Check if pt2.Y < YMax
   ld    hl,(pt2Adress)          ;; [5] hl = pt2
   call  checkYMax               ;; [5] Check if pt2.Y > YMax
   ld    hl,(pt1Adress)          ;; [5] hl = pt1
   jr    z,pt2GEYMax             ;; [2/3] if ZF, pt2.Y <= YMax

   call  checkYMax               ;; [5] pt1.Y > YMax
   jr    nz,noDrawLine           ;; [2/3] Both pt1 and pt2 are outside of screen : no draw and exit
   ;; pt1 is inside but not pt2 - Need to project pt1-pt2 on Y=YMax and modify pt2
   push  iy                      ;; [5] push pt2 adress
   jr    computeYMax             ;; [3] move to computation
pt2GEYMax::                      ;; pt2 in bound of YMax
   call  checkYMax               ;; [5] pt1.Y > YMax
   jr    z,drawLine              ;; [2/3] Nothing to do move to end of checks
   ;; pt2 is inside but not pt1 - Need to project pt1-pt2 on Y=YMax and modify pt1
   push  ix                      ;; [5] push pt1 adress
computeYMax::
   ld    bc,#YMax                ;; [3] input = YMax
   call  computeYIntersect       ;; [5] launch computation on Y intersection of pt1/pt2 with bc, result in hl
   pop   de                      ;; [3] de = adress of point to modify
   ex    de,hl                   ;; [1] hl = adress of pt, de = value to put on X
   ld    (hl),e                  ;; [2] put computed LSB in pt.X
   inc   hl                      ;; [2] move to MSB pt.X
   ld    (hl),d                  ;; [2] put computed MSB in pt.X
   inc   hl                      ;; [2] move to LSB of pt.Y
   ld    (hl),#YMax              ;; [3] put YMax LSB in pt.Y
   inc   hl                      ;; [2] move to MSB of pt.Y
   ld    (hl),#0                 ;; [3] put YMax MSB in pt.Y
drawLine::
   xor   a                       ;; [2] set A=0 for ouput that a line can be drawn
   jr    endClamping             ;; [3] Jump to end of subroutine
noDrawLine::
   ld    a,#0x01                 ;; [2] set A=1 for ouput that a line cannot be drawn
endClamping::
   pop   iy                      ;; [4] Retrieve IX
   pop   ix                      ;; [4] Retrieve IY
   ret                           ;; [3] return
resetZFlagAndReturn::
; Small helper to reset ZFlag and return
   xor   a                       ;; [2] a = 0 and reset ZFlag
   ret                           ;; [3] return
setZFlagAndReturn::
; Small helper to set ZFlag and return
   or   a,#0x01                  ;; [2] a = 1 and set ZFlag
   ret                           ;; [3] return
checkXMin::
;; Set Z Flag if X >= XMin
   inc   hl                      ;; [2] go to MSB of X
   bit   7,(hl)                  ;; [3] Check if msb is set on MSB-X
   ret                           ;; [3] If not (Z == 1) X is positif so >= XMin, if yes (Z==0) X<XMin
checkXMax::
;; Set Z Flag if X <= XMax
   inc   hl                      ;; [2] go to MSB of X
   ld    a,(hl)                  ;; [2] A = MSB-X
   or    a                       ;; [2] check 0
   ret   z                       ;; [2/4] no need to check more X < XMax and Z = 1
   dec   a                       ;; [1] check MSB-X with 1
   jr    nz,resetZFlagAndReturn  ;; [2/3] MSB-X != 1, so X > XMax, set carry and return
   dec   hl                      ;; [2] go to LSB of X
   ld    a,(hl)                  ;; [2] MSB-X == 1, let's continue,  A = LSB-X
   cp    #XMaxM1LSB              ;; [2] Compare with XMaxLSB
   jr    nc,setZFlagAndReturn    ;; [2/3] LSB-X <= XMaxLSB, so everything is fine, return
   jr    resetZFlagAndReturn     ;; [3] LSB-X > XMaxLSB : reset ZF and return

checkYMin::
;; Set Z Flag if Y >= YMin
   inc   hl                      ;; [2] go to MSB of X
   inc   hl                      ;; [2] go to LSB of Y
   inc   hl                      ;; [2] go to MSB of Y
   bit   7,(hl)                  ;; [3] Check if msb of MSB-Y is set
   ret                           ;; [3] If not (Z == 1) Y is positif so >= YMin, if yes (Z==0) Y<YMin

checkYMax::
;; Set Z Flag if Y <= YMax
   inc   hl                      ;; [2] go to MSB of X
   inc   hl                      ;; [2] go to LSB of Y
   inc   hl                      ;; [2] go to MSB of Y
   ld    a,(hl)                  ;; [2] A = MSB-Y
   or    a                       ;; [2] check 0
   jr    nz,resetZFlagAndReturn  ;; [2/3] no need to check more Y < YMax so return
   dec   hl                      ;; [2] go to LSB of Y
   ld    a,(hl)                  ;; [2] A = LSB-Y
   cp    #YMax                   ;; [2] Compare with YMax
   jr    nc,setZFlagAndReturn    ;; [2/3] LSB-Y <= YMax, so everything is fine, reset ZFlag and return
   jr    resetZFlagAndReturn     ;; [3] LSB-Y > YMax,reset Z Flag and return

computeXIntersect::
;; Compute the intersection of the line defined by x=(ix),y=(iy) with the vertical line defined by X = bc
;; returns Y value in HL
   ld    l,(ix+0)                ;; [5] l = LSB of x1
   ld    h,(ix+1)                ;; [5] hl=x1
   ld    a,c                     ;; [1] a=LSB input
   sub   l                       ;; [2] a = LSB of target_dx = input -x1
   ld    e,a                     ;; [1] e = LSB of target_dx
   ld    a,b                     ;; [1] a=MSB input
   sbc   a,h                     ;; [2] a = MSB of target_dx (including carry)
   ld    d,a                     ;; [1] de = target_dx = input - x1

   ld l, (iy+2)                  ;; [5] L = LSB of y2
   ld h, (iy+3)                  ;; [5] HL = y2
   ld c, (ix+2)                  ;; [5] C = LSB of y1
   ld b, (ix+3)                  ;; [5] BC = y1
   or a                          ;; [2] Clear carry
   sbc hl, bc                    ;; [4] HL = dy = y2 - y1

   push  iy                      ;; [5] iy is modified by sdcc
   call  ___mulsint2slong        ;; [5] DEHL = DE * HL
   pop   iy                      ;; [4] retrieve

   push  hl                      ;; [4]
   push  de                      ;; [4] push DEHL

   ld    l,(iy+0)                ;; [5] l = LSB of x2
   ld    h,(iy+1)                ;; [5] hl = x2
   ld    e,(ix+0)                ;; [5] e= LSB of x1
   ld    d,(ix+1)                ;; [5] DE = x1
   or    a                       ;; [2] Clear carry
   sbc   hl,de                   ;; [4] hl = dx = x2 - x1

   ;; push 32bit hl on stack for call __divslong denominator
   ;; So push 0 or #0xFF depending on HL sign
   xor   a                       ;; [2] a = 0
   bit   7,h                     ;; [2] check h msb for sign of hl
   jr    z,cx_notNeg             ;; [2/3] if not ZF, h l is positif
   cpl                           ;; [1] complement a to 0xFF
cx_notNeg:
   ld    (cx_MSBDenom),a         ;; [4] SMC, set MSB to 0 or 0xFF for 32bit view of denominator
   ld    (cx_MSBDenom+1),a       ;; [4] SMC, set LSB to 0 or 0xFF for 32bit view of denominator
   ld    a,l                     ;; [1] a = LSB Denominator
   ld    (cx_LSBDenom),a         ;; [4] SMC, LSB of denominator
   ld    a,h                     ;; [1] a = MSB Denominator
   ld    (cx_LSBDenom+1),a       ;; [4] SMC, MSB of denominator

   pop   de                      ;; [3]
   pop   hl                      ;; [3] pop DEHL to set them before division

cx_MSBDenom=.+1
   ld    bc,#00                  ;; [3] SMC MSB
   push  bc                      ;; [4] push 0 or OxFFFF depending on denom sign
cx_LSBDenom=.+1
   ld    bc,#00                  ;; [3] SMC LSB
   push  bc                      ;; [4] push denominator

   call  __divslong              ;; [5] DE = DEHL / xxBC (on stack)
   pop   bc                      ;; [3] Unstack inputs
   pop   bc                      ;; [3] Unstack inputs

   ld    l,(ix+2)                ;; [5] l = LSB of y1
   ld    h,(ix+3)                ;; [5] hl = y1
   add   hl,de                   ;; [3] hl = y1 + quotient
   ret                           ;; [3] return

computeYIntersect::
   ld    l,(ix+2)                ;; [5] l = LSB of y1
   ld    h,(ix+3)                ;; [5] hl=y1
   ld    a,c                     ;; [1] a=LSB input
   sub   l                       ;; [2] a = LSB of target_dy = input - y1
   ld    e,a                     ;; [1] e = LSB of target_dy = input - y1
   ld    a,b                     ;; [1] a=MSB input
   sbc   a,h                     ;; [2] a = MSB of target_dy (including carry)
   ld    d,a                     ;; [1] de = target_dx = input - y1

   ld l, (iy+0)                  ;; [5] L = LSB of x2
   ld h, (iy+1)                  ;; [5] HL = x2
   ld c, (ix+0)                  ;; [5] C = LSB of x1
   ld b, (ix+1)                  ;; [5] BC = x1
   or a                          ;; [2] Clear carry
   sbc hl, bc                    ;; [4] HL = dx = x2 - x1

   push  iy                      ;; [5] iy is modified by sdcc
   call  ___mulsint2slong        ;; [5] DEHL = DE * HL
   pop   iy                      ;; [4] retrieve

   push  hl                      ;; [4]
   push  de                      ;; [4] push DEHL

   ld    l,(iy+2)                ;; [5] l = LSB of y2
   ld    h,(iy+3)                ;; [5] hl = y2
   ld    e,(ix+2)                ;; [5] e = LSB of y1
   ld    d,(ix+3)                ;; [5] DE = y1
   or    a                       ;; [2] Clear carry
   sbc   hl,de                   ;; [4] hl = dy = y2 - y1

   ;; push 32bit hl on stack for call __divslong denominator
   ;; So push 0 or #0xFF depending on HL sign in SMC
   xor   a                       ;; [2] a = 0
   bit   7,h                     ;; [2] check h msb for sign of hl
   jr    z,cy_notNeg             ;; [2/3] if h > 0 use a = 0
   cpl                           ;; [1] else use a = 0xFF
cy_notNeg:
   ld    (cy_MSBDenom),a         ;; [4] put a in MSB of 32 bit denom
   ld    (cy_MSBDenom+1),a       ;; [4] put a in MSB of 32 bit denom
   ld    a,l                     ;; [1] a = LSB of 32 bit denom
   ld    (cy_LSBDenom),a         ;; [4] put a in LSB of 32 bit denom
   ld    a,h                     ;; [1] a = MSB of 32 bit denom
   ld    (cy_LSBDenom+1),a       ;; [4] put a in LSB 32 bit denom

   pop   de                      ;; [3]
   pop   hl                      ;; [3] pop DEHL to set them before division

cy_MSBDenom=.+1
   ld    bc,#00                  ;; [3] SMC MSB
   push  bc                      ;; [4] push 0 or OxFFFF depending on denom sign
cy_LSBDenom=.+1
   ld    bc,#00                  ;; [3] SMC LSB
   push  bc                      ;; [4] push denominator

   call  __divslong              ;; [5] DE = DEHL / xxBC on stack (xx = 0 or FF)
   pop   bc                      ;; [3] Unstack inputs
   pop   bc                      ;; [3] Unstack inputs

   ld    l,(ix+0)                ;; [5] l = LSB of x1
   ld    h,(ix+1)                ;; [5] hl = x1
   add   hl,de                   ;; [3] hl = x1 + quotient
   ret                           ;; [3] return
