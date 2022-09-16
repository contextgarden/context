/*
    See license.txt in the root of this project.
*/

/*
    For a long time the zint api was quite stable but in after 2020 it started changing: the data
    structures got fields added in the middle So, after a few updates Michal Vlasák suggested that
    we adapt to versions. We can always decide to drop older ones when we get too many. The next
    variant is a mix of our attempts to deal with this issue.

*/

# include "luametatex.h"
# include "lmtoptional.h"

# define ZINT_UNICODE_MODE   1
# define ZINT_OUT_BUFFER     0
# define ZINT_DM_SQUARE    100

struct zint_vector;

typedef struct {
    int                 symbology;
    float               height;
    int                 whitespace_width;
    int                 whitespace_height;
    int                 border_width;
    int                 output_options;
    char                fgcolour[10];
    char                bgcolour[10];
    char               *fgcolor;
    char               *bgcolor;
    char                outfile[256];
    float               scale;
    int                 option_1;
    int                 option_2;
    int                 option_3;
    int                 show_hrt;
    int                 fontsize;
    int                 input_mode;
    int                 eci;
    unsigned char       text[128];
    int                 rows;
    int                 width;
    char                primary[128];
    unsigned char       encoded_data[200][143];
    float               row_height[200];
    char                errtxt[100];
    unsigned char      *bitmap;
    int                 bitmap_width;
    int                 bitmap_height;
    unsigned char      *alphamap;
    unsigned int        bitmap_byte_length;
    float               dot_size;
    struct zint_vector *vector;
    int                 debug;
    int                 warn_level;
} zint_symbol_210;

struct zint_structapp {
    int  index;
    int  count;
    char id[32];
};

typedef struct {
    int                    symbology;
    float                  height;
    float                  scale;
    int                    whitespace_width;
    int                    whitespace_height;
    int                    border_width;
    int                    output_options;
    char                   fgcolour[10];
    char                   bgcolour[10];
    char                  *fgcolor;
    char                  *bgcolor;
    char                   outfile[256];
    char                   primary[128];
    int                    option_1;
    int                    option_2;
    int                    option_3;
    int                    show_hrt;
    int                    fontsize;
    int                    input_mode;
    int                    eci;
    float                  dot_size;
    float                  guard_descent;
    struct zint_structapp  structapp;
    int                    warn_level;
    int                    debug;
    unsigned char          text[128];
    int                    rows;
    int                    width;
    unsigned char          encoded_data[200][144];
    float                  row_height[200];
    char                   errtxt[100];
    unsigned char         *bitmap;
    int                    bitmap_width;
    int                    bitmap_height;
    unsigned char         *alphamap;
    unsigned int           bitmap_byte_length;
    struct zint_vector    *vector;
} zint_symbol_211;


typedef struct zint_rectangle zint_rectangle;

typedef struct {
    double          x;
    double          y;
    double          w;
    double          h;
    zint_rectangle *next;
} lmt_zint_rectangle;

static void lmt_zint_get_rect(
    zint_rectangle     *zint_,
    lmt_zint_rectangle *lmt
)
{
    struct {
        float           x;
        float           y;
        float           height;
        float           width;
        int             colour;
        zint_rectangle *next;
    } *zint = (void*) zint_;
    lmt->x = (double) zint->x;
    lmt->y = (double) zint->y;
    lmt->w = (double) zint->width;
    lmt->h = (double) zint->height;
    lmt->next = zint->next;
}

typedef struct zint_circle zint_circle;

typedef struct {
    double       x;
    double       y;
    double       d;
    zint_circle *next;
} lmt_zint_circle;

static void lmt_zint_get_circle_210
(
    zint_circle     *zint_,
    lmt_zint_circle *lmt
)
{
    struct {
        float         x;
        float         y;
        float         diameter;
        int           colour;
        zint_circle  *next;
    } *zint   = (void*) zint_;
    lmt->x    = (double) zint->x;
    lmt->y    = (double) zint->y;
    lmt->d    = (double) zint->diameter;
    lmt->next = zint->next;
}

