/*
    See license.txt in the root of this project.
*/

# include <stdlib.h>

# include "luametatex.h"

/*
    We only need a few definitions and it's nice that they are already prepared for extensions.
*/

typedef enum {
    LZMA_RESERVED_ENUM = 0
} lzma_reserved_enum;

typedef enum {
    LZMA_OK                = 0,
    LZMA_STREAM_END        = 1,
    LZMA_NO_CHECK          = 2,
    LZMA_UNSUPPORTED_CHECK = 3,
    LZMA_GET_CHECK         = 4,
    LZMA_MEM_ERROR         = 5,
    LZMA_MEMLIMIT_ERROR    = 6,
    LZMA_FORMAT_ERROR      = 7,
    LZMA_OPTIONS_ERROR     = 8,
    LZMA_DATA_ERROR        = 9,
    LZMA_BUF_ERROR         = 10,
    LZMA_PROG_ERROR        = 11,
} lzma_ret;

typedef enum {
    LZMA_RUN          = 0,
    LZMA_SYNC_FLUSH   = 1,
    LZMA_FULL_FLUSH   = 2,
    LZMA_FULL_BARRIER = 4,
    LZMA_FINISH       = 3
} lzma_action;

typedef enum {
    LZMA_CHECK_NONE   = 0,
    LZMA_CHECK_CRC32  = 1,
    LZMA_CHECK_CRC64  = 4,
    LZMA_CHECK_SHA256 = 10
} lzma_check;

typedef struct lzma_internal_s lzma_internal;

typedef struct {
    void *(*alloc)(void *opaque, size_t nmemb, size_t size);
    void  (*free )(void *opaque, void *ptr);
    void *opaque;
} lzma_allocator;

typedef struct {
    const uint8_t        *next_in;
    size_t                avail_in;
    uint64_t              total_in;
    uint8_t              *next_out;
    size_t                avail_out;
    uint64_t              total_out;
    const lzma_allocator *allocator;
    lzma_internal        *internal;
    void                 *reserved_ptr1;
    void                 *reserved_ptr2;
    void                 *reserved_ptr3;
    void                 *reserved_ptr4;
    uint64_t              reserved_int1;
    uint64_t              reserved_int2;
    size_t                reserved_int3;
    size_t                reserved_int4;
    lzma_reserved_enum    reserved_enum1;
    lzma_reserved_enum    reserved_enum2;
} lzma_stream;


# define LZMA_STREAM_INIT { NULL, 0, 0, NULL, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, 0, 0, 0, 0, LZMA_RESERVED_ENUM, LZMA_RESERVED_ENUM }

# define LZMA_TELL_NO_CHECK          UINT32_C(0x01)
# define LZMA_TELL_UNSUPPORTED_CHECK UINT32_C(0x02)
# define LZMA_TELL_ANY_CHECK         UINT32_C(0x04)
# define LZMA_CONCATENATED           UINT32_C(0x08)

typedef struct lzmalib_state_info {

    int initialized;
    int padding;

    int (*lzma_auto_decoder) (lzma_stream *strm, uint64_t memlimit, uint32_t flags);
    int (*lzma_easy_encoder) (lzma_stream *strm, uint32_t preset, lzma_check check);
    int (*lzma_code)         (lzma_stream *strm, lzma_action action);
    int (*lzma_end)          (lzma_stream *strm);

} lzmalib_state_info;

static lzmalib_state_info lzmalib_state = {

    .initialized = 0,
    .padding     = 0,

    .lzma_auto_decoder = NULL,
    .lzma_easy_encoder = NULL,
    .lzma_code         = NULL,
    .lzma_end          = NULL,
};


# define lzma_default_level 6
# define lzma_default_size  0xFFFF

