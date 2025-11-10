/*
    See license.txt in the root of this project.
*/

/* 
    This evolved and will condense a bit more as we can share. In squid mode (all 24) we 
    are different than with the other two modes where we need to distribute, but keeping 
    separate code paths for both makes sense as we don't know yet if or when they will 
    diverge.
*/

# include <signal-common.h>
# include <signal-wifi.h>
# include <signal-bluetooth.h>
# include <signal-hue.h>

# define UsedSerial Serial

# define SERIAL_RX_BUFFER_SIZE 1024
# define SERIAL_BAUD           115200

int signal_serial_initialize(void)
{
    UsedSerial.setRxBufferSize(SERIAL_RX_BUFFER_SIZE);
    UsedSerial.begin(SERIAL_BAUD);
    UsedSerial.setTimeout(100);
    return 1;
}

static void signal_serial_aux_flush(void)
{
    while (UsedSerial.available() > 0) {
        UsedSerial.read();
    }
}

static int signal_serial_next_is_char(void)
{
    while (1) {
        if (UsedSerial.available() > 0) {
            char nxt = UsedSerial.peek();
            if (nxt == ' ') { 
                UsedSerial.read();
                continue;
            } else {
                return 1;
            }
        } else { 
             return 0;
        }
    }
}

static int signal_serial_next_is_digit(void)
{
    while (1) {
        if (UsedSerial.available() > 0) {
            char nxt = UsedSerial.peek();
            if (nxt >= '0' && nxt <= '9') {
                return 1;
            } else if (nxt == ' ') { 
                UsedSerial.read();
                continue;
            } else { 
                return 0;
            }
        } else { 
            return 0;
        }
    }
}

static uint8_t signal_serial_get_command(void)
{
    if (signal_serial_next_is_char()) {
        return UsedSerial.read();
    } else { 
        return 0;
    }
}

static uint8_t signal_serial_get_cardinal_1(void)
{
    char c[2] = { '0', '\0' };
    if (signal_serial_next_is_digit()) {
        c[0] = UsedSerial.read();
    }
    return atoi(c);
}

static int signal_serial_get_cardinal_4(void)
{
    char c[5] = { '\0', '\0', '\0', '\0', '\0' };
    for (int i = 0; i < 4; i++) { 
        if (signal_serial_next_is_digit()) {
            c[i] = UsedSerial.read();
        } else { 
            break;
        }
    }
    return atoi(c);
}

static uint8_t signal_serial_get_byte(void)
{
    if (UsedSerial.available() > 0) {
        return UsedSerial.read();
    } else {
        return 0;
    }
}
static uint8_t signal_serial_get_string(char *buffer, int size)
{
    if (UsedSerial.available() > 0) {
        uint8_t length = 0;
        bzero(buffer, size);
        while (1) {
            if (UsedSerial.available() > 0) {
                char c = UsedSerial.read();
                switch (c) {
                    case '\r':
                    case '\n':
                    case '\0':
                        return length;
                    default:
                        if (length < size - 1) {
                            buffer[length++] = c;
                        }
                        break;
                }
            } else {
                return length;
            }
        }
    } else {
        return 0;
    }
}

static void signal_serial_upto_newline(void)
{
    int eol = 0;
    while (UsedSerial.available() > 0) {
        switch (UsedSerial.peek()) {
            case '\r': case '\n':
                eol = 1;
                UsedSerial.read();
                return;
            default:
                if (eol) {
                    return;
                } else {
                    UsedSerial.read();
                    break;
                }
        }
    }
}

static void signal_serial_hue_sync(int index, int state)
{
    if (signal_configuration->mode & signal_mode_hue) { 
        if (index) {
            signal_serial_hue_set_light(index, state);
        } else { 
            for (int i = 1; i <= signal_configuration->huedata.noflights; i++) {
                signal_serial_hue_set_light(i, state);
            }
        }
    }
}

/* direct */

