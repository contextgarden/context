REM pip install esptool
REM esptool -p PORT flash-id

REM ~ copy /Y ..\..\codebase\vscode\.pio\build\esp32-s3-devkitc-1\spiffs.bin
REM ~ copy /Y ..\..\codebase\vscode\.pio\build\esp32-s3-devkitc-1\*.bin
REM ~ copy /Y "c:\Users\Hans Hagen\.platformio\packages\framework-arduinoespressif32\tools\partitions\boot_app0.bin"

REM ~ devmgmt.msc

set SIGNAL_PORT=COM5
set SIGNAL_BAUD=115200
set SIGNAL_BAUD=460800

set SIGNAL_BOOT=bootloader.bin
set SIGNAL_PARTITIONS=partitions.bin
set SIGNAL_ESPBOOT=boot_app0.bin
set SIGNAL_PROGRAM=firmware.bin

c:\data\system\python\scripts\esptool.exe ^
--chip esp32s3 ^
--port "%SIGNAL_PORT%" ^
--baud %SIGNAL_BAUD% ^
--before usb-reset ^
--after hard-reset ^
write-flash ^
-z ^
--flash-mode dio ^
--flash-freq 80m ^
--flash-size 4MB ^
0x000000 %SIGNAL_BOOT% ^
0x008000 %SIGNAL_PARTITIONS% ^
0x00e000 %SIGNAL_ESPBOOT% ^
0x010000 %SIGNAL_PROGRAM%
