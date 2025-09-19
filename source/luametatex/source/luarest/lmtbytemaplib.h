/*
    See license.txt in the root of this project.
*/

# ifndef LUABYTEMAPLIB_H
# define LUABYTEMAPLIB_H

extern int bytemaplib_bytemapped(
    lua_State     * L,
    unsigned char * bytemap,
    int             nx,
    int             ny,
    int             nz,
    int             slot
);

# endif
