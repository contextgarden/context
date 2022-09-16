/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"
# include "lmtoptional.h"

typedef void PGconn;
typedef void PGresult;

typedef enum postgres_polling_status_type {
    PGRES_POLLING_FAILED,
    PGRES_POLLING_READING,
    PGRES_POLLING_WRITING,
    PGRES_POLLING_OK
} postgres_polling_status_type;

typedef enum postgres_exec_status_type {
    PGRES_EMPTY_QUERY,
    PGRES_COMMAND_OK,
    PGRES_TUPLES_OK,
    PGRES_COPY_OUT,
    PGRES_COPY_IN,
    PGRES_BAD_RESPONSE,
    PGRES_NONFATAL_ERROR,
    PGRES_FATAL_ERROR,
    PGRES_COPY_BOTH,
    PGRES_SINGLE_TUPLE
} postgres_exec_status_type;

typedef enum postgres_connection_status_type {
    PGRES_CONNECTION_OK,
    PGRES_CONNECTION_BAD,
    PGRES_CONNECTION_STARTED,
    PGRES_CONNECTION_MADE,
    PGRES_CONNECTION_AWAITING_RESPONSE,
    PGRES_CONNECTION_AUTH_OK,
    PGRES_CONNECTION_SETENV,
    PGRES_CONNECTION_SSL_STARTUP,
    PGRES_CONNECTION_NEEDED
} postgres_connection_status_type;

# define POSTGRESSLIB_METATABLE  "luatex.postgresslib"

typedef struct postgresslib_data {
    /*tex There is not much more than a pointer currently. */
    PGconn * db;
} postgresslib_data ;

typedef struct postgresslib_state_info {

    int initialized;
    int padding;

    PGconn * (*PQsetdbLogin) (
        const char *pghost,
        const char *pgport,
        const char *pgoptions,
        const char *pgtty,
        const char *dbName,
        const char *login,
        const char *pwd
    );

    postgres_connection_status_type (*PQstatus) (
        const PGconn *conn
    );

    void (*PQfinish) (
        PGconn *conn
    );

    char * (*PQerrorMessage) (
        const PGconn *conn
    );

    int (*PQsendQuery) (
        PGconn     *conn,
        const char *command
    );

    PGresult * (*PQgetResult) (
        PGconn *conn
    );

    postgres_exec_status_type (*PQresultStatus) (
        const PGresult *res
    );

    int (*PQntuples) (
        const PGresult *res
    );

    int (*PQnfields) (
        const PGresult *res
    );

    void (*PQclear) (
        PGresult *res
    );

    char * (*PQfname) (
        const PGresult *res,
        int             column_number
    );

    char * (*PQgetvalue) (
        const PGresult *res,
        int             row_number,
        int             column_number
    );

} postgresslib_state_info;

static postgresslib_state_info postgresslib_state = {

    .initialized    = 0,
    .padding        = 0,

    .PQsetdbLogin   = NULL,
    .PQstatus       = NULL,
    .PQfinish       = NULL,
    .PQerrorMessage = NULL,
    .PQsendQuery    = NULL,
    .PQgetResult    = NULL,
    .PQresultStatus = NULL,
    .PQntuples      = NULL,
    .PQnfields      = NULL,
    .PQclear        = NULL,
    .PQfname        = NULL,
    .PQgetvalue     = NULL,

};

static int postgresslib_initialize(lua_State * L)
{
    if (! postgresslib_state.initialized) {
        const char *filename = lua_tostring(L, 1);
        if (filename != NULL) {

            lmt_library lib = lmt_library_load(filename);

            postgresslib_state.PQsetdbLogin   = lmt_library_find(lib, "PQsetdbLogin");
            postgresslib_state.PQstatus       = lmt_library_find(lib, "PQstatus");
            postgresslib_state.PQfinish       = lmt_library_find(lib, "PQfinish");
            postgresslib_state.PQerrorMessage = lmt_library_find(lib, "PQerrorMessage");
            postgresslib_state.PQsendQuery    = lmt_library_find(lib, "PQsendQuery");
            postgresslib_state.PQgetResult    = lmt_library_find(lib, "PQgetResult");
            postgresslib_state.PQresultStatus = lmt_library_find(lib, "PQresultStatus");
            postgresslib_state.PQntuples      = lmt_library_find(lib, "PQntuples");
            postgresslib_state.PQnfields      = lmt_library_find(lib, "PQnfields");
            postgresslib_state.PQclear        = lmt_library_find(lib, "PQclear");
            postgresslib_state.PQfname        = lmt_library_find(lib, "PQfname");
            postgresslib_state.PQgetvalue     = lmt_library_find(lib, "PQgetvalue");

            postgresslib_state.initialized = lmt_library_okay(lib);
        }
    }
    lua_pushboolean(L, postgresslib_state.initialized);
    return 1;
}

