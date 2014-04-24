if not modules then modules = { } end modules ['attr-ini'] = {
    version   = 1.001,
    comment   = "companion to attr-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local commands, context, nodes, storage = commands, context, nodes, storage

local next, type = next, type

--[[ldx--
<p>We start with a registration system for atributes so that we can use the
symbolic names later on.</p>
--ldx]]--

attributes            = attributes or { }
local attributes      = attributes

local sharedstorage   = storage.shared

local texgetcount     = tex.getcount
local texsetattribute = tex.setattribute

attributes.names      = attributes.names    or { }
attributes.numbers    = attributes.numbers  or { }
attributes.list       = attributes.list     or { }
attributes.states     = attributes.states   or { }
attributes.handlers   = attributes.handlers or { }
attributes.unsetvalue = -0x7FFFFFFF

local names           = attributes.names
local numbers         = attributes.numbers
local list            = attributes.list

storage.register("attributes/names",   names,   "attributes.names")
storage.register("attributes/numbers", numbers, "attributes.numbers")
storage.register("attributes/list",    list,    "attributes.list")

-- function attributes.define(name,number) -- at the tex end
--     if not numbers[name] then
--         numbers[name] = number
--         names[number] = name
--         list[number]  = { }
--     end
-- end

--[[ldx--
<p>We reserve this one as we really want it to be always set (faster).</p>
--ldx]]--

names[0], numbers["fontdynamic"] = "fontdynamic", 0

--[[ldx--
<p>We can use the attributes in the range 127-255 (outside user space). These
are only used when no attribute is set at the \TEX\ end which normally
happens in <l n='context'/>.</p>
--ldx]]--

sharedstorage.attributes_last_private = sharedstorage.attributes_last_private or  127
sharedstorage.attributes_last_public  = sharedstorage.attributes_last_public  or 1024

function attributes.private(name) -- at the lua end (hidden from user)
    local number = numbers[name]
    if not number then
        local last = sharedstorage.attributes_last_private
        if last < 1023 then
            last = last + 1
            sharedstorage.attributes_last_private = last
        else
            report_attribute("no more room for private attributes")
            os.exit()
        end
        number = last
        numbers[name], names[number], list[number] = number, name, { }
    end
    return number
end

function attributes.public(name) -- at the lua end (hidden from user)
    local number = numbers[name]
    if not number then
        local last = sharedstorage.attributes_last_public
        if last < 65535 then
            last = last + 1
            sharedstorage.attributes_last_public = last
        else
            report_attribute("no more room for public attributes")
            os.exit()
        end
        number = last
        numbers[name], names[number], list[number] = number, name, { }
    end
    return number
end

attributes.system = attributes.private

function attributes.define(name,number,category)
    return (attributes[category or "public"] or attributes["public"])(name,number)
end

-- tracers

local report_attribute = logs.reporter("attributes")

local function showlist(what,list)
    if list then
        local a = list.next
        local i = 0
        while a do
            local number, value = a.number, a.value
            i = i + 1
            report_attribute("%S %2i: attribute %3i, value %4i, name %a",what,i,number,value,names[number])
            a = a.next
        end
   end
end

function attributes.showcurrent()
    showlist("current",node.current_attr())
end

function attributes.ofnode(n)
    showlist(n,n.attr)
end

-- interface

commands.showattributes = attributes.showcurrent

function commands.defineattribute(name,category)
    context(attributes.define(name,category))
end

-- rather special

local store = { }

function commands.savecurrentattributes(name)
    name = name or ""
    local n = node.current_attr()
    n = n and n.next
    local t = { }
    while n do
        t[n.number] = n.value
        n = n.next
    end
    store[name] = {
        attr = t,
        font = font.current(),
    }
end

function commands.restorecurrentattributes(name)
    name = name or ""
    local t = store[name]
    if t then
        local attr = t.attr
        local font = t.font
        if attr then
            for k, v in next, attr do
                texsetattribute(k,v)
            end
        end
        if font then
         -- tex.font = font
            context.getvalue(fonts.hashes.csnames[font]) -- we don't have a direct way yet (will discuss it with taco)
        end
    end
 -- store[name] = nil
end
