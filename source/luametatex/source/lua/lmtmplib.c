/*
    See license.txt in the root of this project.
*/

/*tex

    This is an adapted version of \MPLIB\ for ConTeXt LMTX. Interfaces might change as experiments
    demand or indicate this. It's meant for usage in \LUAMETATEX, which is an engine geared at
    \CONTEXT, and which, although useable in production, will in principle be experimental and
    moving for a while, depending on needs, experiments and mood.

    In \LUATEX\, at some point \MPLIB\ got an interface to \LUA\ and that greatly enhanced the
    posibilities. In \LUAMETATEX\ this interface was further improved and in addition scanners
    got added. So in the meantime we have a rather complete and tight integration of \TEX, \LUA,
    and \METAPOST\ and in \CONTEXT\ we use that integration as much as possible.

    An important difference with \LUATEX\ is that we use an upgraded \MPLIB. The \POSTSCRIPT\
    backend has been dropped and there is no longer font and file related code because that
    all goes via \LUA\ now. The binary frontend has been dropped to so we now only have scaled,
    double and decimal.

*/

# include "mpconfig.h"

# include "mp.h"

/*tex
    We can use common definitions but can only load this file after we load the \METAPOST\ stuff,
    which defines a whole bunch of macros that can clash. Using the next one is actually a good
    check for such conflicts.
*/

# include "luametatex.h"

/*tex

    Here are some enumeration arrays to map MPlib enums to \LUA\ strings. If needed we can also
    predefine keys here, as we do with nodes. Some tables relate to the scanners.

*/

# define MPLIB_PATH      0
# define MPLIB_PEN       1
# define MPLIB_PATH_SIZE 8

static const char *mplib_math_options[] = {
    "scaled",
    "double",
    "binary",  /* not available in luatex */
    "decimal",
    NULL
};

static const char *mplib_interaction_options[] = {
    "unknown",
    "batch",
    "nonstop",
    "scroll",
    "errorstop",
    "silent",
    NULL
};

static const char *mplib_filetype_names[] = {
    "terminal", /* mp_filetype_terminal */
    "mp",       /* mp_filetype_program  */
    "data",     /* mp_filetype_text     */
    NULL
};

/*
static const char *knot_type_enum[] = {
    "endpoint", "explicit", "given", "curl", "open", "end_cycle"
};
*/

static const char *mplib_fill_fields[] = {
    "type",
    "path", "htap",
    "pen", "color",
    "linejoin", "miterlimit",
    "prescript", "postscript",
    "stacking",
    NULL
};

static const char *mplib_stroked_fields[] =  {
    "type",
    "path",
    "pen", "color",
    "linejoin", "miterlimit", "linecap",
    "dash",
    "prescript", "postscript",
    "stacking",
    NULL
};

static const char *mplib_start_clip_fields[] = {
    "type",
    "path",
    "prescript", "postscript",
    "stacking",
    NULL
};

static const char *mplib_start_group_fields[] = {
    "type",
    "path",
    "prescript", "postscript",
    "stacking",
    NULL
};

static const char *mplib_start_bounds_fields[] = {
    "type",
    "path",
    "prescript", "postscript",
    "stacking",
    NULL
};

static const char *mplib_stop_clip_fields[] = {
    "type",
    "stacking",
    NULL
};

static const char *mplib_stop_group_fields[] = {
    "type",
    "stacking",
    NULL
};

static const char *mplib_stop_bounds_fields[] = {
    "type",
    "stacking",
    NULL
};

static const char *mplib_no_fields[] = {
    NULL
};

static const char *mplib_codes[] = {
    "undefined",
    "btex",            /* mp_btex_command                */ /* btex verbatimtex */
    "etex",            /* mp_etex_command                */ /* etex */
    "if",              /* mp_if_test_command             */ /* if */
    "fiorelse",        /* mp_fi_or_else_command          */ /* elseif else fi */
    "input",           /* mp_input_command               */ /* input endinput */
    "iteration",       /* mp_iteration_command           */ /* for forsuffixes forever endfor */
    "repeatloop",      /* mp_repeat_loop_command         */ /* used in repeat loop (endfor) */
    "exittest",        /* mp_exit_test_command           */ /* exitif */
    "relax",           /* mp_relax_command               */ /* \\ */
    "scantokens",      /* mp_scan_tokens_command         */ /* scantokens */
    "runscript",       /* mp_runscript_command           */ /* runscript */
    "maketext",        /* mp_maketext_command            */ /* maketext */
    "expandafter",     /* mp_expand_after_command        */ /* expandafter */
    "definedmacro",    /* mp_defined_macro_command       */ /* */
    "save",            /* mp_save_command                */ /* save */
    "interim",         /* mp_interim_command             */ /* interim */
    "let",             /* mp_let_command                 */ /* let */
    "newinternal",     /* mp_new_internal_command        */ /* newinternal */
    "macrodef",        /* mp_macro_def_command           */ /* def vardef (etc) */
    "shipout",         /* mp_ship_out_command            */ /* shipout */
    "addto",           /* mp_add_to_command              */ /* addto */
    "setbounds",       /* mp_bounds_command              */ /* setbounds clip group */
    "protection",      /* mp_protection_command          */
    "property",        /* mp_property_command            */
    "show",            /* mp_show_command                */ /* show showvariable (etc) */
    "mode",            /* mp_mode_command                */ /* batchmode (etc) */
    "onlyset",         /* mp_only_set_command            */ /* randomseed, maxknotpool */
    "message",         /* mp_message_command             */ /* message errmessage */
    "everyjob",        /* mp_every_job_command           */ /* everyjob */
    "delimiters",      /* mp_delimiters_command          */ /* delimiters */
    "write",           /* mp_write_command               */ /* write */
    "typename",        /* mp_type_name_command           */ /* (declare) numeric pair */
    "leftdelimiter",   /* mp_left_delimiter_command      */ /* the left delimiter of a matching pair */
    "begingroup",      /* mp_begin_group_command         */ /* begingroup */
    "nullary",         /* mp_nullary_command             */ /* operator without arguments: normaldeviate (etc) */
    "unary",           /* mp_unary_command               */ /* operator with one argument: sqrt (etc) */
    "str",             /* mp_str_command                 */ /* convert a suffix to a string: str */
    "void",            /* mp_void_command                */ /* convert a suffix to a boolean: void */
    "cycle",           /* mp_cycle_command               */ /* cycle */
    "ofbinary",        /* mp_of_binary_command           */ /* binary operation taking "of", like "point of" */
    "capsule",         /* mp_capsule_command             */ /* */
    "string",          /* mp_string_command              */ /* */
    "internal",        /* mp_internal_quantity_command   */ /* */
    "tag",             /* mp_tag_command                 */ /* a symbolic token without a primitive meaning */
    "numeric",         /* mp_numeric_command             */ /* numeric constant */
    "plusorminus",     /* mp_plus_or_minus_command       */ /* + - */
    "secondarydef",    /* mp_secondary_def_command       */ /* secondarydef */
    "tertiarybinary",  /* mp_tertiary_binary_command     */ /* an operator at the tertiary level: ++ (etc) */
    "leftbrace",       /* mp_left_brace_command          */ /* { */
    "pathjoin",        /* mp_path_join_command           */ /* .. */
    "ampersand",       /* mp_ampersand_command           */ /* & */
    "tertiarydef",     /* mp_tertiary_def_command        */ /* tertiarydef */
    "primarybinary",   /* mp_primary_binary_command      */ /* < (etc) */
    "equals",          /* mp_equals_command              */ /* = */
    "and",             /* mp_and_command                 */ /* and */
    "primarydef",      /* mp_primary_def_command         */ /* primarydef */
    "slash",           /* mp_slash_command               */ /* / */
    "secondarybinary", /* mp_secondary_binary_command    */ /* an operator at the binary level: shifted (etc) */
    "parametertype",   /* mp_parameter_commmand          */ /* primary expr suffix (etc) */
    "controls",        /* mp_controls_command            */ /* controls */
    "tension",         /* mp_tension_command             */ /* tension */
    "atleast",         /* mp_at_least_command            */ /* atleast */
    "curl",            /* mp_curl_command                */ /* curl */
    "macrospecial",    /* mp_macro_special_command       */ /* quote, #@ (etc) */
    "rightdelimiter",  /* mp_right_delimiter_command     */ /* the right delimiter of a matching pair */
    "leftbracket",     /* mp_left_bracket_command        */ /* [ */
    "rightbracket",    /* mp_right_bracket_command       */ /* ] */
    "rightbrace",      /* mp_right_brace_command         */ /* } */
    "with",            /* mp_with_option_command         */ /* withpen (etc) */
    "thingstoadd",     /* mp_thing_to_add_command        */ /* addto contour doublepath also */
    "of",              /* mp_of_command                  */ /* of */
    "to",              /* mp_to_command                  */ /* to */
    "step",            /* mp_step_command                */ /* step */
    "until",           /* mp_until_command               */ /* until */
    "within",          /* mp_within_command              */ /* within */
    "assignment",      /* mp_assignment_command          */ /* := */
    "colon",           /* mp_colon_command               */ /* : */
    "comma",           /* mp_comma_command               */ /* , */
    "semicolon",       /* mp_semicolon_command           */ /* ; */
    "endgroup",        /* mp_end_group_command           */ /* endgroup */
    "stop",            /* mp_stop_command                */ /* end dump */
 // "outertag",        /* mp_outer_tag_command           */ /* protection code added to command code */
    "undefinedcs",     /* mp_undefined_cs_command        */ /* protection code added to command code */
    NULL
};

static const char *mplib_states[] = {
    "normal",
    "skipping",
    "flushing",
    "absorbing",
    "var_defining",
    "op_defining",
    "loop_defining",
    NULL
};

static const char *mplib_types[] = {
    "undefined",       /* mp_undefined_type        */
    "vacuous",         /* mp_vacuous_type          */
    "boolean",         /* mp_boolean_type          */
    "unknownboolean",  /* mp_unknown_boolean_type  */
    "string",          /* mp_string_type           */
    "unknownstring",   /* mp_unknown_string_type   */
    "pen",             /* mp_pen_type              */
    "unknownpen",      /* mp_unknown_pen_type      */
    "nep",             /* mp_nep_type              */
    "unknownnep",      /* mp_unknown_nep_type      */
    "path",            /* mp_path_type             */
    "unknownpath",     /* mp_unknown_path_type     */
    "picture",         /* mp_picture_type          */
    "unknownpicture",  /* mp_unknown_picture_type  */
    "transform",       /* mp_transform_type        */
    "color",           /* mp_color_type            */
    "cmykcolor",       /* mp_cmykcolor_type        */
    "pair",            /* mp_pair_type             */
 // "script",          /*                          */
    "numeric",         /* mp_numeric_type          */
    "known",           /* mp_known_type            */
    "dependent",       /* mp_dependent_type        */
    "protodependent",  /* mp_proto_dependent_type  */
    "independent",     /* mp_independent_type      */
    "tokenlist",       /* mp_token_list_type       */
    "structured",      /* mp_structured_type       */
    "unsuffixedmacro", /* mp_unsuffixed_macro_type */
    "suffixedmacro",   /* mp_suffixed_macro_type   */
    NULL
};

static const char *mplib_colormodels[] = {
    "no",
    "grey",
    "rgb",
    "cmyk",
    NULL
};

/*tex Some statistics. */

typedef struct mplib_state_info {
    int file_callbacks;
    int text_callbacks;
    int script_callbacks;
    int log_callbacks;
    int overload_callbacks;
    int error_callbacks;
    int warning_callbacks;
} mplib_state_info;

static mplib_state_info mplib_state = {
    .file_callbacks     = 0,
    .text_callbacks     = 0,
    .script_callbacks   = 0,
    .log_callbacks      = 0,
    .overload_callbacks = 0,
    .error_callbacks    = 0,
    .warning_callbacks  = 0,
};

/*tex

    We need a few metatable identifiers in order to access the metatables for the main object and result
    userdata. The following code is now replaced by the method that uses keys.

*/

/*
# define MP_METATABLE_INSTANCE "mp.instance"
# define MP_METATABLE_FIGURE   "mp.figure"
# define MP_METATABLE_OBJECT   "mp.object"
*/

/*tex
    This is used for heuristics wrt curves or lines. The default value is rather small
    and often leads to curved rectangles.

    \starttabulate[||||]
    \NC 131/65536.0           \NC 0.0019989013671875 \NC default \NC \NR
    \NC 0.001 * 0x7FFF/0x4000 \NC 0.0019999389648438 \NC kind of the default \NC \NR
    \NC  32/16000.0           \NC 0.002              \NC somewhat cleaner \NC \NR
    \NC  10/ 2000.0           \NC 0.005              \NC often good enough \NC \NR
    \stoptabulate

*/

# define default_bend_tolerance 131/65536.0
# define default_move_tolerance 131/65536.0

typedef enum mp_variables {
    mp_bend_tolerance = 1,
    mp_move_tolerance = 2,
} mp_variables;

static lua_Number mplib_aux_get_bend_tolerance(lua_State *L, int slot)
{
    lua_Number tolerance;
    lua_getiuservalue(L, slot, mp_bend_tolerance);
    tolerance = lua_tonumber(L, -1);
    lua_pop(L, 1);
    return tolerance;
}

static lua_Number mplib_aux_get_move_tolerance(lua_State *L, int slot)
{
    lua_Number tolerance;
    lua_getiuservalue(L, slot, mp_move_tolerance);
    tolerance = lua_tonumber(L, -1);
    lua_pop(L, 1);
    return tolerance;
}

