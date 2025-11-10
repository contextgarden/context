/*
    See license.txt in the root of this project.
*/

# include <signal-common.h>
# include <signal-font.h>
# include <signal-leds.h>
# include <signal-wifi.h>

/*
    The remapper is gone and we now just assume that on the 24 ring the first ine is at the 
    top so we don't need to shift the origin any longer. 
*/

void signal_leds_remap(void)
{
    if (signal_configuration->geometry == signal_geometry_rectangular) {
        signal_configuration->nofsegments   = signal_configuration->nofrows;
        signal_configuration->segmentcount  = signal_configuration->nofcolumns;
        signal_configuration->nofquadrants  = signal_configuration->nofrows;
        signal_configuration->quadrantcount = signal_configuration->nofcolumns;
    } else {
        switch (signal_configuration->nofleds) {
            case 12:
                signal_configuration->nofsegments   =  6;
                signal_configuration->segmentcount  =  2;
                signal_configuration->nofquadrants  =  4;
                signal_configuration->quadrantcount =  3;
                break;
            case 16:
                signal_configuration->nofsegments   =  8;
                signal_configuration->segmentcount  =  2;
                signal_configuration->nofquadrants  =  4;
                signal_configuration->quadrantcount =  4;
                break;
            case 20:
                signal_configuration->nofsegments   = 10;
                signal_configuration->segmentcount  =  2;
                signal_configuration->nofquadrants  =  4;
                signal_configuration->quadrantcount =  5;
                break;
            case 24:
                signal_configuration->nofsegments   =  8;
                signal_configuration->segmentcount  =  3;
                signal_configuration->nofquadrants  =  4;
                signal_configuration->quadrantcount =  6;
                break;
            case 30:
                signal_configuration->nofsegments   = 10;
                signal_configuration->segmentcount  =  3;
                signal_configuration->nofquadrants  =  2; /* exception */
                signal_configuration->quadrantcount = 15;
                break;
            case 40:
                signal_configuration->nofsegments   = 10;
                signal_configuration->segmentcount  =  4;
                signal_configuration->nofquadrants  =  4;
                signal_configuration->quadrantcount = 10;
                break;
            case 60:
                signal_configuration->nofsegments   = 10;
                signal_configuration->segmentcount  =  6;
                signal_configuration->nofquadrants  =  4;
                signal_configuration->quadrantcount = 15;
                break;
            case 144:
                signal_configuration->nofsegments   = 12; /*  8 */
                signal_configuration->segmentcount  = 12; /* 18 */
                signal_configuration->nofquadrants  =  4;
                signal_configuration->quadrantcount = 36;
                break;
            default:
                signal_configuration->nofsegments   = 1;
                signal_configuration->segmentcount  = 1;
                signal_configuration->nofquadrants  = 1;
                signal_configuration->quadrantcount = 1;
                break;
        }
    }
}

void signal_leds_save(void)
{
    memcpy(signal_currentstatus->saved, signal_currentstatus->leds, sizeof(signal_currentstatus->leds));
    signal_currentstatus->issaved = 1;
}

void signal_leds_restore(void)
{
    if (signal_currentstatus->issaved) {
        memcpy(signal_currentstatus->leds, signal_currentstatus->saved, sizeof(signal_currentstatus->leds));
        signal_currentstatus->issaved = 0;
    }
}

/*

One can have a look at:

https://www.nceas.ucsb.edu/sites/default/files/2022-06/Colorblind%20Safe%20Color%20Schemes.pdf

but for leds it is kind of tricky. It will become configurable but for now it's just
an hard coded decision.

*/

static inline void signal_leds_set(int index, CRGB color)
{
    if (index >= 1 && index <= signal_configuration->nofleds) {
        signal_currentstatus->leds[index - 1] = color;
    }
}

void signal_leds_set_single(int index, CRGB color)
{
    if (index >= 1 && index <= signal_configuration->nofleds) {
        signal_currentstatus->leds[index - 1] = color;
    }
}

void signal_leds_set_range(int min, int max, CRGB color)
{
    if (min < 1 ) { 
        min = 1;
    } 
    if (max > signal_configuration->nofleds) {
        max = signal_configuration->nofleds;
    }
    for (int i = min - 1; i <= max - 1; i++) {
        signal_currentstatus->leds[i] = color;
    }
}

/* colors */

