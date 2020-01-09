if not modules then modules = { } end modules ['libs-imp-sqlite'] = {
    version   = 1.001,
    comment   = "companion to util-sql.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- c:/data/develop/tex-context/tex/texmf-win64/bin/lib/luametatex/lua/copies/sqlite/sqlite3.dll

local libname = "sqlite"
local libfile = "sqlite3"

local sqlitelib = resolvers.libraries.validoptional(libname)

if not sqlitelib then return end

local function okay()
    if resolvers.libraries.optionalloaded(libname,libfile) then
        okay = function() return true end
    else
        okay = function() return false end
    end
    return okay()
end

local next, tonumber = next, tonumber
local setmetatable = setmetatable
local formatters = string.formatters

local sql                = utilities.sql or require("util-sql")
local report             = logs.reporter(libname)

local trace_sql          = false  trackers.register("sql.trace",  function(v) trace_sql     = v end)
local trace_queries      = false  trackers.register("sql.queries",function(v) trace_queries = v end)

local sqlite_open        = sqlitelib.open
local sqlite_close       = sqlitelib.close
local sqlite_execute     = sqlitelib.execute
local sqlite_getmessage  = sqlitelib.getmessage

local helpers            = sql.helpers
local methods            = sql.methods
local validspecification = helpers.validspecification
local preparetemplate    = helpers.preparetemplate
local cache              = { }

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
]] ]

local function execute(specification)
    if okay() then
        if trace_sql then
            report("executing sqlite")
        end
        if not validspecification(specification) then
            report("error in specification")
        end
        local query = preparetemplate(specification)
        if not query then
            report("error in preparation")
            return
        end
        local base = specification.database -- or specification.presets and specification.presets.database
        if not base then
            report("no database specified")
            return
        end
        local filename = file.addsuffix(base,"db")
        local result   = { }
        local keys     = { }
        local id       = specification.id
        local db       = nil
        local preamble = nil
        if id then
            local session = cache[id]
            if session then
                db = session.db
            else
                db       = sqlite_open(filename)
                preamble = f_preamble(filename,base,base)
                if not db then
                    report("no session database specified")
                else
                    cache[id] = {
                        name = filename,
                        db   = db,
                    }
                end
            end
        else
            db       = open_db(filename)
            preamble = f_preamble(filename,base,base)
        end
        if not db then
            report("no database opened")
        else
            local converter = specification.converter
            local nofrows   = 0
            local callback  = nil
            if preamble then
                query = preamble .. query -- only needed in open
            end
            if converter then
                local convert = converter.sqlite
                callback = function(nofcolumns,values,fields)
                    nofrows = nofrows + 1
                    result[nofrows] = convert(values)
                end
            else
                local column = { }
                callback = function(nofcolumns,values,fields)
                    for i=1,nofcolumns do
                        local field
                        if fields then
                            field = fields[i]
                            keys[i+1] = field
                        else
                            field = keys[i]
                        end
                        if field then
                            column[field] = values[i]
                        end
                    end
                    nofrows  = nofrows + 1
                    result[nofrows] = column
                end
            end
            local okay = sqlite_execute(db,query,callback)
            if not okay then
                report("error: %s",sqlite_getmessage(db))
         -- elseif converter then
         --     result = converter.sqlite(result)
            end
        end
        if db and not id then
            sqlite_close(db)
        end
        return result, keys
    else
        report("error: ","no library loaded")
    end
end

local wraptemplate = [[
local converters    = utilities.sql.converters
local deserialize   = utilities.sql.deserialize

local tostring      = tostring
local tonumber      = tonumber
local booleanstring = string.booleanstring

%s

return function(cells)
    -- %s (not needed)
    -- %s (not needed)
    return {
        %s
    }
end
]]

local celltemplate = "cells[%s]"

methods.sqlite = {
    execute      = execute,
    usesfiles    = false,
    wraptemplate = wraptemplate,
    celltemplate = celltemplate,
}

package.loaded["util-sql-imp-sqlite"] = methods.sqlite
package.loaded[libname]               = methods.sqlite

return methods.sqlite
