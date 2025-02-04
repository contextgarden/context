/*
    See license.txt in the root of this project.
*/

/*tex

    This module has been there from the start and provides some information that doesn't really
    fit elsewhere. In \LUATEX\ the module got extended ovet time, and in \LUAMETATEX\ most of what
    is here has been redone, also because we want different statistics.

*/
# include "luametatex.h"

# define STATS_METATABLE "tex.stats"

typedef struct statistic_entry {
    const char *name;
    void       *value;
    int         type;
    int         padding;
} statistic_entry;

typedef const char *(*constfunc) (void);
typedef char       *(*charfunc)  (void);
typedef lua_Number  (*numfunc)   (void);
typedef int         (*intfunc)   (void);
typedef int         (*luafunc)   (lua_State *L);

static int statslib_callbackstate(lua_State *L)
{
    lmt_push_callback_usage(L);
    return 1;
}

static int statslib_linebreakstate(lua_State *L)
{
    lua_createtable(L, n_of_par_context_codes + 3, 0);
    for (int i = 0; i < n_of_par_context_codes; i++) {
        lua_push_key_by_index(lmt_interface.par_context_values[i].lua);
        lua_createtable(L, 0, 5);
        lua_set_integer_by_key(L, "calls",         lmt_linebreak_state.passes[i].n_of_break_calls);
        lua_set_integer_by_key(L, "first",         lmt_linebreak_state.passes[i].n_of_first_passes);
        lua_set_integer_by_key(L, "second",        lmt_linebreak_state.passes[i].n_of_second_passes);
        lua_set_integer_by_key(L, "final",         lmt_linebreak_state.passes[i].n_of_final_passes);
        lua_set_integer_by_key(L, "specification", lmt_linebreak_state.passes[i].n_of_specification_passes);
        lua_set_integer_by_key(L, "sub",           lmt_linebreak_state.passes[i].n_of_sub_passes);
        lua_rawset(L, -3);
    }
    lua_set_integer_by_key(L, "lefttwins",   lmt_linebreak_state.n_of_left_twins);
    lua_set_integer_by_key(L, "righttwins",  lmt_linebreak_state.n_of_right_twins);
    lua_set_integer_by_key(L, "doubletwins", lmt_linebreak_state.n_of_double_twins);
    return 1;
}

static int statslib_balancestate(lua_State *L)
{
    lua_createtable(L, 9, 0);
    lua_set_integer_by_key(L, "calls",          lmt_balance_state.passes.n_of_break_calls);
    lua_set_integer_by_key(L, "first",          lmt_balance_state.passes.n_of_first_passes);
    lua_set_integer_by_key(L, "second",         lmt_balance_state.passes.n_of_second_passes);
    lua_set_integer_by_key(L, "final",          lmt_balance_state.passes.n_of_final_passes);
    lua_set_integer_by_key(L, "specification",  lmt_balance_state.passes.n_of_specification_passes);
    lua_set_integer_by_key(L, "sub",            lmt_balance_state.passes.n_of_sub_passes);
    lua_set_integer_by_key(L, "foundinserts",   lmt_balance_state.total_inserts_found);
    lua_set_integer_by_key(L, "checkedinserts", lmt_balance_state.total_inserts_checked);
    lua_set_integer_by_key(L, "callbacks",      lmt_balance_state.n_of_callbacks);
    return 1;
}

static int statslib_hyphenationstate(lua_State *L)
{
    lua_createtable(L, 0, 6);
    lua_set_integer_by_key(L, "lists",      lmt_language_state.list_count);
    lua_set_integer_by_key(L, "words",      lmt_language_state.word_count);
    lua_set_integer_by_key(L, "checked",    lmt_language_state.checked_count);
    lua_set_integer_by_key(L, "hyphenated", lmt_language_state.hyphenated_count);
    lua_set_integer_by_key(L, "exceptions", lmt_language_state.exceptions_count);
    lua_set_integer_by_key(L, "nothing",    lmt_language_state.nothing_count);
    return 1;
}

