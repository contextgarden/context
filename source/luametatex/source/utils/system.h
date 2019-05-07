/*
    See license.txt in the root of this project.
*/

# ifndef UTILS_SYSTEM_H
# define UTILS_SYSTEM_H

extern void set_start_time(int);
extern void set_interrupt_handler(void);
extern void get_date_and_time(int *, int *, int *, int *, int *);
extern double get_current_time(void);
extern void set_run_time(void);
extern double get_run_time(void);

# endif
