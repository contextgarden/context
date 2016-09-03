if not modules then modules = { } end modules ['util-sql-imp-sqlite'] = {
    version   = 1.001,
    comment   = "companion to util-sql.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: make a converter

require("util-sql")

local trace_sql          = false  trackers.register("sql.trace",  function(v) trace_sql     = v end)
local trace_queries      = false  trackers.register("sql.queries",function(v) trace_queries = v end)
local report_state       = logs.reporter("sql","sqlite")

local sql                = utilities.sql
local helpers            = sql.helpers
local methods            = sql.methods
local validspecification = helpers.validspecification
local preparetemplate    = helpers.preparetemplate
local splitdata          = helpers.splitdata
local replacetemplate    = utilities.templates.replace
local serialize          = sql.serialize
local deserialize        = sql.deserialize
local getserver          = sql.getserver

local sqlite             = require("swiglib.sqlite.core")
local swighelpers        = require("swiglib.helpers.core")

-- inspect(table.sortedkeys(sqlite))

local get_list_item      = sqlite.char_p_array_getitem
local is_okay            = sqlite.SQLITE_OK
local execute_query      = sqlite.sqlite3_exec_lua_callback
local error_message      = sqlite.sqlite3_errmsg

local new_db             = sqlite.new_sqlite3_p_array
local open_db            = sqlite.sqlite3_open
local get_db             = sqlite.sqlite3_p_array_getitem
local close_db           = sqlite.sqlite3_close
local dispose_db         = sqlite.delete_sqlite3_p_array

local setmetatable       = setmetatable
local formatters         = string.formatters

local cache              = { }

setmetatable(cache, {
    __gc = function(t)
        for k, v in next, t do
            if trace_sql then
                report_state("closing session %a",k)
            end
            close_db(v.dbh)
            dispose_db(v.db)
        end
    end
})

-- synchronous  journal_mode  locking_mode    1000 logger inserts
--
-- normal       normal        normal          6.8
-- off          off           normal          0.1
-- normal       off           normal          2.1
-- normal       persist       normal          5.8
-- normal       truncate      normal          4.2
-- normal       truncate      exclusive       4.1

local f_preamble = formatters[ [[
ATTACH `%s` AS `%s` ;
PRAGMA `%s`.synchronous = normal ;
PRAGMA journal_mode = truncate ;
]] ]

local function execute(specification)
    if trace_sql then
        report_state("executing sqlite")
    end
    if not validspecification(specification) then
        report_state("error in specification")
    end
    local query = preparetemplate(specification)
    if not query then
        report_state("error in preparation")
        return
    end
    local base = specification.database -- or specification.presets and specification.presets.database
    if not base then
        report_state("no database specified")
        return
    end
    local filename = file.addsuffix(base,"db")
    local result   = { }
    local keys     = { }
    local id       = specification.id
    local db       = nil
    local dbh      = nil
    local okay     = false
    local preamble = nil
    if id then
        local session = cache[id]
        if session then
            dbh  = session.dbh
            okay = is_okay
        else
            db       = new_db(1)
            okay     = open_db(filename,db)
            dbh      = get_db(db,0)
            preamble = f_preamble(filename,base,base)
            if okay ~= is_okay then
                report_state("no session database specified")
            else
                cache[id] = {
                    name = filename,
                    db   = db,
                    dbh  = dbh,
                }
            end
        end
    else
        db       = new_db(1)
        okay     = open_db(filename,db)
        dbh      = get_db(db,0)
        preamble = f_preamble(filename,base,base)
    end
    if okay ~= is_okay then
        report_state("no database opened")
    else
        local keysdone = false
        local nofrows  = 0
        local callback   = function(data,nofcolumns,values,fields)
            local column = { }
            for i=0,nofcolumns-1 do
                local field
                if keysdone then
                    field = keys[i+1]
                else
                    field = get_list_item(fields,i)
                    keys[i+1] = field
                end
                column[field] = get_list_item(values,i)
            end
            nofrows  = nofrows + 1
            keysdone = true
            result[nofrows] = column
            return is_okay
        end
        if preamble then
            query = preamble .. query -- only needed in open
        end
        local okay = execute_query(dbh,query,callback,nil,nil)
        if okay ~= is_okay then
            report_state("error: %s",error_message(dbh))
        end

    end
    if not id then
        close_db(dbh)
        dispose_db(db)
    end
    return result, keys
end

local wraptemplate = [[
local converters    = utilities.sql.converters
local deserialize   = utilities.sql.deserialize

local tostring      = tostring
local tonumber      = tonumber
local booleanstring = string.booleanstring

%s

return function(data)
    local target = %s -- data or { }
    for i=1,#data do
        local cells = data[i]
        target[%s] = {
            %s
        }
    end
    return target
end
]]

local celltemplate = "cells[%s]"

methods.sqlite = {
    execute      = execute,
    usesfiles    = false,
    wraptemplate = wraptemplate,
    celltemplate = celltemplate,
}