static void mplib_aux_set_bend_tolerance(lua_State *L, lua_Number tolerance)
{
    lua_pushnumber(L, tolerance);
    lua_setiuservalue(L, -2, mp_bend_tolerance);
}

static void mplib_aux_set_move_tolerance(lua_State *L, lua_Number tolerance)
{
    lua_pushnumber(L, tolerance);
    lua_setiuservalue(L, -2, mp_move_tolerance);
}

inline static char *lmt_string_from_index(lua_State *L, int n)
{
    size_t l;
    const char *x = lua_tolstring(L, n, &l);
 // return  (x && l > 0) ? lmt_generic_strdup(x) : NULL;
    return  (x && l > 0) ? lmt_memory_strdup(x) : NULL;
}

inline static char *lmt_lstring_from_index(lua_State *L, int n, size_t *l)
{
    const char *x = lua_tolstring(L, n, l);
 // return  (x && l > 0) ? lmt_generic_strdup(x) : NULL;
    return  (x && l > 0) ? lmt_memory_strdup(x) : NULL;
}

static void mplib_aux_invalid_object_warning(const char * detail)
{
    tex_formatted_warning("mp lib","lua <mp %s> expected", detail);
}

static void mplib_aux_invalid_object_error(const char * detail)
{
    tex_formatted_error("mp lib","lua <mp %s> expected", detail);
}

inline static MP *mplib_aux_is_mpud(lua_State *L, int n)
{
    MP *p = (MP *) lua_touserdata(L, n);
    if (p && lua_getmetatable(L, n)) {
        lua_get_metatablelua(mplib_instance);
        if (! lua_rawequal(L, -1, -2)) {
            p = NULL;
        }
        lua_pop(L, 2);
        if (p) {
            return p;
        }
    }
    mplib_aux_invalid_object_error("instance");
    return NULL;
}

inline static MP mplib_aux_is_mp(lua_State *L, int n)
{
    MP *p = (MP *) lua_touserdata(L, n);
    if (p && lua_getmetatable(L, n)) {
        lua_get_metatablelua(mplib_instance);
        if (! lua_rawequal(L, -1, -2)) {
            p = NULL;
        }
        lua_pop(L, 2);
        if (p) {
            return *p;
        }
    }
    mplib_aux_invalid_object_error("instance");
    return NULL;
}

inline static mp_edge_object **mplib_aux_is_figure(lua_State *L, int n)
{
    mp_edge_object **p = (mp_edge_object **) lua_touserdata(L, n);
    if (p && lua_getmetatable(L, n)) {
        lua_get_metatablelua(mplib_figure);
        if (! lua_rawequal(L, -1, -2)) {
            p = NULL;
        }
        lua_pop(L, 2);
        if (p) {
            return p;
        }
    }
    mplib_aux_invalid_object_warning("figure");
    return NULL;
}

inline static mp_graphic_object **mplib_aux_is_gr_object(lua_State *L, int n)
{
    mp_graphic_object **p = (mp_graphic_object **) lua_touserdata(L, n);
    if (p && lua_getmetatable(L, n)) {
        lua_get_metatablelua(mplib_object);
        if (! lua_rawequal(L, -1, -2)) {
            p = NULL;
        }
        lua_pop(L, 2);
        if (p) {
            return p;
        }
    }
    mplib_aux_invalid_object_warning("object");
    return NULL;
}

/*tex In the next array entry 0 is not used */

static int mplib_values_type[mp_stop_bounds_code + 1] = { 0 };
static int mplib_values_knot[6] = { 0 };

static void mplib_aux_initialize_lua(lua_State *L)
{
    (void) L;
    mplib_values_type[mp_fill_code]         = lua_key_index(fill);
    mplib_values_type[mp_stroked_code]      = lua_key_index(outline);
    mplib_values_type[mp_start_clip_code]   = lua_key_index(start_clip);
    mplib_values_type[mp_start_group_code]  = lua_key_index(start_group);
    mplib_values_type[mp_start_bounds_code] = lua_key_index(start_bounds);
    mplib_values_type[mp_stop_clip_code]    = lua_key_index(stop_clip);
    mplib_values_type[mp_stop_group_code]   = lua_key_index(stop_group);
    mplib_values_type[mp_stop_bounds_code]  = lua_key_index(stop_bounds);

    mplib_values_knot[mp_endpoint_knot]  = lua_key_index(endpoint);
    mplib_values_knot[mp_explicit_knot]  = lua_key_index(explicit);
    mplib_values_knot[mp_given_knot]     = lua_key_index(given);
    mplib_values_knot[mp_curl_knot]      = lua_key_index(curl);
    mplib_values_knot[mp_open_knot]      = lua_key_index(open);
    mplib_values_knot[mp_end_cycle_knot] = lua_key_index(end_cycle);
}

static void mplib_aux_push_pentype(lua_State *L, mp_gr_knot h)
{
    if (h && h == h->next) {
        lua_push_value_at_key(L, type, elliptical);
    }
}

static int mplib_set_tolerance(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        mplib_aux_set_bend_tolerance(L, luaL_optnumber(L, 2, default_bend_tolerance));
        mplib_aux_set_move_tolerance(L, luaL_optnumber(L, 3, default_move_tolerance));
    }
    return 0;
}

static int mplib_get_tolerance(lua_State *L)
{

    if (lua_type(L, 1) == LUA_TUSERDATA) {
        MP mp = mplib_aux_is_mp(L, 1);
        if (mp) {
            lua_pushnumber(L, mplib_aux_get_bend_tolerance(L, 1));
            lua_pushnumber(L, mplib_aux_get_move_tolerance(L, 1));
            return 2;
        } else {
            return 0;
        }
    } else {
        lua_pushnumber(L, default_bend_tolerance);
        lua_pushnumber(L, default_move_tolerance);
        return 2;
    }
}

/*tex

    We start by defining the needed callback routines for the library. We could store them per
    instance but it has no advantages so that will be done when we feel the need.

*/

static int mplib_aux_register_function(lua_State *L, int old_id)
{
    if (! (lua_isfunction(L, -1) || lua_isnil(L, -1))) {
        return 0;
    } else {
        lua_pushvalue(L, -1);
        if (old_id) {
            luaL_unref(L, LUA_REGISTRYINDEX, old_id);
        }
        return luaL_ref(L, LUA_REGISTRYINDEX); /*tex |new_id| */
    }
}

static int mplib_aux_find_file_function(lua_State *L, MP_options *options)
{
    options->find_file_id = mplib_aux_register_function(L, options->find_file_id);
    return (! options->find_file_id);
}

static int mplib_aux_run_script_function(lua_State *L, MP_options *options)
{
    options->run_script_id = mplib_aux_register_function(L, options->run_script_id);
    return (! options->run_script_id);
}

static int mplib_aux_run_internal_function(lua_State *L, MP_options *options)
{
    options->run_internal_id = mplib_aux_register_function(L, options->run_internal_id);
    return (! options->run_internal_id);
}

static int mplib_aux_make_text_function(lua_State *L, MP_options *options)
{
    options->make_text_id = mplib_aux_register_function(L, options->make_text_id);
    return (! options->make_text_id);
}

static int mplib_aux_run_logger_function(lua_State *L, MP_options *options)
{
    options->run_logger_id = mplib_aux_register_function(L, options->run_logger_id);
    return (! options->run_logger_id);
}

static int mplib_aux_run_overload_function(lua_State *L, MP_options *options)
{
    options->run_overload_id = mplib_aux_register_function(L, options->run_overload_id);
    return (! options->run_overload_id);
}

static int mplib_aux_run_error_function(lua_State *L, MP_options *options)
{
    options->run_error_id = mplib_aux_register_function(L, options->run_error_id);
    return (! options->run_error_id);
}

static int mplib_aux_open_file_function(lua_State *L, MP_options *options)
{
    options->open_file_id = mplib_aux_register_function(L, options->open_file_id);
    return (! options->open_file_id);
}

static char *mplib_aux_find_file(MP mp, const char *fname, const char *fmode, int ftype)
{
    if (mp->find_file_id) {
        lua_State *L = (lua_State *) mp_userdata(mp);
        int stacktop = lua_gettop(L);
        char *s = NULL;
        lua_rawgeti(L, LUA_REGISTRYINDEX, mp->find_file_id);
        lua_pushstring(L, fname);
        lua_pushstring(L, fmode);
        if (ftype > mp_filetype_text) {
            lua_pushinteger(L, (lua_Integer) ftype - mp_filetype_text);
        } else {
            lua_pushstring(L, mplib_filetype_names[ftype]);
        }
        ++mplib_state.file_callbacks;
        if (lua_pcall(L, 3, 1, 0)) {
            tex_formatted_warning("mplib", "find file: %s", lua_tostring(L, -1));
        } else {
            s = lmt_string_from_index(L, -1);
        }
        lua_settop(L, stacktop);
        return s;
    } else if (fmode[0] != 'r' || (! access(fname, R_OK)) || ftype) {
     // return lmt_generic_strdup(fname);
        return lmt_memory_strdup(fname);
    }
    return NULL;
}

/*

    In retrospect we could have has a more granular approach: a flag that tells that the result is
    a string to be scanned. Maybe I'll that anyway but it definitely means an adaption of the low
    level interface we have in MetaFun. Also, the interface would be a bit ugly because then we
    would like to handle values as in the 'whatever' function which in turn means a flag indicating
    that a string is a string and not something to be scanned as tokens, and being compatible then
    means that this flag comes after the string which kind of conflicts with multiple (number)
    arguments ... in the end we gain too little to accept such an ugly mess as option. So, we stick
    to:

    -- nil     : nothing is injected and no scanning will happen
    -- string  : passed on in order to be scanned
    -- table   : passed on concatenated in order to be scanned
    -- number  : injected as numeric (so no scanning later on)
    -- boolean : injected as boolean (so no scanning later on)

    and dealing with other datatypes is delegated to the injectors.

*/

static int mplib_aux_with_path(lua_State *L, MP mp, int index, int what, int multiple);

static void mplib_aux_inject_whatever(lua_State *L, MP mp, int index)
{
    switch (lua_type(L, index)) {
        case LUA_TBOOLEAN:
            mp_push_boolean_value(mp, lua_toboolean(L, index));
            break;
        case LUA_TNUMBER:
            mp_push_numeric_value(mp, lua_tonumber(L, index));
            break;
        case LUA_TSTRING:
            {
                size_t l;
                const char *s = lua_tolstring(L, index, &l);
                mp_push_string_value(mp, s, (int) l);
                break;
            }
        case LUA_TTABLE:
            {
                if (lua_rawgeti(L, index, 1) == LUA_TTABLE) {
                    /* table of tables */
                    lua_pop(L, 1);
                    mplib_aux_with_path(L, mp, index, 1, 0);
                } else {
                    lua_pop(L, 1);
                    switch (lua_rawlen(L, index)) {
                        case 2 :
                            mp_push_pair_value(mp,
                                lmt_number_from_table(L, index, 1, 0.0),
                                lmt_number_from_table(L, index, 2, 0.0)
                            );
                            break;
                        case 3 :
                            mp_push_color_value(mp,
                                lmt_number_from_table(L, index, 1, 0.0),
                                lmt_number_from_table(L, index, 2, 0.0),
                                lmt_number_from_table(L, index, 3, 0.0)
                            );
                            break;
                        case 4 :
                            mp_push_cmykcolor_value(mp,
                                lmt_number_from_table(L, index, 1, 0.0),
                                lmt_number_from_table(L, index, 2, 0.0),
                                lmt_number_from_table(L, index, 3, 0.0),
                                lmt_number_from_table(L, index, 4, 0.0)
                            );
                            break;
                        case 6 :
                            mp_push_transform_value(mp,
                                lmt_number_from_table(L, index, 1, 0.0),
                                lmt_number_from_table(L, index, 2, 0.0),
                                lmt_number_from_table(L, index, 3, 0.0),
                                lmt_number_from_table(L, index, 4, 0.0),
                                lmt_number_from_table(L, index, 5, 0.0),
                                lmt_number_from_table(L, index, 6, 0.0)
                            );
                            break;
                    }
                }
                break;
            }
    }
}

static char *mplib_aux_return_whatever(lua_State *L, MP mp, int index)
{
    switch (lua_type(L, index)) {
        case LUA_TBOOLEAN:
            mp_push_boolean_value(mp, lua_toboolean(L, index));
            break;
        case LUA_TNUMBER:
            mp_push_numeric_value(mp, lua_tonumber(L, index));
            break;
        /* A string is passed to scantokens. */
        case LUA_TSTRING:
            return lmt_string_from_index(L, index);
        /*tex A table is concatenated and passed to scantokens. */
        case LUA_TTABLE:
            {
                luaL_Buffer b;
                lua_Integer n = (lua_Integer) lua_rawlen(L, index);
                luaL_buffinit(L, &b);
                for (lua_Integer i = 1; i <= n; i++) {
                    lua_rawgeti(L, index, i);
                    luaL_addvalue(&b);
                    lua_pop(L, 1);
                }
                luaL_pushresult(&b);
                return lmt_string_from_index(L, -1);
            }
    }
    return NULL;
}