static int statslib_texstate(lua_State *L)
{
    lua_Integer approximate = 0
        + (lua_Integer) lmt_string_pool_state .string_pool_data    .allocated * (lua_Integer) lmt_string_pool_state .string_pool_data    .itemsize + lmt_string_pool_state .string_pool_data    .extra
        + (lua_Integer) lmt_string_pool_state .string_body_data    .allocated * (lua_Integer) lmt_string_pool_state .string_body_data    .itemsize + lmt_string_pool_state .string_body_data    .extra
        + (lua_Integer) lmt_node_memory_state .nodes_data          .allocated * (lua_Integer) lmt_node_memory_state .nodes_data          .itemsize + lmt_node_memory_state .nodes_data          .extra
        + (lua_Integer) lmt_token_memory_state.tokens_data         .allocated * (lua_Integer) lmt_token_memory_state.tokens_data         .itemsize + lmt_token_memory_state.tokens_data         .extra
        + (lua_Integer) lmt_fileio_state      .io_buffer_data      .allocated * (lua_Integer) lmt_fileio_state      .io_buffer_data      .itemsize + lmt_fileio_state      .io_buffer_data      .extra
        + (lua_Integer) lmt_input_state       .input_stack_data    .allocated * (lua_Integer) lmt_input_state       .input_stack_data    .itemsize + lmt_input_state       .input_stack_data    .extra
        + (lua_Integer) lmt_input_state       .in_stack_data       .allocated * (lua_Integer) lmt_input_state       .in_stack_data       .itemsize + lmt_input_state       .in_stack_data       .extra
        + (lua_Integer) lmt_nest_state        .nest_data           .allocated * (lua_Integer) lmt_nest_state        .nest_data           .itemsize + lmt_nest_state        .nest_data           .extra
        + (lua_Integer) lmt_input_state       .parameter_stack_data.allocated * (lua_Integer) lmt_input_state       .parameter_stack_data.itemsize + lmt_input_state       .parameter_stack_data.extra
        + (lua_Integer) lmt_save_state        .save_stack_data     .allocated * (lua_Integer) lmt_save_state        .save_stack_data     .itemsize + lmt_save_state        .save_stack_data     .extra
        + (lua_Integer) lmt_hash_state        .hash_data           .allocated * (lua_Integer) lmt_hash_state        .hash_data           .itemsize + lmt_hash_state        .hash_data           .extra
        + (lua_Integer) lmt_fileio_state      .io_buffer_data      .allocated * (lua_Integer) lmt_fileio_state      .io_buffer_data      .itemsize + lmt_fileio_state      .io_buffer_data      .extra
        + (lua_Integer) lmt_font_state        .font_data           .allocated * (lua_Integer) lmt_font_state        .font_data           .itemsize + lmt_font_state        .font_data           .extra
        + (lua_Integer) lmt_language_state    .language_data       .allocated * (lua_Integer) lmt_language_state    .language_data       .itemsize + lmt_language_state    .language_data       .extra
        + (lua_Integer) lmt_mark_state        .mark_data           .allocated * (lua_Integer) lmt_mark_state        .mark_data           .itemsize + lmt_mark_state        .mark_data           .extra
        + (lua_Integer) lmt_insert_state      .insert_data         .allocated * (lua_Integer) lmt_insert_state      .insert_data         .itemsize + lmt_insert_state      .insert_data         .extra
        + (lua_Integer) lmt_sparse_state      .sparse_data         .allocated * (lua_Integer) lmt_sparse_state      .sparse_data         .itemsize + lmt_sparse_state      .sparse_data         .extra
        + (lua_Integer) lmt_mvl_state         .mvl_data            .allocated * (lua_Integer) lmt_mvl_state         .mvl_data            .itemsize + lmt_mvl_state         .mvl_data            .extra
    ;
    lua_createtable(L, 0, 4);
    lua_set_integer_by_key(L, "approximate", (int) approximate);
    return 1;
}

static int statslib_luastate(lua_State *L)
{
    lua_createtable(L, 0, 6);
    lua_set_integer_by_key(L, "functionsize",   lmt_lua_state.function_table_size);
    lua_set_integer_by_key(L, "propertiessize", lmt_node_memory_state.node_properties_table_size);
    lua_set_integer_by_key(L, "bytecodes",      lmt_lua_state.bytecode_max);
    lua_set_integer_by_key(L, "bytecodebytes",  lmt_lua_state.bytecode_bytes);
    lua_set_integer_by_key(L, "statebytes",     lmt_lua_state.used_bytes);
    lua_set_integer_by_key(L, "statebytesmax",  lmt_lua_state.used_bytes_max);
    return 1;
}

static int statslib_errorstate(lua_State* L)
{
    lua_createtable(L, 0, 3);
    lua_set_string_by_key(L, "error",         lmt_error_state.last_error);
    lua_set_string_by_key(L, "errorcontext",  lmt_error_state.last_error_context);
    lua_set_string_by_key(L, "luaerror",      lmt_error_state.last_lua_error);
    return 1;
}

static int statslib_warningstate(lua_State* L)
{
    lua_createtable(L, 0, 2);
    lua_set_string_by_key(L, "warningtag",    lmt_error_state.last_warning_tag);
    lua_set_string_by_key(L, "warning",       lmt_error_state.last_warning);
    return 1;
}

static int statslib_aux_stats_name_to_id(const char *name, statistic_entry stats[])
{
    for (int i = 0; stats[i].name; i++) {
        if (strcmp (stats[i].name, name) == 0) {
            return i;
        }
    }
    return -1;
}

static int statslib_aux_limits_state(lua_State* L, limits_data *data)
{
    lua_createtable(L, 0, 4);
    lua_set_integer_by_key(L, "set", data->size);
    lua_set_integer_by_key(L, "min", data->minimum);
    lua_set_integer_by_key(L, "max", data->maximum);
    lua_set_integer_by_key(L, "top", data->top);
    return 1;
}

