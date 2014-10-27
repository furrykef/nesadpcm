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

SongID:             .res 1                  ; only needed for NSF driver


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
        rts

; Remember to clear APU regs when we do non-NSF version
PLAY:
        jsr     PlayAdpcm
        ldx     SongID
        lda     SampleLoopTbl,x
@forever:
        beq     @forever                    ; do nothing if sample does not loop

        ; sample loops
        lda     SongID
        jsr     INIT
        jmp     PLAY


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
