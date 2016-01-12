if not modules then modules = { } end modules ['util-sql-users'] = {
    version   = 1.001,
    comment   = "companion to lmx-*",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is experimental code and currently part of the base installation simply
-- because it's easier to dirtribute this way. Eventually it will be documented
-- and the related scripts will show up as well.

-- local sql = sql or (utilities and utilities.sql) or require("util-sql")
-- local md5 = md5  or require("md5")

local sql = utilities.sql

local format, upper, find, gsub, topattern = string.format, string.upper, string.find, string.gsub, string.topattern
local sumhexa = md5.sumhexa
local toboolean = string.toboolean

local sql   = utilities.sql
local users = { }
sql.users   = users

local trace_sql = false  trackers.register("sql.users.trace", function(v) trace_sql = v end)
local report    = logs.reporter("sql","users")

local function encryptpassword(str)
    if not str or str == "" then
        return ""
    elseif find(str,"^MD5:") then
        return str
    else
        return upper(format("MD5:%s",sumhexa(str)))
    end
end

local function cleanuppassword(str)
    return (gsub(str,"^MD5:",""))
end

local function samepasswords(one,two)
    if not one or not two then
        return false
    end
    if not find(one,"^MD5:") then
        one = encryptpassword(one)
    end
    if not find(two,"^MD5:") then
        two = encryptpassword(two)
    end
    return one == two
end

local function validaddress(address,addresses)
    if address and addresses and address ~= "" and addresses ~= "" then
        if find(address,topattern(addresses,true,true)) then
            return true, "valid remote address"
        end
        return false, "invalid remote address"
    else
        return true, "no remote address check"
    end
end


users.encryptpassword = encryptpassword
users.cleanuppassword = cleanuppassword
users.samepasswords   = samepasswords
users.validaddress    = validaddress

-- print(users.encryptpassword("test")) -- MD5:098F6BCD4621D373CADE4E832627B4F6

local function checkeddb(presets,datatable)
    return sql.usedatabase(presets,datatable or presets.datatable or "users")
end

users.usedb = checkeddb

local groupnames   = { }
local groupnumbers = { }

local function registergroup(name)
    local n = #groupnames + 1
    groupnames  [n]           = name
    groupnames  [tostring(n)] = name
    groupnames  [name]        = name
    groupnumbers[n]           = n
    groupnumbers[tostring(n)] = n
    groupnumbers[name]        = n
    return n
end

registergroup("superuser")
registergroup("administrator")
registergroup("user")
registergroup("guest")

users.groupnames   = groupnames
users.groupnumbers = groupnumbers

-- password 'test':
--
-- INSERT insert into users (`name`,`password`,`group`,`enabled`) values ('...','MD5:098F6BCD4621D373CADE4E832627B4F6',1,1) ;

local template =[[
    CREATE TABLE `users` (
        `id`       int(11)      NOT NULL AUTO_INCREMENT,
        `name`     varchar(80)  NOT NULL,
        `fullname` varchar(80)  NOT NULL,
        `password` varchar(50)  DEFAULT NULL,
        `group`    int(11)      NOT NULL,
        `enabled`  int(11)      DEFAULT '1',
        `email`    varchar(80)  DEFAULT NULL,
        `address`  varchar(256) DEFAULT NULL,
        `theme`    varchar(50)  DEFAULT NULL,
        `data`     longtext,
        PRIMARY KEY (`id`),
        UNIQUE KEY `name_unique` (`name`)
    ) DEFAULT CHARSET = utf8 ;
]]

local converter, fields = sql.makeconverter {
    { name = "id",       type = "number"      },
    { name = "name",     type = "string"      },
    { name = "fullname", type = "string"      },
    { name = "password", type = "string"      },
    { name = "group",    type = groupnames    },
    { name = "enabled",  type = "boolean"     },
    { name = "email",    type = "string"      },
    { name = "address",  type = "string"      },
    { name = "theme",    type = "string"      },
    { name = "data",     type = "deserialize" },
}

function users.createdb(presets,datatable)

    local db = checkeddb(presets,datatable)

    db.execute {
        template  = template,
        variables = {
            basename = db.basename,
        },
    }

    report("datatable %a created in %a",db.name,db.base)

    return db

end

local template =[[
    SELECT
        %fields%
    FROM
        %basename%
    WHERE
        `name` = '%[name]%'
    AND
        `password` = '%[password]%'
    ;
]]

local template =[[
    SELECT
        %fields%
    FROM
        %basename%
    WHERE
        `name` = '%[name]%'
    ;
]]

function users.valid(db,username,password,address)

    local data = db.execute {
        template  = template,
        converter = converter,
        variables = {
            basename = db.basename,
            fields   = fields,
            name     = username,
        },
    }

    local data = data and data[1]

    if not data then
        return false, "unknown user"
    elseif not data.enabled then
        return false, "disabled user"
    elseif data.password ~= encryptpassword(password) then
        return false, "wrong password"
    elseif not validaddress(address,data.address) then
        return false, "invalid address"
    else
        data.password = nil
        return data, "okay"
    end

end

local template =[[
    INSERT INTO %basename% (
        `name`,
        `fullname`,
        `password`,
        `group`,
        `enabled`,
        `email`,
        `address`,
        `theme`,
        `data`
    ) VALUES (
        '%[name]%',
        '%[fullname]%',
        '%[password]%',
        '%[group]%',
        '%[enabled]%',
        '%[email]%',
        '%[address]%',
        '%[theme]%',
        '%[data]%'
    ) ;
]]

function users.add(db,specification)

    local name = specification.username or specification.name

    if not name or name == "" then
        return
    end

    local data = specification.data

    db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            name     = name,
            fullname = name or fullname,
            password = encryptpassword(specification.password or ""),
            group    = groupnumbers[specification.group] or groupnumbers.guest,
            enabled  = toboolean(specification.enabled) and "1" or "0",
            email    = specification.email,
            address  = specification.address,
            theme    = specification.theme,
            data     = type(data) == "table" and db.serialize(data,"return") or "",
        },
    }

