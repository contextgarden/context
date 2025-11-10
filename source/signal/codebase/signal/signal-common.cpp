/*
    See license.txt in the root of this project.
*/

# include <signal-common.h>

static void signal_settings_device(void)
{
    switch (signal_configuration->device) {
        case signal_device_original:
            signal_configuration->device     = signal_device_original;
            signal_configuration->nofleds    = 24;
            signal_configuration->geometry   = signal_geometry_circular;
            signal_configuration->nofrows    = 1;
            signal_configuration->nofcolumns = 1;
            signal_configuration->colororder = GRB;
            break;
        case signal_device_alternative:
            signal_configuration->device     = signal_device_alternative;
            signal_configuration->nofleds    = 160;
            signal_configuration->geometry   = signal_geometry_rectangular;
            signal_configuration->nofrows    = 10;
            signal_configuration->nofcolumns = 16;
            signal_configuration->xoffset    = 2;
            signal_configuration->yoffset    = 1;
            signal_configuration->colororder = RGB;
            break;
        default:
            signal_configuration->device     = signal_device_unknown;
            signal_configuration->nofleds    = LED_NOFLEDS;
            signal_configuration->geometry   = signal_geometry_circular;
            signal_configuration->nofrows    = 1;
            signal_configuration->nofcolumns = 1;
            signal_configuration->colororder = LED_COLORORDER;
            break;
    }
}

static void signal_settings_wipe(void)
{
    bzero(signal_configuration, sizeof(signal_configuration_info));
    bzero(signal_configuration, sizeof(signal_currentstatus_info));
    /* */
    strcpy(signal_configuration->banner, SIGNAL_BANNER);
    /* */
    signal_configuration->version       = SIGNAL_VERSION;
    signal_configuration->revision      = SIGNAL_REVISION;
    signal_configuration->device        = SIGNAL_DEVICE;
    signal_configuration->nofleds       = LED_NOFLEDS;
    signal_configuration->nofsegments   = LED_NOFSEGMENTS;
    signal_configuration->segmentcount  = LED_SEGMENTCOUNT;
    signal_configuration->nofquadrants  = LED_NOFQUADRANTS;
    signal_configuration->quadrantcount = LED_QUADRANTCOUNT;
    signal_configuration->mode          = signal_mode_serial;
    signal_configuration->turnofftime   = LED_TURNOFFTIME * ONE_MINUTE;
    signal_configuration->dimming       = LED_BRIGHTNESS;
    signal_configuration->palette       = 0;
    signal_configuration->remote        = 0;
    /* */
    signal_currentstatus->issaved       = 0;
    signal_currentstatus->filesystem    = 0;
    for (int i = 0; i < LED_MAXNOFLEDS; i++) {
        /* play safe, no bzero here */
        signal_currentstatus->leds[i] = CRGB::Black;
        signal_currentstatus->saved[i] = CRGB::Black;
    }
}

void signal_settings_reset(void)
{
    signal_settings_wipe();
    signal_settings_device();
    signal_leds_remap();
    signal_leds_setcolors();
}

static void signal_settings_cleanup(void)
{
    signal_currentstatus->squid = 0;
    signal_currentstatus->lastturnofftime = 0;
    bzero(signal_currentstatus->squids, sizeof(signal_currentstatus->squids));
}

/*
  We could be more selective in saving and loading but is it worth the effort?
*/

