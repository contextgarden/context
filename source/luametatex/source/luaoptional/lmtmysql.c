/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"
# include "lmtoptional.h"

typedef void           mysql_instance;
typedef void           mysql_result;
typedef char         **mysql_row;
typedef unsigned int   mysql_offset;

typedef struct mysql_field {
    char          *name;
    char          *org_name;
    char          *table;
    char          *org_table;
    char          *db;
    char          *catalog;
    char          *def;
    unsigned long  length;
    unsigned long  max_length;
    unsigned int   name_length;
    unsigned int   org_name_length;
    unsigned int   table_length;
    unsigned int   org_table_length;
    unsigned int   db_length;
    unsigned int   catalog_length;
    unsigned int   def_length;
    unsigned int   flags;
    unsigned int   decimals;
    unsigned int   charsetnr;
    int            type;
    void          *extension;
} mysql_field;

# define MYSQLLIB_METATABLE  "luatex.mysqllib"

typedef struct mysqllib_data {
    /*tex There is not much more than a pointer currently. */
    mysql_instance * db;
} mysqllib_data ;

typedef struct mysqllib_state_info {

    int initialized;
    int padding;

    mysql_instance * (*mysql_init) (
        mysql_instance *mysql
    );

    mysql_instance * (*mysql_real_connect) (
        mysql_instance *mysql,
        const char     *host,
        const char     *user,
        const char     *passwd,
        const char     *db,
        unsigned int    port,
        const char     *unix_socket,
        unsigned long   clientflag
    );

    unsigned int (*mysql_errno) (
        mysql_instance *mysql
    );

    const char * (*mysql_error) (
        mysql_instance *mysql
    );

    int (*mysql_real_query) (
        mysql_instance *mysql,
        const char     *q,
        unsigned long   length
    );

    mysql_result * (*mysql_store_result) (
        mysql_instance *mysql
    );

    void (*mysql_free_result) (
        mysql_result *result
    );

    unsigned long long (*mysql_num_rows) (
        mysql_result *res
    );

    mysql_row (*mysql_fetch_row) (
        mysql_result *result
    );

    unsigned int (*mysql_affected_rows) (
        mysql_instance *mysql
    );

    unsigned int (*mysql_field_count) (
        mysql_instance *mysql
    );

    unsigned int (*mysql_num_fields) (
        mysql_result *res
    );

    mysql_field * (*mysql_fetch_fields) (
        mysql_result *res
    );

    mysql_offset (*mysql_field_seek) (
        mysql_result *result,
        mysql_offset  offset
    );

    void (*mysql_close) (
        mysql_instance *sock
    );

} mysqllib_state_info;

static mysqllib_state_info mysqllib_state = {

    .initialized         = 0,
    .padding             = 0,

    .mysql_init          = NULL,
    .mysql_real_connect  = NULL,
    .mysql_errno         = NULL,
    .mysql_error         = NULL,
    .mysql_real_query    = NULL,
    .mysql_store_result  = NULL,
    .mysql_free_result   = NULL,
    .mysql_num_rows      = NULL,
    .mysql_fetch_row     = NULL,
    .mysql_affected_rows = NULL,
    .mysql_field_count   = NULL,
    .mysql_num_fields    = NULL,
    .mysql_fetch_fields  = NULL,
    .mysql_field_seek    = NULL,
    .mysql_close         = NULL,

};

static int mysqllib_initialize(lua_State * L)
{
    if (! mysqllib_state.initialized) {
        const char *filename = lua_tostring(L, 1);
        if (filename != NULL) {

            lmt_library lib = lmt_library_load(filename);

            mysqllib_state.mysql_init          = lmt_library_find(lib, "mysql_init" );
            mysqllib_state.mysql_real_connect  = lmt_library_find(lib, "mysql_real_connect" );
            mysqllib_state.mysql_errno         = lmt_library_find(lib, "mysql_errno" );
            mysqllib_state.mysql_error         = lmt_library_find(lib, "mysql_error" );
            mysqllib_state.mysql_real_query    = lmt_library_find(lib, "mysql_real_query" );
            mysqllib_state.mysql_store_result  = lmt_library_find(lib, "mysql_store_result" );
            mysqllib_state.mysql_free_result   = lmt_library_find(lib, "mysql_free_result" );
            mysqllib_state.mysql_num_rows      = lmt_library_find(lib, "mysql_num_rows" );
            mysqllib_state.mysql_fetch_row     = lmt_library_find(lib, "mysql_fetch_row" );
            mysqllib_state.mysql_affected_rows = lmt_library_find(lib, "mysql_affected_rows" );
            mysqllib_state.mysql_field_count   = lmt_library_find(lib, "mysql_field_count" );
            mysqllib_state.mysql_num_fields    = lmt_library_find(lib, "mysql_num_fields" );
            mysqllib_state.mysql_fetch_fields  = lmt_library_find(lib, "mysql_fetch_fields" );
            mysqllib_state.mysql_field_seek    = lmt_library_find(lib, "mysql_field_seek" );
            mysqllib_state.mysql_close         = lmt_library_find(lib, "mysql_close" );

            mysqllib_state.initialized = lmt_library_okay(lib);
        }
    }
    lua_pushboolean(L, mysqllib_state.initialized);
    return 1;
}

