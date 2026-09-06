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

.include "macros/cpct_undocumentedOpcodes.h.s"

.globl cpct_drawHorizontalLineM1

;; extern void cpct_drawHorizontalLineM1 (u8* vmem, u16 x0, u16 x1, u8 y, u8 color) __z88dk_callee;
;;    vmem        - Base VRAM memory address (typically 0xC000)
;;    x0          - Starting X coordinate (0-319)
;;    x1          - Ending X coordinate (0-319)
;;    y           - Y coordinate (0-199, 8-bit integer)
;;    color       - Ink color of line (0..3)
;;
;;  x0 and x& does not need to be sorted from left to right
;;  function will automatically swap them if needed
;;
;; Required memory:
;;    TODO bytes (TODO bytes core routine + TODO bytes binding wrapper)
;;
;; Time Measures (Includes TODO us / TODO cycles binding wrapper overhead):
;;    Get color at subPixel 0            | 101    | 11250          | 45000
;;    Get color at subPixel 3            | 101    | 11250          | 45000
;; (end code)

_cpct_drawHorizontalLineM1::
   ld   (restore_ix), ix            ;; [6] Save IX to restore it before returning
   pop   af                         ;; [3] AF = Return address

   ; Get Parameters
   ;; HL = Screen Adress / DE = X0 Coordinate 
   pop   bc                         ;; [3] bc = X1 coordinate 
   pop   ix                         ;; [4] ixh = Y0 coordinate / ixl = color
   
   push af                          ;; [4] Restore return address to stack because __z88dk_callee

.include  /cpct_drawHorizontalLineM1.asm/

restore_ix=.+2
   ld   ix, #0000                 ;; [4] Restore IX before returning  
   ret                              ;; [3] return from c 
