; NESADPCM
; Copyright (C) 2014 Kef Schecter
;
; This code uses the CC0 license, which is nearly equivalent to
; releasing the code into the public domain. In short, you can use it
; for nearly any purpose, without attribution. (That said, attribution
; somewhere is still preferred!) See COPYING.txt included with the
; NESADPCM distribution.


; Set to 1 to use a sampling rate of 4000 Hz instead of 6236 Hz
SRATE_4000 = 0


.segment "ZEROPAGE"

SampleAddr:
SampleAddrLSB:      .res 1
SampleAddrMSB:      .res 1

SampleBytesLeft:
SampleBytesLeftLSB: .res 1
SampleBytesLeftMSB: .res 1

Error:
ErrorLSB:           .res 1
ErrorMSB:           .res 1

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


.segment "CODE"

; Unsigned 16-bit shift
.macro lsr16    var
        lsr     var+1
        ror     var
.endmac

; Add two 16-bit integers and store result in var1
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
        ; wait about 160 cycles
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


AdpcmStepTbl:
        .word 16,  17,  19,  21,  23,   25,   28,   31
        .word 34,  37,  41,  45,  50,   55,   60,   66
        .word 73,  80,  88,  97,  107,  118,  130,  143
        .word 157, 173, 190, 209, 230,  253,  279,  307
        .word 337, 371, 408, 449, 494,  544,  598,  658
        .word 724, 796, 876, 963, 1060, 1166, 1282, 1411
        .word 1552

AdpcmAdjustTbl:
        .byte -1, -1, -1, -1, 2, 4, 6, 8
