/*
    See license.txt in the root of this project.
*/

# if SIGNAL_USE_HUE == 1

    # include <signal-common.h>
    # include <signal-wifi.h>
    
    # include <WiFi.h>
    # include <WiFiClient.h>
    # include <HTTPClient.h>
    
    int signal_hue_initialize(void)
    {
        WiFi.mode(WIFI_STA);
        return signal_wifi_connect(0);
    }

    int signal_serial_hue_set_light(int light, char state)
    {
        int okay = signal_configuration->mode & signal_mode_hue;
        int first = 0;
        int last = 0;
        if (! okay) {
            okay = hue_state_disabled;
        } else if (strlen(signal_configuration->huedata.hub) == 0) {
            okay = hue_state_no_hub;
        } else if (strlen(signal_configuration->huedata.token) == 0) {
            okay = hue_state_no_token;
        } else if (signal_configuration->huedata.noflights == 0) {
            okay = hue_state_no_lights;
        } else if (! signal_currentstatus->wifi) { 
            okay = hue_state_no_wifi;
        } else if (! signal_wifi_connected()) {
            okay = hue_state_no_wifi;
        } else { 
            okay = hue_state_unknown;
        }
        if (okay != hue_state_unknown) {
            return okay;
        }
        if (light < 1) { 
            light = 1;
        } else if (light > signal_configuration->huedata.noflights) { 
            light = signal_configuration->huedata.noflights;
        }
        if (light) { 
            first = light; 
            last  = light; 
        } else {
            first = 1;
            last  = signal_configuration->huedata.noflights;
        }
        for (int l = first; light <= last; light++) {
            light = signal_configuration->huedata.lights[l - 1];
            if (! light) { 
                return hue_state_no_lights;
            } else { 
                
                WiFiClient client;
                HTTPClient http;

                String url = "";
                String put = "";

                int h = 0; int s = 0; int v = 100;

                switch (state) {
                    case 'r': h =     0; s =   0; v =   0; break; // off 
                    case 'b': h = 43691; s = 255; v = 100; break; // blue
                    case 'd': h = 10923; s = 255; v = 100; break; // yellow  
                    case 'f': h = 21845; s = 255; v = 100; break; // green
                    case 'p': h =  7100; s = 255; v = 100; break; // orange 
                 // case 'p': h = 32768; s = 255; v = 100; break; // cyan 
                 // case 'p': h = 54613; s = 255; v = 100; break; // magenta 
                    case 'e': h =     0; s = 255; v = 100; break; // red
                    case 'u': h =     0; s =   0; v = 100; break; // white 
                    default : h =     0; s =   0; v =   0; break; // off 
                }

                url += String(signal_configuration->huedata.hub);
                url += "/api/";
                url += String(signal_configuration->huedata.token);
                url += "/lights/";
                url += light;
                url += "/state";

                put += "{";
                put +=  "\"on\" :"; put += (h == 0 && s == 0 && v == 0) ? "false" : "true";
                put += ",\"hue\":"; put += h;
                put += ",\"sat\":"; put += s;
                put += ",\"bri\":"; put += v;
                put += ",\"transitiontime\":"; put += 0;
                put += "}";

                if (http.begin(client, url)) {
                    http.PUT(put); // the response if not that relevant 
                    http.end();
                } else { 
                    signal_leds_trace_hue(hue_state_failure);
                }
            } 
            return hue_state_unknown;
        }
        return hue_state_unknown;
    }

# else 

    int signal_hue_initialize(void)
    {
        return 0;
    }

    int signal_serial_hue_set_light(int light, char state)
    {
        return 0;
    }

# endif 