void signal_leds_setcolors(void)
{
    signal_currentstatus->colors.black = CRGB(  0,  0,  0);
    signal_currentstatus->colors.white = CRGB(255,255,255);
    switch (signal_configuration->palette) {
        case 1:
            /* Okabe and Ito */
            signal_currentstatus->colors.red     = CRGB(213, 94,  0);
            signal_currentstatus->colors.green   = CRGB(  0,158,115);
            signal_currentstatus->colors.blue    = CRGB(  0,114,178);
            signal_currentstatus->colors.cyan    = CRGB( 86,180,233);
            signal_currentstatus->colors.magenta = CRGB(204,121,167);
            signal_currentstatus->colors.yellow  = CRGB(240,228, 66);
            signal_currentstatus->colors.orange  = CRGB(230,159,  0);
            break;
        case 2:
            /* Paul Tols Bright */
            signal_currentstatus->colors.red     = CRGB(220,205,125);
            signal_currentstatus->colors.green   = CRGB( 51,117, 56);
            signal_currentstatus->colors.blue    = CRGB( 46, 37,133);
            signal_currentstatus->colors.cyan    = CRGB( 93,168,153);
            signal_currentstatus->colors.magenta = CRGB(194,106,119);
            signal_currentstatus->colors.yellow  = CRGB(148,203,236);
            signal_currentstatus->colors.orange  = CRGB(187,187,187);
            break;
        default:
            signal_currentstatus->colors.red     = CRGB(255,  0,  0);
            signal_currentstatus->colors.green   = CRGB(  0,255,  0);
            signal_currentstatus->colors.blue    = CRGB(  0,  0,255);
            signal_currentstatus->colors.cyan    = CRGB(  0,255,255);
            signal_currentstatus->colors.magenta = CRGB(255,  0,255);
            signal_currentstatus->colors.yellow  = CRGB(255,255,  0);
            signal_currentstatus->colors.orange  = CRGB(255,165,  0);
            /* safeguard */
            signal_configuration->palette = 0;
            break;
    }
    signal_currentstatus->colors.reset    = signal_currentstatus->colors.black;
    signal_currentstatus->colors.off      = signal_currentstatus->colors.black;
    signal_currentstatus->colors.on       = signal_currentstatus->colors.white;
    signal_currentstatus->colors.busy     = signal_currentstatus->colors.blue;
    signal_currentstatus->colors.done     = signal_currentstatus->colors.yellow;
    signal_currentstatus->colors.finished = signal_currentstatus->colors.green;
    signal_currentstatus->colors.problem  = signal_currentstatus->colors.orange;
  //signal_currentstatus->colors.problem  = signal_currentstatus->colors.magenta;
  //signal_currentstatus->colors.problem  = signal_currentstatus->colors.cyan;
    signal_currentstatus->colors.error    = signal_currentstatus->colors.red;
    signal_currentstatus->colors.unknown  = signal_currentstatus->colors.white;
}

CRGB signal_leds_state_to_color(int state)
{
    switch (state) {
        case 'b': return signal_currentstatus->colors.busy;
        case 'd': return signal_currentstatus->colors.done;
        case 'f': return signal_currentstatus->colors.finished;
        case 'p': return signal_currentstatus->colors.problem;
        case 'e': return signal_currentstatus->colors.error;
        case 'u': return signal_currentstatus->colors.unknown;
        /* */
        case 'R': return signal_currentstatus->colors.red;
        case 'G': return signal_currentstatus->colors.green;
        case 'B': return signal_currentstatus->colors.blue;
        /* */
        case 'C': return signal_currentstatus->colors.cyan;
        case 'Y': return signal_currentstatus->colors.yellow;
        case 'M': return signal_currentstatus->colors.magenta;
        case 'K': return signal_currentstatus->colors.black;
        /* */
        case 'S': return signal_currentstatus->colors.white;
        case 'W': return signal_currentstatus->colors.white;
        /* */
        case 'O': return signal_currentstatus->colors.orange;
        /* */
        default : return signal_currentstatus->colors.reset;
    }
}

/* We deliberately snap to colors because at the other end we can have a diferent palette. */