static void lmt_zint_get_circle_211
(
    zint_circle     *zint_,
    lmt_zint_circle *lmt
)
{
    struct {
        float         x;
        float         y;
        float         diameter;
        float         width;
        int           colour;
        zint_circle  *next;
    } *zint   = (void*) zint_;
    lmt->x    = (double) zint->x;
    lmt->y    = (double) zint->y;
    lmt->d    = (double) zint->diameter;
    lmt->next = zint->next;
}

typedef struct zint_hexagon zint_hexagon;

typedef struct {
    double        x;
    double        y;
    double        d;
    zint_hexagon *next;
} lmt_zint_hexagon;

static void lmt_zint_get_hexagon
(
    zint_hexagon     *zint_,
    lmt_zint_hexagon *lmt
)
{
    struct {
        float          x;
        float          y;
        float          diameter;
        int            rotation;
        zint_hexagon  *next;
    } *zint   = (void *) zint_;
    lmt->x    = (double) zint->x;
    lmt->y    = (double) zint->y;
    lmt->d    = (double) zint->diameter;
    lmt->next = zint->next;
}

typedef struct zint_string zint_string;

typedef struct {
    double       x;
    double       y;
    double       s;
    const char  *t;
    zint_string *next;
} lmt_zint_string;

static void lmt_zint_next_string(zint_string *zint_, lmt_zint_string *lmt)
{
    struct {
        float          x;
        float          y;
        float          fsize;
        float          width;
        int            length;
        int            rotation;
        int            halign;
        unsigned char *text;
        zint_string   *next;
    } *zint   = (void *) zint_;
    lmt->x    = (double) zint->x;
    lmt->y    = (double) zint->y;
    lmt->s    = (double) zint->fsize;
    lmt->t    = (const char *) zint->text;
    lmt->next = zint->next;
}

typedef struct zint_symbol zint_symbol;

typedef struct zint_vector {
    float           width;
    float           height;
    zint_rectangle *rectangles;
    zint_hexagon   *hexagons;
    zint_string    *strings;
    zint_circle    *circles;
} zint_vector;

static zint_vector *lmt_zint_vector_210(zint_symbol *symbol_)
{
    zint_symbol_210 *symbol = (void*) symbol_;
    return symbol->vector;
}

static zint_vector *lmt_zint_vector_211(zint_symbol *symbol_)
{
    zint_symbol_211 *symbol = (void*) symbol_;
    return symbol->vector;
}

static void lmt_zint_symbol_set_options_210(zint_symbol *symbol_, int symbology, int input_mode, int output_options, int square)
{
    zint_symbol_210 *symbol = (void*) symbol_;
    symbol->symbology = symbology;
    symbol->input_mode = input_mode;
    symbol->output_options = output_options;
    if (square)
        symbol->option_3 = ZINT_DM_SQUARE;
}

static void lmt_zint_symbol_set_options_211(zint_symbol *symbol_, int symbology, int input_mode, int output_options, int square)
{
    zint_symbol_211 *symbol = (void*) symbol_;
    symbol->symbology = symbology;
    symbol->input_mode = input_mode;
    symbol->output_options = output_options;
    if (square) {
        symbol->option_3 = ZINT_DM_SQUARE;
    }
}

typedef struct zintlib_state_info {

    int initialized;
    int version;

    int (*ZBarcode_Version) (
        void
    );

    zint_symbol * (*ZBarcode_Create) (
        void
    );

    void (*ZBarcode_Delete) (
        zint_symbol *symbol
    );

    int (*ZBarcode_Encode_and_Buffer_Vector) (
        zint_symbol         *symbol,
        const unsigned char *input,
        int                  length,
        int                  rotate_angle
    );

} zintlib_state_info;

static zintlib_state_info zintlib_state = {

    .initialized                       = 0,
    .version                           = 0,

    .ZBarcode_Version                  = NULL,
    .ZBarcode_Create                   = NULL,
    .ZBarcode_Delete                   = NULL,
    .ZBarcode_Encode_and_Buffer_Vector = NULL,

};

static void (*lmt_zint_get_circle) (
    zint_circle     *zint_,
	lmt_zint_circle *lmt
);

