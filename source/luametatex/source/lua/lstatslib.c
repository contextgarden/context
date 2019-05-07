/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

typedef struct statistic {
    const char *name;
    char type;
    void *value;
} statistic;

typedef const char *(*constfunc) (void);
typedef char       *(*charfunc)  (void);
typedef lua_Number  (*numfunc)   (void);
typedef int         (*intfunc)   (void);

static const char *getbanner(void)
{
    return (const char *) engine_state.luatex_banner;
}

static const char *getlogname(void)
{
    return (const char *) fileio_state.log_name;
}

static const char *getfilename(void)
{
    const char * s;
    int t;
    int level = in_open;
    while ((level > 0)) {
        s = full_source_filename_stack[level--];
        if (s != NULL) {
            return s;
        }
    }
    /*tex old method */
    level = in_open;
    while ((level > 0)) {
        t = input_stack[level--].name_field;
        if (t >= STRING_OFFSET) {
            return (const char *) str_string(t);
        }
    }
    return NULL;
}

static const char *luatexrevision(void)
{
    return (const char *) (strrchr(version_state.verbose, '.') + 1);
}

static const char *getenginename(void)
{
    return engine_state.engine_name;
}

static lua_Number get_luatexhashchars(void)
{
  return (lua_Number) LUAI_HASHLIMIT;
}

static int get_hash_size(void)
{
    return hash_size; /*tex is a |# define| */
}

static lua_Number get_development_id(void)
{
    return (lua_Number) luatex_development_id ;
}

static struct statistic allstats[] = {

    /* most likely accessed */

    { "output_active",      'b', &output_active },
    { "best_page_break",    'n', &best_page_break },

    { "filename",           'S', (void *) &getfilename },
    { "inputid",            'g', &(iname) },
    { "linenumber",         'g', &input_line },

    { "lasterrorstring",    'c', &error_state.last_error },
    { "lastluaerrorstring", 'c', &error_state.last_lua_error },
    { "lastwarningtag",     'c', &error_state.last_warning_tag },
    { "lastwarningstring",  'c', &error_state.last_warning_str },
    { "lasterrorcontext",   'c', &error_state.last_error_context },

    /* seldom or never accessed */

    { "log_name",           'S', (void *) &getlogname },
    { "banner",             'S', (void *) &getbanner },
    { "luatex_version",     'g', &version_state.version },
    { "luatex_revision",    'S', (void *) &luatexrevision },
    { "development_id",     'N', &get_development_id },
    { "luatex_hashchars",   'N', &get_luatexhashchars },
    { "luatex_engine",      'S', (void *) &getenginename },

    { "ini_version",        'b', &main_state.ini_version },
    { "var_used",           'g', &node_memory_state.var_used },
    { "dyn_used",           'g', &fixed_memory_state.dyn_used },

    { "str_ptr",            'g', &string_pool_state.str_ptr },
    { "init_str_ptr",       'g', &string_pool_state.init_str_ptr },
    { "max_strings",        'g', &main_state.max_strings },
    { "pool_size",          'g', &string_pool_state.pool_size },
    { "var_mem_max",        'g', &var_mem_max },
 /* { "node_mem_usage",     'S', &sprint_node_mem_usage }, */
    { "node_mem_usage",     's', &sprint_node_mem_usage },
    { "fix_mem_max",        'g', &fixed_memory_state.fix_mem_max },
    { "fix_mem_min",        'g', &fixed_memory_state.fix_mem_min },
    { "fix_mem_end",        'g', &fixed_memory_state.fix_mem_end },
    { "cs_count",           'g', &hash_state.cs_count },
    { "hash_size",          'G', &get_hash_size },
    { "hash_extra",         'g', &hash_state.hash_extra },
    { "max_font_id",        'G', &max_font_id }, /* was font_ptr */
    { "max_in_stack",       'g', &max_in_stack },
    { "max_nest_stack",     'g', &max_nest_stack },
    { "max_param_stack",    'g', &max_param_stack },
    { "max_buf_stack",      'g', &max_buf_stack },
    { "max_save_stack",     'g', &max_save_stack },
    { "stack_size",         'g', &main_state.stack_size },
    { "nest_size",          'g', &main_state.nest_size },
    { "param_size",         'g', &main_state.param_size },
    { "buf_size",           'g', &main_state.buf_size },
    { "save_size",          'g', &main_state.save_size },
    { "function_size",      'g', &lua_state.function_table_size },
    { "properties_size",    'g', &node_memory_state.node_properties_table_size },
    { "input_ptr",          'g', &input_ptr }, /* better: input_stack_top */
    { "largest_used_mark",  'g', &biggest_used_mark },
    { "luabytecodes",       'g', &lua_state.bytecode_max },
    { "luabytecode_bytes",  'g', &lua_state.bytecode_bytes },
    { "luastate_bytes",     'g', &lua_state.used_bytes },

