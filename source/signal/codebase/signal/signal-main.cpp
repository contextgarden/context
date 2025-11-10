/*
    See license.txt in the root of this project.
*/

/*

    This gadget evolved out of a presentaiton at BachoTeX 2025 (flagged pdf) where we used hue 
    bulbs to enhance the presentation. As side track we demonstrated error reporting using QR 
    codes and keeping track of the job status with color lamps. As follow up Mojca, Willi, 
    Mikael and Hans decided to make a decidated device for the ConTeXt 2025 meeting.

    This file (and what comes with it) is part of the ConTeXt distrbution and thereby falls 
    under the same (open) license (as usual in TeX distributions).

    Todo: At some point we can do some more condensing with helpers now that I know what we 
    want and what is needed. But maybe quadrants and segments will differ more in functionality 
    at some point, as they originally did. 

    The gadget works best with a (direct) serial (usb) connection because it should not delay a 
    run. There is  amanual in the ConTeXt distribution that explains how to control the various 
    signal modes and the mtx signal script can be used to manage the lot. When in squid mode, 
    normal ConteXt runner will handle initialization but ConTeXt itself updates the states. 

    We started out with a hue based setup. Then went for a rpi pico wifi alternative and
    eventually took a serial as a reference so in the end all code will reflect that. Using the
    arduino IDE code was stepwise added. Then Mojca decided to go for a ESP on the gadget board 
    and suggested using VSCODE which actually was bit less comfortable but in the end I decided 
    to play with it and split the files up. It's not perfect but it's also not meant to be a 
    major showcase of programming either. 

    We can consider user based color palettes that we can set with mtx-signal. In practice we 
    have just a limited set because that's easy to distinguish but some color blind users might 
    prefer different mappings. For now we just have a few (ia1 and ia2). By default this gadget
    has 24 leds and two buttons.

    Hans Hagen and friends 
    Hasselt NL, 2025

    www.contextgarden.net
    www.pragma-ade.nl

*/

 /* We keep this available (mainly for hue control): */
 
# ifndef SIGNAL_USE_WIFI
    # define SIGNAL_USE_WIFI 0
# endif 

 /* We might add support for bt some day: */

# ifndef SIGNAL_USE_BLUETOOTH
    # define SIGNAL_USE_BLUETOOTH 0
# endif 

 /* Who knows ... some esp devices have this: */

# ifndef SIGNAL_USE_ZIGBEE
    # define SIGNAL_USE_ZIGBEE 0
# endif 

# ifndef SIGNAL_USE_FILESYSTEM
    # define SIGNAL_USE_FILESYSTEM 0
# endif 

# ifndef SIGNAL_USE_USEBUTTONS
    # define SIGNAL_USE_BUITTONS 0
# endif 

/* 
    For the sake of platformio the single file was split in smaller ones and moved to 
    a lib path. However, in retrospect I just should have kept all in the single file 
    because in the end for supoirting the rpi pico the arduino ide was the better 
    choice. 

    Some features like bluetooth and buzzers (stubs) might go away as we progress. In 
    the end just plugging into serial is good enough and also relatively fast. The wifi 
    bit we keep for now because it can be used to synchronize two devices and we also 
    (for now) want to keep the hue feature. Both are optional and a bit of a side track.

    So, there might be a stripped down variant some day. It depends a bit on how we move 
    on with this adventure.
    
    Hans Hagen 
    Hasselt NL
    2024+
*/

# include <signal-common.h>
# include <signal-leds.h>
# include <signal-wifi.h>
# include <signal-hue.h>
# include <signal-bluetooth.h>
# include <signal-button.h>
# include <signal-buzzer.h>
# include <signal-serial.h>

/*
    The setup is just calling initializers from the above subsystems. By default
    we don't enable WIFI, BT and HUE. 
*/

signal_configuration_info *configuration_in_ram;
signal_currentstatus_info *currentstatus_in_ram;

signal_configuration_info *signal_get_configuration(void) { return configuration_in_ram; } 
signal_currentstatus_info *signal_get_currentstatus(void) { return currentstatus_in_ram; }

void signal_main_setup(void)
{
    configuration_in_ram = (signal_configuration_info *) calloc(1, sizeof(signal_configuration_info));
    currentstatus_in_ram = (signal_currentstatus_info *) calloc(1, sizeof(signal_currentstatus_info));
    
    signal_settings_reset();
    signal_button_initialize();
    signal_leds_initialize();
    signal_settings_initialize();
    signal_serial_initialize();
    signal_buzzer_initialize();

    if (signal_configuration->mode & signal_mode_hue) {
        signal_hue_initialize();
    } else if (signal_configuration->mode & (signal_mode_wifi | signal_mode_access)) {
        signal_wifi_initialize();
    } else if (signal_configuration->mode & signal_mode_bluetooth) {
        signal_bluetooth_initialize();
    }

    /* signal_bluetooth_initialize(); */ /* a failed test */

    signal_leds_preroll();
}

/* 
    Here we have the main loop which is not that pretty but again, it evolved that way, 
    but I might change it. 
*/

void signal_main_loop(void)
{

    if ((signal_configuration->mode & signal_mode_serial) && signal_serial_handle()) {
        /* okay */
 // } else if ((signal_configuration->mode & signal_mode_hue) && signal_serial_handle())) {
        /* okay */
    } else if (signal_button_processed()) { 
        /* okay */
    } else if (signal_leds_state_checked()) { 
        /* okay */
    } else if ((signal_configuration->mode & (signal_mode_wifi | signal_mode_access)) && signal_wifi_handle()) {    
        /* okay */
    } else if ((signal_configuration->mode & signal_mode_bluetooth) && signal_bluetooth_handle()) {
        /* okay */
    }    

    /* signal_bluetooth_handle(); */ /* a failed test */
}
