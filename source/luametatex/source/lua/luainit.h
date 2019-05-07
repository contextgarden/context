/*
    See license.txt in the root of this project.
*/

# ifndef LUAINIT_H
# define LUAINIT_H

typedef struct engine_state_info {
    int lua_init;
    int lua_only;
    /* */
    const char *luatex_banner;
    const char *engine_name;
    /* */
    char *startup_filename;
    char *startup_jobname;
    /* */
    char *dump_name;
    /* */
    int utc_time;
} engine_state_info;

extern engine_state_info engine_state;

extern void lua_initialize(int ac, char **av);

extern void command_line_to_input(unsigned char *buffer, int first);

# endif
