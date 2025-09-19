/*
    See license.txt in the root of this project.
*/

/*tex 

   We use some of qrcodegen:

       Copyright (c) Project Nayuki. (MIT License)
 
   Currently we have a rather minimal interface. 

*/

# include <luametatex.h>
# include <qrcodegen.h>

/* 
    generate(data)
    generate(data,yesbyte,nopbyte)
    generate(data,yesbyte,nopbyte,newlines)
*/

static int qrcodegenlib_generate(lua_State *L)
{
    const char *text = lua_tostring(L, 1);
    if (text) { 
		uint8_t qrcode[qrcodegen_BUFFER_LEN_MAX];
		uint8_t buffer[qrcodegen_BUFFER_LEN_MAX];
		bool ok = qrcodegen_encodeText(
            text, buffer, qrcode,
			qrcodegen_Ecc_QUARTILE, 
            qrcodegen_VERSION_MIN, qrcodegen_VERSION_MAX, 
            qrcodegen_Mask_AUTO, true
        );
		if (ok) {
            unsigned yes = lmt_optinteger(L, 2, 0);
            unsigned nop = lmt_optinteger(L, 3, yes ? 0 : 255);
            unsigned nln = lua_toboolean(L, 4);
            int size = qrcodegen_getSize(qrcode);
            int length = (nln ? size + 1 : size) * size;
        	char *bytemap = lmt_memory_malloc(length);
            char *p = bytemap;
            if (yes > 255) { 
                yes = 255;
            }
            if (nop > 255) { 
                nop = 255;
            }
	        for (int y = 0; y < size; y++) {
		        for (int x = 0; x < size; x++) {
			        *p++ = (unsigned char) qrcodegen_getModule(qrcode, x, y) ? yes : nop;
        		}
                if (nln) { 
                    *p++ = '\n';
                }
        	}
            lua_pushlstring(L, bytemap, length);
            lua_pushinteger(L, size);
            lmt_memory_free(bytemap);
            return 2;
        }
	}
    return 0;
}

static struct luaL_Reg qrcodegenlib_function_list[] = {
    { "generate", qrcodegenlib_generate },
    { NULL,       NULL                  },
};

int luaopen_qrcodegen(lua_State *L)
{
    lua_newtable(L);
    luaL_setfuncs(L, qrcodegenlib_function_list, 0);
    return 1;
}