static void signal_serial_direct(void)
{
    uint8_t n = signal_serial_get_byte();
    uint8_t m = signal_serial_get_byte();
    uint8_t r = signal_serial_get_byte();
    uint8_t g = signal_serial_get_byte();
    uint8_t b = signal_serial_get_byte();
    if (signal_leds_okay(&r, &g, &b, &n, &m)) {
        signal_leds_set_range(n, m, CRGB(r,g,b));
    }
}

/* individual */

static void signal_serial_individual(void)
{
    uint8_t n = signal_serial_get_byte();
    uint8_t r = signal_serial_get_byte();
    uint8_t g = signal_serial_get_byte();
    uint8_t b = signal_serial_get_byte();
    if (signal_leds_okay(&r, &g, &b, &n, &n)) {
        signal_leds_set_range(1, signal_configuration->nofleds, signal_currentstatus->colors.reset);
        signal_leds_set_single(n, CRGB(r,g,b));
    }
}

/* 

todo: list commands, see manual

*/

signal_range signal_leds_whole_range(void) 
{
    return (signal_range) { 
        .first = 1, 
        .last  = signal_configuration->nofleds 
    };
}

static inline int signal_leds_valid_squid(int squid) 
{
    return 
        squid < 0 ? 1 
      : squid > signal_configuration->nofleds ? signal_configuration->nofleds 
      : squid;
}

static inline int signal_leds_valid_quadrant(int quadrant) 
{
    return 
        quadrant < 0 ? 1 
      : quadrant > signal_configuration->nofquadrants ? signal_configuration->nofquadrants 
      : quadrant;
}

static inline int signal_leds_valid_segment(int segment) 
{
    return 
        segment < 0 ? 1 
      : segment > signal_configuration->nofsegments ? signal_configuration->nofsegments 
      : segment;
}

static void signal_serial_reset_states(void)
{
    signal_currentstatus->squid = 0;
    signal_currentstatus->lastturnofftime = 0;
    bzero(&signal_currentstatus->squids, sizeof(signal_currentstatus->squids));
}

static void signal_mark_busy_count(signal_range range, int squid, CRGB color)
{
    int slice = range.last - range.first + 1; 
    int index = squid % slice;
    signal_leds_set_range(range.first, range.last, signal_currentstatus->colors.done);
    signal_leds_set_single(range.first + index, color); 
}

static int signal_set_busy_count(signal_range range, int squid)
{
 // int slice = range.last - range.first + 1; 
 // int index = squid % slice;
 // signal_leds_set_range(range.first, range.last, signal_currentstatus->colors.done);
 // signal_leds_set_single(range.first + index, signal_currentstatus->colors.busy); 
    signal_mark_busy_count(range, squid, signal_currentstatus->colors.busy);
    return ++squid;
}

static void signal_serial_reset(void)
{
    signal_serial_reset_states();
    signal_leds_all(signal_currentstatus->colors.reset, 0);
}

static void signal_serial_squid_reset_range(signal_range range)
{
    signal_leds_set_range(range.first, range.last, signal_currentstatus->colors.reset);
    signal_serial_reset_states();
}

static void signal_serial_squid_set_range(signal_range range, int state)
{
    signal_leds_set_range(range.first, range.last, signal_leds_state_to_color(state));
}

static void signal_serial_all_rest(int state)
{
    signal_leds_all(signal_leds_state_to_color(state), 0);
}

static void signal_serial_all_step(void)
{
    /* todo: maybe no need of count > 0 */
    signal_leds_all(signal_currentstatus->colors.busy, 0);
}

static void signal_serial_squid_reset(void)
{
    signal_serial_squid_reset_range(signal_leds_whole_range());
}

static void signal_serial_segment_reset(void)
{
    int segment = signal_serial_get_cardinal_1();
    if (segment) {
        signal_serial_squid_reset_range(signal_leds_get_segment(&segment));
    } else { 
        signal_serial_squid_reset_range(signal_leds_whole_range());
    }
    signal_serial_hue_sync(segment, 'r');
}

