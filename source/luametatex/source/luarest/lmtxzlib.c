/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex
    Because we already have |tar| support in \CONTEXT\ (just \LUA), I decided to also get
    a simple |xz| compressor in the engine because thsi file format is popular in the \TEX\
    ecosystem. A bit of research learned that \quote {xz embedded} was the best candidate.

    We could have an |auxxzembedded.h| file but we need to adapt the |xz_config.h| file
    anyway: |XZ_DEC_CONCATENATED| as well as |XZ_USE_CRC64|.

*/

# include "../libraries/xzembedded/xz_config.h"

/*tex

    We initialize the decoder with dynamic allocation mode and a max dictionary size limit
    (64 MB) to protect against malicious headers.

    This wrapper is simular to for instance miniz but with less options. Here We only
    decompress. We need  |xz_dec_catrun| and not |xz_dec_run| as well as 64 bit checksum
    support. We could go for larger chunks but it looks fast enough.

*/

/*tex

    This one calculates the exact byte size of an XZ stream from an in-memory buffer. A \CCODE\
    template was provided by gemini. First a helper to read a 32-bit little-endian integer
    safely from arbitrary memory. We also need a Variable-Length Integer (VLI) decoder that
    reads a variable-length integer from the buffer and advances the pointer/length.

*/


static inline uint32_t read_le32(const uint8_t *buf)
{
    return ((uint32_t) buf[0]      ) |
           ((uint32_t) buf[1] <<  8) |
           ((uint32_t) buf[2] << 16) |
           ((uint32_t) buf[3] << 24);
}

static int read_vli(const uint8_t **buf, size_t *left, uint64_t *val) 
{
    *val = 0;
    int shift = 0;
    while (*left > 0) {
        uint8_t b = **buf;
        (*buf)++;
        (*left)--;
        *val |= (uint64_t) (b & 0x7F) << shift;
        if (! (b & 0x80)) {
            return 0; /* success */
        }
        shift += 7;
        if (shift >= 64) {
            return -1; /* overflow */
        }
    }
    return -1; /* unexpected end of buffer */
}

static int64_t xzlib_aux_targetsize(const char *data, size_t len) 
{
    if (! data) {
        /* bad stream */
        return -1;
    }

    if (len < 12) {
        /* too short to contain a valid XZ stream header and footer */
        return -1;
    }

    const uint8_t *bytes = (const uint8_t *) data;

    // check stream header magic at the beginning (6 bytes) */

    if (bytes[0] != 0xFD || bytes[1] != '7' || bytes[2] != 'z' ||
        bytes[3] != 'X'  || bytes[4] != 'Z' || bytes[5] != 0x00) {
        /* invalid XZ header */
        return -2;
    }

    /* verify stream footer magic at the last 2 bytes ('Y' = 0x59, 'Z' = 0x5A) */

    if (bytes[len - 2] != 0x59 || bytes[len - 1] != 0x5A) {
        /* invalid XZ footer */
        return -2;
    }

    /* extract backward size (4 bytes, located 8 to 5 bytes from the end) */

    uint32_t backward_size_val = read_le32(&bytes[len - 8]);

    /* the actual index size formula is |real_backward_size = (stored_backward_size + 1) * 4| */

    uint64_t index_size = ((uint64_t) backward_size_val + 1) * 4;

    /* compute structural offsets, the index field starts right before the 12-byte stream footer */

    int64_t  index_start = (int64_t) len - 12 - (int64_t) index_size;

    if (index_start < 12) {
        /* corrupted backward size or invalid layout */
        return -3;
    }

    /* index structure starts at bytes[index_start] */

    const uint8_t *ptr = &bytes[index_start];
    size_t left = index_size;

    // index indicator (must be 0x00) */

    if (left == 0 || *ptr != 0x00) {
        return -4;
    }
    ptr++;
    left--;

    /* number of (VLI) records */

    uint64_t num_records = 0;
    if (read_vli(&ptr, &left, &num_records) != 0) {
        return  -5;
    }

    uint64_t total_uncompressed_size = 0;

    /* loop through each block record in the index */

    for (uint64_t i = 0; i < num_records; i++) {
        uint64_t comp_size   = 0;
        uint64_t uncomp_size = 0;
        if (read_vli(&ptr, &left, &comp_size) != 0)  {
            return  -6;
        }
        if (read_vli(&ptr, &left, &uncomp_size) != 0) {
            return -7;
        }
        total_uncompressed_size += uncomp_size;
    }

    /* index CRC32 validation can happen here if needed */

    return total_uncompressed_size;
}

