/*
    See license.txt in the root of this project.
*/

# ifndef SIGNAL_HUE_H
# define SIGNAL_HUE_H

int signal_hue_initialize       (void);
int signal_serial_hue_set_light (int light, char state);

# endif