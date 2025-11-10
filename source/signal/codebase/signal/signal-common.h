/*
    See license.txt in the root of this project.
*/

# ifndef SIGNAL_COMMON_H
# define SIGNAL_COMMON_H

# include <Arduino.h>

// We use pin 4 5 6 but one of them is often used for flash and not all are exposed on the 
// test board that i have. So in retrospect 17 for S1, 18 for S2 and 21 for LED might be 
// more generic (and are also available on the pi afaiks).  

# if (defined(PICO_RP2040) || defined(PICO_RP2350))
 // # include "pico/stdlib.h"
 // # include <hardware/gpio.h>
 // # include <driver/gpio.h>
 // # include "stdlib.h"
    # include <SDFS.h>
# else
    # include <stdio.h>
    # include <driver/gpio.h>
# endif

/* Libraries needed (install in Arduino IDE): FastLED WiFi WebServer LittleFS */

# define SIGNAL_VERSION        1
# define SIGNAL_REVISION       8
# define SIGNAL_BANNER         "context lmtx signal" /* 20 bytes */ /* cot squid mode */

# define SIGNAL_DEVICE         1

# define SIGNAL_CONFIGURATION  "configuration.dat"

# define ONE_SECOND         1000
# define ONE_MINUTE        60000

# define TEST_DELAY          200
# define WIFI_DELAY        10000
# define TRACE_DELAY        2000
# define BOUNCE_DELAY        100
# define STEP_DELAY          100
# define RECONNECT_DELAY   60000

/* 
    todo: generalize the three into a struct with properties; in the end we evolved 
    to that. This save a little code as we can share more and the geometries are more 
    or less frozen anyway.  
*/

typedef struct signal_quantity { 
    int nofleds; 
    int slice;
    /* maybe more */ 
} signal_quantity; 

typedef struct signal_range { 
    int first; 
    int last; 
} signal_range; 

# include <signal-leds.h>

typedef struct hue {
    char token [64];
    char hub [64];
    int  lights [4];
    int  noflights;
} hue;

typedef enum hue_states { 
    hue_state_unknown, 
    hue_state_disabled,
    hue_state_no_hub,
    hue_state_no_token,
    hue_state_no_lights,
    hue_state_no_wifi,
    hue_state_failure,
} hue_states;

typedef enum signal_modes {
    signal_mode_serial    = 0x01,
    signal_mode_wifi      = 0x02,
    signal_mode_bluetooth = 0x04,
    signal_mode_hue       = 0x08,
    signal_mode_access    = 0x10,
    signal_mode_forward   = 0x20,
} signal_modes;

typedef enum signal_devices {
    signal_device_unknown     = 0x00, /* Hope for the best, i.e. one needs to set up leds. */
    signal_device_original    = 0x01, /* The original 24 setup of the 2025 meeting. */
    signal_device_alternative = 0x02, /* A rectangular variant. */
} signal_devices;

typedef enum signal_geometry {
    signal_geometry_circular    = 0x00,
    signal_geometry_rectangular = 0x01,
} signal_geometry;

typedef enum signal_led_states { 
    signal_leds_unknown = 0x00,
    signal_leds_on      = 0x01,
    signal_leds_off     = 0x02,
    signal_leds_up      = 0x03,
    signal_leds_down    = 0x04,
    signal_leds_min     = 0x05,
    signal_leds_default = 0x06,
    signal_leds_max     = 0x07,
} signal_led_states;

typedef enum signal_synchronizers { 
    signal_synchronizer_none,
    signal_synchronizer_server,
    signal_synchronizer_client,
} signal_synchronizers;

typedef struct signal_configuration_info {
    /* these are used for sanity checks */
    char          banner [24];
    int           version;
    int           revision;
    /* when more than zero we have a proper context gadget */
    int           device;
    int           geometry;
    int           nofrows;
    int           nofcolumns;
    int           xoffset;
    int           yoffset;
    int           colororder;
    /* these determine the led configuration */
    int           nofleds;        /* normally 24 is more than enough and also optiomal */
    int           nofsegments;    /* this relates to the number of runs, often max 9 */
    int           segmentcount;
    int           nofquadrants;   /* this gives less granularity in the number of runs */
    int           quadrantcount;
    /* these can be set up */
    int           dimming;
    int           palette;
    unsigned long turnofftime;
    char          ssid [64];
    char          psk [64];
    char          forward [64];
    int           mode;
    int           remote; 
    int           synchronizer;
    uint8_t       peeraddress [6];
    hue           huedata;
 } signal_configuration_info;

# if SIGNAL_USE_DEVICE == ESP32
    # include <esp_now.h>
# endif 

typedef struct signal_currentstatus_info {
    /* these always starts out zero */
    int           wifi;
    int           bluetooth;
    int           filesystem; 
    int           squid;
    int           squids [10];
    unsigned long lastturnofftime;
    unsigned long lastcheckedwifi;
    /* palettes */
    scp           colors;
    int           issaved;
    CRGB          leds[LED_MAXNOFLEDS];
    CRGB          saved[LED_MAXNOFLEDS];
    /* done */
 } signal_currentstatus_info;

int  signal_settings_initialize (void);
void signal_settings_reset      (void);
void signal_settings_save       (void);
void signal_settings_load       (void);
int  signal_settings_prepare    (void);

int  signal_time_flied_by       (int n, int m);

/* 
    We need to make sure that this formerly just defined configuration blob doesn't end
    up in static flash when we have no memory chips. 
*/

signal_configuration_info *signal_get_configuration(void); 
signal_currentstatus_info *signal_get_currentstatus(void); 

# define signal_configuration signal_get_configuration()
# define signal_currentstatus signal_get_currentstatus()

# endif
