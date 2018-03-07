if not modules then modules = { } end modules ['util-sql-logins'] = {
    version   = 1.001,
    comment   = "companion to lmx-*",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not utilities.sql then require("util-sql") end

local sql              = utilities.sql
local sqlexecute       = sql.execute
local sqlmakeconverter = sql.makeconverter

local format = string.format
local ostime = os.time
local formatter = string.formatter

local trace_logins  = true
local report_logins = logs.reporter("sql","logins")

local logins = sql.logins or { }
sql.logins   = logins

logins.maxnoflogins = logins.maxnoflogins or 10
logins.cooldowntime = logins.cooldowntime or 10 * 60
logins.purgetime    = logins.purgetime    or  1 * 60 * 60
logins.autopurge    = true

local template_create = [[
CREATE TABLE
    `logins`
    (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `name` varchar(50) COLLATE utf8_bin NOT NULL,
        `time` int(11) DEFAULT '0',
        `n` int(11) DEFAULT '0',
        `state` int(11) DEFAULT '0',
        PRIMARY KEY (`id`),
        UNIQUE KEY `id_UNIQUE` (`id`),
        UNIQUE KEY `name_UNIQUE` (`name`)
    )
    ENGINE=InnoDB
    DEFAULT CHARSET=utf8
    COLLATE=utf8_bin
    COMMENT='state: 0=unset 1=known 2=unknown'
]]

local states = {
    [0] = "unset",
    [1] = "known",
    [2] = "unknown",
}

local converter_fetch, fields_fetch = sqlmakeconverter {
    { name = "id",    type = "number" },
    { name = "name",  type = "string" },
    { name = "time",  type = "number" },
    { name = "n",     type = "number" },
    { name = "state", type = "number" }, -- faster than mapping
}

local template_fetch = format( [[
    SELECT
      %s
    FROM
        `logins`
    WHERE
        `name` = '%%[name]%%'
]], fields_fetch )

local template_insert = [[
    INSERT INTO `logins`
        ( `name`, `state`, `time`, `n`)
    VALUES
        ('%[name]%', %state%, %time%, %n%)
]]

local template_update = [[
    UPDATE
        `logins`
    SET
        `state` = %state%,
        `time` = %time%,
        `n` = %n%
    WHERE
        `name` = '%[name]%'
]]

local template_delete = [[
    DELETE FROM
        `logins`
    WHERE
        `name` = '%[name]%'
]]

local template_purge = [[
    DELETE FROM
        `logins`
    WHERE
        `time` < '%time%'
]]

-- todo: auto cleanup (when new attempt)

local cache = { } setmetatable(cache, { __mode = 'v' })

local function usercreate(presets)
    sqlexecute {
        template = template_create,
        presets  = presets,
    }
end

local function userunknown(presets,name)
    local d = {
        name  = name,
        state = 2,
        time  = ostime(),
        n     = 0,
    }
    sqlexecute {
        template  = template_update,
        presets   = presets,
        variables = d,
    }
    cache[name] = d
    report_logins("user %a is registered as unknown",name)
end

local function userknown(presets,name)
    local d = {
        name  = name,
        state = 1,
        time  = ostime(),
        n     = 0,
    }
    sqlexecute {
        template  = template_update,
        presets   = presets,
        variables = d,
    }
    cache[name] = d
    report_logins("user %a is registered as known",name)
end

local function userreset(presets,name)
    sqlexecute {
        template  = template_delete,
        presets   = presets,
    }
    cache[name] = nil
    report_logins("user %a is reset",name)
end

local function userpurge(presets,delay)
    sqlexecute {
        template  = template_purge,
        presets   = presets,
        variables = {
            time  = ostime() - (delay or logins.purgetime),
        }
    }
    cache = { }
    report_logins("users are purged")
end

local function verdict(okay,...)
    if not trace_logins then
        -- no tracing
    elseif okay then
        report_logins("%s, granted",formatter(...))
    else
        report_logins("%s, blocked",formatter(...))
    end
    return okay
end

local lasttime  = 0

local function userpermitted(presets,name)
    local currenttime = ostime()
    if logins.autopurge and (lasttime == 0 or (currenttime - lasttime > logins.purgetime)) then
        report_logins("automatic purge triggered")
        userpurge(presets)
        lasttime = currenttime
    end
    local data = cache[name]
    if data then
        report_logins("user %a is cached",name)
    else
        report_logins("user %a is fetched",name)
        data = sqlexecute {
            template  = template_fetch,
            presets   = presets,
            converter = converter_fetch,
            variables = {
                name = name,
            }
        }
    end
    if not data or not data.name then
        local d = {
            name  = name,
            state = 0,
            time  = currenttime,
            n     = 1,
        }
        sqlexecute {
            template  = template_insert,
            presets   = presets,
            variables = d,
        }
        cache[name] = d
        return verdict(true,"creating new entry for %a",name)
    end
    cache[name] = data[1]
    local state = data.state
    if state == 2 then -- unknown
        return verdict(false,"user %a has state %a",name,states[state])
    end
    local n = data.n
    local m = logins.maxnoflogins
    if n > m then
        local deltatime = currenttime - data.time
        local cooldowntime = logins.cooldowntime
        if deltatime < cooldowntime then
            return verdict(false,"user %a is blocked for %s seconds out of %s",name,cooldowntime-deltatime,cooldowntime)
        else
            n = 0
        end
    end
    if n == 0 then
        local d = {
            name  = name,
            state = 0,
            time  = currenttime,
            n     = 1,
        }
        sqlexecute {
            template  = template_update,
            presets   = presets,
            variables = d,
        }
        cache[name] = d
        return verdict(true,"user %a gets a first chance",name)
    else
        local d = {
            name  = name,
            state = 0,
            time  = currenttime,
            n     = n + 1,
        }
        sqlexecute {
            template  = template_update,
            presets   = presets,
            variables = d,
        }
        cache[name] = d
        return verdict(true,"user %a gets a new chance, %s attempts out of %s done",name,n,m)
    end
end

logins.create    = usercreate
logins.known     = userknown
logins.unknown   = userunknown
logins.reset     = userreset
logins.purge     = userpurge
logins.permitted = userpermitted

return logins

-- --

-- sql.setmethod("client")

-- local presets = {
--     database = "test",
--     username = "root",
--     password = "something",
-- }

-- logins.cooldowntime = 2*60
-- logins.maxnoflogins = 3

-- sql.logins.purge(presets,0)

-- for i=1,6 do
--     print("")
--     sql.logins.permitted(presets,"hans")
--     sql.logins.permitted(presets,"kees")
--     sql.logins.permitted(presets,"ton")
--     if i == 1 then
--      -- sql.logins.unknown(presets,"hans")
--      -- sql.logins.known(presets,"kees")
--     end
-- end

-- if loginpermitted(presets,username) then
--     if validlogin(username,...) then
--      -- sql.logins.known(presets,username)
--     elseif unknownuser(username) then
--         sql.logins.unknown(presets,username)
--     end
-- end

