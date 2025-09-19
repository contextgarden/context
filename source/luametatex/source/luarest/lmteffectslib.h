/*
    See license.txt in the root of this project.
*/

# ifndef LUAEFFECTSLIB_H
# define LUAEFFECTSLIB_H

/*tex

    On the \LUA\ stack:

    [1] : mandate octave userdata 
    [2] : optional color function

*/

extern int effectslib_octave_bytemapped(
    lua_State     * L, 
    unsigned char * bytemap, 
    int             nx, 
    int             ny, 
    int             nz, 
    int             slot
);

# endif
