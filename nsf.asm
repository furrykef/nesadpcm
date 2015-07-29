; Demo sounds:
;   1: Homer Simpson from The Simpsons
;   2: The Scout from Team Fortress 2
;   3: Donkey Kong from Mario Kart 64
;   4: "Make your selection now" from Action 53, voiced by tepples
;   5: Drum loop from Sgt. Pepper Reprise by The Beatles

.include "adpcm.asm"


.segment "HEADER"

.byte 'N', 'E', 'S', 'M', $1A               ; ID
.byte $01                                   ; Version
.byte 5                                     ; Number of songs
.byte 1                                     ; Start song
.word $8000
.word INIT
.word PLAY
.byte "ADPCM demo",0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte "Kef Schecter",0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte "CC0 (code only)",0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.word $411A                                 ; NTSC speed
.byte 0, 1, 2, 3, 4, 5, 6, 7                ; Bank values
.word 0                                     ; PAL speed
.byte 0                                     ; Flags, NTSC only
.byte 0
.byte 0,0,0,0                               ; Reserved


.segment "ZEROPAGE"

SongID:             .res 1
Done:               .res 1


.segment "CODE"

INIT:
        sta     SongID
        tax
        ldy     SampleBankTbl,x
        sty     $5ff9                       ; set up banks
        iny
        sty     $5ffa
        iny
        sty     $5ffb
        iny
        sty     $5ffc
        iny
        sty     $5ffd
        iny
        sty     $5ffe
        iny
        sty     $5fff
        asl                                 ; indexing into table of 16-bit values
        tax
        lda     SampleAddrTbl,x
        sta     SampleAddrLSB
        lda     SampleLenTbl,x
        sta     SampleBytesLeftLSB
        inx
        lda     SampleAddrTbl,x
        sta     SampleAddrMSB
        lda     SampleLenTbl,x
        sta     SampleBytesLeftMSB
        lda     #0
        sta     Done
        rts


PLAY:
        lda     Done
        bne     @done

        jsr     PlayAdpcm
        ldx     SongID
        lda     SampleLoopTbl,x
        beq     @done                       ; if sample desn't loop, well, don't loop

        ; sample loops
        lda     SongID
        jsr     INIT
        rts

@done:
        lda     #1
        sta     Done
        rts


SampleAddrTbl:
        .word   Sample1
        .word   Sample2
        .word   Sample3
        .word   Sample4
        .word   Sample5

SampleBankTbl:
        .byte   1
        .byte   8
        .byte   8
        .byte   8
        .byte   8

SampleLenTbl:
        .word   Sample1Len
        .word   Sample2Len
        .word   Sample3Len
        .word   Sample4Len
        .word   Sample5Len

SampleLoopTbl:
        .byte   0
        .byte   0
        .byte   0
        .byte   0
        .byte   1


.segment "ADPCM0"
Sample1:
        .incbin "raws/kablammo-8948.raw"
Sample1Len = * - Sample1

.segment "ADPCM1"
Sample2:
        .incbin "raws/scout-8948.raw"
Sample2Len = * - Sample2

Sample3:
        .incbin "raws/dk-roar-8948.raw"
Sample3Len = * - Sample3

Sample4:
        .incbin "raws/selnow-8948.raw"
Sample4Len = * - Sample4

Sample5:
        .incbin "raws/beatles-8948.raw"
Sample5Len = * - Sample5
