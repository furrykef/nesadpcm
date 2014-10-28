; NESADPCM
; Copyright (C) 2014 Kef Schecter
;
; This code uses the CC0 license, which is nearly equivalent to
; releasing the code into the public domain. In short, you can use it
; for nearly any purpose, without attribution. (That said, attribution
; somewhere is still preferred!) See COPYING.txt included with the
; NESADPCM distribution.


; Set to 1 to use a sampling rate of 4000 Hz (assuming FAST_MODE is off)
SRATE_4000 = 0

; 0: slowest; saves the most space
; 1: faster, but adds over 420 bytes to the ROM
; 2: slightly faster still, but adds over 380 bytes more
SPEED = 2


.segment "ZEROPAGE"

SampleAddr:
SampleAddrLSB:      .res 1
SampleAddrMSB:      .res 1

SampleBytesLeft:
SampleBytesLeftLSB: .res 1
SampleBytesLeftMSB: .res 1

StepSize:
StepSizeLSB:        .res 1
StepSizeMSB:        .res 1

Delta:
DeltaLSB:           .res 1
DeltaMSB:           .res 1

DeltaCopy:
DeltaCopyLSB:       .res 1
DeltaCopyMSB:       .res 1

Code:               .res 1

StepIndex:          .res 1


.if SPEED = 0
Error:
ErrorLSB:           .res 1
ErrorMSB:           .res 1
.else
AdpcmStepTblAddr:
AdpcmStepTblAddrLSB: .res 1
AdpcmStepTblAddrMSB: .res 1
.endif


.segment "CODE"

; Unsigned 16-bit shift
; 10 cycles if var is on zero page
.macro lsr16    var
        lsr     var+1
        ror     var
.endmac

; Add two 16-bit integers and store result in var1
; 20 cycles if both vars are on zero page
.macro add16    var1, var2
        clc
        lda     var1
        adc     var2
        sta     var1
        lda     var1+1
        adc     var2+1
        sta     var1+1
.endmac

; 16-bit subtract var2 from var1 and store result in var1
.macro sub16   var1, var2
        sec
        lda     var1
        sbc     var2
        sta     var1
        lda     var1+1
        sbc     var2+1
        sta     var1+1
.endmac


PlayAdpcm:
        ldy     #0                          ; Y is SampleAddr offset
        sty     StepIndex                   ; clear step index
        sty     DeltaLSB                    ; clear delta
        sty     DeltaMSB
@loop:
        lda     (SampleAddr),y
        lsr
        lsr
        lsr
        lsr
        jsr     HandleAdpcmCode

.if SRATE_4000
        ; wait about 166 cycles
        ; (if the loop happens to cross a page boundary, it will wait rather more)
        ldx     #33
@wait1:
        dex
        bne     @wait1
.endif

        lda     (SampleAddr),y
        and     #$0f
        jsr     HandleAdpcmCode

.if SRATE_4000
        ; wait about 166 cycles
        ; (if the loop happens to cross a page boundary, it will wait rather more)
        ldx     #33
@wait2:
        dex
        bne     @wait2
.endif

        ; decrement SampleBytesLeft and quit if zero
        ; 16-bit decrement taken from http://6502org.wikidot.com/software-incdec#toc2
        lda     SampleBytesLeftLSB
        bne     @lsb_nonzero
        lda     SampleBytesLeftMSB
        beq     @done
        dec     SampleBytesLeftMSB
@lsb_nonzero:
        dec     SampleBytesLeftLSB

        iny
        bne     @loop
        inc     SampleAddrMSB
        jmp     @loop

@done:
        rts


; Based on C code from http://svn.annodex.net/annodex-core/libsndfile-1.0.11/src/vox_adpcm.c
; A = nybble to process (high four bits clear)
; Y must not be modified
HandleAdpcmCode:
        sta     Code

.if SPEED > 0

        ; First, find which step table to use
        asl                                     ; indexing into table of 16-bit values
        tax
        lda     AdpcmCodeTbl,x
        sta     AdpcmStepTblAddrLSB
        inx
        lda     AdpcmCodeTbl,x
        sta     AdpcmStepTblAddrMSB

        ; Now calculate the step
        tya
        pha
        lda     StepIndex
        asl                                     ; indexing into table of 16-bit values
        tay
        lda     (AdpcmStepTblAddr),y
        sta     StepSizeLSB
        iny
        lda     (AdpcmStepTblAddr),y
        sta     StepSizeMSB
.if SPEED < 2
        ; have to negate manually if necessary
        lda     #$08
        bit     Code
        beq     @add_step
        sub16   Delta, StepSize
        jmp     @skip_add
@add_step:
.endif
        add16   Delta, StepSize
@skip_add:
        pla
        tay

.else

        ; Slow mode; this mimics the C code more closely

        lda     StepIndex
        asl                                     ; indexing into table of 16-bit values
        tax
        lda     AdpcmStepTbl,x
        sta     StepSizeLSB
        sta     ErrorLSB
        inx
        lda     AdpcmStepTbl,x
        sta     StepSizeMSB
        sta     ErrorMSB

        ; Error /= 8
        lsr16   Error
        lsr16   Error
        lsr16   Error

        lda     #$04
        bit     Code
        beq     :+
        add16   Error, StepSize