    { "callbacks",          'g', &lua_state.callback_count },
    { "indirect_callbacks", 'g', &lua_state.saved_callback_count },
    { "saved_callbacks",    'g', &lua_state.saved_callback_count },
    { "direct_callbacks",   'g', &lua_state.direct_callback_count },
    { "function_callbacks", 'g', &lua_state.function_callback_count },

    { NULL,                 0,   0 }
};

static struct statistic onlystats[] = {
    { "filename",           'S', (void *) &getfilename },

    { "banner",             'S', (void *) &getbanner },
    { "luatex_version",     'g', &version_state.version },
    { "luatex_revision",    'S', (void *) &luatexrevision },
    { "development_id",     'N', &get_development_id },
    { "luatex_hashchars",   'N', &get_luatexhashchars },
    { "luatex_engine",      'S', (void *) &getenginename },

    { NULL,                 0,   0 }
};

static int stats_name_to_id(const char *name, statistic stats[])
{
    int i;
    for (i = 0; stats[i].name != NULL; i++) {
        if (strcmp(stats[i].name, name) == 0)
            return i;
    }
    return -1;
}

static int do_getstat(lua_State * L, statistic stats[], int i)
{
    switch (stats[i].type) {
        case 'S':
            {
                constfunc f = stats[i].value;
                const char *st = f();
                lua_pushstring(L, st);
                break;
            }
        case 's':
            {
                charfunc f = stats[i].value;
                char *st = f();
                lua_pushstring(L, st);
                free(st);
                break;
            }
        /*
        case 's':
            {
                int str = *(int *) (stats[i].value);
                if (str) {
                    char *ss = makecstring(str);
                    lua_pushstring(L, ss);
                    free(ss);
                } else {
                    lua_pushnil(L);
                }
                break;
            }
        */
        case 'N':
            {
                numfunc n = stats[i].value;
                lua_pushinteger(L, n());
                break;
            }
        case 'G':
            {
                intfunc g = stats[i].value;
                lua_pushinteger(L, g());
                break;
            }
        case 'g':
            lua_pushinteger(L, *(int *) (stats[i].value));
            break;
        case 'c':
            lua_pushstring(L, *(const char **) (stats[i].value));
            break;
        /*
        case 'B':
            g = stats[i].value;
            lua_pushboolean(L, g());
            break;
        */
        case 'n':
            if (*(halfword *) (stats[i].value) != 0)
                lua_nodelib_push_fast(L, *(halfword *) (stats[i].value));
            else
                lua_pushnil(L);
            break;
        case 'b':
            lua_pushboolean(L, *(int *) (stats[i].value));
            break;
        default:
            lua_pushnil(L);
    }
    return 1;
}

static int do_getstats(lua_State * L, statistic stats[])
{
    if (lua_type(L,-1) == LUA_TSTRING) {
        const char *st = lua_tostring(L, -1);
        int i = stats_name_to_id(st,stats);
        if (i >= 0) {
            return do_getstat(L, stats, i);
        }
    }
    return 0;
}

static int getstats(lua_State * L)
{
    return do_getstats(L,allstats);
}

static int getonlystats(lua_State * L)
{
    return do_getstats(L,onlystats);
}

static int do_statslist(lua_State * L, statistic stats[])
{
    int i;
    luaL_checkstack(L, 200, "out of stack space");
    lua_newtable(L);
    for (i = 0; stats[i].name != NULL; i++) {
        lua_pushstring(L, stats[i].name);
        do_getstat(L, stats, i);
        lua_rawset(L, -3);
    }
    return 1;
}

static int allstatslist(lua_State * L)
{
    return do_statslist(L,allstats);
}

static int onlystatslist(lua_State * L)
{
    return do_statslist(L,onlystats);
}

static int resetmessages(lua_State * L)
{
    (void) (L);
    free(error_state.last_warning_str);
    free(error_state.last_warning_tag);
    free(error_state.last_error);
    free(error_state.last_lua_error);
    error_state.last_warning_str = NULL;
    error_state.last_warning_tag = NULL;
    error_state.last_error = NULL;
    error_state.last_lua_error = NULL;
    return 0;
}

static const struct luaL_Reg statslib[] = {
    { "list",          allstatslist },
    { "resetmessages", resetmessages },
    { NULL,            NULL }
};

static const struct luaL_Reg onlystatslib[] = {
    { "list",          onlystatslist },
    { NULL,            NULL }
};

int luaopen_stats(lua_State * L)
{
    lua_newtable(L);
    luaL_setfuncs(L, engine_state.lua_only ? onlystatslib : statslib, 0);
    luaL_newmetatable(L, "tex.stats");
    lua_pushstring(L, "__index");
    lua_pushcfunction(L, engine_state.lua_only ? getonlystats : getstats);
    lua_settable(L, -3);
    lua_setmetatable(L, -2); /*tex meta to itself */
    return 1;
}
