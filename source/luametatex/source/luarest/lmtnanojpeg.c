/*
    See license.txt in the root of this project.
*/

/*tex 

    We use the mimimalistic (a bit adapted) nanojpeg from:

        https://keyj.emphy.de/nanojpeg/
 
    This is just an experiment. We want to play with this in \LUAMETAFUN\ in the context of bytemaps 
    and (perlin) noise so we go for a tiny setup. An alternative is the picojpeg library that 
    comes with arduino but that needs more work (getting rid of specific stuff). 

        https://github.com/richgel999/picojpeg

    We don't do encoding so we end up with a (manipulated or downsampled or ...) \PNG\ instead. 

*/

# include <luametatex.h>
# include <nanojpeg.h>

/* 
    decode(data)
*/

static int nanojpeglib_decode(lua_State *L)
{
    size_t size; 
    const char *jpeg = lua_tolstring(L, 1, &size);
    int done = 0;
    if (jpeg) { 
        njInit();
        if (njDecode(jpeg, (int) size) == NJ_OK) {
            int width = njGetWidth();
            int height = njGetHeight();
            int depth = njIsColor() ? 3 : 1;
            unsigned char * bytes = njGetImage();
            int nofbytes = njGetImageSize();
            if (width * height * depth == nofbytes) {
                lua_pushinteger(L, width);
                lua_pushinteger(L, height);
                lua_pushinteger(L, depth);
                lua_pushlstring(L, (char *) bytes, nofbytes);
                done = 4;
            }
            njDone();
        }
	}
    return done;
}

static struct luaL_Reg nanojpeglib_function_list[] = {
    { "decode", nanojpeglib_decode },
    { NULL,     NULL               },
};

int luaopen_nanojpeg(lua_State *L)
{
    lua_newtable(L);
    luaL_setfuncs(L, nanojpeglib_function_list, 0);
    return 1;
}