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

;; cpct_drawHorizontAlLineM1_asm
;;      (2B HL) = VMEM start adress
;;      (2B DE) = X0
;;      (2B BC) = X1
;;      (2B IX) = ixh INK Color  / ixl = Y
;; Destroyed Register values:
;;      AF, BC, DE, HL, IX
;;
cpct_drawHorizontalLineM1_asm::

.include  /cpct_drawHorizontalLineM1.asm/

    ret                              ;; [3] return from asm