static char *mplib_aux_run_script(MP mp, const char *str, size_t len, int n)
{
    if (mp->run_script_id) {
        lua_State *L = (lua_State *) mp_userdata(mp);
        int stacktop = lua_gettop(L);
        lua_rawgeti(L, LUA_REGISTRYINDEX, mp->run_script_id);
        if (str) {
            lua_pushlstring(L, str, len);
        } else if (n > 0) {
            lua_pushinteger(L, n);
        } else {
            lua_pushnil(L);
        }
        ++mplib_state.script_callbacks;
        if (lua_pcall(L, 1, 2, 0)) {
            tex_formatted_warning("mplib", "run script: %s", lua_tostring(L, -1));
        } else if (lua_toboolean(L, -1)) {
            /* value boolean */
            mplib_aux_inject_whatever(L, mp, -2);
            lua_settop(L, stacktop);
            return NULL;
        } else {
            /* value nil */
            char *s = mplib_aux_return_whatever(L, mp, -2);
            lua_settop(L, stacktop);
            return s;
        }
    }
    return NULL;
}

static void mplib_aux_run_internal(MP mp, int action, int n, int type, const char *name)
{
    if (mp->run_internal_id) {
        lua_State *L = (lua_State *) mp_userdata(mp);
        ++mplib_state.script_callbacks; /* maybe a special counter */
        lua_rawgeti(L, LUA_REGISTRYINDEX, mp->run_internal_id);
        lua_pushinteger(L, action); /* 0=initialize, 1=save, 2=restore */
        lua_pushinteger(L, n);
        if (name) {
            lua_pushinteger(L, type);
            lua_pushstring(L, name);
            if (! lua_pcall(L, 4, 0, 0)) {
                return;
            }
        } else {
            if (lua_pcall(L, 2, 0, 0)) {
                return;
            }
        }
        tex_formatted_warning("mplib", "run internal: %s", lua_tostring(L, -1));
    }
}

static char *mplib_aux_make_text(MP mp, const char *str, size_t len, int mode)
{
    if (mp->make_text_id) {
        lua_State *L = (lua_State *) mp_userdata(mp);
        int stacktop = lua_gettop(L);
        char *s = NULL;
        lua_rawgeti(L, LUA_REGISTRYINDEX, mp->make_text_id);
        lua_pushlstring(L, str, len);
        lua_pushinteger(L, mode);
        ++mplib_state.text_callbacks;
        if (lua_pcall(L, 2, 1, 0)) {
            tex_formatted_warning("mplib", "make text: %s", lua_tostring(L, -1));
        } else {
            s = lmt_string_from_index(L, -1);
        }
        lua_settop(L, stacktop);
        return s;
    }
    return NULL;
}

static void mplib_aux_run_logger(MP mp, int target, const char *str, size_t len)
{
    if (mp->run_logger_id) {
        lua_State *L = (lua_State *) mp_userdata(mp);
        int stacktop = lua_gettop(L);
        lua_rawgeti(L, LUA_REGISTRYINDEX, mp->run_logger_id);
        lua_pushinteger(L, target);
        lua_pushlstring(L, str, len);
        ++mplib_state.log_callbacks;
        if (lua_pcall(L, 2, 0, 0)) {
            tex_formatted_warning("mplib", "run logger: %s", lua_tostring(L, -1));
        }
        lua_settop(L, stacktop);
    }
}

static int mplib_aux_run_overload(MP mp, int property, const char *str, int mode)
{
    int quit = 0;
    if (mp->run_overload_id) {
        lua_State *L = (lua_State *) mp_userdata(mp);
        int stacktop = lua_gettop(L);
        lua_rawgeti(L, LUA_REGISTRYINDEX, mp->run_overload_id);
        lua_pushinteger(L, property);
        lua_pushstring(L, str);
        lua_pushinteger(L, mode);
        ++mplib_state.overload_callbacks;
        if (lua_pcall(L, 3, 1, 0)) {
            tex_formatted_warning("mplib", "run overload: %s", lua_tostring(L, -1));
            quit = 1;
        } else {
            quit = lua_toboolean(L, -1);
        }
        lua_settop(L, stacktop);
    }
    return quit;
}

static void mplib_aux_run_error(MP mp, const char *str, const char *help, int interaction)
{
    if (mp->run_error_id) {
        lua_State *L = (lua_State *) mp_userdata(mp);
        int stacktop = lua_gettop(L);
        lua_rawgeti(L, LUA_REGISTRYINDEX, mp->run_error_id);
        lua_pushstring(L, str);
        lua_pushstring(L, help);
        lua_pushinteger(L, interaction);
        ++mplib_state.error_callbacks;
        if (lua_pcall(L, 3, 0, 0)) {
           tex_formatted_warning("mplib", "run error: %s", lua_tostring(L, -1));
        }
        lua_settop(L, stacktop);
    }
}

/*

    We keep all management in Lua, so for now we don't create an object. Files are normally closed
    anyway. We can always make it nicer. The opener has to return an integer. A value zero indicates
    that no file is opened.

*/

/* index needs checking, no need for pointer (was old) */

static void *mplib_aux_open_file(MP mp, const char *fname, const char *fmode, int ftype)
{
    if (mp->open_file_id) {
        int *index = mp_memory_allocate(sizeof(int));
        if (index) {
            lua_State *L = (lua_State *) mp_userdata(mp);
            int stacktop = lua_gettop(L);
            lua_rawgeti(L, LUA_REGISTRYINDEX, mp->open_file_id);
            lua_pushstring(L, fname);
            lua_pushstring(L, fmode);
            if (ftype > mp_filetype_text) {
                lua_pushinteger(L, (lua_Integer) ftype - mp_filetype_text);
            } else {
                lua_pushstring(L, mplib_filetype_names[ftype]);
            }
            ++mplib_state.file_callbacks;
            if (lua_pcall(L, 3, 1, 0)) {
                *((int*) index) = 0;
            } else if (lua_istable(L, -1)) {
                lua_pushvalue(L, -1);
                *((int*) index) = luaL_ref(L, LUA_REGISTRYINDEX);
            } else {
                tex_normal_warning("mplib", "open file: table expected");
                *((int*) index) = 0;
            }
            lua_settop(L, stacktop);
            return index;
        }
    }
    return NULL;
}

# define mplib_pop_function(idx,tag) \
    lua_rawgeti(L, LUA_REGISTRYINDEX, idx); \
    lua_push_key(tag); \
    lua_rawget(L, -2);

static void mplib_aux_close_file(MP mp, void *index)
{
    if (mp->open_file_id && index) {
        int idx = *((int*) index);
        lua_State *L = (lua_State *) mp_userdata(mp);
        int stacktop = lua_gettop(L);
        mplib_pop_function(idx, close)
        if (lua_isfunction(L, -1)) {
            ++mplib_state.file_callbacks;
            if (lua_pcall(L, 0, 0, 0)) {
                /* no message */
            } else {
                /* nothing to be done here */
            }
        }
        /*
        if (index) {
            luaL_unref(L, idx));
        }
        */
        lua_settop(L, stacktop);
        mp_memory_free(index);
    }
}

static char *mplib_aux_read_file(MP mp, void *index, size_t *size)
{
    if (mp->open_file_id && index) {
        lua_State *L = (lua_State *) mp_userdata(mp);
        int stacktop = lua_gettop(L);
        int idx = *((int*) index);
        char *s = NULL;
        mplib_pop_function(idx, reader)
        if (lua_isfunction(L, -1)) {
            ++mplib_state.file_callbacks;
            if (lua_pcall(L, 0, 1, 0)) {
                *size = 0;
            } else if (lua_type(L, -1) == LUA_TSTRING) {
                s = lmt_lstring_from_index(L, -1, size);
            }
        }
        lua_settop(L, stacktop);
        return s;
    }
    return NULL;
}

static void mplib_aux_write_file(MP mp, void *index, const char *s)
{
    if (mp->open_file_id && index) {
        lua_State *L = (lua_State *) mp_userdata(mp);
        int stacktop = lua_gettop(L);
        int idx = *((int*) index);
        mplib_pop_function(idx, writer)
        if (lua_isfunction(L, -1)) {
            lua_pushstring(L, s);
            ++mplib_state.file_callbacks;
            if (lua_pcall(L, 1, 0, 0)) {
                /* no message */
            } else {
                /* nothing to be done here */
            }
        }
        lua_settop(L, stacktop);
    }
}

static int mplib_scan_next(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    int token = 0;
    int mode = 0;
    int kind = 0;
    if (mp) {
        int keep = 0 ;
        if (lua_gettop(L) > 1) {
            keep = lua_toboolean(L, 2);
        }
        mp_scan_next_value(mp, keep, &token, &mode, &kind);
    }
    lua_pushinteger(L, token);
    lua_pushinteger(L, mode);
    lua_pushinteger(L, kind);
    return 3;
}

static int mplib_scan_expression(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    int kind = 0;
    if (mp) {
        int keep = 0 ;
        if (lua_gettop(L) > 1) {
            keep = lua_toboolean(L, 2);
        }
        mp_scan_expr_value(mp, keep, &kind);
    }
    lua_pushinteger(L, kind);
    return 1;
}

static int mplib_scan_token(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    int token = 0;
    int mode = 0;
    int kind = 0;
    if (mp) {
        int keep = 0 ;
        if (lua_gettop(L) > 1) {
            keep = lua_toboolean(L, 2);
        }
        mp_scan_token_value(mp, keep, &token, &mode, &kind);
    }
    lua_pushinteger(L, token);
    lua_pushinteger(L, mode);
    lua_pushinteger(L, kind);
    return 3;
}

static int mplib_skip_token(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    lua_pushboolean(L, mp ? mp_skip_token_value(mp, lmt_tointeger(L, 2)) : 0);
    return 1;
}

static int mplib_scan_symbol(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        int keep = 0 ;
        int expand = 1 ;
        int top = lua_gettop(L) ;
        char *s = NULL;
        if (top > 2) { // no need to check
            expand = lua_toboolean(L, 3);
        }
        if (top > 1) { // no need to check
            keep = lua_toboolean(L, 2);
        }
        mp_scan_symbol_value(mp, keep, &s, expand) ;
        if (s) {
            /* we could do without the copy */
            lua_pushstring(L, s);
            mp_memory_free(s);
            return 1;
        }
    }
    lua_pushliteral(L,"");
    return 1;
}

static int mplib_scan_property(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        int keep = 0 ;
        int top = lua_gettop(L) ;
        int type = 0 ;
        int property = 0 ;
        int detail = 0 ;
        char *s = NULL;
        if (top > 1) {
            keep = lua_toboolean(L, 2);
        }
        mp_scan_property_value(mp, keep, &type, &s, &property, &detail);
        if (s) {
            lua_pushinteger(L, type);
            lua_pushstring(L, s);
            lua_pushinteger(L, property);
            lua_pushinteger(L, detail);
            mp_memory_free(s);
            return 4;
        }
    }
    return 0;
}

/*tex
    A circle has 8 points and a square 4 so let's just start with 8 slots in the table.
*/

static int aux_is_curved_gr(mp_gr_knot ith, mp_gr_knot pth, lua_Number tolerance)
{
    lua_Number d = pth->left_x - ith->right_x;
    if (fabs(ith->right_x - ith->x_coord - d) <= tolerance && fabs(pth->x_coord - pth->left_x - d) <= tolerance) {
        d = pth->left_y - ith->right_y;
        if (fabs(ith->right_y - ith->y_coord - d) <= tolerance && fabs(pth->y_coord - pth->left_y - d) <= tolerance) {
            return 0;
        }
    }
    return 1;
}

static int aux_is_duplicate_gr(mp_gr_knot pth, mp_gr_knot nxt, lua_Number tolerance)
{
    return (fabs(pth->x_coord - nxt->x_coord) <= tolerance && fabs(pth->y_coord - nxt->y_coord) <= tolerance);
}

# define valid_knot_type(t) (t >= mp_endpoint_knot && t <= mp_end_cycle_knot) /* pens can act weird here */

// -68.031485 2.83464 l
// -68.031485 2.83464 -68.031485 -2.83464 -68.031485 -2.83464 c

static void mplib_aux_push_path(lua_State *L, mp_gr_knot h, int ispen, lua_Number bendtolerance, lua_Number movetolerance)
{
    if (h) {
        int i = 0;
        mp_gr_knot p = h;
        mp_gr_knot q = h;
        int iscycle = 1;
        lua_createtable(L, ispen ? 1 : MPLIB_PATH_SIZE, ispen ? 2 : 1);
        do {
            mp_gr_knot n = p->next;
            int lt = p->left_type;
            int rt = p->right_type;
            if (ispen) {
                lua_createtable(L, 0, 6);
         // } else if (i > 0 && p != h && aux_is_duplicate_gr(p, n, movetolerance) && ! aux_is_curved_gr(p, n, bendtolerance) ) {
            } else if (i > 0 && p != h && n != h && aux_is_duplicate_gr(p, n, movetolerance) && ! aux_is_curved_gr(p, n, bendtolerance) ) {
                n->left_x = p->left_x;
                n->left_y = p->left_y;
                goto NEXTONE;
            } else {
                int ln = lt != mp_explicit_knot;
                int rn = rt != mp_explicit_knot;
                int ic = i > 0 && aux_is_curved_gr(q, p, bendtolerance);
                int st = p->state;
                lua_createtable(L, 0, 6 + (ic ? 1 : 0) + (ln ? 1 : 0) + (rn ? 1 : 0) + (st ? 1: 0));
                if (ln && valid_knot_type(lt)) {
                    lua_push_svalue_at_key(L, left_type, mplib_values_knot[lt]);
                }
                if (rn && valid_knot_type(rt)) {
                    lua_push_svalue_at_key(L, right_type, mplib_values_knot[rt]);
                }
                if (ic) {
                    lua_push_boolean_at_key(L, curved, 1);
                }
                if (st) {
                    lua_push_integer_at_key(L, state, st);
                }
                lua_push_number_at_key(L, x_coord, p->x_coord);
                lua_push_number_at_key(L, y_coord, p->y_coord);
                lua_push_number_at_key(L, left_x,  p->left_x);
                lua_push_number_at_key(L, left_y,  p->left_y);
                lua_push_number_at_key(L, right_x, p->right_x);
                lua_push_number_at_key(L, right_y, p->right_y);
                lua_rawseti(L, -2, ++i);
                if (rt == mp_endpoint_knot) {
                    iscycle = 0;
                    break;
                }
            }
          NEXTONE:   
            q = p;
            p = n;
        } while (p && p != h);
        if (iscycle && i > 1 && aux_is_curved_gr(q, h, bendtolerance)) {
            lua_rawgeti(L, -1, 1);
            lua_push_boolean_at_key(L, curved, 1);
            lua_pop(L, 1);
        }
        if (ispen) {
            lua_push_boolean_at_key(L, pen, 1);
        }
        lua_push_boolean_at_key(L, cycle, iscycle);
    } else {
        lua_pushnil(L);
    }
}

