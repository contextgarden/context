/*
    See license.txt in the root of this project.
*/

# ifndef LMT_MAINBODY_H
# define LMT_MAINBODY_H

/* Global variables */

typedef enum run_states {
    initializing_state,
    updating_state,
    production_state,
} run_states;

typedef enum ready_states {
    output_disabled_state,
    output_enabled_state,
} ready_states;

typedef struct main_state_info {
    int    run_state;       /*tex Are we |INITEX|? */
    int    ready_already;   /*tex A typical \TEX\ variable name. */
    double start_time;
} main_state_info ;

extern main_state_info lmt_main_state ;

/*tex

    The following procedure, which is called just before \TEX\ initializes its input and output,
    establishes the initial values of the date and time. It calls a macro-defined |dateandtime|
    routine. |dateandtime| in turn is also a |CCODE\ macro, which calls |get_date_and_time|,
    passing it the addresses of the day, month, etc., so they can be set by the routine.
    |get_date_and_time| also sets up interrupt catching if that is conditionally compiled in the
    \CCODE\ code.

*/

extern void tex_main_body                 (void);
extern void tex_close_files_and_terminate (int error);

# endif
