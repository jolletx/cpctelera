.module test

    nop

SYMVALUE = 10

.area _DATA_sample
values :
    .db 1, 2, 3
    .dw 0x1234
patch_value : .dw 0
    .asciz "A"
.rept 3
    .db 0
    .dw 0
.endm
.rept SYMVALUE
    .db 0
.endm

.area _CODE
start:
    ld a, b                      ;; [1] already correct
    ld (hl), e                  ;; [3] deliberately incorrect
    jr z, next
    jr c, next
    bit 7, (hl)
    call helper
    call computeXIntersect
    ld bc, #XMinM1
    ld hl, #patch_value + 3
    ld hl, #3 + patch_value
    ld a, #0x01
    ld (patch_value+1), a
    or a, #0x01
    call mystery
    unknown_op 1
    sub e
    ld de,(x0_val)
    or d
    and d
    ld a,<#label
    ld a,>#label
    ld a,<#1234
    ld a,>#0x1234
.macro draw
    ld a, b
.endm
    draw
#ifdef FEATURE
#endif
next:
    xor a
helper:
    ret
computeXIntersect:
    ret
