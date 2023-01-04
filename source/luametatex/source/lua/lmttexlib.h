/*
    See license.txt in the root of this project.
*/

# ifndef LMT_LTEXLIB_H
# define LMT_LTEXLIB_H

extern void lmt_cstring_start    (void);
extern void lmt_cstring_close    (void);
extern int  lmt_cstring_input    (halfword *result, int *cattable, int *partial, int *finalline);

extern void lmt_cstring_print    (int cattable, const char *s, int ispartial);
extern void lmt_tstring_store    (strnumber s, int cattable);
extern void lmt_cstring_store    (char *s, int l, int cattable);

extern int  lmt_check_for_flags  (lua_State *L, int slot, int *flags, int prefixes, int numeric);        /* returns slot */
extern int  lmt_check_for_level  (lua_State *L, int slot, quarterword *level, quarterword defaultlevel); /* returns slot */

extern int  lmt_get_box_id       (lua_State *L, int slot, int report);

/*tex
    In the meantime keys are sequential so we can replace values by keys especially when the type
    field is used.
*/

extern int  lmt_push_info_values (lua_State *L, value_info *values);
extern int  lmt_push_info_keys   (lua_State *L, value_info *values);

# endif
