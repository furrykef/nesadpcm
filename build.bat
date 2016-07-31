@echo off
C:\MFS\cc65\bin\ca65 nsf.asm || goto end
C:\MFS\cc65\bin\ld65 -C adpcm-nsf.cfg -o adpcm.nsf nsf.o
:end
pause
