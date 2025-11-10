# well .. on lunix it has to be _ and on winbdows and mac -

SIGNAL_PORT=COM4:
SIGNAL_PORT=/dev/tty.usbmodem14101
SIGNAL_PORT=/dev/ttyACM0
SIGNAL_BAUD=115200
SIGNAL_BAUD=460800

SIGNAL_BOOT=bootloader.bin
SIGNAL_PARTITIONS=partitions.bin
SIGNAL_ESPBOOT=boot_app0.bin
SIGNAL_PROGRAM=firmware.bin

esptool.py \
--chip esp32s3 \
--port $SIGNAL_PORT \
--baud $SIGNAL_BAUD \
--before usb_reset \
--after hard_reset \
write_flash \
-z \
--flash_mode dio \
--flash_freq 80m \
--flash_size 4MB \
0x000000 $SIGNAL_BOOT \
0x008000 $SIGNAL_PARTITIONS \
0x00e000 $SIGNAL_ESPBOOT \
0x010000 $SIGNAL_PROGRAM