static int lzmalib_compress(lua_State *L)
{
    if (lzmalib_state.initialized) {
        size_t sourcesize = 0;
        const char *source = luaL_checklstring(L, 1, &sourcesize);
        int level = lmt_optinteger(L, 2, lzma_default_level);
        int targetsize = lmt_optinteger(L, 3, lzma_default_size);
        if (level < 0 || level > 9) {
            level = lzma_default_level;
        }
        if (source) {
            lzma_stream strm = LZMA_STREAM_INIT;
            int errorcode = lzmalib_state.lzma_easy_encoder(&strm, level, LZMA_CHECK_CRC64);
            if (errorcode == LZMA_OK) {
                luaL_Buffer buffer;
                luaL_buffinit(L, &buffer);
                strm.next_in = (const uint8_t *) source;
                strm.avail_in = sourcesize;
                if (targetsize < lzma_default_size) {
                    targetsize = lzma_default_size;
                }
                while (1) {
                    char *target = luaL_prepbuffsize(&buffer, targetsize);
                    size_t produced = strm.total_out;
                    strm.next_out = (uint8_t *) target;
                    strm.avail_out = targetsize;
                    errorcode = lzmalib_state.lzma_code(&strm, LZMA_FINISH);
                    produced = strm.total_out - produced;
                    luaL_addsize(&buffer, produced);
                    if (errorcode == LZMA_STREAM_END) {
                        lzmalib_state.lzma_end(&strm);
                        luaL_pushresult(&buffer);
                        return 1;
                    } else if (errorcode != LZMA_OK) {
                        lzmalib_state.lzma_end(&strm);
                        break;
                    }
                }
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

static int lzmalib_decompress(lua_State *L)
{
    if (lzmalib_state.initialized) {
        size_t sourcesize = 0;
        const char *source = luaL_checklstring(L, 1, &sourcesize);
        int targetsize = lmt_optinteger(L, 2, lzma_default_size);
        if (source) {
            lzma_stream strm = LZMA_STREAM_INIT;
            int errorcode = lzmalib_state.lzma_auto_decoder(&strm, UINT64_MAX, LZMA_CONCATENATED);
            if (errorcode == LZMA_OK) {
                luaL_Buffer buffer;
                luaL_buffinit(L, &buffer);
                strm.next_in = (const uint8_t *) source;
                strm.avail_in = sourcesize;
                if (targetsize < lzma_default_size) {
                    targetsize = lzma_default_size;
                }
                while (1) {
                    char *target = luaL_prepbuffsize(&buffer, targetsize);
                    size_t produced = strm.total_out;
                    strm.next_out = (uint8_t *) target;
                    strm.avail_out = targetsize;
                    errorcode = lzmalib_state.lzma_code(&strm, LZMA_RUN);
                    produced = strm.total_out - produced;
                    luaL_addsize(&buffer, produced);
                    if (errorcode == LZMA_STREAM_END || produced == 0) {
                        lzmalib_state.lzma_end(&strm);
                        luaL_pushresult(&buffer);
                        return 1;
                    } else if (errorcode != LZMA_OK) {
                        lzmalib_state.lzma_end(&strm);
                        break;
                    }
                }
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

static int lzmalib_initialize(lua_State *L)
{
    if (! lzmalib_state.initialized) {
        const char *filename = lua_tostring(L, 1);
        if (filename) {

            lmt_library lib = lmt_library_load(filename);

            lzmalib_state.lzma_auto_decoder = lmt_library_find(lib, "lzma_auto_decoder");
            lzmalib_state.lzma_easy_encoder = lmt_library_find(lib, "lzma_easy_encoder");
            lzmalib_state.lzma_code         = lmt_library_find(lib, "lzma_code");
            lzmalib_state.lzma_end          = lmt_library_find(lib, "lzma_end");

            lzmalib_state.initialized = lmt_library_okay(lib);
        }
    }
    lua_pushboolean(L, lzmalib_state.initialized);
    return 1;
}

static struct luaL_Reg lzmalib_function_list[] = {
    { "initialize", lzmalib_initialize },
    { "compress",   lzmalib_compress   },
    { "decompress", lzmalib_decompress },
    { NULL,         NULL               },
};

int luaopen_lzma(lua_State * L)
{
    lmt_library_register(L, "lzma", lzmalib_function_list);
    return 0;
}
