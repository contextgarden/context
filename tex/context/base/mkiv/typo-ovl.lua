if not modules then modules = { } end modules ['typo-ovl'] = {
    version   = 1.001,
    comment   = "companion to typo-ovl.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is dubious code. If you needed it your source is probably bad. We only used
-- in when we had to mark bad content but when cleaning up some project code I decided
-- that it is easier to maintain in the distribution then in a project style. After all,
-- we have hardly any private code. For convenience I hooked it into the existing
-- replacement module (as it used the same code anyway). I did some cleanup.

local next, type = next, type

local context      = context

local nuts         = nodes.nuts
local tonut        = nodes.tonut
local tonode       = nodes.tonode

local nodecodes    = nodes.nodecodes
local glyph_code   = nodecodes.glyph
local disc_code    = nodecodes.disc

local getnext      = nuts.getnext
local getid        = nuts.getid
local getdisc      = nuts.getdisc
local getattr      = nuts.getattr
local setattr      = nuts.setattr
local getattrlist  = nuts.getattrlist
local setattrlist  = nuts.setattrlist
local getfield     = nuts.getfield
local setfont      = nuts.setfont

local nextnode     = nuts.traversers.node

local unsetvalue   = attributes.unsetvalue
local prvattribute = attributes.private

local texgetbox    = tex.getbox
local currentfont  = font.current

local a_overloads  = attributes.private("overloads")
local n_overloads  = 0
local t_overloads  = { }

local overloaded   = { }

local function markasoverload(a)
    local n = prvattribute(a)
    if n then
        overloaded[n] = a
    end
end

attributes.markasoverload = markasoverload

markasoverload("color")
markasoverload("colormodel")
markasoverload("transparency")
markasoverload("case")
markasoverload("negative")
markasoverload("effect")
markasoverload("ruled")
markasoverload("shifted")
markasoverload("kernchars")
markasoverload("kern")
markasoverload("noligature")
markasoverload("viewerlayer")

local function tooverloads(n)
    local current = tonut(n)
    local a = getattrlist(current)
    local s = { }
    while a do
        local n = getfield(a,"number")
        local o = overloaded[n]
        if o then
            local v = getfield(a,"value")
            if v ~= unsetvalue then
                s[n] = v
             -- print(o,n,v)
            end
        end
        a = getnext(a)
    end
    return s
end

attributes.tooverloads = tooverloads

function attributes.applyoverloads(specification,start,stop)
    local start     = tonut(start)
    local processor = specification.processor
    local overloads = specification.processor or getattr(start,a_overloads)
    if overloads and overloads ~= unsetvalue then
        overloads = t_overloads[overloads]
        if not overloads then
            return
        end
    else
        return
    end

    local last    = stop and tonut(stop)
    local oldlist = nil
    local newlist = nil
    local newfont = overloads.font

    local function apply(current)
        local a = getattrlist(current)
        if a == oldlist then
            setattrlist(current,newlist)
        else
            oldlist = getattrlist(current)
            for k, v in next, overloads do
                if type(v) == "number" then
                    setattr(current,k,v)
                else
                    -- can be: ["font"] = number
                end
            end
            newlist = current -- getattrlist(current)
        end
        if newfont then
            setfont(current,newfont)
        end
    end

    for current, id in nextnode, start do
        if id == glyph_code then
            apply(current)
        elseif id == disc_code then
            apply(current)
            if pre then
                while pre do
                    if getid(pre) == glyph_code then
                        apply()
                    end
                    pre = getnext(pre)
                end
            end
            if post then
                while post do
                    if getid(post) == glyph_code then
                        apply()
                    end
                    post = getnext(post)
                end
            end
            if replace then
                while replace do
                    if getid(replace) == glyph_code then
                        apply()
                    end
                    replace = getnext(replace)
                end
            end
        end
        if current == last then
            break
        end
    end
end

-- we assume the same highlight so we're global

interfaces.implement {
    name      = "overloadsattribute",
    arguments = { "string", "integer", "integer" },
    actions   = function(name,font,box)
        local samplebox = texgetbox(box)
        local sample    = samplebox and samplebox.list
        local overloads = sample and tooverloads(sample)
        if overloads then
            overloads.font = font > 0 and font or false
            n_overloads = n_overloads + 1
            t_overloads[n_overloads] = overloads
            t_overloads[name] = overloads
            context(n_overloads)
        else
            context(unsetvalue)
        end
    end
}