static int statslib_aux_memory_state(lua_State* L, memory_data *data)
{
    lua_createtable(L, 0, 11);
    lua_set_integer_by_key(L, "set", data->size); /*tex Can |memory_data_unset|. */
    lua_set_integer_by_key(L, "min", data->minimum);
    lua_set_integer_by_key(L, "max", data->maximum);
    lua_set_integer_by_key(L, "mem", data->allocated);
    lua_set_integer_by_key(L, "ext", data->extra);
    lua_set_integer_by_key(L, "itm", data->itemsize);
    lua_set_integer_by_key(L, "all", data->allocated * data->itemsize + data->extra);
    lua_set_integer_by_key(L, "top", data->top - data->offset);
    lua_set_integer_by_key(L, "ptr", data->ptr - data->offset);
    lua_set_integer_by_key(L, "ini", data->initial); /*tex Can |memory_data_unset|. */
    lua_set_integer_by_key(L, "stp", data->step);
 // lua_set_integer_by_key(L, "off", data->offset);
    return 1;
}

static int statslib_errorlinestate    (lua_State* L) { return statslib_aux_limits_state(L, &lmt_error_state       .line_limits);  }
static int statslib_halferrorlinestate(lua_State* L) { return statslib_aux_limits_state(L, &lmt_error_state       .half_line_limits); }
static int statslib_expandstate       (lua_State* L) { return statslib_aux_limits_state(L, &lmt_expand_state      .limits); }
static int statslib_stringstate       (lua_State* L) { return statslib_aux_memory_state(L, &lmt_string_pool_state .string_pool_data); }
static int statslib_poolstate         (lua_State* L) { return statslib_aux_memory_state(L, &lmt_string_pool_state .string_body_data); }
static int statslib_lookupstate       (lua_State* L) { return statslib_aux_memory_state(L, &lmt_hash_state        .eqtb_data); }
static int statslib_hashstate         (lua_State* L) { return statslib_aux_memory_state(L, &lmt_hash_state        .hash_data); }
static int statslib_nodestate         (lua_State* L) { return statslib_aux_memory_state(L, &lmt_node_memory_state .nodes_data); }
static int statslib_tokenstate        (lua_State* L) { return statslib_aux_memory_state(L, &lmt_token_memory_state.tokens_data); }
static int statslib_inputstate        (lua_State* L) { return statslib_aux_memory_state(L, &lmt_input_state       .input_stack_data); }
static int statslib_filestate         (lua_State* L) { return statslib_aux_memory_state(L, &lmt_input_state       .in_stack_data); }
static int statslib_parameterstate    (lua_State* L) { return statslib_aux_memory_state(L, &lmt_input_state       .parameter_stack_data); }
static int statslib_neststate         (lua_State* L) { return statslib_aux_memory_state(L, &lmt_nest_state        .nest_data); }
static int statslib_savestate         (lua_State* L) { return statslib_aux_memory_state(L, &lmt_save_state        .save_stack_data); }
static int statslib_bufferstate       (lua_State* L) { return statslib_aux_memory_state(L, &lmt_fileio_state      .io_buffer_data); }
static int statslib_fontstate         (lua_State* L) { return statslib_aux_memory_state(L, &lmt_font_state        .font_data); }
static int statslib_languagestate     (lua_State* L) { return statslib_aux_memory_state(L, &lmt_language_state    .language_data); }
static int statslib_markstate         (lua_State* L) { return statslib_aux_memory_state(L, &lmt_mark_state        .mark_data); }
static int statslib_insertstate       (lua_State* L) { return statslib_aux_memory_state(L, &lmt_insert_state      .insert_data); }
static int statslib_sparsestate       (lua_State* L) { return statslib_aux_memory_state(L, &lmt_sparse_state      .sparse_data); }
static int statslib_mvlstate          (lua_State* L) { return statslib_aux_memory_state(L, &lmt_mvl_state         .mvl_data); }

static int statslib_readstate(lua_State *L)
{
    lua_createtable(L, 0, 4);
    lua_set_string_by_key (L, "filename",       tex_current_input_file_name());
    lua_set_integer_by_key(L, "iocode",         lmt_input_state.cur_input.name > io_file_input_code ? io_file_input_code : lmt_input_state.cur_input.name);
    lua_set_integer_by_key(L, "linenumber",     lmt_input_state.input_line);
    lua_set_integer_by_key(L, "skiplinenumber", lmt_condition_state.skip_line);
    return 1;
}

