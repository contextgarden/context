Remarks:

The original code was written using the Arduino IDE for the RPI PICO 2 but the
gadget eventually used an ESP32. For that I decided to try out PlatformIO and
split up the files. On the one hand editing is a bit easier (cross file) once I
had most interfering and annoying features turned off (I only need an editor and
no help with coding). However, in the end I wanted to compile for both platforms
and went back to the Arduino IDE although figuring out selective loading of
specific header files was bit of trial and error because the program pushed some
inclusion text up front. Finally I decided to just use the macros set for the PICO.

With the Arduino IDE files go into the sketch directories. These are organize by
main sketch (an ino file) with its own relatively empty directory and a libraries
tree. In that tree libraries that are installed via the gui end up but we also
put the signal libraries there. The IDE should find them but when testing this it
was somewhat erratic. The language server occasionally does some refresh.

    codebase/ide/context-lmtx-signal/context-lmtx-signal.ino

    codebase/ide/libraries/signal/signal-bluetooth.cpp
    codebase/ide/libraries/signal/signal-button.cpp
    codebase/ide/libraries/signal/signal-buzzer.cpp
    codebase/ide/libraries/signal/signal-common.cpp
    codebase/ide/libraries/signal/signal-hue.cpp
    codebase/ide/libraries/signal/signal-knuth.cpp
    codebase/ide/libraries/signal/signal-leds.cpp
    codebase/ide/libraries/signal/signal-main.cpp
    codebase/ide/libraries/signal/signal-serial.cpp
    codebase/ide/libraries/signal/signal-wifi.cpp
    codebase/ide/libraries/signal/signal-bluetooth.h
    codebase/ide/libraries/signal/signal-button.h
    codebase/ide/libraries/signal/signal-buzzer.h
    codebase/ide/libraries/signal/signal-common.h
    codebase/ide/libraries/signal/signal-hue.h
    codebase/ide/libraries/signal/signal-knuth.h
    codebase/ide/libraries/signal/signal-leds.h
    codebase/ide/libraries/signal/signal-main.h
    codebase/ide/libraries/signal/signal-serial.h
    codebase/ide/libraries/signal/signal-wifi.h

    codebase/ide/libraries/ESPEssentials
    codebase/ide/libraries/FastLED
    codebase/ide/libraries/WiFiManager

In VSCode the places are different. Here I didn't really managed to get the PICO2
code compile (there are too many contradicting suggestions on the web so it has
to wait). But the ESP32 should work out. Eventually you should have these
directories and files:

    codebase/vscode/platformio.ini

    codebase/vscode/src/context-lmtx-signal.cpp

    codebase/vscode/lib/signal/signal-bluetooth.cpp
    codebase/vscode/lib/signal/signal-button.cpp
    codebase/vscode/lib/signal/signal-buzzer.cpp
    codebase/vscode/lib/signal/signal-common.cpp
    codebase/vscode/lib/signal/signal-hue.cpp
    codebase/vscode/lib/signal/signal-knuth.cpp
    codebase/vscode/lib/signal/signal-leds.cpp
    codebase/vscode/lib/signal/signal-main.cpp
    codebase/vscode/lib/signal/signal-serial.cpp
    codebase/vscode/lib/signal/signal-wifi.cpp
    codebase/vscode/lib/signal/signal-bluetooth.h
    codebase/vscode/lib/signal/signal-button.h
    codebase/vscode/lib/signal/signal-buzzer.h
    codebase/vscode/lib/signal/signal-common.h
    codebase/vscode/lib/signal/signal-hue.h
    codebase/vscode/lib/signal/signal-knuth.h
    codebase/vscode/lib/signal/signal-leds.h
    codebase/vscode/lib/signal/signal-main.h
    codebase/vscode/lib/signal/signal-serial.h
    codebase/vscode/lib/signal/signal-wifi.h

    % needed: 

    codebase/vscode/.pio/libdeps/esp32dev/FastLED

    % not needed any more:

 %  codebase/vscode/.pio/libdeps/esp32dev/ESPEssentials
 %  codebase/vscode/.pio/libdeps/esp32dev/WiFiManager

For now this works ok but it might evolve over time. For a long time TeX
distributions were considered complex and huge but these development environments
can dwarf those. I also wonder how fragile this all is in the long run.

The IDE ino file is just a cpp file with a different suffix but all other files
use the cpp (or h) suffix; using the c suffix didn't work out well but the signal
files are for the most part just plain c.

The platformio.ini file looks like this:

; PlatformIO Project Configuration File
;
;   Build options: build flags, source filter
;   Upload options: custom upload port, speed and extra flags
;   Library options: dependencies, extra library storages
;   Advanced options: extra scripting
;
; Please visit documentation for the other options and examples
; https://docs.platformio.org/page/projectconf.html

[env:esp32-s3-devkitc-1]
platform = espressif32
board = esp32-s3-devkitc-1
framework = arduino
board_build.arduino.memory_type = qio_qspi
board_build.flash_mode = qio
board_upload.flash_size = 4MB
board_upload.maximum_size = 4194304
board_build.partitions = default.csv
lib_deps = 
    fastled/FastLED@^3.10.1
build_flags = 
    -DARDUINO_USB_MODE=1
    -DARDUINO_USB_CDC_ON_BOOT=1
    -DSIGNAL_USE_DEVICE=ESP32
    -DSIGNAL_USE_BUTTONS=1
    -DSIGNAL_USE_HUE=1
    -DSIGNAL_USE_CHARACTERS=2
    -DSIGNAL_USE_FILESYSTEM=1
    
For the PICO I didn't manage to make a configuration section that got rid of the
missing __lockBluetooth(); etc error messages. I'll check again at some point.

The code is not perfect but not that critical either. After all it's a bit of a
pet project that just came by as distraction.

HH