static int mysqllib_open(lua_State * L)
{
    if (mysqllib_state.initialized) {
        const char     * database   = luaL_checkstring(L, 1);
        const char     * username   = luaL_optstring(L, 2, NULL);
        const char     * password   = luaL_optstring(L, 3, NULL);
        const char     * host       = luaL_optstring(L, 4, NULL);
        int              port       = lmt_optinteger(L, 5, 0);
        const char     * socket     = NULL; /* luaL_optstring(L, 6, NULL); */
        int              flag       = 0;    /* luaL_optinteger(L, 7, 0); */
        mysql_instance * db         = mysqllib_state.mysql_init(NULL);
        if (db != NULL) {
            if (mysqllib_state.mysql_real_connect(db, host, username, password, database, port, socket, flag)) {
                mysqllib_data *data = lua_newuserdatauv(L, sizeof(data), 0);
                data->db = db ;
                luaL_getmetatable(L, MYSQLLIB_METATABLE);
                lua_setmetatable(L, -2);
                return 1;
            } else {
                mysqllib_state.mysql_close(db);
            }
        }
    }
    return 0;
}

static int mysqllib_close(lua_State * L)
{
    if (mysqllib_state.initialized) {
        mysqllib_data * data = luaL_checkudata(L, 1, MYSQLLIB_METATABLE);
        if (data != NULL) {
            mysqllib_state.mysql_close(data->db);
            data->db = NULL;
        }
    }
    return 0;
}

/* execute(database,querystring,callback) : callback(nofcolumns,values,fields)  */

static int mysqllib_execute(lua_State * L)
{
    if (mysqllib_state.initialized) {
        mysqllib_data * data = luaL_checkudata(L, 1, MYSQLLIB_METATABLE);
        if (data != NULL) {
            size_t length = 0;
            const char *query = lua_tolstring(L, 2, &length);
            if (query != NULL) {
                int error = mysqllib_state.mysql_real_query(data->db, query, (int) length);
                if (!error) {
                    mysql_result * result = mysqllib_state.mysql_store_result(data->db);
                    if (result != NULL) {
                        int nofrows = 0;
                        int nofcolumns = 0;
                        mysqllib_state.mysql_field_seek(result, 0);
                        nofrows = (int) mysqllib_state.mysql_num_rows(result);
                        nofcolumns = mysqllib_state.mysql_num_fields(result);
                        /* This is similar to sqlite but there the callback is more indirect. */
                        if (nofcolumns > 0 && nofrows > 0) {
                            for (int r = 0; r < nofrows; r++) {
                                mysql_row row = mysqllib_state.mysql_fetch_row(result);
                                lua_pushvalue(L, -1);
                                lua_pushinteger(L, nofcolumns);
                                lua_createtable(L, nofcolumns, 0);
                                for (int c = 0; c < nofcolumns; c++) {
                                    lua_pushstring(L, row[c]);
                                    lua_rawseti(L, -2, (lua_Integer)c + 1);
                                }
                                if (r) {
                                    lua_call(L, 2, 0);
                                } else {
                                    mysql_field * fields = mysqllib_state.mysql_fetch_fields(result);
                                    lua_createtable(L, nofcolumns, 0);
                                    for (int c = 0; c < nofcolumns; c++) {
                                        lua_pushstring(L, fields[c].name);
                                        lua_rawseti(L, -2, (lua_Integer)c + 1);
                                    }
                                    lua_call(L, 3, 0);
                                }
                            }
                        }
                        mysqllib_state.mysql_free_result(result);
                    }
                    lua_pushboolean(L, 1);
                    return 1;
                }
            }
        }
    }
    lua_pushboolean(L, 0);
    return 1;
}

static int mysqllib_getmessage(lua_State * L)
{
     if (mysqllib_state.initialized) {
         mysqllib_data * data = luaL_checkudata(L, 1, MYSQLLIB_METATABLE);
         if (data != NULL) {
             lua_pushstring(L, mysqllib_state.mysql_error(data->db));
             return 1;
         }
     }
     return 0;
}

/* private */

static int mysqllib_free(lua_State * L)
{
    return mysqllib_close(L);
}

/* <string> = tostring(instance) */

static int mysqllib_tostring(lua_State * L)
{
    if (mysqllib_state.initialized) {
        mysqllib_data * data = luaL_checkudata(L, 1, MYSQLLIB_METATABLE);
        if (data != NULL) {
            (void) lua_pushfstring(L, "<mysqllib-instance %p>", data);
        } else {
            lua_pushnil(L);
        }
        return 1;
    } else {
        return 0;
    }
}

static const struct luaL_Reg mysqllib_metatable[] = {
    { "__tostring", mysqllib_tostring },
    { "__gc",       mysqllib_free     },
    { NULL,         NULL              },
};

static struct luaL_Reg mysqllib_function_list[] = {
    { "initialize", mysqllib_initialize },
    { "open",       mysqllib_open       },
    { "close",      mysqllib_close      },
    { "execute",    mysqllib_execute    },
    { "getmessage", mysqllib_getmessage },
    { NULL,         NULL                },
};

int luaopen_mysql(lua_State * L)
{
    luaL_newmetatable(L, MYSQLLIB_METATABLE);
    luaL_setfuncs(L, mysqllib_metatable, 0);
    lmt_library_register(L, "mysql", mysqllib_function_list);
    return 0;
}
