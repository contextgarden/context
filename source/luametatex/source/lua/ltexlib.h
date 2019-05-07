/*
    See license.txt in the root of this project.
*/

# ifndef LTEXLIB_H
# define LTEXLIB_H

void luacstring_start(void);
void luacstring_close(void);

int luacstring_input(halfword *n, int *cattable, int *partial, int *finalline);

/*
int luacstring_input(halfword *n);
int luacstring_cattable(void);
int luacstring_partial(void);
int luacstring_final_line(void);
*/

# endif