String signal_leds_synchronize(void)
{
    String s; 
    s.reserve(signal_configuration->nofleds+1);
    for (int i=0; i < signal_configuration->nofleds; i++) {
        CRGB c = signal_currentstatus->leds[i];
        if (c == signal_currentstatus->colors.black  ) { s += 'K'; } else
        if (c == signal_currentstatus->colors.blue   ) { s += 'B'; } else 
        if (c == signal_currentstatus->colors.yellow ) { s += 'Y'; } else 
        if (c == signal_currentstatus->colors.green  ) { s += 'G'; } else 
        if (c == signal_currentstatus->colors.red    ) { s += 'R'; } else 
        if (c == signal_currentstatus->colors.orange ) { s += 'O'; } else 
        if (c == signal_currentstatus->colors.cyan   ) { s += 'C'; } else 
        if (c == signal_currentstatus->colors.magenta) { s += 'M'; } else 
        if (c == signal_currentstatus->colors.white  ) { s += 'W'; } else 
                                                       { s += 'K'; }
    }
    return s;
}

/* helpers */

static signal_range signal_leds_get_range(int slice, int length)
{
    signal_range range; 
    if (slice) {
        range.first = (slice - 1) * length + 1;
        range.last  = range.first + length - 1;
        if (range.first < 1) { 
            range.first = 1;
        }
        if (range.last > signal_configuration->nofleds) { 
            range.last = signal_configuration->nofleds;
        }
    } else { 
        range.first = 1;
        range.last = signal_configuration->nofleds;
    }
    return range;
}

signal_range signal_leds_get_segment(int *segment)
{
    if (*segment < 1) {
        *segment = 1;
    } else if (*segment > signal_configuration->nofsegments) {
        *segment = signal_configuration->nofsegments;
    }
    return signal_leds_get_range(*segment, signal_configuration->segmentcount);
}

signal_range signal_leds_get_quadrant(int *quadrant)
{
    if (*quadrant < 1) {
        *quadrant = 1;
    } else if (*quadrant > signal_configuration->nofquadrants) {
        *quadrant = signal_configuration->nofquadrants;
    }
    return signal_leds_get_range(*quadrant, signal_configuration->quadrantcount);
}

/* leds */

void signal_leds_initialize(void)
{
    signal_leds_remap();
    switch (signal_configuration->colororder) {
        case RGB: FastLED.addLeds<LED_CHIPSET, LED_USEDDATAPIN, RGB>(signal_currentstatus->leds, signal_configuration->nofleds); break;
        case GRB: FastLED.addLeds<LED_CHIPSET, LED_USEDDATAPIN, GRB>(signal_currentstatus->leds, signal_configuration->nofleds); break;
        default:  FastLED.addLeds<LED_CHIPSET, LED_USEDDATAPIN, GRB>(signal_currentstatus->leds, signal_configuration->nofleds); break;
    }
 // FastLED[0].setCorrection(TypicalLEDStrip);
    FastLED.clear();
}

int signal_leds_update(int state)
{
    switch (state) { 
        case signal_leds_on:
           break;
        case signal_leds_off:
           break;
        case signal_leds_up:
           signal_configuration->dimming += LED_BRIGHTNESSSTEP;
           if (signal_configuration->dimming > LED_BRIGHTNESSMAX) {
               signal_configuration->dimming = LED_BRIGHTNESSMAX;
           }
           break;
        case signal_leds_down:
           signal_configuration->dimming -= LED_BRIGHTNESSSTEP;
           if (signal_configuration->dimming < LED_BRIGHTNESSMIN) {
               signal_configuration->dimming = LED_BRIGHTNESSMIN;
           }
           break;
        case signal_leds_min:
           signal_configuration->dimming = LED_BRIGHTNESSMIN;
           break;
        case signal_leds_default:
           signal_configuration->dimming = LED_BRIGHTNESS;
           break;
        case signal_leds_max:
           signal_configuration->dimming = LED_BRIGHTNESSMAX;
           break;
    }
    if (state == signal_leds_off) {
        signal_currentstatus->lastturnofftime = 0;
    } else { 
        signal_currentstatus->lastturnofftime = millis();
    }
    FastLED.setBrightness(signal_configuration->dimming);
    FastLED.show();
    return 1;
}

int signal_leds_state_checked(void)
{
    if (signal_time_flied_by(signal_currentstatus->lastturnofftime, signal_configuration->turnofftime) && signal_leds_turn_off()) { 
        signal_currentstatus->lastturnofftime = 0;
        return 0;
    } else { 
        return 0;
    }
}

