if not modules then modules = { } end modules ['libs-imp-mysql'] = {
    version   = 1.001,
    comment   = "companion to util-sql.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- c:/data/develop/tex-context/tex/texmf-win64/bin/lib/luametatex/lua/copies/mysql/libmysql.dll

local libname = "mysql"
local libfile = "libmysql"

local mysqllib = resolvers.libraries.validoptional(libname)

if not mysqllib then return end

local function okay()
    if resolvers.libraries.optionalloaded(libname,libfile) then
        okay = function() return true end
    else
        okay = function() return false end
    end
    return okay()
end

local lpegmatch = lpeg.match
local setmetatable = setmetatable

local sql                = utilities.sql or require("util-sql")
local report             = logs.reporter(libname)

local trace_sql          = false  trackers.register("sql.trace",  function(v) trace_sql     = v end)
local trace_queries      = false  trackers.register("sql.queries",function(v) trace_queries = v end)

local mysql_open         = mysqllib.open
local mysql_close        = mysqllib.close
local mysql_execute      = mysqllib.execute
local mysql_getmessage   = mysqllib.getmessage

local helpers            = sql.helpers
local methods            = sql.methods
local validspecification = helpers.validspecification
local preparetemplate    = helpers.preparetemplate
local querysplitter      = helpers.querysplitter
local cache              = { }

local function connect(specification)
    return mysql_open(
        specification.database or "",
        specification.username or "",
        specification.password or "",
        specification.host     or "",
        specification.port
    )
end

local function execute_once(specification,retry)
    if okay() then
        if trace_sql then
            report("executing mysql")
        end
        if not validspecification(specification) then
            report("error in specification")
        end
        local query = preparetemplate(specification)
        if not query then
            report("error in preparation")
            return
        else
            query = lpegmatch(querysplitter,query)
        end
        local base = specification.database -- or specification.presets and specification.presets.database
        if not base then
            report("no database specified")
            return
        end
        local result = { }
        local keys   = { }
        local id     = specification.id
        local db     = nil
        if id then
            local session = cache[id]
            if session then
                db = session.db
            else
                db = connect(specification)
                if not db then
                    report("no session database specified")
                else
                    cache[id] = {
                        specification = specification,
                        db            = db,
                    }
                end
            end
        else
            db = connect(specification)
        end
        if not db then
            report("no database opened")
        else
            local converter = specification.converter
            local nofrows   = 0
            local callback  = nil
            if converter then
                local convert = converter.mysql
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
            for i=1,#query do
                local okay = mysql_execute(db,query[i],callback)
                if not okay then
                    if id and option == "retry" and i == 1 then
                        report("error: %s, retrying to connect",mysql_getmessage(db))
                        mysql_close(db)
                        cache[id] = nil
                        return execute_once(specification,false)
                    else
                        report("error: %s",mysql_getmessage(db))
                    end
                end
            end
        end
        if db and not id then
            mysql_close(db)
        end
        -- bonus
        local one = result[1]
        if one then
            setmetatable(result,{ __index = one } )
        end
        --
        return result, keys
    else
        report("error: ","no library loaded")
    end
end

local function execute(specification)
    return execute_once(specification,true)
end

-- Here we build the dataset stepwise so we don't use the data hack that
-- is used in the client variant.

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

methods.mysql = {
    execute      = execute,
    usesfiles    = false,
    wraptemplate = wraptemplate,
    celltemplate = celltemplate,
}

package.loaded["util-sql-imp-mysql"] = methods.mysql
package.loaded[libname]              = methods.mysql
