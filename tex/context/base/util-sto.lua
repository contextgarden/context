if not modules then modules = { } end modules ['util-sto'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local setmetatable, getmetatable, type = setmetatable, getmetatable, type

utilities         = utilities or { }
utilities.storage = utilities.storage or { }
local storage     = utilities.storage

function storage.mark(t)
    if not t then
        print("\nfatal error: storage cannot be marked\n")
        os.exit()
        return
    end
    local m = getmetatable(t)
    if not m then
        m = { }
        setmetatable(t,m)
    end
    m.__storage__ = true
    return t
end

function storage.allocate(t)
    t = t or { }
    local m = getmetatable(t)
    if not m then
        m = { }
        setmetatable(t,m)
    end
    m.__storage__ = true
    return t
end

function storage.marked(t)
    local m = getmetatable(t)
    return m and m.__storage__
end

function storage.checked(t)
    if not t then
        report("\nfatal error: storage has not been allocated\n")
        os.exit()
        return
    end
    return t
end

-- function utilities.storage.delay(parent,name,filename)
--     local m = getmetatable(parent)
--     m.__list[name] = filename
-- end
--
-- function utilities.storage.predefine(parent)
--     local list = { }
--     local m = getmetatable(parent) or {
--         __list = list,
--         __index = function(t,k)
--             local l = require(list[k])
--             t[k] = l
--             return l
--         end
--     }
--     setmetatable(parent,m)
-- end
--
-- bla = { }
-- utilities.storage.predefine(bla)
-- utilities.storage.delay(bla,"test","oepsoeps")
-- local t = bla.test
-- table.print(t)
-- print(t.a)

function storage.setinitializer(data,initialize)
    local m = getmetatable(data) or { }
    m.__index = function(data,k)
        m.__index = nil -- so that we can access the entries during initializing
        initialize()
        return data[k]
    end
    setmetatable(data, m)
end

local keyisvalue = { __index = function(t,k)
    t[k] = k
    return k
end }

function storage.sparse(t)
    t = t or { }
    setmetatable(t,keyisvalue)
    return t
end

-- table namespace ?

local function f_empty ()                           return "" end -- t,k
local function f_self  (t,k) t[k] = k               return k  end
local function f_table (t,k) local v = { } t[k] = v return v  end
local function f_number(t,k) t[k] = 0               return 0  end -- t,k,v
local function f_ignore()                                     end -- t,k,v

local f_index = {
    ["empty"]  = f_empty,
    ["self"]   = f_self,
    ["table"]  = f_table,
    ["number"] = f_number,
}

function table.setmetatableindex(t,f)
    if type(t) ~= "table" then
        f, t = t, { }
    end
    local m = getmetatable(t)
    local i = f_index[f] or f
    if m then
        m.__index = i
    else
        setmetatable(t,{ __index = i })
    end
    return t
end

local f_index = {
    ["ignore"] = f_ignore,
}

function table.setmetatablenewindex(t,f)
    if type(t) ~= "table" then
        f, t = t, { }
    end
    local m = getmetatable(t)
    local i = f_index[f] or f
    if m then
        m.__newindex = i
    else
        setmetatable(t,{ __newindex = i })
    end
    return t
end

function table.setmetatablecall(t,f)
    if type(t) ~= "table" then
        f, t = t, { }
    end
    local m = getmetatable(t)
    if m then
        m.__call = f
    else
        setmetatable(t,{ __call = f })
    end
    return t
end

function table.setmetatablekey(t,key,value)
    local m = getmetatable(t)
    if not m then
        m = { }
        setmetatable(t,m)
    end
    m[key] = value
    return t
end

function table.getmetatablekey(t,key,value)
    local m = getmetatable(t)
    return m and m[key]
end
