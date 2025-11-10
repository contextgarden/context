/*
    See license.txt in the root of this project.
*/

# ifndef SIGNAL_LEDS_H
# define SIGNAL_LEDS_H

/* leds, we number from 1 .. N_OF_LEDS, so we're not zero based */

# define LED_CHIPSET           WS2812B  /* todo: put in configuration */
# define LED_COLORORDER        GRB      
//define LED_USEDDATAPIN       12 // 6        /* todo: put in configuration */
# define LED_USEDDATAPIN       4        /* todo: put in configuration */
# define LED_USEDCLOCKPIN      7        /* todo: put in configuration */

# define LED_BRIGHTNESSMAX    14       
# define LED_BRIGHTNESS       10        /* we want to stay within what the board can drive, for now */
# define LED_BRIGHTNESSMIN     4       
# define LED_BRIGHTNESSSTEP    2
# define LED_TURNOFFTIME      30        /* half an hour */
# define LED_MAXNOFLEDS      160        /* more makes little sense (these sell/meter) */

# define LED_NOFLEDS          24
# define LED_NOFSEGMENTS       8
# define LED_SEGMENTCOUNT      3
# define LED_NOFQUADRANTS      4
# define LED_QUADRANTCOUNT     6

// # define FASTLED_ALLOW_INTERRUPTS 1
// # define FASTLED_ESP32_I2S true

# include <signal-common.h>
# include <FastLED.h>

typedef struct scp {  /* signal_color_palette */
  /* generic primary colors */
    CRGB black;
    CRGB white;
    CRGB red;
    CRGB green;
    CRGB blue;
    CRGB cyan;
    CRGB magenta;
    CRGB yellow;
    CRGB orange;
    /* user intertface colors */
    CRGB reset;
    CRGB off;
    CRGB on;
    CRGB busy;
    CRGB done;
    CRGB finished;
    CRGB problem;
    CRGB error;
    CRGB unknown;
} scp;

void signal_leds_remap                  (void);
void signal_leds_setcolors              (void);
void signal_leds_initialize             (void);
void signal_leds_preroll                (void);
int  signal_leds_turn_on                (void);
int  signal_leds_turn_off               (void);
int  signal_leds_update                 (int state);
  
void signal_leds_trace_check            (void); // initialization
void signal_leds_trace_error            (void); // something went wrong
void signal_leds_trace_okay             (void); // all went well
void signal_leds_trace_configure        (void); // change configuration

void signal_leds_trace_wifi             (int what);
void signal_leds_trace_bluetooth        (int what);
void signal_leds_trace_hue              (int what);

void signal_leds_all                    (CRGB c, int flush);
void signal_leds_dark                   (int flush);
int  signal_leds_okay                   (uint8_t *r, uint8_t *g, uint8_t *b, uint8_t *n, uint8_t *m);

signal_range signal_leds_get_segment    (int *segment);
signal_range signal_leds_get_quadrant   (int *quadrant);
signal_range signal_leds_whole_range    (void);

void signal_leds_set_char               (char c, CRGB yes, CRGB contrast, CRGB nop);
void signal_leds_set_number             (int n, CRGB yes, CRGB nop);
void signal_leds_show_string            (const char *str, CRGB yes, CRGB nop, int d);
void signal_leds_set_range              (int min, int max, CRGB color);
void signal_leds_set_single             (int n, CRGB color);

CRGB   signal_leds_state_to_color       (int c);
String signal_leds_synchronize          (void);

int  signal_leds_state_checked          (void);
int  signal_leds_next_palette           (void);

void signal_leds_save                   (void);
void signal_leds_restore                (void);

void signal_leds_from_string            (String s);


# endif
