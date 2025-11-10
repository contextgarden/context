/*
    See license.txt in the root of this project.
*/

# if (SIGNAL_USE_WIFI == 1) || (SIGNAL_USE_HUE == 1)

    # include <signal-common.h>
    # include <signal-font.h>

    # include <WiFi.h>
    # include <WiFiClient.h>
    # include <HTTPClient.h>
    
    int signal_wifi_connect(int reconnect)
    {
        signal_currentstatus->wifi = 0;
        if (strlen(signal_configuration->ssid) != 0 && strlen(signal_configuration->psk) != 0) {
         // signal_leds_trace_check(); /* needed ? */
            if (signal_configuration->mode & signal_mode_wifi) {
                /* we try for about a minute and then give up */
                int found = 1;
                WiFi.mode(WIFI_STA);
                WiFi.disconnect();
                delay(200);
                if (0) { 
                    found = WiFi.scanNetworks();
                    WiFi.scanDelete();
                }
                if (found) { 
                    WiFi.begin(signal_configuration->ssid, signal_configuration->psk);
                    for (int i = 1; i <= signal_configuration->nofsegments; i++) {
                        signal_leds_trace_wifi(i);
                        if (WiFi.status()  == WL_CONNECTED) {
                            signal_currentstatus->wifi = 1;
                            signal_leds_trace_okay();
                            return 1;
                        } else {
                            delay(WIFI_DELAY);
                        }
                    }
                }
            } else if (signal_configuration->mode & signal_mode_access) { 
                signal_leds_trace_wifi(0);
                delay(TRACE_DELAY);
                WiFi.softAP(signal_configuration->ssid, signal_configuration->psk);
                signal_currentstatus->wifi = 1;
                signal_leds_trace_okay();
                return 1;
            }
            signal_leds_trace_error();
        }
        return 0;
    }

    int signal_wifi_connected(void)
    {
        if (signal_configuration->mode & signal_mode_access) { 
            return 1; /* todo: if has client */
        } else if (signal_configuration->mode & signal_mode_wifi) { 
            return WiFi.status() == WL_CONNECTED;
        } else {
            return 0;
        }
    }

# else 

    int signal_wifi_connect(int reconnect)
    {
        return 0;
    }
    
    int signal_wifi_connected(void)
    {
        return 0;
    }

# endif 

# if SIGNAL_USE_WIFI == 1

    /* 

        There is no need to listen to requests when we're just forwarding. So this is mnode 'forward'. We either use the 
        gateway or we use given ip address. 

    */

    void signal_wifi_forward() 
    {
        if ((signal_configuration->remote) && signal_wifi_connected()) {
            HTTPClient http;            
            String url = "http://";
            url += signal_configuration->forward;
            url += "/synchronize?states=";
            url += signal_leds_synchronize();
            http.begin(url);
            http.GET(); /* no need to check for result */
            http.end();
        }
    }

    void signal_wifi_address(void)
    {
        /* show address */
        int isap = WiFi.getMode() == WIFI_MODE_AP;
        String ip = isap ? WiFi.softAPIP().toString() : WiFi.localIP().toString();
        for (int i = 0; i < ip.length(); i++) {
            unsigned char c = ip.charAt(i);
            switch (c) { 
                case '0': case '1': case '2': case '3': case '4': 
                case '5': case '6': case '7': case '8': case '9':
                    signal_leds_set_number((int) (c - '0'), signal_currentstatus->colors.magenta, signal_currentstatus->colors.reset);
                    signal_leds_update(signal_leds_on);
                    delay(2000);
                    break;
                case '.':
                    signal_leds_all(signal_currentstatus->colors.reset, 0);
                    signal_leds_update(signal_leds_on);
                    delay(4000);
                    break;
                default: 
                    /* error */
                    break;
            }
        }
        signal_leds_all(signal_currentstatus->colors.reset, 0);
        signal_leds_update(signal_leds_on);
    }