static zint_vector *(*lmt_zint_vector)(
    zint_symbol *symbol_
);
static void (*lmt_zint_symbol_set_options)(
    zint_symbol *symbol,
    int          symbology,
    int          input_mode,
    int          output_options,
    int          square
);

static int zintlib_initialize(lua_State * L)
{
    if (! zintlib_state.initialized) {
        const char *filename = lua_tostring(L, 1);
        if (filename) {

            lmt_library lib = lmt_library_load(filename);

            zintlib_state.ZBarcode_Version                  = lmt_library_find(lib, "ZBarcode_Version");
            zintlib_state.ZBarcode_Create                   = lmt_library_find(lib, "ZBarcode_Create");
            zintlib_state.ZBarcode_Delete                   = lmt_library_find(lib, "ZBarcode_Delete");
            zintlib_state.ZBarcode_Encode_and_Buffer_Vector = lmt_library_find(lib, "ZBarcode_Encode_and_Buffer_Vector");

            zintlib_state.initialized = lmt_library_okay(lib);

            if (zintlib_state.ZBarcode_Version) {
                zintlib_state.version = zintlib_state.ZBarcode_Version();
            }
            zintlib_state.version = zintlib_state.version / 100;
            if (zintlib_state.version < 210) {
                zintlib_state.initialized = 0;
            } else if (zintlib_state.version < 211) {
                lmt_zint_get_circle         = lmt_zint_get_circle_210;
                lmt_zint_vector             = lmt_zint_vector_210;
                lmt_zint_symbol_set_options = lmt_zint_symbol_set_options_210;
            } else {
                lmt_zint_get_circle         = lmt_zint_get_circle_211;
                lmt_zint_vector             = lmt_zint_vector_211;
                lmt_zint_symbol_set_options = lmt_zint_symbol_set_options_211;
            }
        }
    }
    lua_pushboolean(L, zintlib_state.initialized);
    return 1;
}

