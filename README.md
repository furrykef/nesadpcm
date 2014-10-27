# NESADPCM
A VOX ADPCM (a.k.a. Dialogic ADPCM or OKI ADPCM) decoder for the NES. It may or may not be adaptable to other 6502-based systems. The code is written for ca65, but should be easily adaptable to other assemblers.

To avoid confusion, in this document, the term "sound clip" will be to used to refer to, well, sound clips. The term "sample" will refer not to a sound clip, but rather the samples sent to the DAC.

The code currently has a maximum playback rate of about 6236 Hz. This can be reduced by inserting delays between samples, allowing you to use smaller sound clips to save space. The playback engine is not perfectly timed and so the playback rate is slightly unsteady. For practical purposes, however, it is good enough.

To save time, the program does not bother checking if the waveform clips. If you're getting horrible distortion artifacts, check to make sure your waveform is not clipping. If it is, try making it a tad quieter.

This program hogs the CPU; you cannot do anything while a sample is playing if you're using the maximum playback rate. If you're playing at, say, 4000 Hz, you get about 160 cycles of time between samples to do whatever it is.

VOX ADPCM is admittedly not the ideal format for playing on 8-bit systems with 7-bit audio. Each sample is actually decoded as 12-bit even though only the 7 most significant bits are heard. This means the program does a fair bit of 16-bit math. A codec that requires only 8-bit math to decode could run significantly faster and so yield a higher maximum sampling rate. But I wanted an ADPCM solution and I wanted it now, and it seemed easier to adapt readily available VOX ADPCM code in C than to find another solution.

Do note that the code doesn't bother to reset $4011 to zero after playing a sample. This means your triangle and noise channels might be a little quiet until you poke a new value into $4011.


## Producing VOX ADPCM samples
Converting your samples to VOX ADPCM is easy! For our example, we're going to use [Audacity](audacity.sourceforge.net), but other tools can be used.

First, load your sample in Audacity. Then, in the bottom-left corner of your screen, click the "Project Rate (Hz)" and type in the playback rate of the engine. For instance, if you're using the engine's maximum playback rate, type 6236.

Next, go to `File->Export...`, then _before_ you save, set "Save as type" to "Other uncompressed files", then click the `Options...` button in the dialog box. Choose "RAW (header-less)" for the header and "VOX ADPCM" for the encoding. Now save your file and voila!

Sometimes this may produce a dialog box claiming an error of "No error". Don't worry; it probably still worked fine.
