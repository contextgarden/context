/*
    See license.txt in the root of this project.
*/

# ifndef LMT_LCALLBACKLIB_H
# define LMT_LCALLBACKLIB_H

# include "lapi.h"

typedef enum callback_types {
    test_only_callback = 1,
    find_log_file_callback,
    find_format_file_callback,
    open_data_file_callback,
    process_jobname_callback,
    start_run_callback,
    stop_run_callback,
    define_font_callback,
    quality_font_callback,
    pre_output_callback,
    buildpage_callback,
    hpack_callback,
    vpack_callback,
    hyphenate_callback,
    ligaturing_callback,
    kerning_callback,
    glyph_run_callback,
    pre_linebreak_callback,
    linebreak_callback,
    post_linebreak_callback,
    append_to_vlist_callback,
    alignment_callback,
    local_box_callback,
    packed_vbox_callback,
    mlist_to_hlist_callback,
    pre_dump_callback,
    start_file_callback,
    stop_file_callback,
    intercept_tex_error_callback,
    intercept_lua_error_callback,
    show_error_message_callback,
    show_warning_message_callback,
    hpack_quality_callback,
    vpack_quality_callback,
    linebreak_check_callback,
    balance_check_callback,
    show_vsplit_callback,
    show_build_callback,
    insert_par_callback,
    append_adjust_callback,
    append_migrate_callback,
    append_line_callback,
 /* pre_line_callback, */
    insert_distance_callback,
 /* fire_up_output_callback, */
    wrapup_run_callback,
    begin_paragraph_callback,
    paragraph_context_callback,
 /* get_math_char_callback, */
    math_rule_callback,
    make_extensible_callback,
    register_extensible_callback,
    show_whatsit_callback,
    get_attribute_callback,
    get_noad_class_callback,
    get_math_dictionary_callback,
    show_lua_call_callback,
    trace_memory_callback,
    handle_overload_callback,
    missing_character_callback,
    process_character_callback,
    linebreak_quality_callback,
    paragraph_pass_callback,
    handle_uleader_callback,
    handle_uinsert_callback,
    italic_correction_callback,
    show_loners_callback,
    tail_append_callback,
    balance_boundary_callback,
    balance_insert_callback,
    total_callbacks,
} callback_types;

/* Todo: provide support for this: */

typedef enum callback_states {
    callback_state_set         = 0x01, /* can be used */
    callback_state_disabled    = 0x02, /* temporarily disabled */
    callback_state_frozen      = 0x04, /* can never be set or changed again */
    callback_state_private     = 0x08, /* don't return the function */
    callback_state_touched     = 0x10, /* set (or unset) by the user */
    callback_state_tracing     = 0x20, /* only called when tracing */
    callback_state_selective   = 0x40, /* only called when there is a need */
    callback_state_fundamental = 0x80, /* need to be set and kick in on demand */
} callback_states;

typedef enum callback_options {
    callback_option_direct = 0x01,
    callback_option_trace  = 0x02,
} callback_options;

typedef struct callback_item_info {
    int          value;
    int          state;
    const char*  name;
} callback_item_info;

typedef struct callback_state_info {
    int                index;
    unsigned           options;
    callback_item_info items[total_callbacks];
} callback_state_info;

extern callback_state_info lmt_callback_state;

typedef enum callback_keys {
    callback_boolean_key   = 'b', /*tex a boolean (int) */
    callback_charnum_key   = 'c', /*tex a byte (char) */
    callback_integer_key   = 'd', /*tex an integer */
    callback_line_key      = 'l', /*tex a buffer section, with implied start */
    callback_strnumber_key = 's', /*tex a \TEX\ string (index) */
    callback_lstring_key   = 'L', /*tex a \LUA\ string (struct) */
    callback_node_key      = 'N', /*tex a \TEX\ node (halfword) */
    callback_string_key    = 'S', /*tex a \CCODE\ string */
    callback_result_s_key  = 'R', /*tex a string (return value) but nil is also okay */
    callback_result_i_key  = 'r', /*tex a number (return value) but nil is also okay */
} callback_keys;

static inline int  lmt_callback_defined         (int i);

static inline int  lmt_callback_call            (lua_State *L, int i, int o, int top);
extern int         lmt_callback_okay            (lua_State *L, int i, int *top);
extern void        lmt_callback_error           (lua_State *L, int top, int i);
static inline void lmt_callback_wrapup          (lua_State *L, int top);
 
extern int         lmt_run_callback             (lua_State *L, int i, const char *values, ...);
extern int         lmt_run_and_save_callback    (lua_State *L, int i, const char *values, ...);
extern int         lmt_run_saved_callback_line  (lua_State *L, int i, int firstpos);
extern int         lmt_run_saved_callback_close (lua_State *L, int i);

extern void        lmt_destroy_saved_callback   (lua_State *L, int i);

extern void        lmt_run_memory_callback      (const char *what, int success);

extern void        lmt_push_callback_usage      (lua_State *L);

/* The implementation: */

static inline int lmt_callback_defined(
    int i
) { 
     /*tex There is no need to check |callback_state_disabled| because value can be used. */
     return (lmt_callback_state.items[i].state & callback_state_disabled) ? -1 : lmt_callback_state.items[i].value; 
}

static inline int lmt_callback_call(
    lua_State *L, 
    int        i, 
    int        o, 
    int        top
) { 
    return lua_pcallk(L, i, o, top + 2, 0, NULL); 
}

static inline void lmt_callback_wrapup(
    lua_State *L, 
    int        top
)  
{ 
    lua_settop(L, top); 
}

# endif
