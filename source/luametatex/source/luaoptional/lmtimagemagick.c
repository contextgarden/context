/*
    See license.txt in the root of this project.
*/

/* This one is real simple. */

# include "luametatex.h"
# include "lmtoptional.h"

typedef struct imlib_state_info {

    int initialized;
    int padding;

    int (*im_MagickCommandGenesis) (
        void  *image_info,
     // int   *command,
        void  *command,
        int    argc,
        const  char **argv,
        char **metadata,
        void  *exception
    );

    void * (*im_AcquireImageInfo) (
        void
    );

    void * (*im_AcquireExceptionInfo) (
        void
    );

    int (*im_ConvertImageCommand) (
        void        *image_info,
        int          argc,
        const char **argv,
        char       **metadata,
        void        *exception
    );

} imlib_state_info;

static imlib_state_info imlib_state = {

    .initialized             = 0,
    .padding                 = 0,

    .im_MagickCommandGenesis = NULL,
    .im_AcquireImageInfo     = NULL,
    .im_AcquireExceptionInfo = NULL,
    .im_ConvertImageCommand  = NULL,

};

static int imlib_initialize(lua_State * L) // todo: table
{
    if (! imlib_state.initialized) {
        const char *filename1 = lua_tostring(L,1);
        const char *filename2 = lua_tostring(L,2);
        if (filename1) {

            lmt_library lib = lmt_library_load(filename1);

            imlib_state.initialized = lmt_library_okay(lib);

            imlib_state.im_AcquireImageInfo     = lmt_library_find(lib, "AcquireImageInfo");
            imlib_state.im_AcquireExceptionInfo = lmt_library_find(lib, "AcquireExceptionInfo");

        }
        if (imlib_state.initialized && filename2) {

            lmt_library lib = lmt_library_load(filename2);

            imlib_state.im_MagickCommandGenesis = lmt_library_find(lib, "MagickCommandGenesis");
            imlib_state.im_ConvertImageCommand  = lmt_library_find(lib, "ConvertImageCommand");

            imlib_state.initialized = lmt_library_okay(lib);
        }
    }
    lua_pushboolean(L, imlib_state.initialized);
    return 1;
}

static int imlib_execute(lua_State * L)
{
    if (imlib_state.initialized) {
        if (lua_type(L, 1) == LUA_TTABLE) {
            const char *inpname = NULL;
            const char *outname = NULL;
            lua_getfield(L, -1, "inputfile" ); inpname = lua_tostring(L, -1); lua_pop(L, 1);
            lua_getfield(L, -1, "outputfile"); outname = lua_tostring(L, -1); lua_pop(L, 1);
            if (inpname && outname) {
                lua_Integer   nofarguments = 0;
                lua_Integer   nofoptions   = 0;
                const char  **arguments    = NULL;
                void         *info         = imlib_state.im_AcquireImageInfo();
                void         *exep         = imlib_state.im_AcquireExceptionInfo();
                if (lua_getfield(L, -1, "options" ) == LUA_TTABLE) {
                    nofoptions = luaL_len(L, -1);
                }
                arguments = lmt_memory_malloc((nofoptions + 4) * sizeof(char *));
                arguments[nofarguments++] = "convert";
                arguments[nofarguments++] = inpname;
                for (lua_Integer i = 1; i <= nofoptions; i++) {
                    switch (lua_rawgeti(L, -1, i)) {
                        case LUA_TSTRING:
                        case LUA_TNUMBER:
                             arguments[nofarguments++] = lua_tostring(L, -1);
                             break;
                        case LUA_TBOOLEAN:
                             arguments[nofarguments++] = lua_toboolean(L, -1) ? "true" : "false";
                             break;
                    }
                    lua_pop(L, 1);
                }
                arguments[nofarguments++] = outname;
                imlib_state.im_MagickCommandGenesis(info, imlib_state.im_ConvertImageCommand, (int) nofarguments, arguments, NULL, exep);
                lmt_memory_free((char *) arguments);
                lua_pop(L, 1);
                lua_pushboolean(L, 1);
                return 2;
            }
        } else {
            lua_pushboolean(L, 0);
            lua_pushliteral(L, "invalid specification");
            return 2;
        }
    }
    lua_pushboolean(L, 0);
    lua_pushliteral(L, "not initialized");
    return 2;
}

static struct luaL_Reg imlib_function_list[] = {
    { "initialize", imlib_initialize },
    { "execute",    imlib_execute    },
    { NULL,         NULL             },
};

int luaopen_imagemagick(lua_State * L)
{
    lmt_library_register(L, "imagemagick", imlib_function_list);
    return 0;
}