static void signal_serial_quadrant_reset(void)
{
    int quadrant = signal_serial_get_cardinal_1();
    if (quadrant) {
        signal_serial_squid_reset_range(signal_leds_get_quadrant(&quadrant));
    } else {
        signal_serial_squid_reset_range(signal_leds_whole_range());
    }
    signal_serial_hue_sync(quadrant, 'r');
}

static void signal_serial_squid_step(void)
{
    signal_currentstatus->squid = signal_set_busy_count(signal_leds_whole_range(), signal_currentstatus->squid);
}

static void signal_serial_squid_mark(void)
{
    signal_mark_busy_count(signal_leds_whole_range(), signal_currentstatus->squid, signal_currentstatus->colors.magenta);
}

static void signal_serial_segment_step(void)
{
    int segment = signal_serial_get_cardinal_1(); // || signal_configuration->current;
    if (segment) {
        signal_currentstatus->squids[segment] = signal_set_busy_count(signal_leds_get_segment(&segment), signal_currentstatus->squids[segment]);
        if (signal_currentstatus->squids[segment] == 1) {
            signal_serial_hue_sync(segment, 'b');
        }
    }
}

static void signal_serial_quadrant_step(void)
{
    int quadrant = signal_serial_get_cardinal_1();
    if (quadrant) {
        signal_currentstatus->squids[quadrant] = signal_set_busy_count(signal_leds_get_quadrant(&quadrant), signal_currentstatus->squids[quadrant]);
        if (signal_currentstatus->squids[quadrant] == 1) {
            signal_serial_hue_sync(quadrant, 'b');
        }
    }
}

static void signal_serial_quadrant_mark(void)
{
    int quadrant = signal_serial_get_cardinal_1();
    if (quadrant) {
        signal_mark_busy_count(signal_leds_get_quadrant(&quadrant), signal_currentstatus->squids[quadrant], signal_currentstatus->colors.magenta);
     // if (signal_currentstatus->squids[quadrant] == 1) {
     //     signal_serial_hue_sync(quadrant, 'b');
     // }
    }
}

static void signal_serial_squid_color(int state) /* move */
{
    int squid = signal_serial_get_cardinal_4();
    if (squid) {
        if (squid > signal_configuration->nofleds) {
            squid = signal_configuration->nofleds;
        }
        signal_leds_set_single(squid, signal_leds_state_to_color(state));
    } else {
        signal_leds_all(signal_leds_state_to_color(state), 0);
    }
    signal_serial_hue_sync(squid, state);
}

static void signal_serial_squid_one(int state) /* move */
{
    int squid = signal_serial_get_cardinal_4();
    if (squid) {
        if (squid > signal_configuration->nofleds) {
            squid = signal_configuration->nofleds;
        }
        signal_leds_set_single(squid, signal_leds_state_to_color(state));
    }
}

static void signal_serial_squid_feedback(int state) /* move */
{
    int squid = signal_serial_get_cardinal_4();
    if (squid) {
        if (squid > signal_configuration->nofleds / 2) {
            squid = signal_configuration->nofleds / 2;
        }
        signal_leds_set_range(2 * (squid - 1) + 1, 2 * (squid - 1) + 2, signal_leds_state_to_color(state));
    }
}

static void signal_serial_squid_rest(int state)
{
    signal_serial_squid_set_range(signal_leds_whole_range(), state);
    signal_serial_hue_sync(1, state);
}

static void signal_serial_segment_rest(int state)
{
    int segment = signal_serial_get_cardinal_1();
    if (segment) {
        signal_serial_squid_set_range(signal_leds_get_segment(&segment), state);
    } else {
        signal_leds_all(signal_leds_state_to_color(state), 0);
    }
    signal_serial_hue_sync(segment, state);
}

