// A problem, is that the IDE already forces a load of arduino.h before the next kicks in. 

# ifndef SIGNAL_USE_DEVICE 

 // # define SIGNAL_USE_DEVICE SIGNAL_USE_RPIPICO2
    # define SIGNAL_USE_DEVICE SIGNAL_USE_ESP32

# endif

//# define SIGNAL_USE_WIFI       0
//# define SIGNAL_USE_HUE        0
//# define SIGNAL_USE_BLUETOOTH  0
//# define SIGNAL_USE_ZIGBEE     0
//# define SIGNAL_USE_FILESYSTEM 0
//# define SIGNAL_USE_BUTTONS    1
//# define SIGNAL_USE_CHARACTERS 0

# include <signal-main.h>

void setup(void)
{
    signal_main_setup();
}

void loop(void)
{
   signal_main_loop();
}
