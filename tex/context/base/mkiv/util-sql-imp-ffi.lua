if not modules then modules = { } end modules ['util-sql-imp-ffi'] = {
    version   = 1.001,
    comment   = "companion to util-sql.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- I looked at luajit-mysql to see how the ffi mapping was done but it didn't work
-- out that well (at least not on windows) but I got the picture. As I have somewhat
-- different demands I simplified / redid the ffi bti and just took the swiglib
-- variant and adapted that.

local tonumber = tonumber
local concat = table.concat
local format, byte = string.format, string.byte
local lpegmatch = lpeg.match
local setmetatable, type = setmetatable, type
local sleep = os.sleep

local trace_sql     = false  trackers.register("sql.trace",  function(v) trace_sql     = v end)
local trace_queries = false  trackers.register("sql.queries",function(v) trace_queries = v end)
local report_state  = logs.reporter("sql","ffi")

if not utilities.sql then
    require("util-sql")
end

ffi.cdef [[

    /*
        This is as lean and mean as possible. After all we just need a connection and
        a query. The rest is handled already in the Lua code elsewhere.
    */

    typedef void MYSQL_instance;
    typedef void MYSQL_result;
    typedef char **MYSQL_row;
    typedef unsigned int MYSQL_offset;

    typedef struct st_mysql_field {
        char *name;
        char *org_name;
        char *table;
        char *org_table;
        char *db;
        char *catalog;
        char *def;
        unsigned long length;
        unsigned long max_length;
        unsigned int name_length;
        unsigned int org_name_length;
        unsigned int table_length;
        unsigned int org_table_length;
        unsigned int db_length;
        unsigned int catalog_length;
        unsigned int def_length;
        unsigned int flags;
        unsigned int decimals;
        unsigned int charsetnr;
        int type;
        void *extension;
    } MYSQL_field;

    void free(void*ptr);
    void * malloc(size_t size);

    MYSQL_instance * mysql_init (
        MYSQL_instance *mysql
    );

    MYSQL_instance * mysql_real_connect (
        MYSQL_instance *mysql,
        const char *host,
        const char *user,
        const char *passwd,
        const char *db,
        unsigned int port,
        const char *unix_socket,
        unsigned long clientflag
    );

    unsigned int mysql_errno (
        MYSQL_instance *mysql
    );

    const char *mysql_error (
        MYSQL_instance *mysql
    );

    /* int mysql_query (
        MYSQL_instance *mysql,
        const char *q
    ); */

    int mysql_real_query (
        MYSQL_instance *mysql,
        const char *q,
        unsigned long length
    );

    MYSQL_result * mysql_store_result (
        MYSQL_instance *mysql
    );

    void mysql_free_result (
        MYSQL_result *result
    );

    unsigned long long mysql_num_rows (
        MYSQL_result *res
    );

    MYSQL_row mysql_fetch_row (
        MYSQL_result *result
    );

    unsigned int mysql_num_fields (
        MYSQL_result *res
    );

    /* MYSQL_field *mysql_fetch_field (
        MYSQL_result *result
    ); */

    MYSQL_field * mysql_fetch_fields (
        MYSQL_result *res
    );

    MYSQL_offset mysql_field_seek(
        MYSQL_result *result,
        MYSQL_offset offset
    );

    void mysql_close(
        MYSQL_instance *sock
    );

    /* unsigned long * mysql_fetch_lengths(
        MYSQL_result *result
    ); */

]]

local sql                    = utilities.sql
local mysql                  = ffi.load(os.name == "windows" and "libmysql" or "libmysqlclient")

local nofretries             = 5
local retrydelay             = 1

local cache                  = { }
local helpers                = sql.helpers
local methods                = sql.methods
local validspecification     = helpers.validspecification
local querysplitter          = helpers.querysplitter
local dataprepared           = helpers.preparetemplate
local serialize              = sql.serialize
local deserialize            = sql.deserialize

local mysql_initialize       = mysql.mysql_init

local mysql_open_connection  = mysql.mysql_real_connect
local mysql_execute_query    = mysql.mysql_real_query
local mysql_close_connection = mysql.mysql_close

local mysql_field_seek       = mysql.mysql_field_seek
local mysql_num_fields       = mysql.mysql_num_fields
local mysql_fetch_fields     = mysql.mysql_fetch_fields
----- mysql_fetch_field      = mysql.mysql_fetch_field
local mysql_num_rows         = mysql.mysql_num_rows
local mysql_fetch_row        = mysql.mysql_fetch_row
----- mysql_fetch_lengths    = mysql.mysql_fetch_lengths
local mysql_init             = mysql.mysql_init
local mysql_store_result     = mysql.mysql_store_result
local mysql_free_result      = mysql.mysql_free_result

local mysql_error_message    = mysql.mysql_error

local NULL                   = ffi.cast("MYSQL_result *",0)

local ffi_tostring           = ffi.string
local ffi_gc                 = ffi.gc

----- mysqldata              = ffi.cast("MYSQL_instance*",mysql.malloc(1024*1024))
local instance               = mysql.mysql_init(nil) -- (mysqldata)

local mysql_constant_false   = false
local mysql_constant_true    = true

local function finish(t)
    local r = t._result_
    if r then
        ffi_gc(r,mysql_free_result)
    end
end

local function getcolnames(t)
    return t.names
end

local function getcoltypes(t)
    return t.types
end

local function numrows(t)
    return tonumber(t.nofrows)
end

local function list(t)
    local result = t._result_
    if result then
        local row = mysql_fetch_row(result)
     -- local len = mysql_fetch_lengths(result)
        local result = { }
        for i=1,t.noffields do
            result[i] = ffi_tostring(row[i-1])
        end
        return result
    end
end

local function hash(t)
    local result = t._result_
    local fields = t.names
    if result then
        local row = mysql_fetch_row(result)
     -- local len = mysql_fetch_lengths(result)
        local result = { }
        for i=1,t.noffields do
            result[fields[i]] = ffi_tostring(row[i-1])
        end
        return result
    end
end

local function wholelist(t)
    return fetch_all_rows(t._result_)
end

local mt = { __index = {
        -- regular
        finish      = finish,
        list        = list,
        hash        = hash,
        wholelist   = wholelist,
        -- compatibility
        numrows     = numrows,
        getcolnames = getcolnames,
        getcoltypes = getcoltypes,
        -- fallback
        _result_    = nil,
        names       = { },
        types       = { },
        noffields   = 0,
        nofrows     = 0,
    }
}

local nt = setmetatable({},mt)

-- session

local function close(t)
    mysql_close_connection(t._connection_)
end

local function execute(t,query)
    if query and query ~= "" then
        local connection = t._connection_
        local result = mysql_execute_query(connection,query,#query)
        if result == 0 then
            local result = mysql_store_result(connection)
            if result then
                mysql_field_seek(result,0)
                local nofrows   = tonumber(mysql_num_rows(result) or 0)
                local noffields = tonumber(mysql_num_fields(result))
                local names     = { }
                local types     = { }
                local fields    = mysql_fetch_fields(result)
                for i=1,noffields do
                    local field = fields[i-1]
                    names[i] = ffi_tostring(field.name)
                    types[i] = tonumber(field.type) -- todo
                end
                local t = {
                    _result_  = result,
                    names     = names,
                    types     = types,
                    noffields = noffields,
                    nofrows   = nofrows,
                }
                return setmetatable(t,mt)
            else
                return nt
            end
        end
    end
    return false
end

local mt = { __index = {
        close   = close,
        execute = execute,
    }
}

local function open(t,database,username,password,host,port)
    local connection = mysql_open_connection(
        t._session_,
        host or "localhost",
        username or "",
        password or "",
        database or "",
        port or 0,
        NULL,
        0
    )
    if connection ~= NULL then
        local t = {
            _connection_ = connection,
        }
        return setmetatable(t,mt)
    end
end

local function message(t)
    return mysql_error_message(t._session_)
end

local function close(t)
    -- dummy, as we have a global session
end

local mt = {
    __index = {
        connect = open,
        close   = close,
        message = message,
    }
}

local function initialize()
    local session = {
        _session_ = mysql_initialize(instance) -- maybe share, single thread anyway
    }
    return setmetatable(session,mt)
end

-- -- -- --

local function connect(session,specification)
    return session:connect(
        specification.database or "",
        specification.username or "",
        specification.password or "",
        specification.host     or "",
        specification.port
    )
end

local function error_in_connection(specification,action)
    report_state("error in connection: [%s] %s@%s to %s:%s",
            action or "unknown",
            specification.database or "no database",
            specification.username or "no username",
            specification.host     or "no host",
            specification.port     or "no port"
        )
end

local function datafetched(specification,query,converter)
    if not query or query == "" then
        report_state("no valid query")
        return { }, { }
    end
    local id = specification.id
    local session, connection
    if id then
        local c = cache[id]
        if c then
            session    = c.session
            connection = c.connection
        end
        if not connection then
            session = initialize()
            connection = connect(session,specification)
            if not connection then
                for i=1,nofretries do
                    sleep(retrydelay)
                    report_state("retrying to connect: [%s.%s] %s@%s to %s:%s",
                            id,i,
                            specification.database or "no database",
                            specification.username or "no username",
                            specification.host     or "no host",
                            specification.port     or "no port"
                        )
                    connection = connect(session,specification)
                    if connection then
                        break
                    end
                end
            end
            if connection then
                cache[id] = { session = session, connection = connection }
            end
        end
    else
        session = initialize()
        connection = connect(session,specification)
        if not connection then
            for i=1,nofretries do
                sleep(retrydelay)
                report_state("retrying to connect: [%s] %s@%s to %s:%s",
                        i,
                        specification.database or "no database",
                        specification.username or "no username",
                        specification.host     or "no host",
                        specification.port     or "no port"
                    )
                connection = connect(session,specification)
                if connection then
                    break
                end
            end
        end
    end
    if not connection then
        report_state("error in connection: %s@%s to %s:%s",
                specification.database or "no database",
                specification.username or "no username",
                specification.host     or "no host",
                specification.port     or "no port"
            )
        return { }, { }
    end
    query = lpegmatch(querysplitter,query)
    local result, message, okay
    for i=1,#query do
        local q = query[i]
        local r, m = connection:execute(q)
        if m then
            report_state("error in query, stage: %s",string.collapsespaces(q or "?"))
            message = message and format("%s\n%s",message,m) or m
        end
        if type(r) == "table" then
            result = r
            okay = true
        elseif not m  then
            okay = true
        end
    end
    local data, keys
    if result then
        if converter then
            data = converter.ffi(result)
        else
            keys = result.names
            data = { }
            for i=1,result.nofrows do
                data[i] = result:hash()
            end
        end
        result:finish() -- result:close()
    elseif message then
        report_state("message %s",message)
    end
    if not keys then
        keys = { }
    end
    if not data then
        data = { }
    end
    if not id then
        connection:close()
        session:close()
    end
    return data, keys
end

local function execute(specification)
    if trace_sql then
        report_state("executing library")
    end
    if not validspecification(specification) then
        report_state("error in specification")
        return
    end
    local query = dataprepared(specification)
    if not query then
        report_state("error in preparation")
        return
    end
    local data, keys = datafetched(specification,query,specification.converter)
    if not data then
        report_state("error in fetching")
        return
    end
    local one = data[1]
    if one then
        setmetatable(data,{ __index = one } )
    end
    return data, keys
end

local wraptemplate = [[
local mysql           = ffi.load(os.name == "windows" and "libmysql" or "libmysqlclient")

local mysql_fetch_row = mysql.mysql_fetch_row
local ffi_tostring    = ffi.string

local converters      = utilities.sql.converters
local deserialize     = utilities.sql.deserialize

local tostring        = tostring
local tonumber        = tonumber
local booleanstring   = string.booleanstring

%s

return function(result)
    if not result then
        return { }
    end
    local nofrows = result.nofrows or 0
    if nofrows == 0 then
        return { }
    end
    local noffields = result.noffields or 0
    local _result_  = result._result_
    local target    = { } -- no %s needed here
    for i=1,nofrows do
        local cells = { }
        local row   = mysql_fetch_row(_result_)
        for j=1,noffields do
            cells[j] = ffi_tostring(row[j-1])
        end
        target[%s] = {
            %s
        }
    end
    result:finish() -- result:close()
    return target
end
]]

local celltemplate = "cells[%s]"

methods.ffi = {
    runner       = function() end, -- never called
    execute      = execute,
    initialize   = initialize, -- returns session
    usesfiles    = false,
    wraptemplate = wraptemplate,
    celltemplate = celltemplate,
}