static void signal_serial_quadrant_rest(int state)
{
    int quadrant = signal_serial_get_cardinal_1();
    if (quadrant) {
        signal_serial_squid_set_range(signal_leds_get_quadrant(&quadrant), state);
    } else {
        signal_leds_all(signal_leds_state_to_color(state), 0);
    }
    signal_serial_hue_sync(quadrant, state);
}

static void signal_serial_all(void)
{
    int cmd = signal_serial_get_command();
    switch (cmd) {
        case 'i': case 'r':           signal_serial_squid_reset(   ); break;
        case 's':                     signal_serial_all_step   (   ); break;    
        case 'b': case 'd': case 'f': 
        case 'p': case 'e': case 'u': /* */
        case 'R': case 'G': case 'B':
        case 'C': case 'M': case 'Y':    
        case 'K': case 'S': case 'W': 
        case 'O':                     signal_serial_all_rest   (cmd); break;
    }
}

static void signal_serial_squid(void)
{
    int cmd = signal_serial_get_command();
    switch (cmd) {
        case 'i': case 'r':           signal_serial_squid_reset(   ); break;
        case 's':                     signal_serial_squid_step (   ); break;
        case 'm':                     signal_serial_squid_mark (   ); break;
        case 'b': case 'd': case 'f': 
        case 'p': case 'e': case 'u': signal_serial_squid_rest (cmd); break;
        case 'R': case 'G': case 'B':
        case 'C': case 'M': case 'Y':    
        case 'K': case 'S': case 'W': 
        case 'O':                     signal_serial_squid_color(cmd); break;
    }
}

static void signal_serial_one(void)
{
    int cmd = signal_serial_get_command();
    switch (cmd) {
        case 'b': case 'd': case 'f': 
        case 'p': case 'e': case 'u':
        case 'R': case 'G': case 'B':
        case 'C': case 'M': case 'Y':    
        case 'K': case 'S': case 'W': 
        case 'O':                     signal_serial_squid_one(cmd); break;
    }
}

static void signal_serial_feedback(void)
{
    int cmd = signal_serial_get_command();
    switch (cmd) {
        case 'b': case 'd': case 'f': 
        case 'p': case 'e': case 'u':
        case 'R': case 'G': case 'B':
        case 'C': case 'M': case 'Y':    
        case 'K': case 'S': case 'W': 
        case 'O':                     signal_serial_squid_feedback(cmd); break;
    }
}

static void signal_serial_segment(void)
{
    int cmd = signal_serial_get_command();
    switch (cmd) {
        case 'i': case 'r':           signal_serial_segment_reset(   ); break;
        case 's':                     signal_serial_segment_step (   ); break;
        case 'b': case 'd': case 'f':
        case 'p': case 'e': case 'u': /* */
        case 'R': case 'G': case 'B':
        case 'C': case 'M': case 'Y':    
        case 'K': case 'S': case 'W': 
        case 'O':                     signal_serial_segment_rest (cmd); break;
    }
}

static void signal_serial_quadrant(void)
{
    int cmd = signal_serial_get_command();
    switch (cmd) {
        case 'i': case 'r':           signal_serial_quadrant_reset(   ); break;
        case 's':                     signal_serial_quadrant_step (   ); break;
        case 'm':                     signal_serial_quadrant_mark (   ); break;
        case 'b': case 'd': case 'f': 
        case 'p': case 'e': case 'u': /* */
        case 'R': case 'G': case 'B':
        case 'C': case 'M': case 'Y':    
        case 'K': case 'S': case 'W': 
        case 'O':                     signal_serial_quadrant_rest (cmd); break;
    }
}

static void signal_serial_text_reset(void)
{
    signal_serial_squid_reset_range(signal_leds_whole_range());
}

static void signal_serial_text_step(void)
{
    /* todo */
    signal_leds_set_char(signal_serial_get_byte(), signal_currentstatus->colors.busy, signal_currentstatus->colors.done, signal_currentstatus->colors.reset);
}

static void signal_serial_text_rest(int state)
{
    signal_leds_set_char(signal_serial_get_byte(), signal_leds_state_to_color(state), signal_currentstatus->colors.white, signal_currentstatus->colors.reset);
    signal_leds_update(signal_leds_on);
}

