REM pip install esptool
REM esptool -p PORT flash-id

copy /Y ..\..\codebase\vscode\.pio\build\esp32-s3-devkitc-1\spiffs.bin
copy /Y ..\..\codebase\vscode\.pio\build\esp32-s3-devkitc-1\*.bin
copy /Y "c:\Users\Hans Hagen\.platformio\packages\framework-arduinoespressif32\tools\partitions\boot_app0.bin"