# else 

    void signal_wifi_forward() 
    {
        /* dummy */
    }

    void signal_wifi_address(void)
    {
        /* dummy */
    }

# endif

# if SIGNAL_USE_WIFI == 1

    # include <WiFi.h>
    # include <WiFiClient.h>
    # include <HTTPClient.h>
    # include <WebServer.h>

    WebServer server(80);

    void signal_wifi_root(void) 
    {
        server.send(200, "text/plain", "welcome\n\r");
    }

    void signal_wifi_notfound(void) 
    {
        server.send(404, "text/plain", "not found\n\r");
    }

    static uint8_t signal_wifi_aux_get_segment (void) { return (uint8_t) server.arg("s").toInt(); }
    static uint8_t signal_wifi_aux_get_quadrant(void) { return (uint8_t) server.arg("k").toInt(); }

    static uint8_t signal_wifi_aux_get_red     (void) { return (uint8_t) server.arg("r").toInt(); }
    static uint8_t signal_wifi_aux_get_green   (void) { return (uint8_t) server.arg("g").toInt(); }
    static uint8_t signal_wifi_aux_get_blue    (void) { return (uint8_t) server.arg("b").toInt(); }

    static uint8_t signal_wifi_aux_get_first   (void) { return (uint8_t) server.arg("n").toInt(); }
    static uint8_t signal_wifi_aux_get_last    (void) { return (uint8_t) server.arg("m").toInt(); }

    void signal_wifi_set(void)
    {
        uint8_t r = signal_wifi_aux_get_red  ();
        uint8_t g = signal_wifi_aux_get_green();
        uint8_t b = signal_wifi_aux_get_blue ();
        uint8_t n = signal_wifi_aux_get_first();
        uint8_t m = signal_wifi_aux_get_last ();
        if (signal_leds_okay(&r, &g, &b, &n, &m)) {
            server.send(200, "text/plain", "valid state");
            signal_leds_set_range(n, m, CRGB(r,g,b));
            signal_leds_update(signal_leds_on);
        } else {
            server.send(200, "text/plain", "invalid state");
        }
    }

    static void signal_wifi_aux_preset(CRGB c, const char *what)
    {
        int segment  = signal_wifi_aux_get_segment ();
        int quadrant = signal_wifi_aux_get_quadrant();
        signal_range range;
        server.send(200, "text/plain", what);
        if (segment) {
            range = signal_leds_get_segment(&segment);
        } else if (quadrant) {
            range = signal_leds_get_quadrant(&quadrant);
        } else {
            range = signal_leds_whole_range();
        }
        signal_leds_set_range(range.first, range.last, c);
        signal_leds_update(signal_leds_on);
    }

    void signal_wifi_busy    (void) { signal_wifi_aux_preset(signal_currentstatus->colors.busy,     "busy"    ); }
    void signal_wifi_done    (void) { signal_wifi_aux_preset(signal_currentstatus->colors.done,     "done"    ); }
    void signal_wifi_finished(void) { signal_wifi_aux_preset(signal_currentstatus->colors.finished, "finished"); }
    void signal_wifi_problem (void) { signal_wifi_aux_preset(signal_currentstatus->colors.problem,  "problem" ); }
    void signal_wifi_error   (void) { signal_wifi_aux_preset(signal_currentstatus->colors.error,    "error"   ); }
    void signal_wifi_unknown (void) { signal_wifi_aux_preset(signal_currentstatus->colors.unknown,  "unknown" ); }
    void signal_wifi_reset   (void) { signal_wifi_aux_preset(signal_currentstatus->colors.reset,    "reset"   ); }
    void signal_wifi_off     (void) { signal_wifi_aux_preset(signal_currentstatus->colors.off,      "off"     ); }
    void signal_wifi_on      (void) { signal_wifi_aux_preset(signal_currentstatus->colors.on,       "on"      ); }

    void signal_wifi_synchronize(void)
    {
        String s = server.arg("states");
        server.send(200, "text/plain", "synchronizing");
        signal_leds_from_string(s);
    }

