/*
    See license.txt in the root of this project.
*/

# ifndef LMT_UTILITIES_SYSTEM_H
# define LMT_UTILITIES_SYSTEM_H

extern void   aux_quit_the_program      (void);

extern void   aux_set_start_time        (int);
extern void   aux_set_interrupt_handler (void);
extern void   aux_get_date_and_time     (int *minutes, int *day, int *month, int *year, int *utc);
extern double aux_get_current_time      (void);
extern void   aux_set_run_time          (void);
extern double aux_get_run_time          (void);

# endif