static void signal_serial_text(void)
{
    int cmd = signal_serial_get_command();
    switch (cmd) {
        case 'i': case 'r':           signal_serial_text_reset(   ); break;
        case 's':                     signal_serial_text_step (   ); break;
        case 'b': case 'd': case 'f': 
        case 'p': case 'e': case 'u': signal_serial_text_rest (cmd); break;
    }
}

static void signal_serial_number_reset(void)
{
    signal_serial_squid_reset_range(signal_leds_whole_range());
}

static void signal_serial_number_step(void)
{
    /* todo: counter */
    signal_leds_set_number(signal_serial_get_cardinal_4(), signal_currentstatus->colors.busy, signal_currentstatus->colors.reset);
}

static void signal_serial_number_rest(int state)
{
    signal_leds_set_number(signal_serial_get_cardinal_4(), signal_leds_state_to_color(state), signal_currentstatus->colors.reset);
    signal_leds_update(signal_leds_on);
}

static void signal_serial_number(void)
{
    int cmd = signal_serial_get_command();
    switch (cmd) {
        case 'i': case 'r':           signal_serial_number_reset(   ); break;
        case 's':                     signal_serial_number_step (   ); break;
        case 'b': case 'd': case 'f': 
        case 'p': case 'e': case 'u': signal_serial_number_rest (cmd); break;
    }
}

/*

cs    save
cf    format

cwr   wifi reset
cwc   wifi connect
cwi   wifi ssid    str 
cwk   wifi psk     str 

chr   hue reset
cht   hue token  str
chh   hue hub    str
chl   hue lights num [max 4 num]

ccN   color 0|1|2

cms   mode serial
cmh   mode serial + hue 
cmw   mode serial + wifi
cmb   mode serial + bluetooth
cma   mode serial + wifi + bluetooth

cdt   devide test 

*/

// use serial helpers 

int  signal_wifi_initialize(void);
int  signal_hue_initialize (void);

static int signal_serial_configure_wifi(void)
{
    switch (signal_serial_get_command()) {
        case 'r': // reset
            bzero(signal_configuration->ssid, 64);
            bzero(signal_configuration->psk, 64);
            return 1;
        case 's': // ssid
            signal_serial_get_string(signal_configuration->ssid, 64);
            return 1;
        case 'p': // psk
            signal_serial_get_string(signal_configuration->psk, 64);
            return 1;
        case 'c': // connect
            if (signal_configuration->mode & (signal_mode_wifi | signal_mode_access)) { 
                signal_wifi_initialize();
                return 1;
            } else if (signal_configuration->mode & signal_mode_hue) { 
                signal_hue_initialize();
                return 1;
            } else {
                return 0;
            }
        default:
            return 0;
    }
}

static int signal_serial_configure_hue(void)
{
    switch (signal_serial_get_command()) {
        case 'r':
            bzero(signal_configuration->huedata.token, 64);
            bzero(signal_configuration->huedata.hub, 64);
            return 1;
        case 't': // token
            signal_serial_get_string(signal_configuration->huedata.token, 64);
            return 1;
        case 'h': // hub
            signal_serial_get_string(signal_configuration->huedata.hub, 64);
            return 1;
        case 'l': // light
            {
                int n = signal_serial_get_cardinal_1();
                signal_configuration->huedata.noflights = 0;
                for (int i = 0; i <= 3; i++) {
                    signal_configuration->huedata.lights[i] = 0;
                }
                if (n >= 1 && n <= 4) {
                    for (int i = 1; i <= n; i++) {
                        int l = signal_serial_get_cardinal_4();
                        if (l) { 
                            signal_configuration->huedata.lights[signal_configuration->huedata.noflights] = l;
                            signal_configuration->huedata.noflights++;
                            //signal_leds_trace_hue();
                            return 1;
                        }
                    }
                }
            }
            return 0;
        default:
            return 0;
    }
}

