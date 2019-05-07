/*
    See license.txt in the root of this project.
*/

# ifndef LUATEXCALLBACKLIB_H
# define LUATEXCALLBACKLIB_H

typedef enum {
    find_write_file_callback = 1,
    find_data_file_callback,
    find_format_file_callback,
    open_data_file_callback,
    read_data_file_callback,
    show_error_hook_callback,
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
    pre_linebreak_filter_callback,
    linebreak_filter_callback,
    post_linebreak_filter_callback,
    append_to_vlist_filter_callback,
    mlist_to_hlist_callback,
    pre_dump_callback,
    start_file_callback,
    stop_file_callback,
    show_error_message_callback,
    show_lua_error_hook_callback,
    show_warning_message_callback,
    hpack_quality_callback,
    vpack_quality_callback,
    insert_local_par_callback,
    contribute_filter_callback,
    build_page_insert_callback,
    wrapup_run_callback,
    new_graf_callback,
    make_extensible_callback,
    show_whatsit_callback,
    terminal_input_callback,          /* when we run out of input */
    total_callbacks,
} callback_callback_types;

extern int callback_set[];

# define callback_defined(a) callback_set[a]

extern int run_callback(int i, const char *values, ...);
extern int run_saved_callback(int i, int name, const char *values, ...);
extern int run_and_save_callback(int i, const char *values, ...);
extern int run_saved_callback_line(int i, int firstpos);
extern void destroy_saved_callback(int i);

extern void get_lua_boolean(const char *table, const char *name, int * target);
extern void get_lua_number(const char *table, const char *name, int *target);
extern void get_lua_string(const char *table, const char *name, char **target);

# define normal_page_filter(A) lua_node_filter_s(buildpage_filter_callback,lua_key_index(A))
# define checked_page_filter(A) if (!output_active) lua_node_filter_s(buildpage_filter_callback,lua_key_index(A))
# define checked_break_filter(A) if (!output_active) lua_node_filter_s(contribute_filter_callback,lua_key_index(A))

extern int callback_okay(lua_State * L, int i);
extern void callback_error(lua_State * L, int top, int i);
# define callback_call(L,i,o,top) lua_pcall(L,i,o,top+2);
# define callback_wrapup(L,top) lua_settop(L,top);


#endif