static int statslib_enginestate(lua_State *L)
{
    lua_createtable(L, 0, 15);
    lua_set_string_by_key (L, "logfilename",     lmt_fileio_state.log_name);
    lua_set_string_by_key (L, "banner",          lmt_engine_state.luatex_banner);
    lua_set_number_by_key (L, "version",         lmt_version_state.luatexversion);
    lua_set_string_by_key (L, "luatex_engine",   lmt_engine_state.engine_name);
    lua_set_integer_by_key(L, "luatex_version",  lmt_version_state.version);
    lua_set_integer_by_key(L, "luatex_revision", lmt_version_state.revision);
    lua_set_integer_by_key(L, "luatex_release",  lmt_version_state.release);
    lua_set_string_by_key(L,  "luatex_verbose",  lmt_version_state.verbose);
    lua_set_integer_by_key(L, "development_id",  lmt_version_state.developmentid);
    lua_set_string_by_key (L, "copyright",       lmt_version_state.copyright);
    lua_set_integer_by_key(L, "format_id",       lmt_version_state.formatid);
    lua_set_integer_by_key(L, "tex_hash_size",   hash_size);
    lua_set_string_by_key (L, "used_compiler",   lmt_version_state.compiler);
 // lua_set_string_by_key (L, "used_libc",       lmt_version_state.libc);
    lua_set_integer_by_key(L, "run_state",       lmt_main_state.run_state);
    lua_set_boolean_by_key(L, "permit_loadlib",  lmt_engine_state.permit_loadlib);
    return 1;
}

static int statslib_aux_getstat_indeed(lua_State *L, statistic_entry stats[], int i)
{
    switch (stats[i].type) {
        case 'S':
            /* string function pointer, no copy */
            {
                const char *st = (*(constfunc) stats[i].value)();
                lua_pushstring(L, st);
                /* No freeing here! */
                break;
            }
     // case 's':
     //     /* string function pointer, copy */
     //     {
     //         char *st = (*(charfunc) stats[i].value)();
     //         lua_pushstring(L, st);
     //         lmt_memory_free(st);
     //         break;
     //     }
     // case 'N':
     //     /* number function pointer */
     //     lua_pushnumber(L, (*(numfunc) stats[i].value)());
     //     break;
     // case 'G':
     //     /* integer function pointer */
     //     lua_pushinteger(L, (*(intfunc) stats[i].value)());
     //     break;
        case 'd':
            /* double pointer */
            lua_pushnumber(L, *(double *) (stats[i].value));
            break;
        case 'g':
            /* integer pointer */
            lua_pushinteger(L, *(int *) (stats[i].value));
            break;
        case 'c':
            /* string pointer */
            lua_pushstring(L, *(const char **) (stats[i].value));
            break;
     // case 'n': /* node */
     //     /* node pointer */
     //     if (*(halfword*) (stats[i].value)) {
     //         lmt_push_node_fast(L, *(halfword *) (stats[i].value));
     //     } else {
     //         lua_pushnil(L);
     //     }
     //     break;
        case 'b':
            /* boolean integer pointer */
            lua_pushboolean(L, *(int *) (stats[i].value));
            break;
        case 'f':
            (*(luafunc) stats[i].value)(L);
            break;
        default:
            /* nothing reasonable */
            lua_pushnil(L);
            break;
    }
    return 1;
}

static int statslib_aux_getstats_indeed(lua_State *L, statistic_entry stats[])
{
    if (lua_type(L, -1) == LUA_TSTRING) {
        const char *st = lua_tostring(L, -1);
        int i = statslib_aux_stats_name_to_id(st, stats);
        if (i >= 0) {
            return statslib_aux_getstat_indeed(L, stats, i);
        }
    }
    return 0;
}

