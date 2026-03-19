[readme.txt](https://github.com/user-attachments/files/26123363/readme.txt)
This spatial shader automatically adjusts black and white levels to maintain consistently high image contrast without color clipping.

The "NaRKoM_Fix_Contrast" shader takes random pixels from the image and, based on these pixels, analyzes the current minimum black level and maximum white level. It then adjusts their black and white levels to the maximum value, being careful not to make the image too dark. It does this smoothly to prevent flickering.

The shader doesn't perfectly preserve all image data without loss, so it needs to maintain a reserve of black and white levels for it to work correctly. For this purpose, there's a second shader, "NaRKoM_protection_BlackWhite_Levels," which has just two simple functions: increase the black level and decrease the white level.
It should be installed before "NaRKoM_Fix_Contrast" to ensure the image always maintains high contrast.

The current default values ​​are configured for "set and forget." But if a game has an interface that already uses maximum white or black, this interferes with the proper operation of the "NaRKoM_Fix_Contrast" shader.
Therefore, in this shader, you can selectively clip the data supplied for its analysis from the top, bottom, left, and right, so that the image analysis doesn't capture the edges of the image.

The shader was written using AI.
I don't know much about programming, but I do understand color correction and have a basic understanding of how things work. So, with great effort, I created this shader to enjoy video games with full use of the monitor's contrast, rather than the washed-out image that game developers sometimes give us.

The shader was written for Reshade 6.5.0. I don't know if it will work elsewhere.

My contact information:
Telegram: @NaRKoMaNko
Discord: NaRKoMaN#8903
vk - vk.com/mastaj
