/*
    See license.txt in the root of this project.
*/

# ifndef LMT_LUAINIT_H
# define LMT_LUAINIT_H

typedef struct engine_state_info {
    int         lua_init;
    int         lua_only;
    const char *luatex_banner;
    const char *engine_name;
    char       *startup_filename;
    char       *startup_jobname;
    char       *dump_name; /* could move to dump_state */
    int         utc_time;  /* kind of obsolete, could be a callback */
    int         permit_loadlib;
} engine_state_info;

extern engine_state_info lmt_engine_state;

extern void        tex_engine_initialize          (int ac, char **av);
extern char       *tex_engine_input_filename      (void);
extern void        tex_engine_check_configuration (void);

extern void        tex_engine_get_config_boolean  (const char *name, int   *target);
extern void        tex_engine_get_config_number   (const char *name, int   *target);
extern void        tex_engine_get_config_string   (const char *name, char **target);
extern int         tex_engine_run_config_function (const char *name);
extern void        tex_engine_set_memory_data     (const char *name, memory_data *data);
extern void        tex_engine_set_limits_data     (const char *name, limits_data *data);

extern void        lmt_make_table                 (lua_State *L, const char *tab, const char *mttab, lua_CFunction getfunc, lua_CFunction setfunc);
extern int         lmt_traceback                  (lua_State *L);
extern void        lmt_error                      (lua_State *L, const char *where, int detail, int fatal);
extern void        lmt_initialize                 (void);
extern void        lmt_dump_engine_info           (dumpstream f);
extern void        lmt_undump_engine_info         (dumpstream f);
extern const char *lmt_error_string               (lua_State *L, int index);

# endif