static int statslib_getconstants(lua_State *L)
{
    lua_createtable(L, 0, 100);

    lua_set_integer_by_key(L, "no_catcode_table",               no_catcode_table_preset);
    lua_set_integer_by_key(L, "default_catcode_table",          default_catcode_table_preset);
                                                                
    lua_set_cardinal_by_key(L,"max_cardinal",                   max_cardinal);
    lua_set_cardinal_by_key(L,"min_cardinal",                   min_cardinal);
    lua_set_integer_by_key(L, "max_integer",                    max_integer);
    lua_set_integer_by_key(L, "min_integer",                    min_integer);
    lua_set_integer_by_key(L, "max_dimen",                      max_dimension); /* obsolete */
    lua_set_integer_by_key(L, "min_dimen",                      min_dimension); /* obsolete */
    lua_set_integer_by_key(L, "max_dimension",                  max_dimension);
    lua_set_integer_by_key(L, "min_dimension",                  min_dimension);
    lua_set_integer_by_key(L, "min_data_value",                 min_data_value);
    lua_set_integer_by_key(L, "max_data_value",                 max_data_value);
    lua_set_integer_by_key(L, "max_half_value",                 max_half_value);
                                                                
    lua_set_integer_by_key(L, "max_limited_scale",              max_limited_scale);
    lua_set_integer_by_key(L, "max_math_style_scale",           max_math_style_scale);
                                                                
    lua_set_integer_by_key(L, "one_bp",                         one_bp);
                                                                
    lua_set_integer_by_key(L, "infinity",                       max_infinity);
    lua_set_integer_by_key(L, "min_infinity",                   min_infinity);
    lua_set_integer_by_key(L, "awful_bad",                      awful_bad);
    lua_set_integer_by_key(L, "infinite_bad",                   infinite_bad);
    lua_set_integer_by_key(L, "infinite_penalty",               infinite_penalty);
    lua_set_integer_by_key(L, "eject_penalty",                  eject_penalty);
    lua_set_integer_by_key(L, "deplorable",                     deplorable);
    lua_set_integer_by_key(L, "large_width_excess",             large_width_excess);
    lua_set_integer_by_key(L, "small_stretchability",           small_stretchability);
    lua_set_integer_by_key(L, "decent_criterion",               decent_criterion);
    lua_set_integer_by_key(L, "loose_criterion",                loose_criterion);
                                                                
    lua_set_integer_by_key(L, "default_rule",                   default_rule);
    lua_set_integer_by_key(L, "ignore_depth",                   ignore_depth);
                                                                
    lua_set_integer_by_key(L, "min_quarterword",                min_quarterword);
    lua_set_integer_by_key(L, "max_quarterword",                max_quarterword);
                                                                
    lua_set_integer_by_key(L, "min_halfword",                   min_halfword);
    lua_set_integer_by_key(L, "max_halfword",                   max_halfword);
                                                                
    lua_set_integer_by_key(L, "null_flag",                      null_flag);
    lua_set_integer_by_key(L, "zero_glue",                      zero_glue);
    lua_set_integer_by_key(L, "unity",                          unity);
    lua_set_integer_by_key(L, "two",                            two);
    lua_set_integer_by_key(L, "null",                           null);
    lua_set_integer_by_key(L, "null_font",                      null_font);
                                                                
    lua_set_integer_by_key(L, "unused_attribute_value",         unused_attribute_value);
    lua_set_integer_by_key(L, "unused_state_value",             unused_state_value);
    lua_set_integer_by_key(L, "unused_script_value",            unused_script_value);
                                                                
    lua_set_integer_by_key(L, "preset_rule_thickness",          preset_rule_thickness);
    lua_set_integer_by_key(L, "running_rule",                   null_flag);
                                                                
    lua_set_integer_by_key(L, "min_space_factor",               min_space_factor);
    lua_set_integer_by_key(L, "max_space_factor",               max_space_factor);
    lua_set_integer_by_key(L, "min_scale_factor",               min_scale_factor);
    lua_set_integer_by_key(L, "max_scale_factor",               max_scale_factor);
    lua_set_integer_by_key(L, "default_space_factor",           default_space_factor);
    lua_set_integer_by_key(L, "special_space_factor",           special_space_factor);
    lua_set_integer_by_key(L, "default_tolerance",              default_tolerance);
    lua_set_integer_by_key(L, "default_hangafter",              default_hangafter);
    lua_set_integer_by_key(L, "default_deadcycles",             default_deadcycles);
    lua_set_integer_by_key(L, "default_pre_display_gap",        default_pre_display_gap);
    lua_set_integer_by_key(L, "default_eqno_gap_step",          default_eqno_gap_step);
                                                                
    lua_set_integer_by_key(L, "default_output_box",             default_output_box);
                                                                
    lua_set_integer_by_key(L, "max_n_of_fonts",                 max_n_of_fonts);
    lua_set_integer_by_key(L, "max_n_of_bytecodes",             max_n_of_bytecodes);
    lua_set_integer_by_key(L, "max_n_of_math_families",         max_n_of_math_families);
    lua_set_integer_by_key(L, "max_n_of_languages",             max_n_of_languages);
    lua_set_integer_by_key(L, "max_n_of_catcode_tables",        max_n_of_catcode_tables);
 /* lua_set_integer_by_key(L, "max_n_of_hjcode_tables",         max_n_of_hjcode_tables); */ /* meaningless */
    lua_set_integer_by_key(L, "max_n_of_marks",                 max_n_of_marks);
                                                                
    lua_set_integer_by_key(L, "max_character_code",             max_character_code);
    lua_set_integer_by_key(L, "max_mark_index",                 max_mark_index);
                                                                
    lua_set_integer_by_key(L, "max_toks_register_index",        max_toks_register_index);
    lua_set_integer_by_key(L, "max_box_register_index",         max_box_register_index);
    lua_set_integer_by_key(L, "max_int_register_index",         max_integer_register_index);   /* obsolete */
    lua_set_integer_by_key(L, "max_integer_register_index",     max_integer_register_index);
    lua_set_integer_by_key(L, "max_float_register_index",       max_posit_register_index);
    lua_set_integer_by_key(L, "max_dimension_register_index",   max_dimension_register_index);
    lua_set_integer_by_key(L, "max_dimen_register_index",       max_dimension_register_index); /* obsolete */
    lua_set_integer_by_key(L, "max_attribute_register_index",   max_attribute_register_index);
    lua_set_integer_by_key(L, "max_glue_register_index",        max_glue_register_index);
    lua_set_integer_by_key(L, "max_muglue_register_index",      max_muglue_register_index);
                                                                
    lua_set_integer_by_key(L, "max_bytecode_index",             max_bytecode_index);
    lua_set_integer_by_key(L, "max_math_family_index",          max_math_family_index);
    lua_set_integer_by_key(L, "max_math_class_code",            max_math_class_code);
    lua_set_integer_by_key(L, "max_function_reference",         max_function_reference);
                                                                
    lua_set_integer_by_key(L, "min_mvl_index",                  min_mvl_index);
    lua_set_integer_by_key(L, "max_mvl_index",                  max_mvl_index);

    lua_set_integer_by_key(L, "max_newline_character",          max_newline_character);
    lua_set_integer_by_key(L, "max_endline_character",          max_endline_character);
                                                                
    lua_set_integer_by_key(L, "max_size_of_word",               max_size_of_word);
                                                                
    lua_set_integer_by_key(L, "tex_hash_size",                  hash_size);
    lua_set_integer_by_key(L, "tex_hash_prime",                 hash_prime);
    lua_set_integer_by_key(L, "tex_eqtb_size",                  eqtb_size);
                                                                
    lua_set_integer_by_key(L, "math_first_user_class",          math_first_user_class);
    lua_set_integer_by_key(L, "math_last_user_class",           math_last_user_class);
    lua_set_integer_by_key(L, "math_all_class",                 math_all_class);
    lua_set_integer_by_key(L, "math_begin_class",               math_begin_class);
    lua_set_integer_by_key(L, "math_end_class",                 math_end_class);

    lua_set_integer_by_key(L, "unused_math_family",             unused_math_family);
    lua_set_integer_by_key(L, "unused_math_style",              unused_math_style);
    lua_set_integer_by_key(L, "assumed_math_control",           assumed_math_control);
                                                                
    lua_set_integer_by_key(L, "undefined_math_parameter",       undefined_math_parameter);
                                                                
    lua_set_integer_by_key(L, "max_calculated_badness",         max_calculated_badness);
                                                                
    lua_set_integer_by_key(L, "max_math_scaling_factor",        max_math_scaling_factor);   
    lua_set_integer_by_key(L, "math_default_penalty",           math_default_penalty);   

    lua_set_integer_by_key(L, "max_font_adjust_step",           max_font_adjust_step);            
    lua_set_integer_by_key(L, "max_font_adjust_stretch_factor", max_font_adjust_stretch_factor);
    lua_set_integer_by_key(L, "max_font_adjust_shrink_factor",  max_font_adjust_shrink_factor);

    lua_set_integer_by_key(L, "max_twin_length",                max_twin_length); 

    lua_set_integer_by_key(L, "default_character_control",      default_character_control); 

    lua_set_integer_by_key(L, "min_n_of_fitness_values",        min_n_of_fitness_values);
    lua_set_integer_by_key(L, "max_n_of_fitness_values",        max_n_of_fitness_values);
    lua_set_integer_by_key(L, "all_fitness_values",             all_fitness_values);

    return 1;
}

