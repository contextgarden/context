/*
    See license.txt in the root of this project.
*/

# ifndef LNODELIB_H
# define LNODELIB_H

extern void     lmt_push_node             (lua_State *L);
extern void     lmt_push_node_fast        (lua_State *L, halfword n);
extern void     lmt_push_directornode     (lua_State *L, halfword n, int isdirect);
extern void     lmt_node_list_to_lua      (lua_State *L, halfword n);
extern halfword lmt_node_list_from_lua    (lua_State *L, int n);
extern int      lmt_get_math_style        (lua_State *L, int n, int dflt);
extern int      lmt_get_math_parameter    (lua_State *L, int n, int dflt);
extern halfword lmt_check_isnode          (lua_State *L, int i);
extern halfword lmt_check_isdirect        (lua_State *L, int i);
extern halfword lmt_check_isdirectornode  (lua_State *L, int i, int *isdirect);
extern void     lmt_initialize_properties (int set_size);

extern halfword lmt_hpack_filter_callback(
    halfword head,
    scaled   size,
    int      packtype,
    int      extrainfo,
    int      direction,
    halfword a
);

extern halfword lmt_vpack_filter_callback(
    halfword head,
    scaled   size,
    int      packtype,
    scaled   depth,
    int      extrainfo,
    int      direction,
    halfword a
);

extern halfword lmt_packed_vbox_filter_callback(
    halfword box,
    int      extrainfo
);

extern void lmt_node_filter_callback(
    int       filterid,
    int       extrainfo,
    halfword  head,
    halfword *tail
);

extern int lmt_linebreak_callback(
    int       isbroken,
    halfword  head,
    halfword *newhead
);

extern void lmt_alignment_callback(
    halfword head,
    halfword context,
    halfword attrlist,
    halfword preamble
);

extern void lmt_local_box_callback(
    halfword linebox,
    halfword leftbox,
    halfword rightbox,
    halfword middlebox,
    halfword linenumber,
    scaled   leftskip,
    scaled   rightskip,
    scaled   lefthang,
    scaled   righthang,
    scaled   indentation,
    scaled   parinitleftskip,
    scaled   parinitrightskip,
    scaled   parfillleftskip,
    scaled   parfillrightskip,
    scaled   overshoot
);

extern int lmt_append_to_vlist_callback(
    halfword  box,
    int       location,
    halfword  prevdepth,
    halfword *result,
    int      *nextdepth,
    int      *prevset,
    int      *checkdepth
);

extern void lmt_begin_paragraph_callback(
    int invmode,
    int *indented,
    int context
);

extern void lmt_paragraph_context_callback(
    int context,
    int *ignore
);


extern void lmt_page_filter_callback(
    int      context,
    halfword boundary
);

extern void lmt_append_line_filter_callback(
    halfword context,
    halfword index
);

# endif