static int xzlib_decompresssize(lua_State *L)
{
    size_t      len = 0;
    const char *str = lua_tolstring(L, 1, &len);
    if (str) { 
        lua_Integer size = (lua_Integer) xzlib_aux_targetsize(str, len);
        if (size > 0) {
            lua_pushinteger(L, size);
            return 1;
        }
    }
    return 0;
}

/*tex
    Because we have the whole data stream loaded we can calculate the target length and use a fast
    code path. So, we extended the decompressor but kept the previous chunk variant as fallback.

    \starttabulate
        \NC date              \NC 2026-10-27 \NC \NR
        \NC file              \NC cont-tfm.tar.xz \NC \NR
        \NC compressed        \NC 227,915,180 \NC \NR
        \NC uncompressed      \NC 367,853,056 \NC \NR
        \NC compression ratio \NC 1.61 \NC \NR
        \NC chunked           \NC 12.3 sec \NC \NR
        \NC single allocation \NC 11.8 sec \NC \NR
        \NC laptop            \NC (2018) Xeon E3-1505M v6, Windows 11 \NC \NR
    \stoptabulate

    Although we only gain about 4\percent\ we get less memory fragmentation and no spikes in memory
    usage (stable baseline).

*/

static int xzlib_decompress(lua_State *L)
{
    size_t       size       = 0;
    const char  *data       = luaL_checklstring(L, 1, &size);
    lua_Integer  max        = luaL_optinteger(L, 2, 0);
    int          success    = 0;
    int64_t      targetsize = xzlib_aux_targetsize(data, size);

    if (max > 0 && targetsize > max) {
     // tex_formatted_warning("xz decompress", "target size: %i, max size: %i, overflow", targetsize, max);
        goto DONE;
    }

    struct xz_dec *decoder = xz_dec_init(XZ_DYNALLOC, 1 << 26);

    if (! decoder) {
        goto DONE;
    }

    luaL_Buffer buffer;

    struct xz_buf b;
    b.in      = (const uint8_t *) data;
    b.in_pos  = 0;
    b.in_size = size;

    if (targetsize > 0) {
        char *out_ptr = luaL_buffinitsize(L, &buffer, (size_t) targetsize);
        
        b.out      = (uint8_t *) out_ptr;
        b.out_pos  = 0;
        b.out_size = (size_t) targetsize;

        enum xz_ret ret = xz_dec_catrun(decoder, &b, 1);

        if (ret == XZ_STREAM_END && b.out_pos == (size_t) targetsize) {
            success = 1;
            luaL_pushresultsize(&buffer, b.out_pos);
        }
    }

    if (! success) {
        luaL_buffinit(L, &buffer);
        size_t chunksize = 16 * 1024;
        while (1) {
            uint8_t *out = (uint8_t *) luaL_prepbuffsize(&buffer, chunksize);

            b.out      = out;
            b.out_pos  = 0;
            b.out_size = chunksize;

            enum xz_ret ret = xz_dec_catrun(decoder, &b, 1);
            
            if (b.out_pos > 0) {
                luaL_addsize(&buffer, b.out_pos);
            }
            if (ret == XZ_STREAM_END) {
                success = 1;
                luaL_pushresult(&buffer);
                break;
            } else if (ret != XZ_OK) {
                success = 0;
                break;
            }
        }
    }

    xz_dec_end(decoder);

  DONE:
    if (! success) {
        lua_pushnil(L);
    }
    return 1;
}

static struct luaL_Reg xzlib_function_list[] = {
    { "decompress",     xzlib_decompress     },
    { "decompresssize", xzlib_decompresssize },
    { NULL,             NULL                 },
};

int luaopen_xz(lua_State *L)
{
    xz_crc32_init();
    xz_crc64_init();
    lua_newtable(L);
    luaL_setfuncs(L, xzlib_function_list, 0);
    return 1;
}