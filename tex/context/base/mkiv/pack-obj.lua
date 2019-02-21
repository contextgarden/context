if not modules then modules = { } end modules ['pack-obj'] = {
    version   = 1.001,
    comment   = "companion to pack-obj.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>We save object references in the main utility table. jobobjects are
reusable components.</p>
--ldx]]--

local context         = context
local codeinjections  = backends.codeinjections
local ctx_doifelse    = commands.doifelse

local report          = logs.reporter("objects")
local trace           = false  trackers.register("objects",function(v) trace = v end)

local nuts            = nodes.nuts

local setlink         = nuts.setlink
local getlist         = nuts.getlist
local setbox          = nuts.setbox

local new_latelua     = nuts.pool.latelua

local settexdimen     = tokens.setters.dimen

local getcount        = tex.getcount

local implement       = interfaces.implement
local setmacro        = interfaces.setmacro

local allocate        = utilities.storage.allocate

local collected       = allocate()
local tobesaved       = allocate()

local jobobjects      = {
    collected = collected,
    tobesaved = tobesaved,
}

job.objects           = jobobjects

local function initializer()
    collected = jobobjects.collected
    tobesaved = jobobjects.tobesaved
end

job.register('job.objects.collected', tobesaved, initializer, nil)

local function saveobject(tag,number,page)
    local data = { number, page }
    tobesaved[tag] = data
    collected[tag] = data
end

local function saveobjectspec(specification)
    local tag  = specification.tag
    local data = { specification.number, specification.page }
    tobesaved[tag] = data
    collected[tag] = data
end

local function setobject(tag,number,page)
    collected[tag] = { number, page }
end

local function getobject(tag)
    return collected[tag] or tobesaved[tag]
end

local function getobjectnumber(tag,default)
    local o = collected[tag] or tobesaved[tag]
    return o and o[1] or default
end

local function getobjectpage(tag,default)
    local o = collected[tag] or tobesaved[tag]
    return o and o[2] or default
end

jobobjects.save   = saveobject
jobobjects.set    = setobject
jobobjects.get    = getobject
jobobjects.number = getobjectnumber
jobobjects.page   = getobjectpage

-- implement {
--     name      = "saveobject",
--     actions   = saveobject
-- }
--
-- implement {
--     name      = "setobject",
--     actions   = setobject,
--     arguments = { "string", "integer", "integer" }
-- }
--
-- implement {
--     name      = "objectnumber",
--     actions   = { getobjectnumber, context },
--     arguments = "2 strings",
-- }
--
-- implement {
--     name      = "objectpage",
--     actions   = { getobjectpage, context },
--     arguments = "2 strings",
-- }
--
-- implement {
--     name      = "doifelseobjectreferencefound",
--     actions   = { getobject, commands.doifelse },
--     arguments = "string"
-- }

-- if false then
--     -- we can flush the inline ref ourselves now if we want
--     local flush = new_latelua("pdf.flushxform("..index..")")
--     flush.next = list
--     next.prev = flush
-- end

local data = table.setmetatableindex("table")

objects = {
    data = data,
    n    = 0,
}

local objects = objects

function objects.register(ns,id,b,referenced,offset,mode)
    local n = objects.n + 1
    objects.n = n
    nodes.handlers.finalizebox(b)
    if mode == 0 then
        -- tex
        data[ns][id] = {
            codeinjections.registerboxresource(b), -- a box number
            offset,
            referenced or false,
            mode,
        }
    else
        -- box (backend)
        data[ns][id] = {
            codeinjections.registerboxresource(b,offset), -- a box number
            false,
            referenced,
            mode,
        }
    end
    if trace then
        report("registering object %a (n=%i)",id,n)
    end
end

function objects.restore(ns,id) -- why not just pass a box number here too (ok, we also set offset)
    local d = data[ns][id]
    if d then
        local index  = d[1]
        local offset = d[2]
        local status = d[3]
        local mode   = d[4]
        local hbox   = codeinjections.restoreboxresource(index) -- a nut !
        if status then
            local list = getlist(hbox)
            local page = new_latelua {
                action = saveobjectspec,
                tag    = ns .. "::" .. id,
                number = index,
                page   = getcount("realpageno"),
            }
            setlink(list,page)
        end
        setbox("objectbox",hbox)
        settexdimen("objectoff",offset or 0)
    else
        setbox("objectbox",nil)
        settexdimen("objectoff",0) -- for good old times
    end
    if trace then
        report("restoring object %a",id)
    end
end

function objects.dimensions(index)
    local d = data[ns][id]
    if d then
        return codeinjections.boxresourcedimensions(d[1])
    else
        return 0, 0, 0, 0
    end
end

function objects.reference(ns,id)
    local d = data[ns][id]
    if d then
        return d[1]
    else
        return getobjectnumber(ns .."::" .. id,0)
    end
end

function objects.page(ns,id)
    return getobjectpage(ns .."::" .. id,getcount("realpageno"))
end

function objects.found(ns,id)
    return data[ns][id]
end

implement {
    name      = "registerreferencedobject",
    arguments = { "string", "string", "integer", true, "dimension", "integer" },
    actions   = objects.register,
}

implement {
    name      = "registerobject",
    arguments = { "string", "string", "integer", false, "dimension", "integer" },
    actions   = objects.register,
}

implement {
    name      = "restoreobject",
    arguments = "2 strings",
    actions   = objects.restore,
}

implement {
    name      = "doifelseobject",
    arguments = "2 strings",
    actions   = function(ns,id)
        ctx_doifelse(data[ns][id])
     -- ctx_doifelse(objects.reference(ns,id))
    end,
}

implement {
    name      = "doifelseobjectreference",
    arguments = "2 strings",
    actions   = function(ns,id)
     -- ctx_doifelse(data[ns][id])
        ctx_doifelse(objects.reference(ns,id))
    end,
}

implement {
    name      = "getobjectreference",
    arguments = { "string", "string", "csname" },
    actions   = function(ns,id,target)
        setmacro(target,objects.reference(ns,id),"global")
    end
}

implement {
    name      = "getobjectreferencepage",
    arguments = { "string", "string", "csname" },
    actions   = function(ns,id,target)
        setmacro(target,objects.page(ns,id),"global")
    end
}

implement {
    name      = "getobjectdimensions",
    arguments = "2 strings",
    actions   = function(ns,id)
        local object = data[ns][id]
        local w, h, d, o = 0, 0, 0, 0
        if object then
            w, h, d, o = codeinjections.boxresourcedimensions(object[1])
        end
        settexdimen("objectwd",w or 0)
        settexdimen("objectht",h or 0)
        settexdimen("objectdp",d or 0)
        settexdimen("objectoff",o or #objects > 2 and object[2] or 0)
    end
}

-- for the moment here:

implement {
    name      = "registerbackendsymbol",
    arguments = { "string", "integer" },
    actions   = function(...)
        codeinjections.registersymbol(...)
    end
}