# if SIGNAL_USE_FILESYSTEM

    static int signal_configration_okay(signal_configuration_info *source)
    {
        int okay =
               (signal_configuration->version == source->version)
            && (signal_configuration->revision == source->revision)
            && (signal_configuration->device == source->device)
            && (strcmp(signal_configuration->banner, source->banner) == 0) ;
            if (okay) { 
                memcpy(signal_configuration, source, sizeof(signal_configuration_info));
            }
            return okay; 
    }

    /* 
        I can't get a file system working from platformio and what one reads on the internet 
        doesn't make me happy so we now try preferences instead on esp. 
    */

    # if 0

        # include "FS.h"

        # if 1
            # include "SPIFFS.h"
            # define USEDFS SPIFFS
        # else 
            # include <LittleFS.h>
            # define USEDFS LittleFS
        # endif 

        static void signal_filesystem_wipe(void)
        {
            if (signal_currentstatus->filesystem) {
                USEDFS.end();
                signal_currentstatus->filesystem = 0;
            }
        }

        static int signal_filesystem_available(void)
        {
            if (! signal_currentstatus->filesystem) {
                signal_currentstatus->filesystem = USEDFS.begin(true);
            }     
            return signal_currentstatus->filesystem;
        }

        static int signal_filesystem_save(void)
        {
            if (signal_filesystem_available()) {
                File f = USEDFS.open(SIGNAL_CONFIGURATION, FILE_WRITE);
                if (f) {
                    int okay = f.write((byte *) signal_configuration,  sizeof(signal_configuration_info)) == sizeof(signal_configuration_info) ? 1 : 0;
                    f.close();
                    return okay;
                }
            }
            return 0;
        }

        static int signal_filesystem_load(void)
        {
            if (signal_filesystem_available()) {
                File f = USEDFS.open(SIGNAL_CONFIGURATION, FILE_READ);
                if (f) {
                    signal_configuration_info *saved_configuration = (signal_configuration_info *) malloc(sizeof(signal_configuration_info));
                    int okay = f.readBytes((char *) &saved_configuration, sizeof(signal_configuration_info)) == sizeof(signal_configuration_info);
                    if (okay) { 
                        okay = signal_configration_okay(saved_configuration);
                    }
                    free(saved_configuration);
                    return okay;
                }
            }
            return 0;
        }

    # else 

        # include <Preferences.h>

        Preferences preferences;

        static void signal_filesystem_wipe(void)
        {
            preferences.clear();
            signal_currentstatus->filesystem = 0;
        }

        static int signal_filesystem_available(void)
        {
            if (! signal_currentstatus->filesystem) {
                signal_currentstatus->filesystem = preferences.begin("storage", false);
            }     
            if (signal_currentstatus->filesystem) {
                signal_leds_trace_configure();
            }
            return signal_currentstatus->filesystem;
        }

        static int signal_filesystem_save(void)
        {
            if (signal_filesystem_available()) { 
                return preferences.putBytes("configuration", signal_configuration, sizeof(signal_configuration_info)) == sizeof(signal_configuration_info);
            } else { 
               return 0;
            }
        }

        static int signal_filesystem_load(void)
        {
            if (signal_filesystem_available()) { 
                signal_configuration_info *saved_configuration = (signal_configuration_info *) malloc(sizeof(signal_configuration_info));
                int okay = preferences.getBytes("configuration", saved_configuration, sizeof(signal_configuration_info)) == sizeof(signal_configuration_info);
                if (okay) { 
                    okay = signal_configration_okay(saved_configuration);
                }
                free(saved_configuration);
                return okay;
            } else { 
                return 0;
            }
        }

    # endif 

    void signal_settings_save(void)
    {
        if (signal_filesystem_save()) {
            signal_leds_trace_okay();
        } else {
            signal_leds_trace_error();
        }
    }

    void signal_settings_load(void)
    {
        if (signal_filesystem_load()) {
            signal_leds_remap();
            signal_leds_setcolors();
            signal_leds_trace_okay();
        } else {
            signal_leds_trace_error();
        }
    }

    int signal_settings_initialize(void)
    {
        if (signal_filesystem_available()) {
            signal_leds_trace_check();
            signal_settings_load();
        }
        return 1;
    }

    int signal_settings_prepare(void)
    {
        signal_filesystem_wipe();
        if (signal_filesystem_available()) {
            signal_leds_trace_okay();
        } else {
            signal_leds_trace_error();
        }
        return signal_currentstatus->filesystem;
    }

# else 

    void signal_settings_save(void)
    {
        signal_settings_cleanup();
    }

    void signal_settings_load(void)
    {
        signal_settings_cleanup();
        signal_settings_reset();
    }

    int signal_settings_initialize(void)
    {
        return 1;
    }

    int signal_settings_prepare(void)
    {
        return 1;
    }

# endif 

int signal_time_flied_by(int n, int m)
{
    return n ? (millis() - n) > m : 0;
}