static struct statistic_entry statslib_entries[] = {

    /*tex But these are now collected in tables: */

    { .name = "enginestate",        .value = &statslib_enginestate,        .type = 'f' },
    { .name = "errorlinestate",     .value = &statslib_errorlinestate,     .type = 'f' },
    { .name = "halferrorlinestate", .value = &statslib_halferrorlinestate, .type = 'f' },
    { .name = "expandstate",        .value = &statslib_expandstate,        .type = 'f' },
    { .name = "stringstate",        .value = &statslib_stringstate,        .type = 'f' },
    { .name = "poolstate",          .value = &statslib_poolstate,          .type = 'f' },
    { .name = "hashstate",          .value = &statslib_hashstate,          .type = 'f' },
    { .name = "lookupstate",        .value = &statslib_lookupstate,        .type = 'f' },
    { .name = "nodestate",          .value = &statslib_nodestate,          .type = 'f' },
    { .name = "tokenstate",         .value = &statslib_tokenstate,         .type = 'f' },
    { .name = "inputstate",         .value = &statslib_inputstate,         .type = 'f' },
    { .name = "filestate",          .value = &statslib_filestate,          .type = 'f' },
    { .name = "parameterstate",     .value = &statslib_parameterstate,     .type = 'f' },
    { .name = "neststate",          .value = &statslib_neststate,          .type = 'f' },
    { .name = "savestate",          .value = &statslib_savestate,          .type = 'f' },
    { .name = "bufferstate",        .value = &statslib_bufferstate,        .type = 'f' },
    { .name = "texstate",           .value = &statslib_texstate,           .type = 'f' },
    { .name = "luastate",           .value = &statslib_luastate,           .type = 'f' },
    { .name = "callbackstate",      .value = &statslib_callbackstate,      .type = 'f' },
    { .name = "linebreakstate",     .value = &statslib_linebreakstate,     .type = 'f' },
    { .name = "balancestate",       .value = &statslib_balancestate,       .type = 'f' },
    { .name = "hyphenationstate",   .value = &statslib_hyphenationstate,   .type = 'f' },
    { .name = "errorstate",         .value = &statslib_errorstate,         .type = 'f' },
    { .name = "warningstate",       .value = &statslib_warningstate,       .type = 'f' },
    { .name = "readstate",          .value = &statslib_readstate,          .type = 'f' },
    { .name = "fontstate",          .value = &statslib_fontstate,          .type = 'f' },
    { .name = "languagestate",      .value = &statslib_languagestate,      .type = 'f' },
    { .name = "markstate",          .value = &statslib_markstate,          .type = 'f' },
    { .name = "insertstate",        .value = &statslib_insertstate,        .type = 'f' },
    { .name = "sparsestate",        .value = &statslib_sparsestate,        .type = 'f' },
    { .name = "mvlstate",           .value = &statslib_mvlstate,           .type = 'f' },