static int signal_serial_configure_device(void)
{
    switch (signal_serial_get_command()) {
        /* we can't change the led binding when we change the led mapping too */ /* 
        case 'd':
            { 
                int n = signal_serial_get_cardinal_1();
                switch (n) { 
                    case signal_device_original:
                    case signal_device_alternative:
                        signal_configuration->device = n;
                        signal_settings_device();
                        signal_leds_initialize();
                        return 1;
                }
            }
            return 0;
        */ 
        /* we can't change the led count without side effects of the led binding */ /* 
        case 'n':
            { 
                int n = signal_serial_get_cardinal_4();
                if (n >= 1 && n <= LED_MAXNOFLEDS) {
                    //signal_configuration->nofleds = n;
                    //signal_configuration->ledorigin = 0;
                    //signal_leds_initialize();
                    //signal_leds_preroll();
                }
            }
            return 0;
        */
        case 'p':
            signal_leds_preroll();
            return 0;
        default:
            return 0;
    }
}

static int signal_serial_color(void)
{
    int palette = signal_serial_get_cardinal_1();
    if (palette != signal_configuration->palette) {
        signal_configuration->palette = palette;
        signal_leds_setcolors();
        signal_leds_preroll();
        signal_settings_save();
        return 1;
    } else {
        return 0;
    }
}

static int signal_serial_configure_mode(void)
{    
    switch (signal_serial_get_command()) {
        case 'r':
            /* reset */ 
        case 's': 
            signal_configuration->mode = signal_mode_serial;
            return 1;
        case 'h': 
            signal_configuration->mode = signal_mode_serial | signal_mode_hue;
            return 1;
        case 'w': 
            signal_configuration->mode = signal_mode_serial | signal_mode_wifi;
            return 1;
        case 'a': 
            signal_configuration->mode = signal_mode_serial | signal_mode_access;
            return 1;
        case 'b': 
            signal_configuration->mode = signal_mode_serial | signal_mode_bluetooth;
            return 1;
        default:
            return 0;
    }
}

static int signal_serial_configure_remote(void)
{    
    switch (signal_serial_get_command()) {
        case 'r':
            bzero(signal_configuration->forward, 64);
        case 'd': /* disable */
            signal_configuration->remote = 0;
            return 1;
        case 'e': /* enable */ 
            signal_configuration->remote = 1;
            return 1;
        case 'a': /* address */
            signal_serial_get_string(signal_configuration->forward, 64);
            return 1;
        default:
            return 0;            
    }
}

static void signal_serial_configure(void)
{
    signal_leds_trace_configure();
    if (UsedSerial.available() > 0) {
        int changed = 0;
        // int cmd = signal_serial_get_command();
        switch (UsedSerial.read()) {
            case 'd': // device
                if (UsedSerial.available() > 0) {
                    changed = signal_serial_configure_device();
                }
                break;
            case 'c': // color
                if (UsedSerial.available() > 0) {
                    changed = signal_serial_color();
                }
                break;
            case 'h':
                if (UsedSerial.available() > 0) {
                    changed = signal_serial_configure_hue();
                }
                break;
            case 'a': // access
            case 'w': // wifi
                if (UsedSerial.available() > 0) {
                    changed = signal_serial_configure_wifi();
                }
                break;
            case 's': // save
                signal_settings_save();
                changed = 1;
                break;
            case 'l': // load
                signal_settings_load();
                changed = 1;
                break;
            case 'f': // format
                signal_settings_prepare();
                break;
            case 'm': // mode
                if (UsedSerial.available() > 0) {
                    changed = signal_serial_configure_mode();
                }
                break;
            case 'r': // remote (forward)
                changed = signal_serial_configure_remote();
                break;
            }
            if (changed) {
                signal_leds_trace_okay();
            } else {
                signal_leds_trace_error();
            }
    }
}

/* forward ([get|put|post] url data) */

/* an outlier, it will become a helper in the hue module */