static int aux_is_curved(MP mp, mp_knot ith, mp_knot pth, lua_Number tolerance)
{
    lua_Number d = mp_number_as_double(mp, pth->left_x) - mp_number_as_double(mp, ith->right_x);
    if (fabs(mp_number_as_double(mp, ith->right_x) - mp_number_as_double(mp, ith->x_coord) - d) <= tolerance && fabs(mp_number_as_double(mp, pth->x_coord) - mp_number_as_double(mp, pth->left_x) - d) <= tolerance) {
        d = mp_number_as_double(mp, pth->left_y) - mp_number_as_double(mp, ith->right_y);
        if (fabs(mp_number_as_double(mp, ith->right_y) - mp_number_as_double(mp, ith->y_coord) - d) <= tolerance && fabs(mp_number_as_double(mp, pth->y_coord) - mp_number_as_double(mp, pth->left_y) - d) <= tolerance) {
            return 0;
        }
    }
    return 1;
}

static void aux_mplib_knot_to_path(lua_State *L, MP mp, mp_knot h, int ispen, int compact, int check, lua_Number bendtolerance) // maybe also movetolerance
{
    int i = 1;
    mp_knot p = h;
    mp_knot q = h;
    int iscycle = 1;
    lua_createtable(L, ispen ? 1 : MPLIB_PATH_SIZE, ispen ? 2 : 1);
    if (compact) {
        do {
            lua_createtable(L, 2, 0);
            lua_push_number_at_index(L, 1, mp_number_as_double(mp, p->x_coord));
            lua_push_number_at_index(L, 2, mp_number_as_double(mp, p->y_coord));
            lua_rawseti(L, -2, i++);
            if (p->right_type == mp_endpoint_knot) {
                iscycle = 0;
                break;
            } else {
                p = p->next;
            }
        } while (p && p != h);
    } else {
        do {
            int lt = p->left_type;
            int rt = p->right_type;
            int ln = lt != mp_explicit_knot;
            int rn = rt != mp_explicit_knot;
            int ic = check && (i > 1) && aux_is_curved(mp, q, p, bendtolerance);
            lua_createtable(L, 0, 6 + (ic ? 1 : 0) + (ln ? 1 : 0) + (rn ? 1 : 0));
            if (ln && valid_knot_type(lt)) {
                lua_push_svalue_at_key(L, left_type, mplib_values_knot[lt]);
            } else {
                /* a pen */
            }
            if (rn && valid_knot_type(rt)) {
                lua_push_svalue_at_key(L, right_type, mplib_values_knot[rt]);
            } else {
                /* a pen */
            }
            if (ic) {
                lua_push_boolean_at_key(L, curved, 1);
            }
            lua_push_number_at_index(L, 1, mp_number_as_double(mp, p->x_coord));
            lua_push_number_at_index(L, 2, mp_number_as_double(mp, p->y_coord));
            lua_push_number_at_index(L, 3, mp_number_as_double(mp, p->left_x));
            lua_push_number_at_index(L, 4, mp_number_as_double(mp, p->left_y));
            lua_push_number_at_index(L, 5, mp_number_as_double(mp, p->right_x));
            lua_push_number_at_index(L, 6, mp_number_as_double(mp, p->right_y));
            lua_rawseti(L, -2, i++);
            if (rt == mp_endpoint_knot) {
                iscycle = 0;
                break;
            } else {
                q = p;
                p = p->next;
            }
        } while (p && p != h);
        if (check && iscycle && i > 1 && aux_is_curved(mp, q, h, bendtolerance)) {
            lua_rawgeti(L, -1, 1);
            lua_push_boolean_at_key(L, curved, 1);
            lua_pop(L, 1);
        }
    }
    if (ispen) {
        lua_push_boolean_at_key(L, pen, 1);
    }
    lua_push_boolean_at_key(L, cycle, iscycle);
}

/*tex

    A couple of scanners. I know what I want to change but not now. First some longer term
    experiments.

*/

# define push_number_in_slot(L,i,n) \
    lua_pushnumber(L, n); \
    lua_rawseti(L, -2, i);

# define kind_of_expression(n) \
    lmt_optinteger(L, n, 0)

static int mplib_scan_string(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        char *s = NULL;
        size_t l = 0;
        mp_scan_string_value(mp, kind_of_expression(2), &s, &l) ;
        if (s) {
            lua_pushlstring(L, s, l);
            return 1;
        }
    }
    lua_pushliteral(L,"");
    return 1;
}

static int mplib_scan_boolean(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    int b = 0;
    if (mp) {
        mp_scan_boolean_value(mp, kind_of_expression(2), &b);
    }
    lua_pushboolean(L, b);
    return 1;
}

static int mplib_scan_numeric(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    double d = 0.0;
    if (mp) {
        mp_scan_numeric_value(mp, kind_of_expression(2), &d);
    }
    lua_pushnumber(L, d);
    return 1;
}

static int mplib_scan_integer(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    double d = 0.0;
    if (mp) {
        mp_scan_numeric_value(mp, kind_of_expression(2), &d);
    }
    lua_pushinteger(L, (int) d); /* floored */
    return 1;
}

static int mplib_scan_pair(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    double x = 0.0;
    double y = 0.0;
    if (mp) {
        mp_scan_pair_value(mp, kind_of_expression(3), &x, &y);
    }
    if (lua_toboolean(L, 2)) {
        lua_createtable(L, 2, 0);
        push_number_in_slot(L, 1, x);
        push_number_in_slot(L, 2, y);
        return 1;
    } else {
        lua_pushnumber(L, x);
        lua_pushnumber(L, y);
        return 2;
    }
}

static int mplib_scan_color(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    double r = 0.0;
    double g = 0.0;
    double b = 0.0;
    if (mp) {
        mp_scan_color_value(mp, kind_of_expression(3), &r, &g, &b);
    }
    if (lua_toboolean(L, 2)) {
        lua_createtable(L, 3, 0);
        push_number_in_slot(L, 1, r);
        push_number_in_slot(L, 2, g);
        push_number_in_slot(L, 3, b);
        return 1;
    } else {
        lua_pushnumber(L, r);
        lua_pushnumber(L, g);
        lua_pushnumber(L, b);
        return 3;
    }
}

static int mplib_scan_cmykcolor(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    double c = 0.0;
    double m = 0.0;
    double y = 0.0;
    double k = 0.0;
    if (mp) {
        mp_scan_cmykcolor_value(mp, kind_of_expression(3), &c, &m, &y, &k);
    }
    if (lua_toboolean(L, 2)) {
        lua_createtable(L, 4, 0);
        push_number_in_slot(L, 1, c);
        push_number_in_slot(L, 2, m);
        push_number_in_slot(L, 3, y);
        push_number_in_slot(L, 4, k);
        return 1;
    } else {
        lua_pushnumber(L, c);
        lua_pushnumber(L, m);
        lua_pushnumber(L, y);
        lua_pushnumber(L, k);
        return 4;
    }
}

static int mplib_scan_transform(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    double x  = 0.0;
    double y  = 0.0;
    double xx = 0.0;
    double xy = 0.0;
    double yx = 0.0;
    double yy = 0.0;
    if (mp) {
        mp_scan_transform_value(mp, kind_of_expression(3), &x, &y, &xx, &xy, &yx, &yy);
    }
    if (lua_toboolean(L, 2)) {
        lua_createtable(L, 6, 0);
        push_number_in_slot(L, 1, x);
        push_number_in_slot(L, 2, y);
        push_number_in_slot(L, 3, xx);
        push_number_in_slot(L, 4, xy);
        push_number_in_slot(L, 5, yx);
        push_number_in_slot(L, 6, yy);
        return 1;
    } else {
        lua_pushnumber(L, x);
        lua_pushnumber(L, y);
        lua_pushnumber(L, xx);
        lua_pushnumber(L, xy);
        lua_pushnumber(L, yx);
        lua_pushnumber(L, yy);
        return 6;
    }
}

static int mplib_scan_path(lua_State *L) /* 1=mp 2=compact 3=kind(prim) 4=check */
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        mp_knot p = NULL;
        lua_Number t = mplib_aux_get_bend_tolerance(L, 1); /* iuservalue */
        mp_scan_path_value(mp, kind_of_expression(3), &p);
        if (p) {
            aux_mplib_knot_to_path(L, mp, p, 0, lua_toboolean(L, 2), lua_toboolean(L, 4), t);
            return 1;
        }
    }
    return 0;
}

static int mplib_scan_pen(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        mp_knot p = NULL ;
        lua_Number t = mplib_aux_get_bend_tolerance(L, 1);
        mp_scan_path_value(mp, kind_of_expression(3), &p) ;
        if (p) {
            aux_mplib_knot_to_path(L, mp, p, 1, lua_toboolean(L, 2), lua_toboolean(L, 4), t);
            return 1;
        }
    }
    return 0;
}

static int mplib_inject_string(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        size_t l = 0;
        const char *s = lua_tolstring(L, 2, &l);
        mp_push_string_value(mp, s, (int) l);
    }
    return 0;
}

static int mplib_inject_boolean(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        int b = lua_toboolean(L, 2);
        mp_push_boolean_value(mp, b);
    }
    return 0;
}

static int mplib_inject_numeric(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        double d = lua_tonumber(L, 2);
        mp_push_numeric_value(mp, d);
    }
    return 0;
}

static int mplib_inject_integer(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        int i = lmt_tointeger(L, 2);
        mp_push_integer_value(mp, i);
    }
    return 0;
}

static int mplib_inject_pair(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        switch (lua_type(L, 2)) {
            case LUA_TNUMBER:
                mp_push_pair_value(mp,
                    luaL_optnumber(L, 2, 0),
                    luaL_optnumber(L, 3, 0)
                );
                break;
            case LUA_TTABLE:
                mp_push_pair_value(mp,
                    lmt_number_from_table(L, 2, 1, 0.0),
                    lmt_number_from_table(L, 2, 2, 0.0)
                );
                break;
        }
    }
    return 0;
}

static int mplib_inject_color(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        switch (lua_type(L, 2)) {
            case LUA_TNUMBER:
                mp_push_color_value(mp,
                    luaL_optnumber(L, 2, 0),
                    luaL_optnumber(L, 3, 0),
                    luaL_optnumber(L, 4, 0)
                );
                break;
            case LUA_TTABLE:
                mp_push_color_value(mp,
                    lmt_number_from_table(L, 2, 1, 0.0),
                    lmt_number_from_table(L, 2, 2, 0.0),
                    lmt_number_from_table(L, 2, 3, 0.0)
                );
                break;
        }
    }
    return 0;
}

static int mplib_inject_cmykcolor(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        switch (lua_type(L, 2)) {
            case LUA_TNUMBER:
                mp_push_cmykcolor_value(mp,
                    luaL_optnumber(L, 2, 0),
                    luaL_optnumber(L, 3, 0),
                    luaL_optnumber(L, 4, 0),
                    luaL_optnumber(L, 5, 0)
                );
                break;
            case LUA_TTABLE:
                mp_push_cmykcolor_value(mp,
                    lmt_number_from_table(L, 2, 1, 0.0),
                    lmt_number_from_table(L, 2, 2, 0.0),
                    lmt_number_from_table(L, 2, 3, 0.0),
                    lmt_number_from_table(L, 2, 4, 0.0)
                );
                break;
        }
    }
    return 0;
}

static int mplib_inject_transform(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        switch (lua_type(L, 2)) {
            case LUA_TNUMBER:
                mp_push_transform_value(mp,
                    luaL_optnumber(L, 2, 0), // 1
                    luaL_optnumber(L, 3, 0),
                    luaL_optnumber(L, 4, 0),
                    luaL_optnumber(L, 5, 0), // 1
                    luaL_optnumber(L, 6, 0),
                    luaL_optnumber(L, 7, 0)
                );
                break;
            case LUA_TTABLE:
                mp_push_transform_value(mp,
                    lmt_number_from_table(L, 2, 1, 0.0), // 1.0
                    lmt_number_from_table(L, 2, 2, 0.0),
                    lmt_number_from_table(L, 2, 3, 0.0),
                    lmt_number_from_table(L, 2, 4, 0.0), // 1.0
                    lmt_number_from_table(L, 2, 5, 0.0),
                    lmt_number_from_table(L, 2, 6, 0.0)
                );
                break;
        }
    }
    return 0;
}