    /*tex Lua keys: */

    { .name = "lua_version_major",   .value = (void *) &lmt_version_state.luaversionmajor,   .type = 'g' },
    { .name = "lua_version_minor",   .value = (void *) &lmt_version_state.luaversionminor,   .type = 'g' },
    { .name = "lua_version_release", .value = (void *) &lmt_version_state.luaversionrelease, .type = 'g' },
    { .name = "lua_version",         .value = (void *) &lmt_version_state.luaversion,        .type = 'd' },
    { .name = "lua_format",          .value = (void *) &lmt_version_state.luaformat,         .type = 'g' },

    /*tex We keep these as direct accessible keys: */

    { .name = "filename",           .value = (void *) &tex_current_input_file_name,     .type = 'S' },
    { .name = "logfilename",        .value = (void *) &lmt_fileio_state.log_name,       .type = 'c' },
    { .name = "banner",             .value = (void *) &lmt_engine_state.luatex_banner,  .type = 'c' },
    { .name = "copyright",          .value = (void *) &lmt_version_state.copyright,     .type = 'c' },
    /* */
    { .name = "majorversion",       .value = (void *) &lmt_version_state.majorversion,  .type = 'g' },
    { .name = "minorversion",       .value = (void *) &lmt_version_state.minorversion,  .type = 'g' },
    { .name = "release",            .value = (void *) &lmt_version_state.release,       .type = 'g' },
    { .name = "development_id",     .value = (void *) &lmt_version_state.developmentid, .type = 'g' },
    { .name = "format_id",          .value = (void *) &lmt_version_state.formatid,      .type = 'g' },
    /* */
    { .name = "version",            .value = (void *) &lmt_version_state.luatexversion, .type = 'd' },
    /* */
    { .name = "luatex_engine",      .value = (void *) &lmt_engine_state.engine_name,    .type = 'c' },
    { .name = "luatex_version",     .value = (void *) &lmt_version_state.version,       .type = 'g' },
    { .name = "luatex_revision",    .value = (void *) &lmt_version_state.revision,      .type = 'g' },
    { .name = "luatex_release",     .value = (void *) &lmt_version_state.release,       .type = 'g' },
    { .name = "luatex_verbose",     .value = (void *) &lmt_version_state.verbose,       .type = 'c' },
    /* */
    { .name = "used_compiler",      .value = (void *) &lmt_version_state.compiler,      .type = 'c' },
    { .name = "run_state",          .value = (void *) &lmt_main_state.run_state,        .type = 'g' },
    { .name = "permit_loadlib",     .value = (void *) &lmt_engine_state.permit_loadlib, .type = 'b' },

    { .name = NULL,                 .value = NULL,                                      .type = 0   },
};

static struct statistic_entry statslib_entries_only[] = {
    { .name = "filename",            .value = (void *) &tex_current_input_file_name,         .type = 'S' },
    { .name = "banner",              .value = (void *) &lmt_engine_state.luatex_banner,      .type = 'c' },
    { .name = "copyright",           .value = (void *) &lmt_version_state.copyright,         .type = 'c' },
    /* */                                                                                    
    { .name = "majorversion",        .value = (void *) &lmt_version_state.majorversion,      .type = 'g' },
    { .name = "minorversion",        .value = (void *) &lmt_version_state.minorversion,      .type = 'g' },
    { .name = "release",             .value = (void *) &lmt_version_state.release,           .type = 'g' },
    { .name = "development_id",      .value = (void *) &lmt_version_state.developmentid,     .type = 'g' },
    { .name = "format_id",           .value = (void *) &lmt_version_state.formatid,          .type = 'g' },
    /* */                                                                                    
    { .name = "version",             .value = (void *) &lmt_version_state.luatexversion,     .type = 'd' },
    /* */                                                                                    
    { .name = "luatex_engine",       .value = (void *) &lmt_engine_state.engine_name,        .type = 'c' },
    { .name = "luatex_version",      .value = (void *) &lmt_version_state.version,           .type = 'g' },
    { .name = "luatex_revision",     .value = (void *) &lmt_version_state.revision,          .type = 'g' },
    { .name = "luatex_release",      .value = (void *) &lmt_version_state.release,           .type = 'g' },
    { .name = "luatex_verbose",      .value = (void *) &lmt_version_state.verbose,           .type = 'c' },
    /* */                                                                                    
    { .name = "used_compiler",       .value = (void *) &lmt_version_state.compiler,          .type = 'c' },