static void signal_leds_segment(int segment, CRGB color)
{
    signal_range range = segment ? signal_leds_get_segment(&segment) : signal_leds_whole_range();
    signal_leds_set_range(range.first, range.last, color);
    signal_leds_update(signal_leds_on);
}

void signal_leds_all(CRGB c, int flush)
{
    for (int i = 1; i <= signal_configuration->nofleds; i++) {
        signal_leds_set(i, c);
	}
    if (flush) {
        signal_leds_update(signal_leds_on);
    }
}

int signal_leds_okay(uint8_t *r, uint8_t *g, uint8_t *b, uint8_t *n, uint8_t *m)
{
    if (*n >= 1 && *n <= signal_configuration->nofleds) {
        if (*m == 0) {
            *m = *n;
        }
        if (*m >= 1 && *m <= signal_configuration->nofleds) {
            /* okay */
        } else {
            return 0;
        }
    } else {
        *n = 1;
        *m = signal_configuration->nofleds;
    }
    if (*m < *n) {
        *m = *n;
    }
    if (*r < 0) { *r = 0; } else if (*r > 255) { *r = 255; }
    if (*g < 0) { *g = 0; } else if (*g > 255) { *g = 255; }
    if (*b < 0) { *b = 0; } else if (*b > 255) { *b = 255; }
    return 1;
}

int signal_leds_next_palette(void)
{
    ++signal_configuration->palette;
    signal_leds_setcolors();
    signal_leds_preroll();
    return 1; 
}

static void signal_character_aux_replace(const char *s, CRGB yes, CRGB contrast, CRGB nop)
{
    if (s && strlen(s) == signal_configuration->nofleds) {
        for (int p = 1; p <= signal_configuration->nofleds; p++) {
            switch (*s) {
                case '-': 
                    signal_leds_set(p, nop); 
                    break;
                case '+': 
                    signal_leds_set(p, yes); 
                    break;
                case '!': 
                    signal_leds_set(p, contrast); 
                    break;
            }
            s++;
        }
    }
}

static void signal_character_aux_overlay(const char *s, CRGB yes)
{
    if (s && strlen(s) == signal_configuration->nofleds) {
        for (int p = 1; p <= signal_configuration->nofleds; p++) {
            if (*s == '+') {
                signal_leds_set(p, yes);
            }
            s++;
        }
    }
}

/* 
    This was used to show a Knuth 36 character but we no longer assume rectangular devices to 
    be used. This might come back in another way.

    */ /* 

void signal_leds_set_char(char c, CRGB yes, CRGB contrast, CRGB nop)
{
    if (signal_font_supported()) {
        signal_leds_all(signal_currentstatus->colors.reset, 0);
        if (signal_configuration->geometry == signal_geometry_rectangular) {
            const char *s = signal_character_get(c);
            if (s) {
                int columns = strlen(s) / 8;
                if (columns > 0) {
                    int x = signal_configuration->xoffset + 1;
                    int y = signal_configuration->yoffset + 1;
                    for (int r = 1; r <= 8; r++) {
                        int p = ((y - 1 + r - 1) * signal_configuration->nofcolumns) + x;
                        for (int c = 1; c <= columns; c++) {
                            if (p >= 0 && p <= signal_configuration->nofleds) {
                                switch (*s) {
                                    case '-':
                                        signal_leds_set(p++, nop);
                                        break;
                                    case '+':
                                        signal_leds_set(p++, yes);
                                        break;
                                    case '!':
                                        signal_leds_set(p++, contrast);
                                        break;
                                    default:
                                        return;
                                }
                                ++s;
                                ++p;
                            } else {
                                return;
                            }
                        }
                    }
                }
            }
        } else { 
            signal_character_aux_replace(signal_character_get(c), yes, contrast, nop);
        }
    } else {
        signal_leds_dark(signal_leds_on);
    }
}

*/

void signal_leds_set_char(char c, CRGB yes, CRGB contrast, CRGB nop)
{
    if (signal_font_supported()) {
        signal_leds_all(signal_currentstatus->colors.reset, 0);
        signal_character_aux_replace(signal_character_get(c), yes, contrast, nop);
    } else {
        signal_leds_dark(signal_leds_on);
    }
}

void signal_leds_set_number(int c, CRGB yes, CRGB nop)
{
    if (signal_font_supported()) {
        signal_leds_all(nop, 0);
        signal_character_aux_overlay(signal_digit_get_top   (c % 10), yes);
        signal_character_aux_overlay(signal_digit_get_bottom(c / 10), yes);
    } else { 
        signal_leds_dark(signal_leds_on);
    }
}

