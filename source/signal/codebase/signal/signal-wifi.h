/*
    See license.txt in the root of this project.
*/

# ifndef SIGNAL_WIFI_H
# define SIGNAL_WIFI_H

int  signal_wifi_initialize (void);
int  signal_wifi_handle     (void);
int  signal_wifi_connect    (int reconnect);
int  signal_wifi_connected  (void);
void signal_wifi_forward    (void);
void signal_wifi_address    (void);
void signal_wifi_accesspoint(void);

# endif 