static int postgresslib_open(lua_State * L)
{
    if (postgresslib_state.initialized) {
        const char *database  = luaL_checkstring(L, 1);
        const char *username  = luaL_optstring(L, 2, NULL);
        const char *password  = luaL_optstring(L, 3, NULL);
        const char *host      = luaL_optstring(L, 4, NULL);
        const char *port      = luaL_optstring(L, 5, NULL);
        PGconn     *db        = postgresslib_state.PQsetdbLogin(host, port, NULL, NULL, database, username, password);
        if (db != NULL && postgresslib_state.PQstatus(db) == PGRES_CONNECTION_BAD) {
            postgresslib_state.PQfinish(db);
        } else {
            postgresslib_data *data = lua_newuserdatauv(L, sizeof(data), 0);
            data->db = db ;
            luaL_getmetatable(L, POSTGRESSLIB_METATABLE);
            lua_setmetatable(L, -2);
            return 1;
        }
    }
    return 0;
}

static int postgresslib_close(lua_State * L)
{
    if (postgresslib_state.initialized) {
        postgresslib_data * data = luaL_checkudata(L,1,POSTGRESSLIB_METATABLE);
        if (data != NULL) {
            postgresslib_state.PQfinish(data->db);
            data->db = NULL;
        }
    }
    return 0;
}

/* execute(database,querystring,callback) : callback(nofcolumns,values,fields)  */

static int postgresslib_execute(lua_State * L)
{
    if (postgresslib_state.initialized) {
        postgresslib_data * data = luaL_checkudata(L, 1, POSTGRESSLIB_METATABLE);
        if (data != NULL) {
            size_t length = 0;
            const char *query = lua_tolstring(L, 2, &length);
            if (query != NULL) {
                int error = postgresslib_state.PQsendQuery(data->db, query);
                if (!error) {
                    PGresult * result = postgresslib_state.PQgetResult(data->db);
                    if (result) {
                        if (postgresslib_state.PQresultStatus(result) == PGRES_TUPLES_OK) {
                            int nofrows    = postgresslib_state.PQntuples(result);
                            int nofcolumns = postgresslib_state.PQnfields(result);
                            /* This is similar to sqlite but there the callback is more indirect. */
                            if (nofcolumns > 0 && nofrows > 0) {
                                for (int r = 0; r < nofrows; r++) {
                                    lua_pushvalue(L, -1);
                                    lua_pushinteger(L, nofcolumns);
                                    lua_createtable(L, nofcolumns, 0);
                                    for (int c = 0; c < nofcolumns; c++) {
                                        lua_pushstring(L, postgresslib_state.PQgetvalue(result, r, c));
                                        lua_rawseti(L,- 2, (lua_Integer)c + 1);
                                    }
                                    if (r) {
                                        lua_call(L, 2, 0);
                                    } else {
                                        lua_createtable(L, nofcolumns, 0);
                                        for (int c = 0; c < nofcolumns; c++) {
                                            lua_pushstring(L, postgresslib_state.PQfname(result,c));
                                            lua_rawseti(L, -2, (lua_Integer)c + 1);
                                        }
                                        lua_call(L,3,0);
                                   }
                                }
                            }
                        }
                        postgresslib_state.PQclear(result);
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

static int postgresslib_getmessage(lua_State * L)
{
    if (postgresslib_state.initialized) {
        postgresslib_data * data = luaL_checkudata(L, 1, POSTGRESSLIB_METATABLE);
        if (data != NULL) {
            lua_pushstring(L, postgresslib_state.PQerrorMessage(data->db));
            return 1;
        }
    }
    return 0;
}

/* private */

static int postgresslib_free(lua_State * L)
{
    return postgresslib_close(L);
}

/* <string> = tostring(instance) */

static int postgresslib_tostring(lua_State * L)
 {
    if (postgresslib_state.initialized) {
        postgresslib_data * data = luaL_checkudata(L, 1, POSTGRESSLIB_METATABLE);
        if (data != NULL) {
            (void) lua_pushfstring(L, "<postgresslib-instance %p>", data);
        } else {
            lua_pushnil(L);
        }
        return 1;
    } else {
        return 0;
    }
}

static const struct luaL_Reg postgresslib_metatable[] = {
    { "__tostring", postgresslib_tostring },
    { "__gc",       postgresslib_free     },
    { NULL,         NULL                  },
};

static struct luaL_Reg postgresslib_function_list[] = {
    { "initialize", postgresslib_initialize },
    { "open",       postgresslib_open       },
    { "close",      postgresslib_close      },
    { "execute",    postgresslib_execute    },
    { "getmessage", postgresslib_getmessage },
    { NULL,         NULL                    },
};

int luaopen_postgress(lua_State * L)
{
    luaL_newmetatable(L, POSTGRESSLIB_METATABLE);
    luaL_setfuncs(L, postgresslib_metatable, 0);
    lmt_library_register(L, "postgress", postgresslib_function_list);
    return 0;
}