void signal_leds_show_string(const char *str, CRGB yes, CRGB nop, int d)
{
    if (signal_font_supported() && str) {
        while (*str) {
            signal_leds_set_char(*str, signal_currentstatus->colors.finished, signal_currentstatus->colors.finished, signal_currentstatus->colors.reset);
            signal_leds_update(signal_leds_on);
            delay(d);
            str++;
        }
        delay(d);
    }
    signal_leds_dark(signal_leds_on);
}

void signal_leds_dark(int flush)
{
    signal_leds_all(signal_currentstatus->colors.black, flush);
}

static void signal_leds_trace(CRGB c)
{
    signal_leds_all(c, 1);
    delay(TRACE_DELAY);
    signal_leds_all(signal_currentstatus->colors.black, 1);
}

void signal_leds_trace_check    (void) { signal_leds_trace(signal_currentstatus->colors.yellow); } // various checking / initialization
void signal_leds_trace_error    (void) { signal_leds_trace(signal_currentstatus->colors.red   ); } // something went wrong
void signal_leds_trace_okay     (void) { signal_leds_trace(signal_currentstatus->colors.green ); } // all went well
void signal_leds_trace_configure(void) { signal_leds_trace(signal_currentstatus->colors.blue  ); } // change configuration

void signal_leds_trace_wifi     (int what) { signal_leds_segment(what, signal_currentstatus->colors.magenta); }
void signal_leds_trace_bluetooth(int what) { signal_leds_segment(what, signal_currentstatus->colors.cyan);    }
void signal_leds_trace_hue      (int what) { signal_leds_segment(what, signal_currentstatus->colors.magenta); }

void signal_leds_preroll(void)
{
  /* We test the primary colors, not the states.  */
    CRGB states[] = {
        signal_currentstatus->colors.red,
        signal_currentstatus->colors.green,
        signal_currentstatus->colors.blue,
        signal_currentstatus->colors.cyan,
        signal_currentstatus->colors.magenta,
        signal_currentstatus->colors.yellow,
        signal_currentstatus->colors.white,
        signal_currentstatus->colors.black,
    //  signal_currentstatus->colors.orange,
    };
    /* We show everything. */
    for (int i = 0; i <= 7; i++) {
        signal_leds_all(states[i], 1);
        delay(TEST_DELAY);
    }
    signal_leds_all(signal_currentstatus->colors.black, 1);
    /* We show the segments. */
    for (int segment = 1; segment <= signal_configuration->nofsegments; segment++) {
        signal_range range = signal_leds_get_segment(&segment);
        signal_leds_set_range(range.first, range.last, states[(segment % 2) + 1]);
        signal_leds_update(signal_leds_on);
        delay(TEST_DELAY);
    }
    signal_leds_all(signal_currentstatus->colors.black, 1);
    /* We show the quadrants. */
    for (int quadrant = 1; quadrant <= signal_configuration->nofquadrants; quadrant++) {
        signal_range range = signal_leds_get_quadrant(&quadrant);
        signal_leds_set_range(range.first, range.last, states[(quadrant % 2) + 1]);
        signal_leds_update(signal_leds_on);
        delay(TEST_DELAY);
    }
    signal_leds_all(signal_currentstatus->colors.black, 1);
    /* We show the steps. */
    for (int i = 1; i <= signal_configuration->nofleds; i++) {
        signal_leds_set_range(i, i, signal_currentstatus->colors.white); 
        signal_leds_update(signal_leds_on);
        delay(STEP_DELAY);
    }
    /* We go dark. */
    signal_leds_all(signal_currentstatus->colors.black, 1);
}

int signal_leds_turn_on()
{
    signal_leds_restore(); 
    signal_leds_update(signal_leds_on);
    return 1;
}

int signal_leds_turn_off()
{
    signal_leds_save(); 
    signal_leds_all(signal_currentstatus->colors.black, 1);
 // signal_leds_update(signal_leds_off);
    return 1;
}

void signal_leds_from_string(String s)
{
    signal_leds_dark(0);
    for (int i = 0; i < signal_configuration->nofleds; i++) {
        signal_leds_set_single(i+1, signal_leds_state_to_color(s.charAt(i)));
    }
    signal_leds_update(signal_leds_on);
}