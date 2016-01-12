if not modules then modules = { } end modules ['page-pst'] = {
    version   = 1.001,
    comment   = "companion to page-pst.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: adapt message

local tonumber, next, type = tonumber, next, type
local find, validstring = string.find, string.valid

local context     = context
local implement   = interfaces.implement

local texgetcount = tex.getcount
local texsetcount = tex.setcount

local sortedkeys   = table.sortedkeys
local formatters   = string.formatters

local cache = { }

local function flush(page)
    local c = cache[page]
    if c then
        for i=1,#c do
         -- characters.showstring(c[i])
            context.viafile(c[i],formatters["page.%s"](validstring(page,"nopage")))
        end
        cache[page] = nil
    end
end

local function setnextpage()
    local n = next(cache) and sortedkeys(cache)[1]
    if not n then
        n = 0           -- nothing in the cache
    elseif n == 0 then
        n = -1          -- generic buffer (0)
    elseif n > 0 then
                        -- upcoming page (realpageno)
    end
    texsetcount("global","c_page_postponed_blocks_next_page",n)
end

local function flushpostponedblocks(specification)
    -- we need to flush previously pending pages as well and the zero
    -- slot is the generic one so that one is always flushed
    local t = sortedkeys(cache)
    local p = tonumber(specification.page) or texgetcount("realpageno") or 0
    for i=1,#t do
        local ti = t[i]
        if ti <= p then
            flush(ti)
        else
            break
        end
    end
    setnextpage()
end

implement {
    name      = "flushpostponedblocks",
    actions   = flushpostponedblocks,
    arguments = {
        {
            { "page" }
        }
    }
}

local function registerpostponedblock(page)
    if type(page) == "string" then
        if find(page,"^+") then
            page = texgetcount("realpageno") + (tonumber(page) or 1) -- future delta page
        else
            page = tonumber(page) or 0 -- preferred page or otherwise first possible occasion
        end
    end
    if not page then
        page = 0
    end
    local c = cache[page]
    if not c then
        c = { }
        cache[page] = c
    end
    c[#c+1] = buffers.raw("postponedblock")
    buffers.erase("postponedblock")
    if page == 0 then
        interfaces.showmessage("layouts",3,#c)
    else
        interfaces.showmessage("layouts",3,formatters["%s (realpage: %s)"](#c,page))
    end
    setnextpage()
end

implement {
    name      = "registerpostponedblock",
    actions   = registerpostponedblock,
    arguments = "string"
}

