/*
    See license.txt in the root of this project.
*/

# if SIGNAL_USE_BLUETOOTH == 1

    /*
        This is a waste of time. Although we can pair from windows a serial connection doesn't 
        work because somehow the esp doesn't tell windows that it is a serial device. One can 
        get it to relate to a port but even then ... it also keeps dropping off. I wonder why 
        the classic BT was dropped ... it makes the device less interesting. 
    */

    // # include <BleSerial.h>
    // # include <signal-common.h>
    // # include <signal-leds.h>

    // BleSerial SerialBT;

    int signal_bluetooth_initialize(void)
    {
    // SerialBT.begin("CONTEXT SIGNAL BT");
    // SerialBT.setTimeout(10);
        return 0
    }

    int signal_bluetooth_handle(void)
    {
    // if (SerialBT.available()) {
    //     signal_leds_trace_wifi(2);
    //     while (SerialBT.available()) {
    //         SerialBT.read();
    //     }
    // }
        return 0;
    }

# else

    int signal_bluetooth_initialize(void)
    {
        return 0;
    }

    int signal_bluetooth_handle(void)
    {
        return 0;
    }

# endif