static int mplib_new(lua_State *L)
{
    MP *mpud = lua_newuserdatauv(L, sizeof(MP *), 2);
    if (mpud) {
        MP mp = NULL;
        struct MP_options *options = mp_options();
        lua_Number bendtolerance = default_bend_tolerance;
        lua_Number movetolerance = default_move_tolerance;
        options->userdata        = (void *) L;
        options->job_name        = NULL;
        options->extensions      = 0 ;
        options->utf8_mode       = 0;
        options->text_mode       = 0;
        options->show_mode      = 0;
        options->halt_on_error   = 0;
        options->find_file       = mplib_aux_find_file;
        options->run_script      = mplib_aux_run_script;
        options->run_internal    = mplib_aux_run_internal;
        options->run_logger      = mplib_aux_run_logger;
        options->run_overload    = mplib_aux_run_overload;
        options->run_error       = mplib_aux_run_error;
        options->make_text       = mplib_aux_make_text;
        options->open_file       = mplib_aux_open_file;
        options->close_file      = mplib_aux_close_file;
        options->read_file       = mplib_aux_read_file;
        options->write_file      = mplib_aux_write_file;
        options->shipout_backend = mplib_shipout_backend;
        if (lua_type(L, 1) == LUA_TTABLE) {
            lua_pushnil(L);
            while (lua_next(L, 1)) {
                if (lua_type(L, -2) == LUA_TSTRING) {
                    const char *s = lua_tostring(L, -2);
                    if (lua_key_eq(s, random_seed)) {
                        options->random_seed = (int) lua_tointeger(L, -1);
                    } else if (lua_key_eq(s, interaction)) {
                        options->interaction = luaL_checkoption(L, -1, "silent", mplib_interaction_options);
                    } else if (lua_key_eq(s, job_name)) {
                     // options->job_name = lmt_generic_strdup(lua_tostring(L, -1));
                        options->job_name = lmt_memory_strdup(lua_tostring(L, -1));
                    } else if (lua_key_eq(s, find_file)) {
                        if (mplib_aux_find_file_function(L, options)) {
                            tex_normal_warning("mplib", "find file: function expected");
                        }
                    } else if (lua_key_eq(s, run_script)) {
                        if (mplib_aux_run_script_function(L, options)) {
                            tex_normal_warning("mplib", "run script: function expected");
                        }
                    } else if (lua_key_eq(s, run_internal)) {
                        if (mplib_aux_run_internal_function(L, options)) {
                            tex_normal_warning("mplib", "run internal: function expected");
                        }
                    } else if (lua_key_eq(s, make_text)) {
                        if (mplib_aux_make_text_function(L, options)) {
                            tex_normal_warning("mplib", "make text: function expected");
                        }
                    } else if (lua_key_eq(s, extensions)) {
                        options->extensions = (int) lua_tointeger(L, -1);
                    } else if (lua_key_eq(s, math_mode)) {
                        options->math_mode = luaL_checkoption(L, -1, "scaled", mplib_math_options);
                    } else if (lua_key_eq(s, utf8_mode)) {
                        options->utf8_mode = (int) lua_toboolean(L, -1);
                    } else if (lua_key_eq(s, text_mode)) {
                        options->text_mode = (int) lua_toboolean(L, -1);
                    } else if (lua_key_eq(s, show_mode)) {
                        options->show_mode = (int) lua_toboolean(L, -1);
                    } else if (lua_key_eq(s, halt_on_error)) {
                        options->halt_on_error = (int) lua_toboolean(L, -1);
                    } else if (lua_key_eq(s, run_logger)) {
                        if (mplib_aux_run_logger_function(L, options)) {
                            tex_normal_warning("mplib", "run logger: function expected");
                        }
                    } else if (lua_key_eq(s, run_overload)) {
                        if (mplib_aux_run_overload_function(L, options)) {
                            tex_normal_warning("mplib", "run overload: function expected");
                        }
                    } else if (lua_key_eq(s, run_error)) {
                        if (mplib_aux_run_error_function(L, options)) {
                            tex_normal_warning("mplib", "run error: function expected");
                        }
                    } else if (lua_key_eq(s, open_file)) {
                        if (mplib_aux_open_file_function(L, options)) {
                            tex_normal_warning("mplib", "open file: function expected");
                        }
                    } else if (lua_key_eq(s, bend_tolerance)) {
                        bendtolerance = lua_tonumber(L, -1);
                    } else if (lua_key_eq(s, move_tolerance)) {
                        movetolerance = lua_tonumber(L, -1);
                    }
                }
                lua_pop(L, 1);
            }
        }
        if (! options->job_name || ! *(options->job_name)) {
            mp_memory_free(options); /* leaks */
            tex_normal_warning("mplib", "job_name is not set");
            goto BAD;
        }
        mp = mp_initialize(options);
        mp_memory_free(options); /* leaks */
        if (mp) {
            *mpud = mp;
            mplib_aux_set_bend_tolerance(L, bendtolerance);
            mplib_aux_set_move_tolerance(L, movetolerance);
         // luaL_getmetatable(L, MP_METATABLE_INSTANCE);
            lua_get_metatablelua(mplib_instance);
            lua_setmetatable(L, -2);
            return 1;
        }
    }
  BAD:
    lua_pushnil(L);
    return 1;
}

# define mplib_collect_id(id) do { \
    if (id) { \
        luaL_unref(L, LUA_REGISTRYINDEX, id); \
    } \
} while(0)

static int mplib_instance_collect(lua_State *L)
{
    MP *mpud = mplib_aux_is_mpud(L, 1);
    if (*mpud) {
        MP mp = *mpud;
        int run_logger_id = (mp)->run_logger_id;
        mplib_collect_id((mp)->find_file_id);
        mplib_collect_id((mp)->run_script_id);
        mplib_collect_id((mp)->run_internal_id);
        mplib_collect_id((mp)->run_overload_id);
        mplib_collect_id((mp)->run_error_id);
        mplib_collect_id((mp)->make_text_id);
        mplib_collect_id((mp)->open_file_id);
        mp_finish(mp);
        *mpud = NULL;
        mplib_collect_id(run_logger_id);
    }
    return 0;
}

static int mplib_instance_tostring(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        lua_pushfstring(L, "<mp.instance %p>", mp);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int mplib_aux_wrapresults(lua_State *L, mp_run_data *res, int status, lua_Number bendtolerance, lua_Number movetolerance)
{
    lua_newtable(L);
    if (res->edges) {
        struct mp_edge_object *p = res->edges;
        int i = 1;
        lua_push_key(fig);
        lua_newtable(L);
        while (p) {
            struct mp_edge_object **v = lua_newuserdatauv(L, sizeof(struct mp_edge_object *), 2);
            *v = p;
            mplib_aux_set_bend_tolerance(L, bendtolerance);
            mplib_aux_set_move_tolerance(L, movetolerance);
         // luaL_getmetatable(L, MP_METATABLE_FIGURE);
            lua_get_metatablelua(mplib_figure);
            lua_setmetatable(L, -2);
            lua_rawseti(L, -2, i);
            i++;
            p = p->next;
        }
        lua_rawset(L,-3);
        res->edges = NULL;
    }
    lua_push_integer_at_key(L, status, status);
    return 1;
}

static int mplib_execute(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        /* no string in slot 2 or an empty string means that we already filled the terminal */
        size_t l = 0;
        lua_Number bendtolerance = mplib_aux_get_bend_tolerance(L, 1);
        lua_Number movetolerance = mplib_aux_get_move_tolerance(L, 1);
        const char *s = lua_isstring(L, 2) ? lua_tolstring(L, 2, &l) : NULL;
        int h = mp_execute(mp, s, l);
        mp_run_data *res = mp_rundata(mp);
        return mplib_aux_wrapresults(L, res, h, bendtolerance, movetolerance);
    }
    lua_pushnil(L);
    return 1;
}