:       lsr16   StepSize
        lda     #$02
        bit     Code
        beq     :+
        add16   Error, StepSize
:       lsr16   StepSize
        lda     #$01
        bit     Code
        beq     :+
        add16   Error, StepSize
:
        lda     #$08
        bit     Code
        beq     @add_error
        sub16   Delta, Error
        jmp     @output
@add_error:
        add16   Delta, Error

.endif                                      ; SPEED

@output:
        ; We're gonna skip clipping Delta and just hope it never clips
        ; DeltaCopy := Delta >> 4 (get the 8 most significant bits)
        lda     DeltaLSB
        sta     DeltaCopyLSB
        lda     DeltaMSB
        sta     DeltaCopyMSB
        lsr16   DeltaCopy
        lsr16   DeltaCopy
        lsr16   DeltaCopy
        lsr16   DeltaCopy
        lda     DeltaCopyLSB
        clc                                 ; convert to unsigned
        adc     #$80
        lsr                                 ; convert to 7-bit
        sta     $4011                       ; finally output the sample

        lda     Code
        and     #$07
        tax
        lda     AdpcmAdjustTbl,x
        clc
        adc     StepIndex

        ; Clamp StepIndex to range [0..48] (this *is* necessary)
        bpl     @index_not_neg
        lda     #0
        beq     @index_in_range             ; branch always taken
@index_not_neg:
        cmp     #49
        bcc     @index_in_range
        lda     #48
@index_in_range:
        sta     StepIndex

        ; Whew!
        rts

.if SPEED > 0

AdpcmCodeTbl:
        .word AdpcmStepTbl0
        .word AdpcmStepTbl1
        .word AdpcmStepTbl2
        .word AdpcmStepTbl3
        .word AdpcmStepTbl4
        .word AdpcmStepTbl5
        .word AdpcmStepTbl6
        .word AdpcmStepTbl7
.if SPEED = 1
        ; Second half is same as first half
        ; (negation will be performed in code)
        .word AdpcmStepTbl0
        .word AdpcmStepTbl1
        .word AdpcmStepTbl2
        .word AdpcmStepTbl3
        .word AdpcmStepTbl4
        .word AdpcmStepTbl5
        .word AdpcmStepTbl6
        .word AdpcmStepTbl7
.else
        ; Second half is negative of first half
        .word AdpcmStepTbl8
        .word AdpcmStepTbl9
        .word AdpcmStepTblA
        .word AdpcmStepTblB
        .word AdpcmStepTblC
        .word AdpcmStepTblD
        .word AdpcmStepTblE
        .word AdpcmStepTblF
.endif

AdpcmStepTbl0:
        .word 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 6, 6, 7, 8, 8, 9, 10, 11, 12, 13, 15, 16, 18, 20, 22, 24, 26, 29, 32, 35, 38, 42, 46, 51, 56, 62, 68, 75, 82, 90, 100, 110, 120, 132, 146, 160, 176, 194

AdpcmStepTbl1:
        .word 6, 6, 7, 8, 9, 9, 10, 12, 13, 14, 15, 17, 19, 21, 22, 25, 27, 30, 33, 36, 40, 44, 49, 54, 59, 65, 71, 78, 86, 95, 105, 115, 126, 139, 153, 168, 185, 204, 224, 247, 272, 298, 328, 361, 398, 437, 481, 528, 582

AdpcmStepTbl2:
        .word 10, 11, 12, 13, 14, 16, 18, 19, 21, 23, 26, 28, 31, 34, 38, 41, 46, 50, 55, 61, 67, 74, 81, 89, 98, 108, 119, 131, 144, 158, 174, 192, 211, 232, 255, 281, 309, 340, 374, 411, 452, 498, 548, 602, 662, 729, 801, 880, 970

AdpcmStepTbl3:
        .word 14, 15, 17, 18, 20, 22, 24, 27, 30, 32, 36, 39, 44, 48, 52, 58, 64, 70, 77, 85, 94, 103, 114, 125, 137, 151, 166, 183, 201, 221, 244, 269, 295, 325, 357, 393, 432, 476, 523, 576, 634, 696, 766, 843, 928, 1020, 1122, 1232, 1358

AdpcmStepTbl4:
        .word 18, 19, 21, 24, 26, 28, 32, 35, 38, 42, 46, 51, 56, 62, 68, 74, 82, 90, 99, 109, 120, 133, 146, 161, 177, 195, 214, 235, 259, 285, 314, 345, 379, 417, 459, 505, 556, 612, 673, 740, 814, 896, 986, 1083, 1192, 1312, 1442, 1584, 1746

AdpcmStepTbl5:
        .word 22, 23, 26, 29, 32, 34, 38, 43, 47, 51, 56, 62, 69, 76, 82, 91, 100, 110, 121, 133, 147, 162, 179, 197, 216, 238, 261, 287, 316, 348, 384, 422, 463, 510, 561, 617, 679, 748, 822, 905, 996, 1094, 1204, 1324, 1458, 1603, 1763, 1936, 2134