//    char macStr[18] = { 0 };
//    sprintf(macStr, "%02X:%02X:%02X:%02X:%02X:%02X", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
//    return String(macStr);

    void signal_wifi_info(void)
    {
        int isap = WiFi.getMode() == WIFI_MODE_AP;
        String html = "<!DOCTYPE HTML>";
        html += "<html>";
        html += "<head>";
        html += "</head>";
        html += "<body>";
        html += "<pre><code>\n";
        html += "mac address : " + (isap ? WiFi.softAPmacAddress()    : WiFi.macAddress()        ) + "\n";
        html += "ip address  : " + (isap ? WiFi.softAPIP().toString() : WiFi.localIP().toString()) + "\n";
        html += "identifier  : " + (isap ? WiFi.softAPSSID()          : WiFi.SSID()              ) + "\n";
        html += "</code></pre>";
        html += "</body>";
        html += "</html>";
        server.send(200, "text/html", html);
    }

    void signal_wifi_initialize(void)
    {

     // WiFi.mode(WIFI_STA);

        signal_wifi_connect(0);

     // if (signal_currentstatus->wifi & (signal_configuration->mode & (signal_mode_wifi | signal_mode_access))) {
     // }

        /* harmless overhead if not used */

        server.on("/",            signal_wifi_root);

        server.on("/reset",       signal_wifi_reset);
        server.on("/set",         signal_wifi_set);

        server.on("/busy",        signal_wifi_busy);
        server.on("/done",        signal_wifi_done);
        server.on("/finished",    signal_wifi_finished);
        server.on("/problem",     signal_wifi_problem);
        server.on("/error",       signal_wifi_error);
        server.on("/unknown",     signal_wifi_unknown);

        server.on("/on",          signal_wifi_on);
        server.on("/off",         signal_wifi_off);

        server.on("/synchronize", signal_wifi_synchronize);

        server.on("/info",        signal_wifi_info);

        server.onNotFound(signal_wifi_notfound);

        server.begin();
    }

    void signal_wifi_accesspoint(void)
    {
        signal_configuration->mode = signal_mode_serial | signal_mode_access;
        if (! strlen(signal_configuration->ssid)) { 
            bzero(signal_configuration->ssid, 64);
# if SIGNAL_USE_DEVICE == ESP32
            sprintf(signal_configuration->ssid, "CONTEXT WATCH %012llX", ESP.getEfuseMac());
# else 
            strcpy(signal_configuration->ssid, "CONTEXT WATCH");
# endif 
        }
        if (! strlen(signal_configuration->psk)) { 
            bzero(signal_configuration->psk, 64);
            strcpy(signal_configuration->psk, "welcome to the context watch");
        }
        signal_wifi_initialize();
    }

    int signal_wifi_handle(void)
    {
        /* a bit redundant checking */
        if (signal_configuration->mode & (signal_mode_wifi | signal_mode_access)) {
            if (signal_currentstatus->wifi) {
                /*
                    Todo: we don't want to test this every time so we just assume a reboot. At least
                    we don't want to do this every time when we are connected to the serial port.
                */
                if (! signal_wifi_connected()) {
                    unsigned long currenttime = millis();
                    if (currenttime - signal_currentstatus->lastcheckedwifi >= RECONNECT_DELAY) {
                        WiFi.disconnect();
                        WiFi.reconnect();
                        signal_currentstatus->lastcheckedwifi = currenttime;
                    }
                    if (signal_wifi_connected()) {
                     // signal_currentstatus->wifi = 0;
                    }
                }
            } 
            if (signal_currentstatus->wifi) {
                server.handleClient();
                return 1;
            }
        }
        return 0;
    }

# else

    int signal_wifi_initialize(void)
    {
        return 0;
    }

    int signal_wifi_handle(void)
    {
        return 0;
    }

# endif