end

local template =[[
    SELECT
        %fields%
    FROM
        %basename%
    WHERE
        `name` = '%[name]%' ;
]]

function users.getbyname(db,name)

    local data = db.execute {
        template  = template,
        converter = converter,
        variables = {
            basename = db.basename,
            fields   = fields,
            name     = name,
        },
    }

    return data and data[1] or nil

end

local template =[[
    SELECT
        %fields%
    FROM
        %basename%
    WHERE
        `id` = '%id%' ;
]]

local function getbyid(db,id)

    local data = db.execute {
        template  = template,
        converter = converter,
        variables = {
            basename = db.basename,
            fields   = fields,
            id       = id,
        },
    }

    return data and data[1] or nil

end

users.getbyid = getbyid

local template =[[
    UPDATE
        %basename%
    SET
        `fullname` = '%[fullname]%',
        `password` = '%[password]%',
        `group`    = '%[group]%',
        `enabled`  = '%[enabled]%',
        `email`    = '%[email]%',
        `address`  = '%[address]%',
        `theme`    = '%[theme]%',
        `data`     = '%[data]%'
    WHERE
        `id` = '%id%'
    ;
]]

function users.save(db,id,specification)

    id = tonumber(id)

    if not id then
        return
    end

    local user = getbyid(db,id)

    if tonumber(user.id) ~= id then
        return
    end

    local fullname = specification.fullname == nil and user.fulname   or specification.fullname
    local password = specification.password == nil and user.password  or specification.password
    local group    = specification.group    == nil and user.group     or specification.group
    local enabled  = specification.enabled  == nil and user.enabled   or specification.enabled
    local email    = specification.email    == nil and user.email     or specification.email
    local address  = specification.address  == nil and user.address   or specification.address
    local theme    = specification.theme    == nil and user.theme     or specification.theme
    local data     = specification.data     == nil and user.data      or specification.data

    db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            id       = id,
            fullname = fullname,
            password = encryptpassword(password),
            group    = groupnumbers[group],
            enabled  = toboolean(enabled) and "1" or "0",
            email    = email,
            address  = address,
            theme    = theme,
            data     = type(data) == "table" and db.serialize(data,"return") or "",
        },
    }

    return getbyid(db,id)

end

local template =[[
    DELETE FROM
        %basename%
    WHERE
        `id` = '%id%' ;
]]

function users.remove(db,id)

    db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            id       = id,
        },
    }

end

local template =[[
    SELECT
        %fields%
    FROM
        %basename%
    ORDER BY
        `name` ;
]]

function users.collect(db) -- maybe also an id/name only variant

    local records, keys = db.execute {
        template  = template,
        converter = converter,
        variables = {
            basename = db.basename,
            fields   = fields,
        },
    }

    return records, keys

end
