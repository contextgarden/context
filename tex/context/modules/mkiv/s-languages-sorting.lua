if not modules then modules = { } end modules ['s-languages-system'] = {
    version   = 1.001,
    comment   = "companion to s-languages-system.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.languages         = moduledata.languages         or { }
moduledata.languages.sorting = moduledata.languages.sorting or { }

local formatters = string.formatters
local utfbyte, utfcharacters = utf.byte, utf.characters
local sortedpairs = table.sortedpairs

local definitions       = sorters.definitions
local constants         = sorters.constants
local replacementoffset = constants.replacementoffset

local currentfont       = font.current
local fontchars         = fonts.hashes.characters

local c_darkblue        = { "darkblue" }
local c_darkred         = { "darkred" }
local f_chr             = formatters["\\tttf%H"]

local function chr(str,done)
    if done then
        context.space()
    end
    local c = fontchars[currentfont()]
    for s in utfcharacters(str) do
        local u = utfbyte(s)
        if c[u] then
            context(s)
        elseif u > replacementoffset then
            context.color(c_darkblue, f_chr(u))
        else
            context.color(c_darkred, f_chr(u))
        end
    end
    return true
end

local function map(a,b,done)
    if done then
        context.space()
    end
 -- context.tttf()
    chr(a)
    context("=")
    chr(b)
    return true
end

local function nop()
 -- context.tttf()
    context("none")
end

local function key(data,field)
    context.NC()
        context(field)
        context.NC()
        context(data[field])
        context.NC()
    context.NR()
end

function moduledata.languages.sorting.showinstalled(tag)
    if not tag or tag == "" or tag == interfaces.variables.all then
        for tag, data in sortedpairs(definitions) do
            moduledata.languages.sorting.showinstalled (tag)
        end
    else
        sorters.update() -- syncs data
        local data = definitions[tag]
        if data then
            context.starttabulate { "|lB|pl|" }
            key(data,"language")
            key(data,"parent")
            key(data,"method")
            context.NC()
                context("replacements")
                context.NC()
                    local replacements = data.replacements
                    if #replacements == 0 then
                        nop()
                    else
                        for i=1,#replacements do
                            local r = replacements[i]
                            map(r[1],r[2],i > 1)
                        end
                   end
               context.NC()
            context.NR()
            context.NC()
                context("order")
                context.NC()
                    local orders = data.orders
                    for i=1,#orders do
                        chr(orders[i],i > 1)
                    end
                context.NC()
            context.NR()
            context.NC()
                context("entries")
                context.NC()
                    local done = false
                    for k, e in sortedpairs(data.entries) do
                        done = map(k,e,done)
                    end
                context.NC()
            context.NR()
            context.stoptabulate()
        end
    end
end