static int mplib_finish(lua_State *L)
{
    MP *mpud = mplib_aux_is_mpud(L, 1);
    if (*mpud) {
        MP mp = *mpud;
        lua_Number bendtolerance = mplib_aux_get_bend_tolerance(L, 1);
        lua_Number movetolerance = mplib_aux_get_move_tolerance(L, 1);
        int h = mp_execute(mp, NULL, 0);
        mp_run_data *res = mp_rundata(mp);
        int i = mplib_aux_wrapresults(L, res, h, bendtolerance, movetolerance);
        mp_finish(mp);
        *mpud = NULL;
        return i;
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int mplib_showcontext(lua_State *L)
{
    MP *mpud = mplib_aux_is_mpud(L, 1);
    if (*mpud) {
        MP mp = *mpud;
        mp_show_context(mp);
    }
    return 0;
}

static int mplib_gethashentry(lua_State *L)
{
    MP *mpud = mplib_aux_is_mpud(L, 1);
    if (*mpud) {
        MP mp = *mpud;
        char *name = (char *) lua_tostring(L, 2);
        if (name) {
            mp_symbol_entry *s = (mp_symbol_entry *) mp_fetch_symbol(mp, name);
            if (s) {
                mp_node q = s->type == mp_tag_command ? s->v.data.node : NULL;
                lua_pushinteger(L, s->type);
                lua_pushinteger(L, s->property);
                if (q) {
                    lua_pushinteger(L, q->type);
                    return 3;
                } else {
                    return 2;
                }
            }
        }
    }
    return 0;
}

static int mplib_gethashentries(lua_State *L)
{
    MP *mpud = mplib_aux_is_mpud(L, 1);
    if (*mpud) {
        MP mp = *mpud;
        int full = lua_toboolean(L, 2);
        if (mp_initialize_symbol_traverse(mp)) {
            size_t n = 0;
            lua_newtable(L);
            while (1) {
                mp_symbol_entry *s = (mp_symbol_entry *) mp_fetch_symbol_traverse(mp);
                if (s) {
                    if (full) {
                        mp_node q = s->type == mp_tag_command ? s->v.data.node : NULL;
                        lua_createtable(L, (q || s->property == 0x1) ? 4 : 3, 0);
                        lua_pushinteger(L, s->type);
                        lua_rawseti(L, -2, 1);
                        lua_pushinteger(L, s->property);
                        lua_rawseti(L, -2, 2);
                        lua_pushlstring(L, (const char *) s->text->str, s->text->len);
                        lua_rawseti(L, -2, 3);
                        if (q) {
                            lua_pushinteger(L, q->type);
                            lua_rawseti(L, -2, 4);
                        } else if (s->property == 0x1) {
                            lua_pushinteger(L, s->v.data.indep.serial);
                            lua_rawseti(L, -2, 4);
                        }
                    } else {
                        lua_pushlstring(L, (const char *) s->text->str, s->text->len);
                    }
                    lua_rawseti(L, -2, ++n);
                } else {
                    break;
                }
            }
            mp_kill_symbol_traverse(mp);
            return 1;
        }
    }
    return 0;
}

static int mplib_version(lua_State *L)
{
    char *s = mp_metapost_version();
    lua_pushstring(L, s);
    mp_memory_free(s);
    return 1;
}

static int mplib_getstatistics(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        lua_createtable(L, 0, 9);
        lua_push_integer_at_key(L, memory,     mp->var_used);                     /* bytes of node memory */
        lua_push_integer_at_key(L, hash,       mp->st_count);
        lua_push_integer_at_key(L, parameters, mp->max_param_stack);              /* allocated: mp->param_size */
        lua_push_integer_at_key(L, input,      mp->max_in_stack);                 /* allocated: mp->stack_size */
        lua_push_integer_at_key(L, tokens,     mp->num_token_nodes);
        lua_push_integer_at_key(L, pairs,      mp->num_pair_nodes);
        lua_push_integer_at_key(L, knots,      mp->num_knot_nodes);
        lua_push_integer_at_key(L, nodes,      mp->num_value_nodes);
        lua_push_integer_at_key(L, symbols,    mp->num_symbolic_nodes);
        lua_push_integer_at_key(L, characters, mp->max_pl_used);
        lua_push_integer_at_key(L, strings,    mp->max_strs_used);
        lua_push_integer_at_key(L, internals,  mp->int_ptr);                      /* allocates: mp->max_internal */
     /* lua_push_integer_at_key(L, buffer,     mp->max_buf_stack + 1); */         /* allocated: mp->buf_size */
     /* lua_push_integer_at_key(L, open,       mp->in_open_max - file_bottom); */ /* allocated: mp->max_in_open - file_bottom */
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int mplib_getstatus(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        lua_pushinteger(L, mp->scanner_status);
        return 1;
    } else {
        return 0;
    }
}

static int mplib_aux_set_direction(lua_State *L, MP mp, mp_knot p) {
    double direction_x = (double) lua_tonumber(L, -1);
    double direction_y = 0;
    lua_pop(L, 1);
    lua_push_key(direction_y);
    if (lua_rawget(L, -2) == LUA_TNUMBER) {
        direction_y = (double) lua_tonumber(L, -1);
        lua_pop(L, 1);
        return mp_set_knot_direction(mp, p, direction_x, direction_y) ? 1 : 0;
    } else {
        return 0;
    }
}

static int mplib_aux_set_left_curl(lua_State *L, MP mp, mp_knot p) {
    double curl = (double) lua_tonumber(L, -1);
    lua_pop(L, 1);
    return mp_set_knot_left_curl(mp, p, curl) ? 1 : 0;
}

static int mplib_aux_set_left_tension(lua_State *L, MP mp, mp_knot p) {
    double tension = (double) lua_tonumber(L, -1);
    lua_pop(L, 1);
    return mp_set_knot_left_tension(mp, p, tension) ? 1 : 0;
}

static int mplib_aux_set_left_control(lua_State *L, MP mp, mp_knot p) {
    double x = (double) lua_tonumber(L, -1);
    double y = 0;
    lua_pop(L, 1);
    lua_push_key(left_y);
    if (lua_rawget(L, -2) == LUA_TNUMBER) {
        y = (double) lua_tonumber(L, -1);
        lua_pop(L, 1);
        return mp_set_knot_left_control(mp, p, x, y) ? 1 : 0;
    } else {
        return 0;
    }
}

static int mplib_aux_set_right_curl(lua_State *L, MP mp, mp_knot p) {
    double curl = (double) lua_tonumber(L, -1);
    lua_pop(L, 1);
    return mp_set_knot_right_curl(mp, p, curl) ? 1 : 0;
}

static int mplib_aux_set_right_tension(lua_State *L, MP mp, mp_knot p) {
    double tension = (double) lua_tonumber(L, -1);
    lua_pop(L, 1);
    return mp_set_knot_right_tension(mp, p, tension) ? 1 : 0;
}

static int mplib_aux_set_right_control(lua_State *L, MP mp, mp_knot p) {
    double x = (double) lua_tonumber(L, -1);
    lua_pop(L, 1);
    lua_push_key(right_y);
    if (lua_rawget(L, -2) == LUA_TNUMBER) {
        double y = (double) lua_tonumber(L, -1);
        lua_pop(L, 1);
        return mp_set_knot_right_control(mp, p, x, y) ? 1 : 0;
    } else {
        return 0;
    }
}

static int mplib_aux_with_path(lua_State *L, MP mp, int index, int inject, int multiple)
{
 // setbuf(stdout, NULL);
    if (! mp) {
        lua_pushboolean(L, 0);
        lua_pushstring(L, "valid instance expected");
        return 2;
    } else if (! lua_istable(L, index) || lua_rawlen(L, index) <= 0) {
        lua_pushboolean(L, 0);
        lua_pushstring(L, "non empty table expected");
        return 2;
    } else {
        mp_knot p = NULL;
        mp_knot q = NULL;
        mp_knot first = NULL;
        const char *errormsg = NULL;
        int cyclic = 0;
        int curled = 0;
        int solve = 0;
        int numpoints = (int) lua_rawlen(L, index);
        /*tex
            As a bonus we check for two keys. When an index is negative we come from the
            callback in which case we definitely cannot check the rest of the arguments.
        */
        if (multiple && lua_type(L, index + 1) == LUA_TBOOLEAN) {
            cyclic = lua_toboolean(L, index + 1);
        } else {
            lua_push_key(close);
            if (lua_rawget(L, index - 1) == LUA_TBOOLEAN) {
                cyclic = lua_toboolean(L, -1);
            }
            lua_pop(L, 1);
            lua_push_key(cycle); /* wins */
            if (lua_rawget(L, index - 1) == LUA_TBOOLEAN) {
                cyclic = lua_toboolean(L, -1);
            }
            lua_pop(L, 1);
        }
        if (multiple && lua_type(L, index + 2) == LUA_TBOOLEAN) {
            curled = lua_toboolean(L, index + 2);
        } else {
            lua_push_key(curled);
            if (lua_rawget(L, index - 1) == LUA_TBOOLEAN) {
                curled = lua_toboolean(L, -1);
            }
            lua_pop(L, 1);
        }
        /*tex We build up the path. */
        if (lua_rawgeti(L, index, 1) == LUA_TTABLE) {
            lua_Unsigned len = lua_rawlen(L, -1);
            lua_pop(L, 1);
            if (len >= 2) {
                /* .. : p1 .. controls a and b         .. p2  : { p1 a   b   } */
                /* -- : p1 .. { curl 1 } .. { curl 1 } .. p2  : { p1 nil nil } */
                for (int i = 1; i <= numpoints; i++) {
                    if (lua_rawgeti(L, index, i) == LUA_TTABLE) {
                        double x0, y0;
                        lua_rawgeti(L, -1, 1);
                        lua_rawgeti(L, -2, 2);
                        x0 = lua_tonumber(L, -2);
                        y0 = lua_tonumber(L, -1);
                        q = p;
                        p = mp_append_knot_xy(mp, p, x0, y0); /* makes end point */
                        lua_pop(L, 2);
                        if (p) {
                            double x1, y1, x2, y2;
                            if (curled) {
                                x1 = x0;
                                y1 = y0;
                                x2 = x0;
                                y2 = y0;
                            } else {
                                lua_rawgeti(L, -1, 3);
                                lua_rawgeti(L, -2, 4);
                                lua_rawgeti(L, -3, 5);
                                lua_rawgeti(L, -4, 6);
                                x1 = luaL_optnumber(L, -4, x0);
                                y1 = luaL_optnumber(L, -3, y0);
                                x2 = luaL_optnumber(L, -2, x0);
                                y2 = luaL_optnumber(L, -1, y0);
                                lua_pop(L, 4);
                            }
                            mp_set_knot_left_control(mp, p, x1, y1);
                            mp_set_knot_right_control(mp, p, x2, y2);
                            if (! first) {
                                first = p;
                            }
                        } else {
                            errormsg = "knot creation failure";
                            goto BAD;
                        }
                    }
                    /*tex Up the next item */
                    lua_pop(L, 1);
                }
            } else if (len > 0) {
                errormsg = "messy table";
                goto BAD;
            } else {
                for (int i = 1; i <= numpoints; i++) {
                    if (lua_rawgeti(L, index, i) == LUA_TTABLE) {
                        /* We can probably also use the _xy here. */
                        int left_set = 0;
                        int right_set = 0;
                        double x_coord, y_coord;
                        if (! lua_istable(L, -1)) {
                            errormsg = "wrong argument types";
                            goto BAD;
                        }
                        lua_push_key(x_coord);
                        if (lua_rawget(L, -2) != LUA_TNUMBER) {
                            errormsg = "missing x coordinate";
                            goto BAD;
                        }
                        x_coord = (double) lua_tonumber(L, -1);
                        lua_pop(L, 1);
                        lua_push_key(y_coord);
                        if (lua_rawget(L, -2) != LUA_TNUMBER) {
                            errormsg = "missing y coordinate";
                            goto BAD;
                        }
                        y_coord = (double) lua_tonumber(L, -1);
                        lua_pop(L, 1);
                        /* */
                        q = p;
                        if (q) {
                            /*tex
                                We have to save the right_tension because |mp_append_knot| trashes it,
                                believing that it is as yet uninitialized .. I need to check this.
                            */
                            double saved_tension = mp_number_as_double(mp, p->right_tension);
                            p = mp_append_knot(mp, p, x_coord, y_coord);
                            if (p) {
                                mp_set_knot_right_tension(mp, q, saved_tension);
                            }
                        } else {
                            p = mp_append_knot(mp, p, x_coord, y_coord);
                        }
                        if (p) {
                            errormsg = "knot creation failure";
                            goto BAD;
                        }
                        /* */
                        if (! first) {
                            first = p;
                        }
                        lua_push_key(left_curl);
                        if (lua_rawget(L, -2) != LUA_TNUMBER) {
                            lua_pop(L, 1);
                        } else if (! mplib_aux_set_left_curl(L, mp, p)) {
                            errormsg = "failed to set left curl";
                            goto BAD;
                        } else {
                            left_set  = 1;
                            solve = 1;
                        }
                        lua_push_key(left_tension);
                        if (lua_rawget(L, -2) != LUA_TNUMBER) {
                            lua_pop(L, 1);
                        } else if (left_set) {
                            errormsg = "left side already set";
                            goto BAD;
                        } else if (! mplib_aux_set_left_tension(L, mp, p)) {
                            errormsg = "failed to set left tension";
                            goto BAD;
                        } else {
                            left_set = 1;
                            solve = 1;
                        }
                        lua_push_key(left_x);
                        if (lua_rawget(L, -2) != LUA_TNUMBER) {
                            lua_pop(L, 1);
                        } else if (left_set) {
                            errormsg = "left side already set";
                            goto BAD;
                        } else if (! mplib_aux_set_left_control(L, mp, p)) {
                            errormsg = "failed to set left control";
                            goto BAD;
                        }
                        lua_push_key(right_curl);
                        if (lua_rawget(L, -2) != LUA_TNUMBER) {
                            lua_pop(L, 1);
                        } else if (! mplib_aux_set_right_curl(L, mp, p)) {
                            errormsg = "failed to set right curl";
                            goto BAD;
                        } else {
                            right_set  = 1;
                            solve = 1;
                        }
                        lua_push_key(right_tension);
                        if (lua_rawget(L, -2) != LUA_TNUMBER) {
                            lua_pop(L,1);
                        } else if (right_set) {
                            errormsg = "right side already set";
                            goto BAD;
                        } else if (! mplib_aux_set_right_tension(L, mp, p)) {
                            errormsg = "failed to set right tension";
                            goto BAD;
                        } else {
                            right_set = 1;
                            solve = 1;
                        }
                        lua_push_key(right_x);
                        if (lua_rawget(L, -2) != LUA_TNUMBER) {
                            lua_pop(L, 1);
                        } else if (right_set) {
                            errormsg = "right side already set";
                            goto BAD;
                        } else if (! mplib_aux_set_right_control(L, mp, p)) {
                            errormsg = "failed to set right control";
                            goto BAD;
                        }
                        lua_push_key(direction_x);
                        if (lua_rawget(L, -2) != LUA_TNUMBER) {
                            lua_pop(L, 1);
                        } else if (! mplib_aux_set_direction(L, mp, p)) {
                            errormsg = "failed to set direction";
                            goto BAD;
                        }
                    }
                    lua_pop(L, 1);
                }
            }
        }
        if (first && p) {
            /* not: mp_close_path(mp, p, first); */
            if (cyclic) {
                p->right_type = mp_explicit_knot;
                first->left_type = mp_explicit_knot;
            } else {
                /* check this on shapes-001.tex and arrows-001.tex */
                p->right_type = mp_endpoint_knot;
                first->left_type = mp_endpoint_knot;
            }
            p->next = first;
            if (inject) {
                if (solve && ! mp_solve_path(mp, first)) {
                    tex_normal_warning("lua", "failed to solve the path");
                }
                mp_push_path_value(mp, first);
                return 0;
            } else {
                /*tex We're finished reading arguments so we squeeze the new values back into the table. */
                if (! mp_solve_path(mp, first)) {
                    errormsg = "failed to solve the path";
                } else {
                    /* We replace in the original table .. maybe not a good idea at all. */
                    p = first;
                    for (int i = 1; i <= numpoints; i++) {
                        lua_rawgeti(L, -1, i);
                        lua_push_number_at_key(L, left_x,  mp_number_as_double(mp, p->left_x));
                        lua_push_number_at_key(L, left_y,  mp_number_as_double(mp, p->left_y));
                        lua_push_number_at_key(L, right_x, mp_number_as_double(mp, p->right_x));
                        lua_push_number_at_key(L, right_y, mp_number_as_double(mp, p->right_y));
                        /*tex This is a bit overkill, wiping  \unknown */
                        lua_push_nil_at_key(L, left_tension);
                        lua_push_nil_at_key(L, right_tension);
                        lua_push_nil_at_key(L, left_curl);
                        lua_push_nil_at_key(L, right_curl);
                        lua_push_nil_at_key(L, direction_x);
                        lua_push_nil_at_key(L, direction_y);
                        /*tex \unknown\ till here. */
                        lua_push_svalue_at_key(L, left_type, mplib_values_knot[p->left_type]);
                        lua_push_svalue_at_key(L, right_type, mplib_values_knot[p->right_type]);
                        lua_pop(L, 1);
                        p = p->next;
                    }
                    lua_pushboolean(L, 1);
                    return 1;
                }
            }
        } else {
            errormsg = "invalid path";
        }
      BAD:
        if (p) {
            mp_free_path(mp, p);
        }
        lua_pushboolean(L, 0);
        if (errormsg) {
            lua_pushstring(L, errormsg);
            return 2;
        } else {
            return 1;
        }
    }
}

static int mplib_solvepath(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        return mplib_aux_with_path(L, mp, 2, 0, 1);
    } else {
        return 0;
    }
}

static int mplib_inject_path(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        return mplib_aux_with_path(L, mp, 2, 1, 1);
    } else {
        return 0;
    }
}

static int mplib_inject_whatever(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        mplib_aux_inject_whatever(L, mp, 2);
    }
    return 0;
}

/*tex The next methods are for collecting the results from |fig|. */

static int mplib_figure_collect(lua_State *L)
{
    struct mp_edge_object **hh = mplib_aux_is_figure(L, 1);
    if (*hh) {
        mp_gr_toss_objects(*hh);
        *hh = NULL;
    }
    return 0;
}