static void signal_serial_hue(void)
{
    /* we need to grab serial anyway, even when not okay */
    if (signal_configuration->mode & signal_mode_hue) {
        char state = UsedSerial.available() > 0 ? UsedSerial.read() : 'r';
        int light  = UsedSerial.available() > 0 ? signal_serial_get_cardinal_1() : 0;
        int okay   = hue_state_unknown;
        if (! light) { 
            /* zero means all lights */
        } else if (light > signal_configuration->huedata.noflights) {
            light = signal_configuration->huedata.noflights;
        }
        okay = signal_serial_hue_set_light(light, state);
        if (okay != hue_state_unknown) {
            signal_leds_trace_hue(okay);
        }
    }
}

/* 
    Experimental wireless synchronization. 
*/

static void signal_serial_wireless(void)
{
    int cmd = signal_serial_get_command();
    switch (cmd) {
        case 'f': 
         // signal_currentstatus->pending = 1; 
            signal_wifi_forward();
            break;
        case 'a': 
            signal_wifi_address();
            break;
    }
}

/* 
    Because anything can be send to this device we do a simple check for valid commands so that
    we don't get random led behaviour in case someone decides to mess it up. Of course this is 
    just a minimalistic approach and TeX users normally are behaving nice and have control over
    their machines anyway. 
*/

const char *prefix = ":lmtx:1:" ;
const int   prelen = 8;

typedef enum signal_serial_states { 
    serial_state_unavailable = 0x00,
    serial_state_invalid     = 0x01,
    serial_state_collecting  = 0x02,
    serial_state_command     = 0x03,
} signal_serial_states;

static int signal_serial_get_state(void)
{
  AGAIN:
    int n = UsedSerial.available();
    if (n > 0) {
        switch (UsedSerial.peek()) {
            case '\n':
            case '\r':
            case  ' ':
                UsedSerial.read();
                goto AGAIN;
            default:
                break;
           
        }
    }
    if (n <= 0) { 
        return serial_state_unavailable;
    } else if (n > prelen) { 
        /* 
            At some point we can decide to check the number but currently we only have 
            a hard coded 1 so ... 
        */
        for (int i = 0; i < prelen; i++) {
            if (UsedSerial.read() != prefix[i]) {
                return serial_state_invalid;                 
            }
        }
        return serial_state_command;
    } else {
        return serial_state_collecting;
    }
}

int signal_serial_handle(void)
{
    switch (signal_serial_get_state()) {
        case serial_state_unavailable:
            return 0;
        case serial_state_invalid: 
            signal_serial_aux_flush(); 
            return 0;
        case serial_state_collecting:
            return 0;
        case serial_state_command:
            while (1) {
                switch (signal_serial_get_command()) {
                    case 'a': signal_serial_all       (); break;
                    case 'c': signal_serial_configure (); break;
                    case 'd': signal_serial_direct    (); break;
                    case 'f': signal_serial_feedback  (); break;
                    case 'h': signal_serial_hue       (); break;
                    case 'i': signal_serial_individual(); break;
                    case 'k': signal_serial_quadrant  (); break;
                    case 'n': signal_serial_number    (); break;
                    case 'o': signal_serial_one       (); break;
                    case 'q': signal_serial_squid     (); break;
                    case 'r': signal_serial_reset     (); break;
                    case 's': signal_serial_segment   (); break;
                    case 't': signal_serial_text      (); break;
                    case 'w': signal_serial_wireless  (); break;
                    default : signal_serial_aux_flush (); break;
                }
                switch (signal_serial_get_state()) {
                    case serial_state_unavailable:
                        goto DONE;
                    case serial_state_invalid: 
                        signal_serial_aux_flush(); 
                        goto DONE;
                    case serial_state_collecting:
                        goto DONE;
                    case serial_state_command:
                        continue;
                }
            }
          DONE:
            signal_leds_update(signal_leds_on);
            return 1;
        default: 
            return 0;
    }
}