static int zintlib_execute(lua_State * L)
{
    if (zintlib_state.initialized) {
        if (lua_type(L, 1) == LUA_TTABLE) {
            int code = -1;
            size_t l = 0;
            const unsigned char *s = NULL;
            const char *o = NULL;
            if (lua_getfield(L, 1, "code") == LUA_TNUMBER) {
                code = lmt_tointeger(L, -1);
            }
            lua_pop(L, 1);
            switch (lua_getfield(L, 1, "text")) {
                case LUA_TSTRING:
                case LUA_TNUMBER:
                    s = (const unsigned char *) lua_tolstring(L, -1, &l);
                    break;
            }
            lua_pop(L, 1);
            if (lua_getfield(L, 1, "option") == LUA_TSTRING) {
                /* for the moment one option */
                o = lua_tostring(L, -1);
            }
            lua_pop(L, 1);
            if (code >= 0 && l > 0) {
                zint_symbol *symbol = zintlib_state.ZBarcode_Create();
                if (symbol) {
                    /*tex
                        We could handle this at the \LUA\ end but as we only have a few options we
                        do it here.
                    */
                    int square = (o && (strcmp(o, "square") == 0)) ? 1 : 0;
                    lmt_zint_symbol_set_options(symbol, code, ZINT_UNICODE_MODE, ZINT_OUT_BUFFER, square);
                    if (zintlib_state.ZBarcode_Encode_and_Buffer_Vector(symbol, s, (int) l, 0)) {
                        zintlib_state.ZBarcode_Delete(symbol);
                        lua_pushboolean(L, 0);
                        lua_pushstring(L, "invalid result");
                    } else {
                        zint_vector *vector = lmt_zint_vector(symbol);
                        if (vector) {
                            /*tex
                                It's a bit like the svg output ... first I used named fields but a
                                list is more efficient, not so much in the \LUA\ interfacing but in
                                generating an compact path at the \METAPOST\ end.
                            */
                            lua_createtable(L, 0, 4);
                            if (vector->rectangles) {
                                lmt_zint_rectangle rectangle;
                                int i = 1;
                                lua_newtable(L);
                                for (zint_rectangle *r = vector->rectangles; r; r = rectangle.next) {
                                    lmt_zint_get_rect(r, &rectangle);
                                    lua_createtable(L, 4, 0);
                                    lua_pushinteger(L, lmt_roundedfloat(rectangle.x)); lua_rawseti(L, -2, 1);
                                    lua_pushinteger(L, lmt_roundedfloat(rectangle.y)); lua_rawseti(L, -2, 2);
                                    lua_pushinteger(L, lmt_roundedfloat(rectangle.w)); lua_rawseti(L, -2, 3);
                                    lua_pushinteger(L, lmt_roundedfloat(rectangle.h)); lua_rawseti(L, -2, 4);
                                    lua_rawseti(L, -2, i++);
                                }
                                lua_setfield(L, -2, "rectangles");
                            }
                            if (vector->hexagons) {
                                lmt_zint_hexagon hexagon;
                                int i = 1;
                                lua_newtable(L);
                                for (zint_hexagon *h = vector->hexagons; h; h = hexagon.next) {
                                    lmt_zint_get_hexagon(h, &hexagon);
                                    lua_createtable(L, 0, 3);
                                    lua_pushinteger(L, lmt_roundedfloat(hexagon.x)); lua_rawseti(L, -2, 1);
                                    lua_pushinteger(L, lmt_roundedfloat(hexagon.y)); lua_rawseti(L, -2, 2);
                                    lua_pushinteger(L, lmt_roundedfloat(hexagon.d)); lua_rawseti(L, -2, 3);
                                    lua_rawseti(L, -2, i++);
                                }
                                lua_setfield(L, -2, "hexagons");
                            }
                            if (vector->circles) {
                                lmt_zint_circle circle;
                                int i = 1;
                                lua_newtable(L);
                                for (zint_circle *c = vector->circles; c; c = circle.next) {
                                    lmt_zint_get_circle(c, &circle);
                                    lua_createtable(L, 0, 3);
                                    lua_pushinteger(L, lmt_roundedfloat(circle.x)); lua_rawseti(L, -2, 1);
                                    lua_pushinteger(L, lmt_roundedfloat(circle.y)); lua_rawseti(L, -2, 2);
                                    lua_pushinteger(L, lmt_roundedfloat(circle.d)); lua_rawseti(L, -2, 3);
                                    lua_rawseti(L, -2, i++);
                                }
                                lua_setfield(L, -2, "circles");
                            }
                            if (vector->strings) {
                                lmt_zint_string string;
                                int i = 1;
                                lua_newtable(L);
                                for (zint_string *s = vector->strings; s; s = string.next) {
                                    lmt_zint_next_string(s, &string);
                                    lua_createtable(L, 0, 4);
                                    lua_pushinteger(L, lmt_roundedfloat(string.x)); lua_rawseti(L, -2, 1);
                                    lua_pushinteger(L, lmt_roundedfloat(string.y)); lua_rawseti(L, -2, 2);
                                    lua_pushinteger(L, lmt_roundedfloat(string.s)); lua_rawseti(L, -2, 3);
                                    lua_pushstring (L,                  string.t ); lua_rawseti(L, -2, 4);
                                    lua_rawseti(L, -2, i++);
                                }
                                lua_setfield(L, -2, "strings");
                            }
                            zintlib_state.ZBarcode_Delete(symbol);
                            return 1;
                        } else {
                            zintlib_state.ZBarcode_Delete(symbol);
                            lua_pushboolean(L, 0);
                            lua_pushstring(L, "invalid result vector");
                        }
                    }
                } else {
                    lua_pushboolean(L, 0);
                    lua_pushstring(L, "invalid result symbol");
                }
            } else {
                lua_pushboolean(L, 0);
                lua_pushstring(L, "invalid code");
            }
        } else {
            lua_pushboolean(L, 0);
            lua_pushstring(L, "invalid specification");
        }
    } else {
        lua_pushboolean(L, 0);
        lua_pushstring(L, "not initialized");
    }
    return 2;
}

static struct luaL_Reg zintlib_function_list[] = {
    { "initialize", zintlib_initialize },
    { "execute",    zintlib_execute    },
    { NULL,         NULL               },
};

int luaopen_zint(lua_State * L)
{
    lmt_library_register(L, "zint", zintlib_function_list);
    return 0;
}