static int mplib_figure_objects(lua_State *L)
{
    struct mp_edge_object **hh = mplib_aux_is_figure(L, 1);
    if (*hh) {
        int i = 1;
        struct mp_graphic_object *p = (*hh)->body;
        lua_Number bendtolerance = mplib_aux_get_bend_tolerance(L, 1);
        lua_Number movetolerance = mplib_aux_get_move_tolerance(L, 1);
        lua_newtable(L);
        while (p) {
            struct mp_graphic_object **v = lua_newuserdatauv(L, sizeof(struct mp_graphic_object *), 2);
            *v = p;
            mplib_aux_set_bend_tolerance(L, bendtolerance);
            mplib_aux_set_move_tolerance(L, movetolerance);
         // luaL_getmetatable(L, MP_METATABLE_OBJECT);
            lua_get_metatablelua(mplib_object);
            lua_setmetatable(L, -2);
            lua_rawseti(L, -2, i);
            i++;
            p = p->next;
        }
        /*tex Prevent a double free: */
        (*hh)->body = NULL;
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int mplib_figure_stacking(lua_State *L)
{
    struct mp_edge_object **hh = mplib_aux_is_figure(L, 1);
    int stacking = 0; /* This only works when before fetching objects! */
    if (*hh) {
        struct mp_graphic_object *p = (*hh)->body;
        while (p) {
            if (((mp_shape_object *) p)->stacking) {
                stacking = 1;
                break;
            } else {
                p = p->next;
            }
        }
    }
    lua_pushboolean(L, stacking);
    return 1;
}

static int mplib_figure_tostring(lua_State *L)
{
    struct mp_edge_object **hh = mplib_aux_is_figure(L, 1);
    if (*hh) {
        lua_pushfstring(L, "<mp.figure %p>", *hh);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int mplib_figure_width(lua_State *L)
{
    struct mp_edge_object **hh = mplib_aux_is_figure(L, 1);
    if (*hh) {
        lua_pushnumber(L, (*hh)->width);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int mplib_figure_height(lua_State *L)
{
    struct mp_edge_object **hh = mplib_aux_is_figure(L, 1);
    if (*hh) {
        lua_pushnumber(L, (*hh)->height);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int mplib_figure_depth(lua_State *L)
{
    struct mp_edge_object **hh = mplib_aux_is_figure(L, 1);
    if (*hh) {
        lua_pushnumber(L, (*hh)->depth);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int mplib_figure_italic(lua_State *L)
{
    struct mp_edge_object **hh = mplib_aux_is_figure(L, 1);
    if (*hh) {
        lua_pushnumber(L, (*hh)->italic);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int mplib_figure_charcode(lua_State *L)
{
    struct mp_edge_object **hh = mplib_aux_is_figure(L, 1);
    if (*hh) {
        lua_pushinteger(L, (lua_Integer) (*hh)->charcode);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int mplib_figure_tolerance(lua_State *L)
{
    struct mp_edge_object **hh = mplib_aux_is_figure(L, 1);
    if (*hh) {
        lua_pushnumber(L, mplib_aux_get_bend_tolerance(L, 1));
        lua_pushnumber(L, mplib_aux_get_move_tolerance(L, 1));
    } else {
        lua_pushnil(L);
        lua_pushnil(L);
    }
    return 2;
}

static int mplib_figure_bounds(lua_State *L)
{
    struct mp_edge_object **hh = mplib_aux_is_figure(L, 1);
    lua_createtable(L, 4, 0);
    lua_push_number_at_index(L, 1, (*hh)->minx);
    lua_push_number_at_index(L, 2, (*hh)->miny);
    lua_push_number_at_index(L, 3, (*hh)->maxx);
    lua_push_number_at_index(L, 4, (*hh)->maxy);
    return 1;
}

/*tex The methods for the figure objects plus a few helpers. */

static int mplib_object_collect(lua_State *L)
{
    struct mp_graphic_object **hh = mplib_aux_is_gr_object(L, 1);
    if (*hh) {
        mp_gr_toss_object(*hh);
        *hh = NULL;
    }
    return 0;
}

static int mplib_object_tostring(lua_State *L)
{
    struct mp_graphic_object **hh = mplib_aux_is_gr_object(L, 1);
    lua_pushfstring(L, "<mp.object %p>", *hh);
    return 1;
}

# define pyth(a,b)      (sqrt((a)*(a) + (b)*(b)))
# define aspect_bound   (10.0/65536.0)
# define aspect_default 1.0
# define eps            0.0001

static double mplib_aux_coord_range_x(mp_gr_knot h, double dz)
{
    double zlo = 0.0;
    double zhi = 0.0;
    mp_gr_knot f = h;
    while (h) {
        double z = h->x_coord;
        if (z < zlo) {
            zlo = z;
        } else if (z > zhi) {
            zhi = z;
        }
        z = h->right_x;
        if (z < zlo) {
            zlo = z;
        } else if (z > zhi) {
            zhi = z;
        }
        z = h->left_x;
        if (z < zlo) {
            zlo = z;
        } else if (z > zhi) {
            zhi = z;
        }
        h = h->next;
        if (h == f) {
            break;
        }
    }
    return (zhi - zlo <= dz) ? aspect_bound : aspect_default;
}

static double mplib_aux_coord_range_y(mp_gr_knot h, double dz)
{
    double zlo = 0.0;
    double zhi = 0.0;
    mp_gr_knot f = h;
    while (h) {
        double z = h->y_coord;
        if (z < zlo) {
            zlo = z;
        } else if (z > zhi) {
            zhi = z;
        }
        z = h->right_y;
        if (z < zlo) {
            zlo = z;
        } else if (z > zhi) {
            zhi = z;
        }
        z = h->left_y;
        if (z < zlo) {
            zlo = z;
        } else if (z > zhi) {
            zhi = z;
        }
        h = h->next;
        if (h == f) {
            break;
        }
    }
    return (zhi - zlo <= dz) ? aspect_bound : aspect_default;
}

static int mplib_object_peninfo(lua_State *L)
{
    struct mp_graphic_object **hh = mplib_aux_is_gr_object(L, -1);
    if (! *hh) {
        lua_pushnil(L);
        return 1;
    } else {
        mp_gr_knot p = NULL;
        mp_gr_knot path = NULL;
        switch ((*hh)->type) { 
            case mp_fill_code:
            case mp_stroked_code:
                p    = ((mp_shape_object *) (*hh))->pen;
                path = ((mp_shape_object *) (*hh))->path;
                break;
        }
        if (! p || ! path) {
            lua_pushnil(L);
            return 1;
        } else {
            double wx, wy;
            double rx = 1.0, sx = 0.0, sy = 0.0, ry = 1.0, tx = 0.0, ty = 0.0;
            double width = 1.0;
            double x_coord = p->x_coord;
            double y_coord = p->y_coord;
            double left_x  = p->left_x;
            double left_y  = p->left_y;
            double right_x = p->right_x;
            double right_y = p->right_y;
            if ((right_x == x_coord) && (left_y == y_coord)) {
                wx = fabs(left_x  - x_coord);
                wy = fabs(right_y - y_coord);
            } else {
                wx = pyth(left_x - x_coord, right_x - x_coord);
                wy = pyth(left_y - y_coord, right_y - y_coord);
            }
            if ((wy/mplib_aux_coord_range_x(path, wx)) >= (wx/mplib_aux_coord_range_y(path, wy))) {
                width = wy;
            } else {
                width = wx;
            }
            tx = x_coord;
            ty = y_coord;
            sx = left_x - tx;
            rx = left_y - ty;
            ry = right_x - tx;
            sy = right_y - ty;
            if (width != 1.0) {
                if (width == 0.0) {
                    sx = 1.0;
                    sy = 1.0;
                } else {
                    rx /= width;
                    ry /= width;
                    sx /= width;
                    sy /= width;
                }
            }
            if (fabs(sx) < eps) {
                sx = eps;
            }
            if (fabs(sy) < eps) {
                sy = eps;
            }
            lua_createtable(L,0,7);
            lua_push_number_at_key(L, width, width);
            lua_push_number_at_key(L, rx, rx);
            lua_push_number_at_key(L, sx, sx);
            lua_push_number_at_key(L, sy, sy);
            lua_push_number_at_key(L, ry, ry);
            lua_push_number_at_key(L, tx, tx);
            lua_push_number_at_key(L, ty, ty);
            return 1;
        }
    }
}

/*tex Here is a helper that reports the valid field names of the possible objects. */

static void mplib_aux_mplib_push_fields(lua_State* L, const char **fields)
{
    lua_newtable(L);
    for (lua_Integer i = 0; fields[i]; i++) {
        lua_pushstring(L, fields[i]); /* not yet an index */
        lua_rawseti(L, -2, i + 1);
    }
}

static int mplib_gettype(lua_State *L)
{
    struct mp_graphic_object **hh = mplib_aux_is_gr_object(L, 1);
    if (*hh) {
        lua_pushinteger(L, (*hh)->type);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int mplib_getobjecttypes(lua_State* L)
{
    lua_createtable(L, 7, 1);
    lua_push_key_at_index(L, fill,         mp_fill_code);
    lua_push_key_at_index(L, outline,      mp_stroked_code);
    lua_push_key_at_index(L, start_clip,   mp_start_clip_code);
    lua_push_key_at_index(L, start_group,  mp_start_group_code);
    lua_push_key_at_index(L, start_bounds, mp_start_bounds_code);
    lua_push_key_at_index(L, stop_clip,    mp_stop_clip_code);
    lua_push_key_at_index(L, stop_group,   mp_stop_group_code);
    lua_push_key_at_index(L, stop_bounds,  mp_stop_bounds_code);
    return 1;
}

static int mplib_getfields(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TUSERDATA) {
        struct mp_graphic_object **hh = mplib_aux_is_gr_object(L, 1);
        if (*hh) {
            const char **fields;
            switch ((*hh)->type) {
                case mp_fill_code        : fields = mplib_fill_fields;         break;
                case mp_stroked_code     : fields = mplib_stroked_fields;      break;
                case mp_start_clip_code  : fields = mplib_start_clip_fields;   break;
                case mp_start_group_code : fields = mplib_start_group_fields;  break;
                case mp_start_bounds_code: fields = mplib_start_bounds_fields; break;
                case mp_stop_clip_code   : fields = mplib_stop_clip_fields;    break;
                case mp_stop_group_code  : fields = mplib_stop_group_fields;   break;
                case mp_stop_bounds_code : fields = mplib_stop_bounds_fields;  break;
                default                  : fields = mplib_no_fields;           break;
            }
            mplib_aux_mplib_push_fields(L, fields);
        } else {
            lua_pushnil(L);
        }
    } else {
        lua_createtable(L, 8, 0);
        mplib_aux_mplib_push_fields(L, mplib_fill_fields);         lua_rawseti(L, -2, mp_fill_code);
        mplib_aux_mplib_push_fields(L, mplib_stroked_fields);      lua_rawseti(L, -2, mp_stroked_code);
        mplib_aux_mplib_push_fields(L, mplib_start_clip_fields);   lua_rawseti(L, -2, mp_start_clip_code);
        mplib_aux_mplib_push_fields(L, mplib_start_group_fields);  lua_rawseti(L, -2, mp_start_group_code);
        mplib_aux_mplib_push_fields(L, mplib_start_bounds_fields); lua_rawseti(L, -2, mp_start_bounds_code);
        mplib_aux_mplib_push_fields(L, mplib_stop_clip_fields);    lua_rawseti(L, -2, mp_stop_clip_code);
        mplib_aux_mplib_push_fields(L, mplib_stop_group_fields);   lua_rawseti(L, -2, mp_stop_group_code);
        mplib_aux_mplib_push_fields(L, mplib_stop_bounds_fields);  lua_rawseti(L, -2, mp_stop_bounds_code);
    }
    return 1;
}

static int mplib_push_values(lua_State *L, const char *list[])
{
    lua_newtable(L);
    for (lua_Integer i = 0; list[i]; i++) {
        lua_pushstring(L, list[i]);
        lua_rawseti(L, -2, i);
    }
    return 1;
}

static int mplib_getcodes(lua_State *L)
{
    return mplib_push_values(L, mplib_codes);
}

static int mplib_gettypes(lua_State *L)
{
    return mplib_push_values(L, mplib_types);
}

static int mplib_getcolormodels(lua_State *L)
{
    return mplib_push_values(L, mplib_colormodels);
}

static int mplib_getstates(lua_State *L)
{
    return mplib_push_values(L, mplib_states);
}

static int mplib_getcallbackstate(lua_State *L)
{
    lua_createtable(L, 0, 5);
    lua_push_integer_at_key(L, file,       mplib_state.file_callbacks);
    lua_push_integer_at_key(L, text,       mplib_state.text_callbacks);
    lua_push_integer_at_key(L, script,     mplib_state.script_callbacks);
    lua_push_integer_at_key(L, log,        mplib_state.log_callbacks);
    lua_push_integer_at_key(L, overloaded, mplib_state.overload_callbacks);
    lua_push_integer_at_key(L, error,      mplib_state.error_callbacks);
    lua_push_integer_at_key(L, warning,    mplib_state.warning_callbacks);
    lua_push_integer_at_key(L, count,
          mplib_state.file_callbacks     + mplib_state.text_callbacks
        + mplib_state.script_callbacks   + mplib_state.log_callbacks
        + mplib_state.overload_callbacks + mplib_state.error_callbacks
        + mplib_state.warning_callbacks
    );
    return 1;
}

/*tex

    This assumes that the top of the stack is a table or nil already in the case.
*/

static void mplib_aux_push_color(lua_State *L, struct mp_graphic_object *p)
{
    if (p) {
        int object_color_model;
        mp_color object_color;
        switch (p->type) {
            case mp_fill_code:
            case mp_stroked_code:
                {
                    mp_shape_object *h = (mp_shape_object *) p;
                    object_color_model = h->color_model; 
                    object_color = h->color; 
                }
                break;
            default:
                object_color_model = mp_no_model;
                object_color = (mp_color) { { 0.0 }, { 0.0 }, { 0.0 }, { 0.0 } };
                break;
        }
        switch (object_color_model) {
            case mp_grey_model:
                lua_createtable(L, 1, 0);
                lua_push_number_at_index(L, 1, object_color.gray);
                break;
            case mp_rgb_model:
                lua_createtable(L, 3, 0);
                lua_push_number_at_index(L, 1, object_color.red);
                lua_push_number_at_index(L, 2, object_color.green);
                lua_push_number_at_index(L, 3, object_color.blue);
                break;
            case mp_cmyk_model:
                lua_createtable(L, 4, 0);
                lua_push_number_at_index(L, 1, object_color.cyan);
                lua_push_number_at_index(L, 2, object_color.magenta);
                lua_push_number_at_index(L, 3, object_color.yellow);
                lua_push_number_at_index(L, 4, object_color.black);
                break;
            default:
                lua_pushnil(L);
                break;
        }
    } else {
        lua_pushnil(L);
    }
}

/*tex The dash scale is not exported, the field has no external value. */

static void mplib_aux_push_dash(lua_State *L, struct mp_shape_object *h)
{
    if (h && h->dash) {
        mp_dash_object *d = h->dash;
        lua_newtable(L); /* we could start at size 2 or so */
        lua_push_number_at_key(L, offset, d->offset);
        if (d->array) {
            int i = 0;
            lua_push_key(dashes);
            lua_newtable(L);
            while (*(d->array + i) != -1) {
                double ds = *(d->array + i);
                lua_pushnumber(L, ds);
                i++;
                lua_rawseti(L, -2, i);
            }
            lua_rawset(L, -3);
        }
    } else {
        lua_pushnil(L);
    }
}

static void mplib_aux_shape(lua_State *L, const char *s, struct mp_shape_object *h, lua_Number bendtolerance, lua_Number movetolerance)
{
    if (lua_key_eq(s, path)) {
        mplib_aux_push_path(L, h->path, MPLIB_PATH, bendtolerance, movetolerance);
    } else if (lua_key_eq(s, htap)) {
        mplib_aux_push_path(L, h->htap, MPLIB_PATH, bendtolerance, movetolerance);
    } else if (lua_key_eq(s, pen)) {
        mplib_aux_push_path(L, h->pen, MPLIB_PEN, bendtolerance, movetolerance);
        /* pushed in the table at the top */
        mplib_aux_push_pentype(L, h->pen);
    } else if (lua_key_eq(s, color)) {
        mplib_aux_push_color(L, (mp_graphic_object *) h);
    } else if (lua_key_eq(s, linejoin)) {
        lua_pushnumber(L, (lua_Number) h->linejoin);
    } else if (lua_key_eq(s, linecap)) {
        lua_pushnumber(L, (lua_Number) h->linecap);
 // } else if (lua_key_eq(s, stacking)) {
 //     lua_pushinteger(L, (lua_Integer) h->stacking);
    } else if (lua_key_eq(s, miterlimit)) {
        lua_pushnumber(L, h->miterlimit);
    } else if (lua_key_eq(s, prescript)) {
        lua_pushlstring(L, h->pre_script, h->pre_length);
    } else if (lua_key_eq(s, postscript)) {
        lua_pushlstring(L, h->post_script, h->post_length);
    } else if (lua_key_eq(s, dash)) {
        mplib_aux_push_dash(L, h);
    } else {
        lua_pushnil(L);
    }
}

static void mplib_aux_start(lua_State *L, const char *s, struct mp_start_object *h, lua_Number bendtolerance, lua_Number movetolerance)
{
    if (lua_key_eq(s, path)) {
        mplib_aux_push_path(L, h->path, MPLIB_PATH, bendtolerance, movetolerance);
    } else if (lua_key_eq(s, prescript)) {
        lua_pushlstring(L, h->pre_script, h->pre_length);
    } else if (lua_key_eq(s, postscript)) {
        lua_pushlstring(L, h->post_script, h->post_length);
 // } else if (lua_key_eq(s, stacking)) {
 //     lua_pushinteger(L, (lua_Integer) h->stacking);
    } else {
        lua_pushnil(L);
    }
}

// static void mplib_aux_stop(lua_State *L, const char *s, struct mp_stop_object *h, lua_Number bendtolerance, lua_Number movetolerance)
// {
//     if (lua_key_eq(s, stacking)) {
//         lua_pushinteger(L, (lua_Integer) h->stacking);
//     } else {
//         lua_pushnil(L);
//     }
// }

static int mplib_object_index(lua_State *L)
{
    struct mp_graphic_object **hh = mplib_aux_is_gr_object(L, 1); /* no need for test */
    if (*hh) {
        struct mp_graphic_object *h = *hh;
        const char *s = lua_tostring(L, 2);
        /* todo: remove stacking from specific aux  */
        if (lua_key_eq(s, type)) {
            lua_push_key_by_index(mplib_values_type[h->type]);
        } else if (lua_key_eq(s, stacking)) {
            lua_pushinteger(L, (lua_Integer) h->stacking);
        } else {
            lua_Number bendtolerance = mplib_aux_get_bend_tolerance(L, 1);
            lua_Number movetolerance = mplib_aux_get_move_tolerance(L, 1);
            /* todo: we can use generic casts */
            switch (h->type) {
                case mp_fill_code:
                case mp_stroked_code:
                    mplib_aux_shape(L, s, (mp_shape_object *) h, bendtolerance, movetolerance);
                    break;
                case mp_start_clip_code:
                case mp_start_group_code:
                case mp_start_bounds_code:
                    mplib_aux_start(L, s, (mp_start_object *) h, bendtolerance, movetolerance);
                    break;
             // case mp_stop_clip_code:
             // case mp_stop_group_code:
             // case mp_stop_bounds_code:
             //     mplib_aux_stop_clip(L, s, (mp_stop_object *) h, bendtolerance, movetolerance);
             //     break;
                default:
                    lua_pushnil(L);
                    break;
            }
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* Experiment: mpx, kind, macro, arguments */

static int mplib_expand_tex(lua_State *L)
{
    MP mp = mplib_aux_is_mp(L, 1);
    if (mp) {
        int kind = lmt_tointeger(L, 2);
        halfword tail = null;
        halfword head = lmt_macro_to_tok(L, 3, &tail);
        if (head) {
            switch (kind) {
                case lua_value_none_code:
                case lua_value_dimension_code:
                    {
                        halfword value = 0;
                        halfword space = tex_get_available_token(space_token);
                        halfword relax = tex_get_available_token(deep_frozen_relax_token);
                        token_link(tail) = space;
                        token_link(space) = relax;
                        tex_begin_inserted_list(head);
                        lmt_error_state.intercept = 1;
                        lmt_error_state.last_intercept = 0;
                        value = tex_scan_dimen(0, 0, 0, 0, NULL);
                        lmt_error_state.intercept = 0;
                        while (cur_tok != deep_frozen_relax_token) {
                            tex_get_token();
                        }
                        if (! lmt_error_state.last_intercept) {
                            mp_push_numeric_value(mp, (double) value * (7200.0/7227.0) / 65536.0);
                            break;
                        } else if (kind == lua_value_none_code) {
                            head = lmt_macro_to_tok(L, 3, &tail);
                            goto TRYAGAIN;
                        } else {
                         // head = lmt_macro_to_tok(L, 3, &tail);
                         // goto JUSTINCASE;
                            lua_pushboolean(L, 0);
                            return 1;
                        }
                    }
                case lua_value_integer_code:
                case lua_value_cardinal_code:
                case lua_value_boolean_code:
                  TRYAGAIN:
                    {
                        halfword value = 0;
                        halfword space = tex_get_available_token(space_token);
                        halfword relax = tex_get_available_token(deep_frozen_relax_token);
                        token_link(tail) = space;
                        token_link(space) = relax;
                        tex_begin_inserted_list(head);
                        lmt_error_state.intercept = 1;
                        lmt_error_state.last_intercept = 0;
                        value = tex_scan_int(0, NULL);
                        lmt_error_state.intercept = 0;
                        while (cur_tok != deep_frozen_relax_token) {
                            tex_get_token();
                        }
                        if (lmt_error_state.last_intercept) {
                         // head = lmt_macro_to_tok(L, 3, &tail);
                         // goto JUSTINCASE;
                            lua_pushboolean(L, 0);
                            return 1;
                        } else if (kind == lua_value_boolean_code) {
                            mp_push_boolean_value(mp, value);
                            break;
                        } else {
                            mp_push_numeric_value(mp, value);
                            break;
                        }
                    }
                default:
               // JUSTINCASE:
                    {
                        int len = 0;
                        const char *str = (const char *) lmt_get_expansion(head, &len);
                        mp_push_string_value(mp, str, str ? len : 0); /* len includes \0 */
                        break;
                    }
            }
        }
    }
    lua_pushboolean(L, 1);
    return 1;
}

/* */

static const struct luaL_Reg mplib_instance_metatable[] = {
    { "__gc",       mplib_instance_collect  },
    { "__tostring", mplib_instance_tostring },
    { NULL,         NULL                    },
};

static const struct luaL_Reg mplib_figure_metatable[] = {
    { "__gc",         mplib_figure_collect   },
    { "__tostring",   mplib_figure_tostring  },
    { "objects",      mplib_figure_objects   },
    { "boundingbox",  mplib_figure_bounds    },
    { "width",        mplib_figure_width     },
    { "height",       mplib_figure_height    },
    { "depth",        mplib_figure_depth     },
    { "italic",       mplib_figure_italic    },
    { "charcode",     mplib_figure_charcode  },
    { "tolerance",    mplib_figure_tolerance },
    { "stacking",     mplib_figure_stacking  },
    { NULL,           NULL                   },
};

static const struct luaL_Reg mplib_object_metatable[] = {
    { "__gc",       mplib_object_collect  },
    { "__tostring", mplib_object_tostring },
    { "__index",    mplib_object_index    },
    { NULL,         NULL                  },
};

static const struct luaL_Reg mplib_instance_functions_list[] = {
    { "execute",       mplib_execute       },
    { "finish",        mplib_finish        },
    { "getstatistics", mplib_getstatistics },
    { "getstatus",     mplib_getstatus     },
    { "solvepath",     mplib_solvepath     },
    { NULL,            NULL                },
};

static const struct luaL_Reg mplib_functions_list[] = {
    { "new",              mplib_new              },
    { "version",          mplib_version          },
    /* */
    { "getfields",        mplib_getfields        },
    { "gettype",          mplib_gettype          },
    { "gettypes",         mplib_gettypes         },
    { "getcolormodels",   mplib_getcolormodels   },
    { "getcodes",         mplib_getcodes         },
    { "getstates",        mplib_getstates        },
    { "getobjecttypes",   mplib_getobjecttypes   },
    { "getcallbackstate", mplib_getcallbackstate },
    /* */
    { "settolerance",     mplib_set_tolerance    },
    { "gettolerance",     mplib_get_tolerance    },
    /* indirect */
    { "execute",          mplib_execute          },
    { "finish",           mplib_finish           },
    { "showcontext",      mplib_showcontext      },
    { "gethashentries",   mplib_gethashentries   },
    { "gethashentry",     mplib_gethashentry     },
    { "getstatistics",    mplib_getstatistics    },
    { "getstatus",        mplib_getstatus        },
    { "solvepath",        mplib_solvepath        },
    /* helpers */
    { "peninfo",          mplib_object_peninfo   },
    /* scanners */
    { "scannext",         mplib_scan_next        },
    { "scanexpression",   mplib_scan_expression  },
    { "scantoken",        mplib_scan_token       },
    { "scansymbol",       mplib_scan_symbol      },
    { "scanproperty",     mplib_scan_property    },
    { "scannumeric",      mplib_scan_numeric     },
    { "scannumber",       mplib_scan_numeric     }, /* bonus */
    { "scaninteger",      mplib_scan_integer     },
    { "scanboolean",      mplib_scan_boolean     },
    { "scanstring",       mplib_scan_string      },
    { "scanpair",         mplib_scan_pair        },
    { "scancolor",        mplib_scan_color       },
    { "scancmykcolor",    mplib_scan_cmykcolor   },
    { "scantransform",    mplib_scan_transform   },
    { "scanpath",         mplib_scan_path        },
    { "scanpen",          mplib_scan_pen         },
    /* skippers */
    { "skiptoken",        mplib_skip_token       },
    /* injectors */
    { "injectnumeric",    mplib_inject_numeric   },
    { "injectnumber",     mplib_inject_numeric   }, /* bonus */
    { "injectinteger",    mplib_inject_integer   },
    { "injectboolean",    mplib_inject_boolean   },
    { "injectstring",     mplib_inject_string    },
    { "injectpair",       mplib_inject_pair      },
    { "injectcolor",      mplib_inject_color     },
    { "injectcmykcolor",  mplib_inject_cmykcolor },
    { "injecttransform",  mplib_inject_transform },
    { "injectpath",       mplib_inject_path      },
    { "injectwhatever",   mplib_inject_whatever  },
    /* */
    { "expandtex",        mplib_expand_tex       },
    /* */
    { NULL,               NULL                   },
};

int luaopen_mplib(lua_State *L)
{
    mplib_aux_initialize_lua(L);

    luaL_newmetatable(L, MP_METATABLE_OBJECT);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_setfuncs(L, mplib_object_metatable, 0);
    luaL_newmetatable(L, MP_METATABLE_FIGURE);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_setfuncs(L, mplib_figure_metatable, 0);
    luaL_newmetatable(L, MP_METATABLE_INSTANCE);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_setfuncs(L, mplib_instance_metatable, 0);
    luaL_setfuncs(L, mplib_instance_functions_list, 0);
    lua_newtable(L);
    luaL_setfuncs(L, mplib_functions_list, 0);
    return 1;
}
