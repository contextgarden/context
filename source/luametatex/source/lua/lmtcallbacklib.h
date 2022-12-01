/*
    See license.txt in the root of this project.
*/

# ifndef LMT_LCALLBACKLIB_H
# define LMT_LCALLBACKLIB_H

# include "lapi.h"

typedef enum callback_callback_types {
    find_log_file_callback = 1,
    find_format_file_callback,
    open_data_file_callback,
    process_jobname_callback,
    start_run_callback,
    stop_run_callback,
    define_font_callback,
    pre_output_filter_callback,
    buildpage_filter_callback,
    hpack_filter_callback,
    vpack_filter_callback,
    hyphenate_callback,
    ligaturing_callback,
    kerning_callback,
    glyph_run_callback,
    pre_linebreak_filter_callback,
    linebreak_filter_callback,
    post_linebreak_filter_callback,
    append_to_vlist_filter_callback,
    alignment_filter_callback,
    local_box_filter_callback,
    packed_vbox_filter_callback,
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
    insert_par_callback,
    append_line_filter_callback,
    build_page_insert_callback,
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
    total_callbacks,
} callback_callback_types;

typedef struct callback_state_info {
    int metatable_id;
    int padding;
    int values[total_callbacks];
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
    callback_result_key    = 'R', /*tex a string (return value) but nil is also okay */
} callback_keys;

inline static int  lmt_callback_defined         (int a)                               { return lmt_callback_state.values[a]; }
inline static int  lmt_callback_call            (lua_State *L, int i, int o, int top) { return lua_pcallk(L, i, o, top + 2, 0, NULL); }

extern int         lmt_callback_okay            (lua_State *L, int i, int *top);
extern void        lmt_callback_error           (lua_State *L, int top, int i);
inline static void lmt_callback_wrapup          (lua_State *L, int top)  { lua_settop(L, top); }
 
extern int         lmt_run_callback             (lua_State *L, int i, const char *values, ...);
extern int         lmt_run_and_save_callback    (lua_State *L, int i, const char *values, ...);
extern int         lmt_run_saved_callback_line  (lua_State *L, int i, int firstpos);
extern int         lmt_run_saved_callback_close (lua_State *L, int i);

extern void        lmt_destroy_saved_callback   (lua_State *L, int i);

extern void        lmt_run_memory_callback      (const char *what, int success);

extern void        lmt_push_callback_usage      (lua_State *L);

# endif