    { .name = "lua_version_major",   .value = (void *) &lmt_version_state.luaversionmajor,   .type = 'g' },
    { .name = "lua_version_minor",   .value = (void *) &lmt_version_state.luaversionminor,   .type = 'g' },
    { .name = "lua_version_release", .value = (void *) &lmt_version_state.luaversionrelease, .type = 'g' },
    { .name = "lua_version",         .value = (void *) &lmt_version_state.luaversion,        .type = 'd' },
    { .name = "lua_format",          .value = (void *) &lmt_version_state.luaformat,         .type = 'g' },

    { .name = NULL,                  .value = NULL,                                          .type = 0   },
};

static int statslib_aux_getstats(lua_State *L)
{
    return statslib_aux_getstats_indeed(L, statslib_entries);
}

static int statslib_aux_getstats_only(lua_State *L)
{
    return statslib_aux_getstats_indeed(L, statslib_entries_only);
}

static int statslib_aux_statslist(lua_State *L, statistic_entry stats[])
{
    lua_createtable(L, 0, 60);
    for (int i = 0; stats[i].name; i++) {
        lua_pushstring(L, stats[i].name);
        statslib_aux_getstat_indeed(L, stats, i);
        lua_rawset(L, -3);
    }
    return 1;
}

static int statslib_statslist(lua_State *L)
{
    return statslib_aux_statslist(L, statslib_entries);
}

static int statslib_statslist_only(lua_State *L)
{
    return statslib_aux_statslist(L, statslib_entries_only);
}

static int statslib_resetmessages(lua_State *L)
{
    (void) (L);
    lmt_memory_free(lmt_error_state.last_warning);
    lmt_memory_free(lmt_error_state.last_warning_tag);
    lmt_memory_free(lmt_error_state.last_error);
    lmt_memory_free(lmt_error_state.last_lua_error);
    lmt_error_state.last_warning = NULL;
    lmt_error_state.last_warning_tag = NULL;
    lmt_error_state.last_error = NULL;
    lmt_error_state.last_lua_error = NULL;
    return 0;
}

static const struct luaL_Reg statslib_function_list[] = {
    { "list",                  statslib_statslist          }, /* for old times sake */
    { "getconstants",          statslib_getconstants       },
    { "resetmessages",         statslib_resetmessages      },

    { "gettexstate",           statslib_texstate           },
    { "getluastate",           statslib_luastate           },
    { "geterrorstate",         statslib_errorstate         },
    { "getwarningstate",       statslib_warningstate       },
    { "getreadstate",          statslib_readstate          },
    { "getcallbackstate",      statslib_callbackstate      },
    { "getlinebreakstate",     statslib_linebreakstate     },
    { "getbalancestate",       statslib_balancestate       },
    { "gethyphenationstate",   statslib_hyphenationstate   },

    { "geterrorlinestate",     statslib_errorlinestate     },
    { "gethalferrorlinestate", statslib_halferrorlinestate },
    { "getexpandstate",        statslib_expandstate        },

    { "getstringstate",        statslib_stringstate        },
    { "getpoolstate",          statslib_poolstate          },
    { "gethashstate",          statslib_hashstate          },
    { "getlookupstate",        statslib_lookupstate        },
    { "getnodestate",          statslib_nodestate          },
    { "gettokenstate",         statslib_tokenstate         },
    { "getinputstate",         statslib_inputstate         },
    { "getfilestate",          statslib_filestate          },
    { "getparameterstate",     statslib_parameterstate     },
    { "getneststate",          statslib_neststate          },
    { "getsavestate",          statslib_savestate          },
    { "getbufferstate",        statslib_bufferstate        },
    { "getfontstate",          statslib_fontstate          },
    { "getlanguagestate",      statslib_languagestate      },
    { "getmarkstate",          statslib_markstate          },
    { "getinsertstate",        statslib_insertstate        },
    { "getsparsestate",        statslib_sparsestate        },
    { "getmvlstate",           statslib_mvlstate           },

    { NULL,                    NULL                        },
};

static const struct luaL_Reg statslib_function_list_only[] = {
    { "list", statslib_statslist_only },
    { NULL,   NULL                    },
};

int luaopen_status(lua_State *L)
{
    lua_newtable(L);
    luaL_setfuncs(L, lmt_engine_state.lua_only ? statslib_function_list_only : statslib_function_list, 0);
    luaL_newmetatable(L, STATS_METATABLE);
    lua_pushstring(L, "__index");
    lua_pushcfunction(L, lmt_engine_state.lua_only ? statslib_aux_getstats_only : statslib_aux_getstats);
    lua_settable(L, -3);
    lua_setmetatable(L, -2); /*tex meta to itself */
    return 1;
}
