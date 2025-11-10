/*
    See license.txt in the root of this project.
*/

# ifndef SIGNAL_BUTTON_H
# define SIGNAL_BUTTON_H

typedef enum signal_bottons { 
    signal_button_left  = 1,
    signal_button_right = 2,

} signal_buttons;

int signal_button_initialize (void);
int signal_button_processed  (void);
int signal_button_pressed    (int what);

# endif