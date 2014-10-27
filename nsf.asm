.segment "HEADER"

.byte 'N', 'E', 'S', 'M', $1A               ; ID
.byte $01                                   ; Version
.byte 4                                     ; Number of songs
.byte 1                                     ; Start song
.word $8000
.word INIT
.word PLAY
.byte "ADPCM demo",0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte "Kef Schecter",0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte "CC0",0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.word $411A                                 ; NTSC speed
.byte 0, 0, 0, 0, 0, 0, 0, 0                ; Bank values
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

SampleLenTbl:
        .word   Sample1Len
        .word   Sample2Len
        .word   Sample3Len
        .word   Sample4Len

SampleLoopTbl:
        .byte   0
        .byte   0
        .byte   0
        .byte   1


Sample1:
        .incbin "raws/kablammo-6236.raw"
Sample1End:
Sample1Len = Sample1End - Sample1

Sample2:
        .incbin "raws/scout-6236.raw"
Sample2End:
Sample2Len = Sample2End - Sample2

Sample3:
        .incbin "raws/dk-roar-6236.raw"
Sample3End:
Sample3Len = Sample3End - Sample3

Sample4:
        .incbin "raws/beatles-6236.raw"
Sample4End:
Sample4Len = Sample4End - Sample4


.include "adpcm.asm"