AdpcmStepTbl6:
        .word 26, 28, 31, 34, 37, 41, 46, 50, 55, 60, 67, 73, 81, 89, 98, 107, 119, 130, 143, 158, 174, 192, 211, 232, 255, 281, 309, 340, 374, 411, 453, 499, 548, 603, 663, 730, 803, 884, 972, 1069, 1176, 1294, 1424, 1565, 1722, 1895, 2083, 2288, 2522

AdpcmStepTbl7:
        .word 30, 32, 36, 39, 43, 47, 52, 58, 64, 69, 77, 84, 94, 103, 112, 124, 137, 150, 165, 182, 201, 221, 244, 268, 294, 324, 356, 392, 431, 474, 523, 576, 632, 696, 765, 842, 926, 1020, 1121, 1234, 1358, 1492, 1642, 1806, 1988, 2186, 2404, 2640, 2910

AdpcmStepTbl8:
        .word -2, -2, -2, -3, -3, -3, -4, -4, -4, -5, -5, -6, -6, -7, -8, -8, -9, -10, -11, -12, -13, -15, -16, -18, -20, -22, -24, -26, -29, -32, -35, -38, -42, -46, -51, -56, -62, -68, -75, -82, -90, -100, -110, -120, -132, -146, -160, -176, -194

AdpcmStepTbl9:
        .word -6, -6, -7, -8, -9, -9, -10, -12, -13, -14, -15, -17, -19, -21, -22, -25, -27, -30, -33, -36, -40, -44, -49, -54, -59, -65, -71, -78, -86, -95, -105, -115, -126, -139, -153, -168, -185, -204, -224, -247, -272, -298, -328, -361, -398, -437, -481, -528, -582

AdpcmStepTblA:
        .word -10, -11, -12, -13, -14, -16, -18, -19, -21, -23, -26, -28, -31, -34, -38, -41, -46, -50, -55, -61, -67, -74, -81, -89, -98, -108, -119, -131, -144, -158, -174, -192, -211, -232, -255, -281, -309, -340, -374, -411, -452, -498, -548, -602, -662, -729, -801, -880, -970

AdpcmStepTblB:
        .word -14, -15, -17, -18, -20, -22, -24, -27, -30, -32, -36, -39, -44, -48, -52, -58, -64, -70, -77, -85, -94, -103, -114, -125, -137, -151, -166, -183, -201, -221, -244, -269, -295, -325, -357, -393, -432, -476, -523, -576, -634, -696, -766, -843, -928, -1020, -1122, -1232, -1358

AdpcmStepTblC:
        .word -18, -19, -21, -24, -26, -28, -32, -35, -38, -42, -46, -51, -56, -62, -68, -74, -82, -90, -99, -109, -120, -133, -146, -161, -177, -195, -214, -235, -259, -285, -314, -345, -379, -417, -459, -505, -556, -612, -673, -740, -814, -896, -986, -1083, -1192, -1312, -1442, -1584, -1746

AdpcmStepTblD:
        .word -22, -23, -26, -29, -32, -34, -38, -43, -47, -51, -56, -62, -69, -76, -82, -91, -100, -110, -121, -133, -147, -162, -179, -197, -216, -238, -261, -287, -316, -348, -384, -422, -463, -510, -561, -617, -679, -748, -822, -905, -996, -1094, -1204, -1324, -1458, -1603, -1763, -1936, -2134

AdpcmStepTblE:
        .word -26, -28, -31, -34, -37, -41, -46, -50, -55, -60, -67, -73, -81, -89, -98, -107, -119, -130, -143, -158, -174, -192, -211, -232, -255, -281, -309, -340, -374, -411, -453, -499, -548, -603, -663, -730, -803, -884, -972, -1069, -1176, -1294, -1424, -1565, -1722, -1895, -2083, -2288, -2522

AdpcmStepTblF:
        .word -30, -32, -36, -39, -43, -47, -52, -58, -64, -69, -77, -84, -94, -103, -112, -124, -137, -150, -165, -182, -201, -221, -244, -268, -294, -324, -356, -392, -431, -474, -523, -576, -632, -696, -765, -842, -926, -1020, -1121, -1234, -1358, -1492, -1642, -1806, -1988, -2186, -2404, -2640, -2910

.else

AdpcmStepTbl:
        .word 16,  17,  19,  21,  23,   25,   28,   31
        .word 34,  37,  41,  45,  50,   55,   60,   66
        .word 73,  80,  88,  97,  107,  118,  130,  143
        .word 157, 173, 190, 209, 230,  253,  279,  307
        .word 337, 371, 408, 449, 494,  544,  598,  658
        .word 724, 796, 876, 963, 1060, 1166, 1282, 1411
        .word 1552

.endif                                      ; SPEED

AdpcmAdjustTbl:
        .byte -1, -1, -1, -1, 2, 4, 6, 8
