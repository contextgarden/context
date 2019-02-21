if not modules then modules = { } end modules ['lxml-aux'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- not all functions here make sense anymore vbut we keep them for
-- compatibility reasons

local trace_manipulations = false  trackers.register("lxml.manipulations", function(v) trace_manipulations = v end)
local trace_inclusions    = false  trackers.register("lxml.inclusions",    function(v) trace_inclusions    = v end)

local report_xml = logs.reporter("xml")

local xml = xml

local xmlcopy, xmlname = xml.copy, xml.name
local xmlinheritedconvert = xml.inheritedconvert
local xmlapplylpath = xml.applylpath

local type, next, setmetatable, getmetatable = type, next, setmetatable, getmetatable
local insert, remove, fastcopy, concat = table.insert, table.remove, table.fastcopy, table.concat
local gmatch, gsub, format, find, strip = string.gmatch, string.gsub, string.format, string.find, string.strip
local utfbyte = utf.byte
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local striplinepatterns = utilities.strings.striplinepatterns

local function report(what,pattern,c,e)
    report_xml("%s element %a, root %a, position %a, index %a, pattern %a",what,xmlname(e),xmlname(e.__p__),c,e.ni,pattern)
end

local function withelements(e,handle,depth)
    if e and handle then
        local edt = e.dt
        if edt then
            depth = depth or 0
            for i=1,#edt do
                local e = edt[i]
                if type(e) == "table" then
                    handle(e,depth)
                    withelements(e,handle,depth+1)
                end
            end
        end
    end
end

xml.withelements = withelements

function xml.withelement(e,n,handle) -- slow
    if e and n ~= 0 and handle then
        local edt = e.dt
        if edt then
            if n > 0 then
                for i=1,#edt do
                    local ei = edt[i]
                    if type(ei) == "table" then
                        if n == 1 then
                            handle(ei)
                            return
                        else
                            n = n - 1
                        end
                    end
                end
            elseif n < 0 then
                for i=#edt,1,-1 do
                    local ei = edt[i]
                    if type(ei) == "table" then
                        if n == -1 then
                            handle(ei)
                            return
                        else
                            n = n + 1
                        end
                    end
                end
            end
        end
    end
end

function xml.each(root,pattern,handle,reverse)
    local collected = xmlapplylpath(root,pattern)
    if collected then
        if handle then
            if reverse then
                for c=#collected,1,-1 do
                    handle(collected[c])
                end
            else
                for c=1,#collected do
                    handle(collected[c])
                end
            end
        end
        return collected
    end
end

function xml.processattributes(root,pattern,handle)
    local collected = xmlapplylpath(root,pattern)
    if collected and handle then
        for c=1,#collected do
            handle(collected[c].at)
        end
    end
    return collected
end

--[[ldx--
<p>The following functions collect elements and texts.</p>
--ldx]]--

-- are these still needed -> lxml-cmp.lua

function xml.collect(root, pattern)
    return xmlapplylpath(root,pattern)
end

function xml.collecttexts(root, pattern, flatten) -- todo: variant with handle
    local collected = xmlapplylpath(root,pattern)
    if collected and flatten then
        local xmltostring = xml.tostring
        for c=1,#collected do
            collected[c] = xmltostring(collected[c].dt)
        end
    end
    return collected or { }
end

function xml.collect_tags(root, pattern, nonamespace)
    local collected = xmlapplylpath(root,pattern)
    if collected then
        local t = { }
        local n = 0
        for c=1,#collected do
            local e  = collected[c]
            local ns = e.ns
            local tg = e.tg
            n = n + 1
            if nonamespace then
                t[n] = tg
            elseif ns == "" then
                t[n] = tg
            else
                t[n] = ns .. ":" .. tg
            end
        end
        return t
    end
end

--[[ldx--
<p>We've now arrived at the functions that manipulate the tree.</p>
--ldx]]--

local no_root = { no_root = true }

local function redo_ni(d)
    for k=1,#d do
        local dk = d[k]
        if type(dk) == "table" then
            dk.ni = k
        end
    end
end

xml.reindex = redo_ni

local function xmltoelement(whatever,root)
    if not whatever then
        return nil
    end
    local element
    if type(whatever) == "string" then
        element = xmlinheritedconvert(whatever,root) -- beware, not really a root
    else
        element = whatever -- we assume a table
    end
    if element.error then
        return whatever -- string
    end
    if element then
    --~ if element.ri then
    --~     element = element.dt[element.ri].dt
    --~ else
    --~     element = element.dt
    --~ end
    end
    return element
end

xml.toelement = xmltoelement

local function copiedelement(element,newparent)
    if type(element) == "string" then
        return element
    else
        element = xmlcopy(element).dt
        if newparent and type(element) == "table" then
            element.__p__ = newparent
        end
        return element
    end
end

function xml.delete(root,pattern)
    if not pattern or pattern == "" then
        local p = root.__p__
        if p then
            if trace_manipulations then
                report('deleting',"--",c,root)
            end
            local d = p.dt
            remove(d,root.ni)
            redo_ni(d) -- can be made faster and inlined
        end
    else
        local collected = xmlapplylpath(root,pattern)
        if collected then
            for c=1,#collected do
                local e = collected[c]
                local p = e.__p__
                if p then
                    if trace_manipulations then
                        report('deleting',pattern,c,e)
                    end
                    local d  = p.dt
                    local ni = e.ni
                    if ni <= #d then
                        if false then
                            p.dt[ni] = ""
                        else
                            -- what if multiple deleted in one set
                            remove(d,ni)
                            redo_ni(d) -- can be made faster and inlined
                        end
                    else
                        -- disturbing
                    end
                end
            end
        end
    end
end

function xml.replace(root,pattern,whatever)
    local element = root and xmltoelement(whatever,root)
    local collected = element and xmlapplylpath(root,pattern)
    if collected then
        for c=1,#collected do
            local e = collected[c]
            local p = e.__p__
            if p then
                if trace_manipulations then
                    report('replacing',pattern,c,e)
                end
                local d = p.dt
                local n = e.ni
                local t = copiedelement(element,p)
                if type(t) == "table" then
                    d[n] = t[1]
                    for i=2,#t do
                        n = n + 1
                        insert(d,n,t[i])
                    end
                else
                    d[n] = t
                end
                redo_ni(d) -- probably not needed
            end
        end
    end
end

local function wrap(e,wrapper)
    local t = {
        rn = e.rn,
        tg = e.tg,
        ns = e.ns,
        at = e.at,
        dt = e.dt,
        __p__ = e,
    }
    setmetatable(t,getmetatable(e))
    e.rn = wrapper.rn or e.rn or ""
    e.tg = wrapper.tg or e.tg or ""
    e.ns = wrapper.ns or e.ns or ""
    e.at = fastcopy(wrapper.at)
    e.dt = { t }
end

function xml.wrap(root,pattern,whatever)
    if whatever then
        local wrapper = xmltoelement(whatever,root)
        local collected = xmlapplylpath(root,pattern)
        if collected then
            for c=1,#collected do
                local e = collected[c]
                if trace_manipulations then
                    report('wrapping',pattern,c,e)
                end
                wrap(e,wrapper)
            end
        end
    else
        wrap(root,xmltoelement(pattern))
    end
end

local function inject_element(root,pattern,whatever,prepend)
    local element = root and xmltoelement(whatever,root)
    local collected = element and xmlapplylpath(root,pattern)
    local function inject_e(e)
        local r   = e.__p__
        local d   = r.dt
        local k   = e.ni
        local rri = r.ri
        local edt = (rri and d[rri].dt) or (d and d[k] and d[k].dt)
        if edt then
            local be, af
            local cp = copiedelement(element,e)
            if prepend then
                be, af = cp, edt
            else
                be, af = edt, cp
            end
            local bn = #be
            for i=1,#af do
                bn = bn + 1
                be[bn] = af[i]
            end
            if rri then
                r.dt[rri].dt = be
            else
                d[k].dt = be
            end
            redo_ni(d)
        end
    end
    if not collected then
        -- nothing
    elseif collected.tg then
        -- first or so
        inject_e(collected)
    else
        for c=1,#collected do
            inject_e(collected[c])
        end
    end
end

local function insert_element(root,pattern,whatever,before) -- todo: element als functie
    local element = root and xmltoelement(whatever,root)
    local collected = element and xmlapplylpath(root,pattern)
    local function insert_e(e)
        local r = e.__p__
        local d = r.dt
        local k = e.ni
        if not before then
            k = k + 1
        end
        insert(d,k,copiedelement(element,r))
        redo_ni(d)
    end
    if not collected then
        -- nothing
    elseif collected.tg then
        -- first or so
        insert_e(collected)
    else
        for c=1,#collected do
            insert_e(collected[c])
        end
    end
end

xml.insert_element  =                 insert_element
xml.insertafter     =                 insert_element
xml.insertbefore    = function(r,p,e) insert_element(r,p,e,true) end
xml.injectafter     =                 inject_element
xml.injectbefore    = function(r,p,e) inject_element(r,p,e,true) end

-- loaddata can restrict loading

local function include(xmldata,pattern,attribute,recursive,loaddata,level)
 -- attribute = attribute or 'href'
    pattern   = pattern or 'include'
    loaddata  = loaddata or io.loaddata
    local collected = xmlapplylpath(xmldata,pattern)
    if collected then
        if not level then
            level = 1
        end
        for c=1,#collected do
            local ek = collected[c]
            local name = nil
            local ekdt = ek.dt
            if ekdt then
                local ekat = ek.at
                local ekrt = ek.__p__
                if ekrt then
                    local epdt = ekrt.dt
                    if not attribute or attribute == "" then
                        name = (type(ekdt) == "table" and ekdt[1]) or ekdt -- check, probably always tab or str
                    end
                    if not name then
                        for a in gmatch(attribute or "href","([^|]+)") do
                            name = ekat[a]
                            if name then
                                break
                            end
                        end
                    end
                    local data = nil
                    if name and name ~= "" then
                        local d, n = loaddata(name)
                        data = d or ""
                        name = n or name
                        if trace_inclusions then
                            report_xml("including %s bytes from %a at level %s by pattern %a and attribute %a (%srecursing)",#data,name,level,pattern,attribute or "",recursive and "" or "not ")
                        end
                    end
                    if not data or data == "" then
                        epdt[ek.ni] = "" -- xml.empty(d,k)
                    elseif ekat["parse"] == "text" then
                        -- for the moment hard coded
                        epdt[ek.ni] = xml.escaped(data) -- d[k] = xml.escaped(data)
                    else
local settings = xmldata.settings
local savedresource = settings.currentresource
settings.currentresource = name
                        local xi = xmlinheritedconvert(data,xmldata)
                        if not xi then
                            epdt[ek.ni] = "" -- xml.empty(d,k)
                        else
                            if recursive then
                                include(xi,pattern,attribute,recursive,loaddata,level+1)
                            end
                            local child = xml.body(xi) -- xml.assign(d,k,xi)
                            child.__p__ = ekrt
                            child.__f__ = name -- handy for tracing
child.cf = name
                            epdt[ek.ni] = child
                            local settings   = xmldata.settings
                            local inclusions = settings and settings.inclusions
                            if inclusions then
                                inclusions[#inclusions+1] = name
                            elseif settings then
                                settings.inclusions = { name }
                            else
                                settings = { inclusions = { name } }
                                xmldata.settings = settings
                            end
                            if child.er then
                                local badinclusions = settings.badinclusions
                                if badinclusions then
                                    badinclusions[#badinclusions+1] = name
                                else
                                    settings.badinclusions = { name }
                                end
                            end
                        end
settings.currentresource = savedresource
                    end
                end
            end
        end
    end
end

xml.include = include

function xml.inclusion(e,default)
    while e do
        local f = e.__f__
        if f then
            return f
        else
            e = e.__p__
        end
    end
    return default
end

local function getinclusions(key,e,sorted)
    while e do
        local settings = e.settings
        if settings then
            local inclusions = settings[key]
            if inclusions then
                inclusions = table.unique(inclusions) -- a copy
                if sorted then
                    table.sort(inclusions) -- so we sort the copy
                end
                return inclusions -- and return the copy
            else
                e = e.__p__
            end
        else
            e = e.__p__
        end
    end
end

function xml.inclusions(e,sorted)
    return getinclusions("inclusions",e,sorted)
end

function xml.badinclusions(e,sorted)
    return getinclusions("badinclusions",e,sorted)
end

local b_collapser  = lpegpatterns.b_collapser
local m_collapser  = lpegpatterns.m_collapser
local e_collapser  = lpegpatterns.e_collapser

local b_stripper   = lpegpatterns.b_stripper
local m_stripper   = lpegpatterns.m_stripper
local e_stripper   = lpegpatterns.e_stripper

local function stripelement(e,nolines,anywhere)
    local edt = e.dt
    if edt then
        local n = #edt
        if n == 0 then
            return e -- convenient
        elseif anywhere then
            local t = { }
            local m = 0
            for e=1,n do
                local str = edt[e]
                if type(str) ~= "string" then
                    m = m + 1
                    t[m] = str
                elseif str ~= "" then
                    if nolines then
                        str = lpegmatch((n == 1 and b_collapser) or (n == m and e_collapser) or m_collapser,str)
                    else
                        str = lpegmatch((n == 1 and b_stripper) or (n == m and e_stripper) or m_stripper,str)
                    end
                    if str ~= "" then
                        m = m + 1
                        t[m] = str
                    end
                end
            end
            e.dt = t
        else
            local str = edt[1]
            if type(str) == "string" then
                if str ~= "" then
                    str = lpegmatch(nolines and b_collapser or b_stripper,str)
                end
                if str == "" then
                    remove(edt,1)
                    n = n - 1
                else
                    edt[1] = str
                end
            end
            if n > 0 then
                str = edt[n]
                if type(str) == "string" then
                    if str == "" then
                        remove(edt)
                    else
                        str = lpegmatch(nolines and e_collapser or e_stripper,str)
                        if str == "" then
                            remove(edt)
                        else
                            edt[n] = str
                        end
                    end
                end
            end
        end
    end
    return e -- convenient
end

xml.stripelement = stripelement

function xml.strip(root,pattern,nolines,anywhere) -- strips all leading and trailing spacing
    local collected = xmlapplylpath(root,pattern) -- beware, indices no longer are valid now
    if collected then
        for i=1,#collected do
            stripelement(collected[i],nolines,anywhere)
        end
    end
end

local function renamespace(root, oldspace, newspace) -- fast variant
    local ndt = #root.dt
    for i=1,ndt or 0 do
        local e = root[i]
        if type(e) == "table" then
            if e.ns == oldspace then
                e.ns = newspace
                if e.rn then
                    e.rn = newspace
                end
            end
            local edt = e.dt
            if edt then
                renamespace(edt, oldspace, newspace)
            end
        end
    end
end

xml.renamespace = renamespace

function xml.remaptag(root, pattern, newtg)
    local collected = xmlapplylpath(root,pattern)
    if collected then
        for c=1,#collected do
            collected[c].tg = newtg
        end
    end
end

function xml.remapnamespace(root, pattern, newns)
    local collected = xmlapplylpath(root,pattern)
    if collected then
        for c=1,#collected do
            collected[c].ns = newns
        end
    end
end

function xml.checknamespace(root, pattern, newns)
    local collected = xmlapplylpath(root,pattern)
    if collected then
        for c=1,#collected do
            local e = collected[c]
            if (not e.rn or e.rn == "") and e.ns == "" then
                e.rn = newns
            end
        end
    end
end

function xml.remapname(root, pattern, newtg, newns, newrn)
    local collected = xmlapplylpath(root,pattern)
    if collected then
        for c=1,#collected do
            local e = collected[c]
            e.tg, e.ns, e.rn = newtg, newns, newrn
        end
    end
end

--[[ldx--
<p>Helper (for q2p).</p>
--ldx]]--

function xml.cdatatotext(e)
    local dt = e.dt
    if #dt == 1 then
        local first = dt[1]
        if first.tg == "@cd@" then
            e.dt = first.dt
        end
    else
        -- maybe option
    end
end

-- local x = xml.convert("<x><a>1<b>2</b>3</a></x>")
-- xml.texttocdata(xml.first(x,"a"))
-- print(x) -- <x><![CDATA[1<b>2</b>3]]></x>

function xml.texttocdata(e) -- could be a finalizer
    local dt = e.dt
    local s = xml.tostring(dt) -- no shortcut?
    e.tg = "@cd@"
    e.special = true
    e.ns = ""
    e.rn = ""
    e.dt = { s }
    e.at = nil
end

-- local x = xml.convert("<x><a>1<b>2</b>3</a></x>")
-- xml.tocdata(xml.first(x,"a"))
-- print(x) -- <x><![CDATA[<a>1<b>2</b>3</a>]]></x>

function xml.elementtocdata(e) -- could be a finalizer
    local dt = e.dt
    local s = xml.tostring(e) -- no shortcut?
    e.tg = "@cd@"
    e.special = true
    e.ns = ""
    e.rn = ""
    e.dt = { s }
    e.at = nil
end

xml.builtinentities = table.tohash { "amp", "quot", "apos", "lt", "gt" } -- used often so share

local entities        = characters and characters.entities or nil
local builtinentities = xml.builtinentities

function xml.addentitiesdoctype(root,option) -- we could also have a 'resolve' i.e. inline hex
    if not entities then
        require("char-ent")
        entities = characters.entities
    end
    if entities and root and root.tg == "@rt@" and root.statistics then
        local list = { }
        local hexify = option == "hexadecimal"
        for k, v in table.sortedhash(root.statistics.entities.names) do
            if not builtinentities[k] then
                local e = entities[k]
                if not e then
                    e = format("[%s]",k)
                elseif hexify then
                    e = format("&#%05X;",utfbyte(k))
                end
                list[#list+1] = format("  <!ENTITY %s %q >",k,e)
            end
        end
        local dt = root.dt
        local n = dt[1].tg == "@pi@" and 2 or 1
        if #list > 0 then
            insert(dt, n, { "\n" })
            insert(dt, n, {
               tg      = "@dt@", -- beware, doctype is unparsed
               dt      = { format("Something [\n%s\n] ",concat(list)) },
               ns      = "",
               special = true,
            })
            insert(dt, n, { "\n\n" })
        else
         -- insert(dt, n, { table.serialize(root.statistics) })
        end
    end
end

-- local str = [==[
-- <?xml version='1.0' standalone='yes' ?>
-- <root>
-- <a>test &nbsp; test &#123; test</a>
-- <b><![CDATA[oeps]]></b>
-- </root>
-- ]==]
--
-- local x = xml.convert(str)
-- xml.addentitiesdoctype(x,"hexadecimal")
-- print(x)

--[[ldx--
<p>Here are a few synonyms.</p>
--ldx]]--

xml.all     = xml.each
xml.insert  = xml.insertafter
xml.inject  = xml.injectafter
xml.after   = xml.insertafter
xml.before  = xml.insertbefore
xml.process = xml.each

-- obsolete

xml.obsolete   = xml.obsolete or { }
local obsolete = xml.obsolete

xml.strip_whitespace           = xml.strip                 obsolete.strip_whitespace      = xml.strip
xml.collect_elements           = xml.collect               obsolete.collect_elements      = xml.collect
xml.delete_element             = xml.delete                obsolete.delete_element        = xml.delete
xml.replace_element            = xml.replace               obsolete.replace_element       = xml.replace
xml.each_element               = xml.each                  obsolete.each_element          = xml.each
xml.process_elements           = xml.process               obsolete.process_elements      = xml.process
xml.insert_element_after       = xml.insertafter           obsolete.insert_element_after  = xml.insertafter
xml.insert_element_before      = xml.insertbefore          obsolete.insert_element_before = xml.insertbefore
xml.inject_element_after       = xml.injectafter           obsolete.inject_element_after  = xml.injectafter
xml.inject_element_before      = xml.injectbefore          obsolete.inject_element_before = xml.injectbefore
xml.process_attributes         = xml.processattributes     obsolete.process_attributes    = xml.processattributes
xml.collect_texts              = xml.collecttexts          obsolete.collect_texts         = xml.collecttexts
xml.inject_element             = xml.inject                obsolete.inject_element        = xml.inject
xml.remap_tag                  = xml.remaptag              obsolete.remap_tag             = xml.remaptag
xml.remap_name                 = xml.remapname             obsolete.remap_name            = xml.remapname
xml.remap_namespace            = xml.remapnamespace        obsolete.remap_namespace       = xml.remapnamespace

-- new (probably ok)

function xml.cdata(e)
    if e then
        local dt = e.dt
        if dt and #dt == 1 then
            local first = dt[1]
            return first.tg == "@cd@" and first.dt[1] or ""
        end
    end
    return ""
end

function xml.finalizers.xml.cdata(collected)
    if collected then
        local e = collected[1]
        if e then
            local dt = e.dt
            if dt and #dt == 1 then
                local first = dt[1]
                return first.tg == "@cd@" and first.dt[1] or ""
            end
        end
    end
    return ""
end

function xml.insertcomment(e,str,n)
    insert(e.dt,n or 1,{
        tg      = "@cm@",
        ns      = "",
        special = true,
        at      = { },
        dt      = { str },
    })
end

function xml.insertcdata(e,str,n)
    insert(e.dt,n or 1,{
        tg      = "@cd@",
        ns      = "",
        special = true,
        at      = { },
        dt      = { str },
    })
end

function xml.setcomment(e,str,n)
    e.dt = { {
        tg      = "@cm@",
        ns      = "",
        special = true,
        at      = { },
        dt      = { str },
    } }
end

function xml.setcdata(e,str)
    e.dt = { {
        tg      = "@cd@",
        ns      = "",
        special = true,
        at      = { },
        dt      = { str },
    } }
end

-- maybe helpers like this will move to an autoloader

function xml.separate(x,pattern)
    local collected = xmlapplylpath(x,pattern)
    if collected then
        for c=1,#collected do
            local e = collected[c]
            local d = e.dt
            if d == x then
                report_xml("warning: xml.separate changes root")
                x = d
            end
            local t  = { "\n" }
            local n  = 1
            local i  = 1
            local nd = #d
            while i <= nd do
                while i <= nd do
                    local di = d[i]
                    if type(di) == "string" then
                        if di == "\n" or find(di,"^%s+$") then -- first test is speedup
                            i = i + 1
                        else
                            d[i] = strip(di)
                            break
                        end
                    else
                        break
                    end
                end
                if i > nd then
                    break
                end
                t[n+1] = "\n"
                t[n+2] = d[i]
                t[n+3] = "\n"
                n = n + 3
                i = i + 1
            end
            t[n+1] = "\n"
            setmetatable(t,getmetatable(d))
            e.dt = t
        end
    end
    return x
end

--

local helpers = xml.helpers or { }
xml.helpers   = helpers

local function normal(e,action)
    local edt = e.dt
    if edt then
        for i=1,#edt do
            local str = edt[i]
            if type(str) == "string" and str ~= "" then
                edt[i] = action(str)
            end
        end
    end
end

local function recurse(e,action)
    local edt = e.dt
    if edt then
        for i=1,#edt do
            local str = edt[i]
            if type(str) ~= "string" then
                recurse(str,action) -- ,recursive
            elseif str ~= "" then
                edt[i] = action(str)
            end
        end
    end
end

function helpers.recursetext(collected,action,recursive)
    if recursive then
        for i=1,#collected do
            recurse(collected[i],action)
        end
    else
        for i=1,#collected do
           normal(collected[i],action)
        end
    end
end

-- on request ... undocumented ...
--
-- _tag       : element name
-- _type      : node type (_element can be an option)
-- _namespace : only if given
--
-- [1..n]     : text or table
-- key        : value or attribite 'key'
--
-- local str = [[
-- <?xml version="1.0" ?>
-- <a one="1">
--     <!-- rubish -->
--   <b two="1"/>
--   <b two="2">
--     c &gt; d
--   </b>
-- </a>
-- ]]
--
-- inspect(xml.totable(xml.convert(str)))
-- inspect(xml.totable(xml.convert(str),true))
-- inspect(xml.totable(xml.convert(str),true,true))

local specials = {
    ["@rt@"] = "root",
    ["@pi@"] = "instruction",
    ["@cm@"] = "comment",
    ["@dt@"] = "declaration",
    ["@cd@"] = "cdata",
}

local function convert(x,strip,flat)
    local ns = x.ns
    local tg = x.tg
    local at = x.at
    local dt = x.dt
    local node = flat and {
        [0] = (not x.special and (ns ~= "" and ns .. ":" .. tg or tg)) or nil,
    } or {
        _namespace = ns ~= "" and ns or nil,
        _tag       = not x.special and tg or nil,
        _type      = specials[tg] or "_element",
    }
    if at then
        for k, v in next, at do
            node[k] = v
        end
    end
    local n = 0
    for i=1,#dt do
        local di = dt[i]
        if type(di) == "table" then
            if flat and di.special then
                -- ignore
            else
                di = convert(di,strip,flat)
                if di then
                    n = n + 1
                    node[n] = di
                end
            end
        elseif strip then
            di = lpegmatch(strip,di)
            if di ~= "" then
                n = n + 1
                node[n] = di
            end
        else
            n = n + 1
            node[n] = di
        end
    end
    if next(node) then
        return node
    end
end

function xml.totable(x,strip,flat)
    if type(x) == "table" then
        if strip then
            strip = striplinepatterns[strip]
        end
        return convert(x,strip,flat)
    end
end

-- namespace, name, attributes
-- name, attributes
-- name

function xml.rename(e,namespace,name,attributes)
    if type(e) ~= "table" or not e.tg then
        return
    end
    if type(name) == "table" then
        attributes = name
        name       = namespace
        namespace  = ""
    elseif type(name) ~= "string" then
        attributes = { }
        name       = namespace
        namespace  = ""
    end
    if type(attributes) ~= "table" then
        attributes = { }
    end
    e.ns = namespace
    e.rn = namespace
    e.tg = name
    e.at = attributes
end
