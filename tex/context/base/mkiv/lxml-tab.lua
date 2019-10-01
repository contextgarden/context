if not modules then modules = { } end modules ['lxml-tab'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this module needs a cleanup: check latest lpeg, passing args, (sub)grammar, etc etc
-- stripping spaces from e.g. cont-en.xml saves .2 sec runtime so it's not worth the
-- trouble

-- todo: when serializing optionally remap named entities to hex (if known in char-ent.lua)
-- maybe when letter -> utf, else name .. then we need an option to the serializer .. a bit
-- of work so we delay this till we cleanup

local trace_entities = false  trackers.register("xml.entities", function(v) trace_entities = v end)

local report_xml = logs and logs.reporter("xml","core") or function(...) print(string.format(...)) end

--[[ldx--
<p>The parser used here is inspired by the variant discussed in the lua book, but
handles comment and processing instructions, has a different structure, provides
parent access; a first version used different trickery but was less optimized to we
went this route. First we had a find based parser, now we have an <l n='lpeg'/> based one.
The find based parser can be found in l-xml-edu.lua along with other older code.</p>
--ldx]]--

if lpeg.setmaxstack then lpeg.setmaxstack(1000) end -- deeply nested xml files

xml = xml or { }
local xml = xml

--~ local xml = xml

local concat, remove, insert = table.concat, table.remove, table.insert
local type, next, setmetatable, getmetatable, tonumber, rawset, select = type, next, setmetatable, getmetatable, tonumber, rawset, select
local lower, find, match, gsub = string.lower, string.find, string.match, string.gsub
local sort = table.sort
local utfchar = utf.char
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local P, S, R, C, V, C, Cs = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.V, lpeg.C, lpeg.Cs
local formatters = string.formatters

--[[ldx--
<p>First a hack to enable namespace resolving. A namespace is characterized by
a <l n='url'/>. The following function associates a namespace prefix with a
pattern. We use <l n='lpeg'/>, which in this case is more than twice as fast as a
find based solution where we loop over an array of patterns. Less code and
much cleaner.</p>
--ldx]]--

do -- begin of namespace closure (we ran out of locals)

xml.xmlns = xml.xmlns or { }

--[[ldx--
<p>The next function associates a namespace prefix with an <l n='url'/>. This
normally happens independent of parsing.</p>

<typing>
xml.registerns("mml","mathml")
</typing>
--ldx]]--

local check = P(false)
local parse = check

function xml.registerns(namespace, pattern) -- pattern can be an lpeg
    check = check + C(P(lower(pattern))) / namespace
    parse = P { P(check) + 1 * V(1) }
end

--[[ldx--
<p>The next function also registers a namespace, but this time we map a
given namespace prefix onto a registered one, using the given
<l n='url'/>. This used for attributes like <t>xmlns:m</t>.</p>

<typing>
xml.checkns("m","http://www.w3.org/mathml")
</typing>
--ldx]]--

function xml.checkns(namespace,url)
    local ns = lpegmatch(parse,lower(url))
    if ns and namespace ~= ns then
        xml.xmlns[namespace] = ns
    end
end

--[[ldx--
<p>Next we provide a way to turn an <l n='url'/> into a registered
namespace. This used for the <t>xmlns</t> attribute.</p>

<typing>
resolvedns = xml.resolvens("http://www.w3.org/mathml")
</typing>

This returns <t>mml</t>.
--ldx]]--

function xml.resolvens(url)
     return lpegmatch(parse,lower(url)) or ""
end

--[[ldx--
<p>A namespace in an element can be remapped onto the registered
one efficiently by using the <t>xml.xmlns</t> table.</p>
--ldx]]--

end -- end of namespace closure

--[[ldx--
<p>This version uses <l n='lpeg'/>. We follow the same approach as before, stack and top and
such. This version is about twice as fast which is mostly due to the fact that
we don't have to prepare the stream for cdata, doctype etc etc. This variant is
is dedicated to Luigi Scarso, who challenged me with 40 megabyte <l n='xml'/> files that
took 12.5 seconds to load (1.5 for file io and the rest for tree building). With
the <l n='lpeg'/> implementation we got that down to less 7.3 seconds. Loading the 14
<l n='context'/> interface definition files (2.6 meg) went down from 1.05 seconds to 0.55.</p>

<p>Next comes the parser. The rather messy doctype definition comes in many
disguises so it is no surprice that later on have to dedicate quite some
<l n='lpeg'/> code to it.</p>

<typing>
<!DOCTYPE Something PUBLIC "... ..." "..." [ ... ] >
<!DOCTYPE Something PUBLIC "... ..." "..." >
<!DOCTYPE Something SYSTEM "... ..." [ ... ] >
<!DOCTYPE Something SYSTEM "... ..." >
<!DOCTYPE Something [ ... ] >
<!DOCTYPE Something >
</typing>

<p>The code may look a bit complex but this is mostly due to the fact that we
resolve namespaces and attach metatables. There is only one public function:</p>

<typing>
local x = xml.convert(somestring)
</typing>

<p>An optional second boolean argument tells this function not to create a root
element.</p>

<p>Valid entities are:</p>

<typing>
<!ENTITY xxxx SYSTEM "yyyy" NDATA zzzz>
<!ENTITY xxxx PUBLIC "yyyy" >
<!ENTITY xxxx "yyyy" >
</typing>
--ldx]]--

-- not just one big nested table capture (lpeg overflow)

local nsremap, resolvens = xml.xmlns, xml.resolvens

local stack, level, top, at, xmlnms, errorstr
local entities, parameters
local strip, utfize, resolve, cleanup, resolve_predefined, unify_predefined
local dcache, hcache, acache
local mt, dt, nt
local currentfilename, currentline, linenumbers

local grammar_parsed_text_one
local grammar_parsed_text_two
local grammar_unparsed_text

local handle_hex_entity
local handle_dec_entity
local handle_any_entity_dtd
local handle_any_entity_text

local function preparexmlstate(settings)
    if settings then
        linenumbers        = settings.linenumbers
        stack              = { }
        level              = 0
        top                = { }
        at                 = { }
        mt                 = { }
        dt                 = { }
        nt                 = 0   -- some 5% faster than #dt on cont-en.xml
        xmlns              = { }
        errorstr           = nil
        strip              = settings.strip_cm_and_dt
        utfize             = settings.utfize_entities
        resolve            = settings.resolve_entities            -- enable this in order to apply the dtd
        resolve_predefined = settings.resolve_predefined_entities -- in case we have escaped entities
        unify_predefined   = settings.unify_predefined_entities   -- &#038; -> &amp;
        cleanup            = settings.text_cleanup
        entities           = settings.entities or { }
        currentfilename    = settings.currentresource
        currentline        = 1
        parameters         = { }
        reported_at_errors = { }
        dcache             = { }
        hcache             = { }
        acache             = { }
        if utfize == nil then
            settings.utfize_entities = true
            utfize = true
        end
        if resolve_predefined == nil then
            settings.resolve_predefined_entities = true
            resolve_predefined = true
        end
    else
        linenumbers        = false
        stack              = nil
        level              = nil
        top                = nil
        at                 = nil
        mt                 = nil
        dt                 = nil
        nt                 = nil
        xmlns              = nil
        errorstr           = nil
        strip              = nil
        utfize             = nil
        resolve            = nil
        resolve_predefined = nil
        unify_predefined   = nil
        cleanup            = nil
        entities           = nil
        parameters         = nil
        reported_at_errors = nil
        dcache             = nil
        hcache             = nil
        acache             = nil
        currentfilename    = nil
        currentline        = 1
    end
end

local function initialize_mt(root)
    mt = { __index = root } -- will be redefined later
end

function xml.setproperty(root,k,v)
    getmetatable(root).__index[k] = v
end

function xml.checkerror(top,toclose)
    return "" -- can be set
end

local checkns = xml.checkns

local function add_attribute(namespace,tag,value)
    if cleanup and value ~= "" then
        value = cleanup(value) -- new
    end
    if tag == "xmlns" then
        xmlns[#xmlns+1] = resolvens(value)
        at[tag] = value
    elseif namespace == "" then
        at[tag] = value
    elseif namespace == "xmlns" then
        checkns(tag,value)
        at["xmlns:" .. tag] = value
    else
        -- for the moment this way:
        at[namespace .. ":" .. tag] = value
    end
end

local function add_empty(spacing, namespace, tag)
    if spacing ~= "" then
        nt = nt + 1
        dt[nt] = spacing
    end
    local resolved = namespace == "" and xmlns[#xmlns] or nsremap[namespace] or namespace
    top = stack[level]
    dt = top.dt
    nt = #dt + 1
    local t = linenumbers and {
        ns = namespace or "",
        rn = resolved,
        tg = tag,
        at = at,
        dt = { },
        ni = nt, -- set slot, needed for css filtering
        cf = currentfilename,
        cl = currentline,
        __p__ = top,
    } or {
        ns = namespace or "",
        rn = resolved,
        tg = tag,
        at = at,
        dt = { },
        ni = nt, -- set slot, needed for css filtering
        __p__ = top,
    }
    dt[nt] = t
    setmetatable(t, mt)
    if at.xmlns then
        remove(xmlns)
    end
    at = { }
end

local function add_begin(spacing, namespace, tag)
    if spacing ~= "" then
        nt = nt + 1
        dt[nt] = spacing
    end
    local resolved = namespace == "" and xmlns[#xmlns] or nsremap[namespace] or namespace
    dt = { }
    top = linenumbers and {
        ns = namespace or "",
        rn = resolved,
        tg = tag,
        at = at,
        dt = dt,
        ni = nil, -- preset slot, needed for css filtering
        cf = currentfilename,
        cl = currentline,
        __p__ = stack[level],
    } or {
        ns = namespace or "",
        rn = resolved,
        tg = tag,
        at = at,
        dt = dt,
        ni = nil, -- preset slot, needed for css filtering
        __p__ = stack[level],
    }
    setmetatable(top, mt)
    nt = 0
    level = level + 1
    stack[level] = top
    at = { }
end

local function add_end(spacing, namespace, tag)
    if spacing ~= "" then
        nt = nt + 1
        dt[nt] = spacing
    end
    local toclose = stack[level]
    level = level - 1
    top = stack[level]
    if level < 1 then
        errorstr = formatters["unable to close %s %s"](tag,xml.checkerror(top,toclose) or "")
        report_xml(errorstr)
    elseif toclose.tg ~= tag then -- no namespace check
        errorstr = formatters["unable to close %s with %s %s"](toclose.tg,tag,xml.checkerror(top,toclose) or "")
        report_xml(errorstr)
    end
    dt = top.dt
    nt = #dt + 1
    dt[nt] = toclose
    toclose.ni = nt -- update slot, needed for css filtering
    if toclose.at.xmlns then
        remove(xmlns)
    end
end

-- local spaceonly = lpegpatterns.whitespace^0 * P(-1)
--
-- will be an option: dataonly
--
-- if #text == 0 or     lpegmatch(spaceonly,text) then
--     return
-- end

local function add_text(text)
    if text == "" then
        return
    end
    if cleanup then
        if nt > 0 then
            local s = dt[nt]
            if type(s) == "string" then
                dt[nt] = s .. cleanup(text)
            else
                nt = nt + 1
                dt[nt] = cleanup(text)
            end
        else
            nt = 1
            dt[1] = cleanup(text)
        end
    else
        if nt > 0 then
            local s = dt[nt]
            if type(s) == "string" then
                dt[nt] = s .. text
            else
                nt = nt + 1
                dt[nt] = text
            end
        else
            nt = 1
            dt[1] = text
        end
    end
end

local function add_special(what, spacing, text)
    if spacing ~= "" then
        nt = nt + 1
        dt[nt] = spacing
    end
    if strip and (what == "@cm@" or what == "@dt@") then
        -- forget it
    else
        nt = nt + 1
        dt[nt] = linenumbers and {
            special = true,
            ns      = "",
            tg      = what,
            ni      = nil, -- preset slot
            dt      = { text },
            cf      = currentfilename,
            cl      = currentline,
        } or {
            special = true,
            ns      = "",
            tg      = what,
            ni      = nil, -- preset slot
            dt      = { text },
        }
    end
end

local function set_message(txt)
    errorstr = "garbage at the end of the file: " .. gsub(txt,"([ \n\r\t]*)","")
end

local function attribute_value_error(str)
    if not reported_at_errors[str] then
        report_xml("invalid attribute value %a",str)
        reported_at_errors[str] = true
        at._error_ = str
    end
    return str
end

local function attribute_specification_error(str)
    if not reported_at_errors[str] then
        report_xml("invalid attribute specification %a",str)
        reported_at_errors[str] = true
        at._error_ = str
    end
    return str
end

-- I'm sure that this lpeg can be simplified (less captures) but it evolved ...
-- so i'm not going to change it now.

do

    -- In order to overcome lua limitations we wrap entity stuff in a closure.

    local badentity = "&" -- was "&error;"

    xml.placeholders = {
        unknown_dec_entity = function(str) return str == "" and badentity or formatters["&%s;"](str) end,
        unknown_hex_entity = function(str) return formatters["&#x%s;"](str) end,
        unknown_any_entity = function(str) return formatters["&#x%s;"](str) end,
    }

    local function fromhex(s)
        local n = tonumber(s,16)
        if n then
            return utfchar(n)
        else
            return formatters["h:%s"](s), true
        end
    end

    local function fromdec(s)
        local n = tonumber(s)
        if n then
            return utfchar(n)
        else
            return formatters["d:%s"](s), true
        end
    end

    local p_rest = (1-P(";"))^0
    local p_many = P(1)^0

    local parsedentity =
        P("&#") * (P("x")*(p_rest/fromhex) + (p_rest/fromdec)) * P(";") * P(-1) +
        P ("#") * (P("x")*(p_many/fromhex) + (p_many/fromdec))

    xml.parsedentitylpeg = parsedentity

    -- parsing in the xml file

    local predefined_unified = {
        [38] = "&amp;",
        [42] = "&quot;",
        [47] = "&apos;",
        [74] = "&lt;",
        [76] = "&gt;",
    }

    local predefined_simplified = {
        [38] = "&", amp  = "&",
        [42] = '"', quot = '"',
        [47] = "'", apos = "'",
        [74] = "<", lt   = "<",
        [76] = ">", gt   = ">",
    }

    local nofprivates = 0xF0000 -- shared but seldom used

    local privates_u = { -- unescaped
        [ [[&]] ] = "&amp;",
        [ [["]] ] = "&quot;",
        [ [[']] ] = "&apos;",
        [ [[<]] ] = "&lt;",
        [ [[>]] ] = "&gt;",
    }

    local privates_p = { -- needed for roundtrip as well as serialize to tex
    }

    local privates_s = { -- for tex
        [ [["]] ] = "&U+22;",
        [ [[#]] ] = "&U+23;",
        [ [[$]] ] = "&U+24;",
        [ [[%]] ] = "&U+25;",
        [ [[&]] ] = "&U+26;",
        [ [[']] ] = "&U+27;",
        [ [[<]] ] = "&U+3C;",
        [ [[>]] ] = "&U+3E;",
        [ [[\]] ] = "&U+5C;",
        [ [[{]] ] = "&U+7B;",
        [ [[|]] ] = "&U+7C;",
        [ [[}]] ] = "&U+7D;",
        [ [[~]] ] = "&U+7E;",
    }

    local privates_x = { -- for xml
        [ [["]] ] = "&U+22;",
        [ [[#]] ] = "&U+23;",
        [ [[$]] ] = "&U+24;",
        [ [[%]] ] = "&U+25;",
        [ [[']] ] = "&U+27;",
        [ [[\]] ] = "&U+5C;",
        [ [[{]] ] = "&U+7B;",
        [ [[|]] ] = "&U+7C;",
        [ [[}]] ] = "&U+7D;",
        [ [[~]] ] = "&U+7E;",
    }

    local privates_n = { -- keeps track of defined ones
    }

    local escaped       = utf.remapper(privates_u,"dynamic")
    local unprivatized  = utf.remapper(privates_p,"dynamic")
    local unspecialized = utf.remapper(privates_s,"dynamic")
    local despecialized = utf.remapper(privates_x,"dynamic")

    xml.unprivatized  = unprivatized
    xml.unspecialized = unspecialized
    xml.despecialized = despecialized
    xml.escaped       = escaped

    local function unescaped(s)
        local p = privates_n[s]
        if not p then
            nofprivates = nofprivates + 1
            p = utfchar(nofprivates)
            privates_n[s] = p
            s = "&" .. s .. ";" -- todo: use char-ent to map to hex
            privates_u[p] = s
            privates_p[p] = s
            privates_s[p] = s
        end
        return p
    end

    xml.privatetoken = unescaped
    xml.privatecodes = privates_n
    xml.specialcodes = privates_s

    function xml.addspecialcode(key,value)
        privates_s[key] = value or "&" .. s .. ";"
    end

    handle_hex_entity = function(str)
        local h = hcache[str]
        if not h then
            local n = tonumber(str,16)
            h = unify_predefined and predefined_unified[n]
            if h then
                if trace_entities then
                    report_xml("utfize, converting hex entity &#x%s; into %a",str,h)
                end
            elseif utfize then
                h = (n and utfchar(n)) or xml.unknown_hex_entity(str) or ""
                if not n then
                    report_xml("utfize, ignoring hex entity &#x%s;",str)
                elseif trace_entities then
                    report_xml("utfize, converting hex entity &#x%s; into %a",str,h)
                end
            else
                if trace_entities then
                    report_xml("found entity &#x%s;",str)
                end
                h = "&#x" .. str .. ";"
            end
            hcache[str] = h
        end
        return h
    end

    handle_dec_entity = function(str)
        local d = dcache[str]
        if not d then
            local n = tonumber(str)
            d = unify_predefined and predefined_unified[n]
            if d then
                if trace_entities then
                    report_xml("utfize, converting dec entity &#%s; into %a",str,d)
                end
            elseif utfize then
                d = (n and utfchar(n)) or placeholders.unknown_dec_entity(str) or ""
                if not n then
                    report_xml("utfize, ignoring dec entity &#%s;",str)
                elseif trace_entities then
                    report_xml("utfize, converting dec entity &#%s; into %a",str,d)
                end
            else
                if trace_entities then
                    report_xml("found entity &#%s;",str)
                end
                d = "&#" .. str .. ";"
            end
            dcache[str] = d
        end
        return d
    end

    handle_any_entity_dtd = function(str)
        if resolve then
            local a = resolve_predefined and predefined_simplified[str] -- true by default
            if a then
                if trace_entities then
                    report_xml("resolving entity &%s; to predefined %a",str,a)
                end
            else
                if type(resolve) == "function" then
                    a = resolve(str,entities) or entities[str]
                else
                    a = entities[str]
                end
                if a then
                    if type(a) == "function" then
                        if trace_entities then
                            report_xml("expanding entity &%s; to function call",str)
                        end
                        a = a(str) or ""
                    end
                    a = lpegmatch(parsedentity,a) or a -- for nested
                    if trace_entities then
                        report_xml("resolving entity &%s; to internal %a",str,a)
                    end
                else
                    local unknown_any_entity = placeholders.unknown_any_entity
                    if unknown_any_entity then
                        a = unknown_any_entity(str) or ""
                    end
                    if a then
                        if trace_entities then
                            report_xml("resolving entity &%s; to external %s",str,a)
                        end
                    else
                        if trace_entities then
                            report_xml("keeping entity &%s;",str)
                        end
                        if str == "" then
                            a = badentity
                        else
                            a = "&" .. str .. ";"
                        end
                    end
                end
            end
            return a
        else
            local a = acache[str]
            if not a then
                a = resolve_predefined and predefined_simplified[str]
                if a then
                    -- one of the predefined
                    acache[str] = a
                    if trace_entities then
                        report_xml("entity &%s; becomes %a",str,a)
                    end
                elseif str == "" then
                    if trace_entities then
                        report_xml("invalid entity &%s;",str)
                    end
                    a = badentity
                    acache[str] = a
                else
                    if trace_entities then
                        report_xml("entity &%s; is made private",str)
                    end
                 -- a = "&" .. str .. ";"
                    a = unescaped(str)
                    acache[str] = a
                end
            end
            return a
        end
    end

    handle_any_entity_text = function(str)
        if resolve then
            local a = resolve_predefined and predefined_simplified[str]
            if a then
                if trace_entities then
                    report_xml("resolving entity &%s; to predefined %a",str,a)
                end
            else
                if type(resolve) == "function" then
                    a = resolve(str,entities) or entities[str]
                else
                    a = entities[str]
                end
                if a then
                    if type(a) == "function" then
                        if trace_entities then
                            report_xml("expanding entity &%s; to function call",str)
                        end
                        a = a(str) or ""
                    end
                    a = lpegmatch(grammar_parsed_text_two,a) or a
                    if type(a) == "number" then
                        return ""
                    else
                        a = lpegmatch(parsedentity,a) or a -- for nested
                        if trace_entities then
                            report_xml("resolving entity &%s; to internal %a",str,a)
                        end
                    end
                    if trace_entities then
                        report_xml("resolving entity &%s; to internal %a",str,a)
                    end
                else
                    local unknown_any_entity = placeholders.unknown_any_entity
                    if unknown_any_entity then
                        a = unknown_any_entity(str) or ""
                    end
                    if a then
                        if trace_entities then
                            report_xml("resolving entity &%s; to external %s",str,a)
                        end
                    else
                        if trace_entities then
                            report_xml("keeping entity &%s;",str)
                        end
                        if str == "" then
                            a = badentity
                        else
                            a = "&" .. str .. ";"
                        end
                    end
                end
            end
            return a
        else
            local a = acache[str]
            if not a then
                a = resolve_predefined and predefined_simplified[str]
                if a then
                    -- one of the predefined
                    acache[str] = a
                    if trace_entities then
                        report_xml("entity &%s; becomes %a",str,a)
                    end
                elseif str == "" then
                    if trace_entities then
                        report_xml("invalid entity &%s;",str)
                    end
                    a = badentity
                    acache[str] = a
                else
                    if trace_entities then
                        report_xml("entity &%s; is made private",str)
                    end
                 -- a = "&" .. str .. ";"
                    a = unescaped(str)
                    acache[str] = a
                end
            end
            return a
        end
    end

    -- for tex

    local p_rest = (1-P(";"))^1

    local spec = {
        [0x23] = "\\Ux{23}", -- #
        [0x24] = "\\Ux{24}", -- $
        [0x25] = "\\Ux{25}", -- %
        [0x5C] = "\\Ux{5C}", -- \
        [0x7B] = "\\Ux{7B}", -- {
        [0x7C] = "\\Ux{7C}", -- |
        [0x7D] = "\\Ux{7D}", -- }
        [0x7E] = "\\Ux{7E}", -- ~
    }

    local hash = table.setmetatableindex(spec,function(t,k)
        local v = utfchar(k)
        t[k] = v
        return v
    end)

    local function fromuni(s)
        local n = tonumber(s,16)
        if n then
            return hash[n]
        else
            return formatters["u:%s"](s), true
        end
    end

    local function fromhex(s)
        local n = tonumber(s,16)
        if n then
            return hash[n]
        else
            return formatters["h:%s"](s), true
        end
    end

    local function fromdec(s)
        local n = tonumber(s)
        if n then
            return hash[n]
        else
            return formatters["d:%s"](s), true
        end
    end

    local reparsedentity =
        P("U+") * (p_rest/fromuni)
      + P("#")  * (
            P("x") * (p_rest/fromhex)
          + p_rest/fromdec
        )

    local hash = table.setmetatableindex(function(t,k)
        local v = utfchar(k)
        t[k] = v
        return v
    end)

    local function fromuni(s)
        local n = tonumber(s,16)
        if n then
            return hash[n]
        else
            return formatters["u:%s"](s), true
        end
    end

    local function fromhex(s)
        local n = tonumber(s,16)
        if n then
            return hash[n]
        else
            return formatters["h:%s"](s), true
        end
    end

    local function fromdec(s)
        local n = tonumber(s)
        if n then
            return hash[n]
        else
            return formatters["d:%s"](s), true
        end
    end

    local unescapedentity =
        P("U+") * (p_rest/fromuni)
      + P("#")  * (
            P("x") * (p_rest/fromhex)
          + p_rest/fromdec
        )

    xml.reparsedentitylpeg  = reparsedentity   -- with \Ux{...} for special tex entities
    xml.unescapedentitylpeg = unescapedentity  -- normal characters

end

-- we use these later on

local escaped      = xml.escaped
local unescaped    = xml.unescaped
local placeholders = xml.placeholders

--

local function handle_end_entity(str)
    report_xml("error in entity, %a found without ending %a",str,";")
    return str
end

local function handle_crap_error(chr)
    report_xml("error in parsing, unexpected %a found ",chr)
    add_text(chr)
    return chr
end

local function handlenewline()
    currentline = currentline + 1
end

-- first = ":" | [A-Z] | "_" | [a-z] | [#xC0-#xD6] | [#xD8-#xF6] | [#x00F8-#x02FF] |
--         [#x0370-#x037D] | [#x037F-#x1FFF] | [#x200C-#x200D] | [#x2070-#x218F] |
--         [#x2C00-#x2FEF] | [#x3001-#xD7FF] | [#xF900-#xFDCF] | [#xFDF0-#xFFFD] |
--         [#x10000-#xEFFFF]
-- rest  = "-" | "." | [0-9] | #xB7 | [#x300-#x36F] | [#x203F-#x2040]
-- name  = first + (first + rest)^1
--
-- We assume utf and do no real checking!

local spacetab         = S(' \t')
local space            = S(' \r\n\t')
local newline          = lpegpatterns.newline / handlenewline
local anything         = P(1)
local open             = P('<')
local close            = P('>')
local squote           = S("'")
local dquote           = S('"')
local equal            = P('=')
local slash            = P('/')
local colon            = P(':')
local semicolon        = P(';')
local ampersand        = P('&')
----- valid_0          = lpegpatterns.utf8two + lpegpatterns.utf8three + lpegpatterns.utf8four
local valid_0          = R("\128\255") -- basically any encoding without checking (fast)
local valid_1          = R('az', 'AZ') + S('_') + valid_0
local valid_2          = valid_1 + R('09') + S('-.')
local valid            = valid_1 * valid_2^0
local name_yes         = C(valid^1) * colon * C(valid^1)
local name_nop         = C(P(true)) * C(valid^1)
local name             = name_yes + name_nop
local utfbom           = lpegpatterns.utfbom -- no capture
local spacing          = C(space^0)

local space_nl         = spacetab + newline
local spacing_nl       = Cs((space_nl)^0)
local anything_nl      = newline + P(1)

local function weirdentity(k,v)
    if trace_entities then
        report_xml("registering %s entity %a as %a","weird",k,v)
    end
    parameters[k] = v
end
local function normalentity(k,v)
    if trace_entities then
        report_xml("registering %s entity %a as %a","normal",k,v)
    end
    entities[k] = v
end
local function systementity(k,v,n)
    if trace_entities then
        report_xml("registering %s entity %a as %a","system",k,v)
    end
    entities[k] = v
end
local function publicentity(k,v,n)
    if trace_entities then
        report_xml("registering %s entity %a as %a","public",k,v)
    end
    entities[k] = v
end
local function entityfile(pattern,k,v,n)
    if n then
        local okay, data
        local loadbinfile = resolvers and resolvers.loadbinfile
        if loadbinfile then
            okay, data = loadbinfile(n)
        else
            data = io.loaddata(n)
            okay = data and data ~= ""
        end
        if okay then
            if trace_entities then
                report_xml("loading public entities %a as %a from %a",k,v,n)
            end
            lpegmatch(pattern,data)
            return
        end
    end
    report_xml("ignoring public entities %a as %a from %a",k,v,n)
end

local function install(spacenewline,spacing,anything)

    local anyentitycontent = (1-open-semicolon-space-close-ampersand)^0
    local hexentitycontent = R("AF","af","09")^1
    local decentitycontent = R("09")^1
    local parsedentity     = P("#")/"" * (
                                    P("x")/"" * (hexentitycontent/handle_hex_entity) +
                                                (decentitycontent/handle_dec_entity)
                                ) +             (anyentitycontent/handle_any_entity_dtd) -- can be Cc(true)
    local parsedentity_text= P("#")/"" * (
                                    P("x")/"" * (hexentitycontent/handle_hex_entity) +
                                                (decentitycontent/handle_dec_entity)
                                ) +             (anyentitycontent/handle_any_entity_text) -- can be Cc(false)
    local entity           = (ampersand/"") * parsedentity   * (semicolon/"")
                           + ampersand * (anyentitycontent / handle_end_entity)
    local entity_text      = (ampersand/"") * parsedentity_text * (semicolon/"")
                           + ampersand * (anyentitycontent / handle_end_entity)

    local text_unparsed    = Cs((anything-open)^1)
    local text_parsed      = (Cs((anything-open-ampersand)^1)/add_text + Cs(entity_text)/add_text)^1

    local somespace        = (spacenewline)^1
    local optionalspace    = (spacenewline)^0

    local value            = (squote * Cs((entity + (anything - squote))^0) * squote) + (dquote * Cs((entity + (anything - dquote))^0) * dquote) -- ampersand and < also invalid in value

    local endofattributes  = slash * close + close -- recovery of flacky html
    local whatever         = space * name * optionalspace * equal
    local wrongvalue       = Cs(P(entity + (1-space-endofattributes))^1) / attribute_value_error

    local attributevalue   = value + wrongvalue

    local attribute        = (somespace * name * optionalspace * equal * optionalspace * attributevalue) / add_attribute

 -- local attributes       = (attribute + somespace^-1 * (((1-endofattributes)^1)/attribute_specification_error))^0
    local attributes       = (attribute + somespace^-1 * (((anything-endofattributes)^1)/attribute_specification_error))^0

    local parsedtext       = text_parsed   -- / add_text
    local unparsedtext     = text_unparsed / add_text
    local balanced         = P { "[" * ((anything - S"[]") + V(1))^0 * "]" } -- taken from lpeg manual, () example

    local emptyelement     = (spacing * open         * name * attributes * optionalspace * slash * close) / add_empty
    local beginelement     = (spacing * open         * name * attributes * optionalspace         * close) / add_begin
    local endelement       = (spacing * open * slash * name              * optionalspace         * close) / add_end

    -- todo: combine the opens in:

    local begincomment     = open * P("!--")
    local endcomment       = P("--") * close
    local begininstruction = open * P("?")
    local endinstruction   = P("?") * close
    local begincdata       = open * P("![CDATA[")
    local endcdata         = P("]]") * close

    local someinstruction  = C((anything - endinstruction)^0)
    local somecomment      = C((anything - endcomment    )^0)
    local somecdata        = C((anything - endcdata      )^0)

    -- todo: separate dtd parser

    local begindoctype     = open * P("!DOCTYPE")
    local enddoctype       = close
    local beginset         = P("[")
    local endset           = P("]")
    local wrdtypename      = C((anything-somespace-P(";"))^1)
    local doctypename      = C((anything-somespace-close)^0)
    local elementdoctype   = optionalspace * P("<!ELEMENT") * (anything-close)^0 * close

    local basiccomment     = begincomment * ((anything - endcomment)^0) * endcomment

    local weirdentitytype  = P("%") * (somespace * doctypename * somespace * value) / weirdentity
    local normalentitytype = (doctypename * somespace * value) / normalentity
    local publicentitytype = (doctypename * somespace * P("PUBLIC") * somespace * value) / publicentity

    local systementitytype = (doctypename * somespace * P("SYSTEM") * somespace * value * somespace * P("NDATA") * somespace * doctypename)/systementity
    local entitydoctype    = optionalspace * P("<!ENTITY") * somespace * (systementitytype + publicentitytype + normalentitytype + weirdentitytype) * optionalspace * close

    local publicentityfile = (doctypename * somespace * P("PUBLIC") * somespace * value * (somespace * value)^0) / function(...)
        entityfile(entitydoctype,...)
    end

    local function weirdresolve(s)
        lpegmatch(entitydoctype,parameters[s])
    end

    local function normalresolve(s)
        lpegmatch(entitydoctype,entities[s])
    end

    local entityresolve    = P("%") * (wrdtypename/weirdresolve ) * P(";")
                           + P("&") * (wrdtypename/normalresolve) * P(";")

    entitydoctype          = entitydoctype + entityresolve

    -- we accept comments in doctypes

    local doctypeset       = beginset * optionalspace * P(elementdoctype + entitydoctype + entityresolve + basiccomment + space)^0 * optionalspace * endset
    local definitiondoctype= doctypename * somespace * doctypeset
    local publicdoctype    = doctypename * somespace * P("PUBLIC") * somespace * value * somespace * value * somespace * doctypeset
    local systemdoctype    = doctypename * somespace * P("SYSTEM") * somespace * value * somespace * doctypeset
    local simpledoctype    = (anything-close)^1 -- * balanced^0
    local somedoctype      = C((somespace * (

publicentityfile +

    publicdoctype + systemdoctype + definitiondoctype + simpledoctype) * optionalspace)^0)

    local instruction      = (spacing * begininstruction * someinstruction * endinstruction) / function(...) add_special("@pi@",...) end
    local comment          = (spacing * begincomment     * somecomment     * endcomment    ) / function(...) add_special("@cm@",...) end
    local cdata            = (spacing * begincdata       * somecdata       * endcdata      ) / function(...) add_special("@cd@",...) end
    local doctype          = (spacing * begindoctype     * somedoctype     * enddoctype    ) / function(...) add_special("@dt@",...) end

    local crap_parsed     = anything - beginelement - endelement - emptyelement - begininstruction - begincomment - begincdata - ampersand
    local crap_unparsed   = anything - beginelement - endelement - emptyelement - begininstruction - begincomment - begincdata

    local parsedcrap      = Cs((crap_parsed^1 + entity_text)^1) / handle_crap_error
    local parsedcrap      = Cs((crap_parsed^1 + entity_text)^1) / handle_crap_error
    local unparsedcrap    = Cs((crap_unparsed              )^1) / handle_crap_error

    --  nicer but slower:
    --
    --  local instruction = (Cc("@pi@") * spacing * begininstruction * someinstruction * endinstruction) / add_special
    --  local comment     = (Cc("@cm@") * spacing * begincomment     * somecomment     * endcomment    ) / add_special
    --  local cdata       = (Cc("@cd@") * spacing * begincdata       * somecdata       * endcdata      ) / add_special
    --  local doctype     = (Cc("@dt@") * spacing * begindoctype     * somedoctype     * enddoctype    ) / add_special

    local trailer = space^0 * (text_unparsed/set_message)^0

    --  comment + emptyelement + text + cdata + instruction + V("parent"), -- 6.5 seconds on 40 MB database file
    --  text + comment + emptyelement + cdata + instruction + V("parent"), -- 5.8
    --  text + V("parent") + emptyelement + comment + cdata + instruction, -- 5.5

    -- local grammar_parsed_text = P { "preamble",
    --     preamble = utfbom^0 * instruction^0 * (doctype + comment + instruction)^0 * V("parent") * trailer,
    --     parent   = beginelement * V("children")^0 * endelement,
    --     children = parsedtext + V("parent") + emptyelement + comment + cdata + instruction + parsedcrap,
    -- }

    local grammar_parsed_text_one = P { "preamble",
        preamble = utfbom^0 * instruction^0 * (doctype + comment + instruction)^0,
    }

    local grammar_parsed_text_two = P { "followup",
        followup = V("parent") * trailer,
        parent   = beginelement * V("children")^0 * endelement,
        children = parsedtext + V("parent") + emptyelement + comment + cdata + instruction + parsedcrap,
    }

    local grammar_unparsed_text = P { "preamble",
        preamble = utfbom^0 * instruction^0 * (doctype + comment + instruction)^0 * V("parent") * trailer,
        parent   = beginelement * V("children")^0 * endelement,
        children = unparsedtext + V("parent") + emptyelement + comment + cdata + instruction + unparsedcrap,
    }

    return grammar_parsed_text_one, grammar_parsed_text_two, grammar_unparsed_text

end

local
    grammar_parsed_text_one_nop ,
    grammar_parsed_text_two_nop ,
    grammar_unparsed_text_nop   = install(space, spacing, anything)

local
    grammar_parsed_text_one_yes ,
    grammar_parsed_text_two_yes ,
    grammar_unparsed_text_yes   = install(space_nl, spacing_nl, anything_nl)

-- maybe we will add settings to result as well

local function _xmlconvert_(data,settings,detail)
    settings = settings or { } -- no_root strip_cm_and_dt given_entities parent_root error_handler
    preparexmlstate(settings)
    if settings.linenumbers then
        grammar_parsed_text_one = grammar_parsed_text_one_yes
        grammar_parsed_text_two = grammar_parsed_text_two_yes
        grammar_unparsed_text   = grammar_unparsed_text_yes
    else
        grammar_parsed_text_one = grammar_parsed_text_one_nop
        grammar_parsed_text_two = grammar_parsed_text_two_nop
        grammar_unparsed_text   = grammar_unparsed_text_nop
    end
    local preprocessor = settings.preprocessor
    if data and data ~= "" and type(preprocessor) == "function" then
        data = preprocessor(data,settings) or data -- settings.currentresource
    end
    if settings.parent_root then
        mt = getmetatable(settings.parent_root)
    else
        initialize_mt(top)
    end
    level = level + 1
    stack[level] = top
    top.dt = { }
    dt = top.dt
    nt = 0
    if not data or data == "" then
        errorstr = "empty xml file"
    elseif data == true then
        errorstr = detail or "problematic xml file"
    elseif utfize or resolve then
        local m = lpegmatch(grammar_parsed_text_one,data)
        if m then
            m = lpegmatch(grammar_parsed_text_two,data,m)
        end
     -- local m = lpegmatch(grammar_parsed_text,data)
        if m then
         -- errorstr = "" can be set!
        else
            errorstr = "invalid xml file - parsed text"
        end
    elseif type(data) == "string" then
        if lpegmatch(grammar_unparsed_text,data) then
            errorstr = ""
        else
            errorstr = "invalid xml file - unparsed text"
        end
    else
        errorstr = "invalid xml file - no text at all"
    end
    local result
    if errorstr and errorstr ~= "" then
        result = { dt = { { ns = "", tg = "error", dt = { errorstr }, at = { }, er = true } } }
        setmetatable(result, mt)
        setmetatable(result.dt[1], mt)
        setmetatable(stack, mt)
        local errorhandler = settings.error_handler
        if errorhandler == false then
            -- no error message
        else
            errorhandler = errorhandler or xml.errorhandler
            if errorhandler then
                local currentresource = settings.currentresource
                if currentresource and currentresource ~= "" then
                    xml.errorhandler(formatters["load error in [%s]: %s"](currentresource,errorstr),currentresource)
                else
                    xml.errorhandler(formatters["load error: %s"](errorstr))
                end
            end
        end
    else
        result = stack[1]
    end
    if not settings.no_root then
        result = { special = true, ns = "", tg = '@rt@', dt = result.dt, at={ }, entities = entities, settings = settings }
        setmetatable(result, mt)
        local rdt = result.dt
        for k=1,#rdt do
            local v = rdt[k]
            if type(v) == "table" and not v.special then -- always table -)
                result.ri = k -- rootindex
                v.__p__ = result  -- new, experiment, else we cannot go back to settings, we need to test this !
                break
            end
        end
    end
    if errorstr and errorstr ~= "" then
        result.error = true
    else
        errorstr = nil
    end
    result.statistics = {
        errormessage = errorstr,
        entities = {
            decimals      = dcache,
            hexadecimals  = hcache,
            names         = acache,
            intermediates = parameters,
        }
    }
    preparexmlstate() -- resets
    return result
end

-- Because we can have a crash (stack issues) with faulty xml, we wrap this one
-- in a protector:

local function xmlconvert(data,settings)
    local ok, result = pcall(function() return _xmlconvert_(data,settings) end)
    if ok then
        return result
    elseif type(result) == "string" then
        return _xmlconvert_(true,settings,result)
    else
        return _xmlconvert_(true,settings)
    end
end

xml.convert = xmlconvert

function xml.inheritedconvert(data,xmldata) -- xmldata is parent
    local settings = xmldata.settings
    if settings then
        settings.parent_root = xmldata -- to be tested
    end
 -- settings.no_root = true
    local xc = xmlconvert(data,settings) -- hm, we might need to locate settings
 -- xc.settings = nil
 -- xc.entities = nil
 -- xc.special = nil
 -- xc.ri = nil
 -- print(xc.tg)
    return xc
end

--[[ldx--
<p>Packaging data in an xml like table is done with the following
function. Maybe it will go away (when not used).</p>
--ldx]]--

function xml.is_valid(root)
    return root and root.dt and root.dt[1] and type(root.dt[1]) == "table" and not root.dt[1].er
end

function xml.package(tag,attributes,data)
    local ns, tg = match(tag,"^(.-):?([^:]+)$")
    local t = { ns = ns, tg = tg, dt = data or "", at = attributes or {} }
    setmetatable(t, mt)
    return t
end

function xml.is_valid(root)
    return root and not root.error
end

xml.errorhandler = report_xml

--[[ldx--
<p>We cannot load an <l n='lpeg'/> from a filehandle so we need to load
the whole file first. The function accepts a string representing
a filename or a file handle.</p>
--ldx]]--

function xml.load(filename,settings)
    local data = ""
    if type(filename) == "string" then
     -- local data = io.loaddata(filename) -- todo: check type in io.loaddata
        local f = io.open(filename,'r') -- why not 'rb'
        if f then
            data = f:read("*all") -- io.readall(f) ... only makes sense for large files
            f:close()
        end
    elseif filename then -- filehandle
        data = filename:read("*all") -- io.readall(f) ... only makes sense for large files
    end
    if settings then
        settings.currentresource = filename
        local result = xmlconvert(data,settings)
        settings.currentresource = nil
        return result
    else
        return xmlconvert(data,{ currentresource = filename })
    end
end

--[[ldx--
<p>When we inject new elements, we need to convert strings to
valid trees, which is what the next function does.</p>
--ldx]]--

local no_root = { no_root = true }

function xml.toxml(data)
    if type(data) == "string" then
        local root = { xmlconvert(data,no_root) }
        return (#root > 1 and root) or root[1]
    else
        return data
    end
end

--[[ldx--
<p>For copying a tree we use a dedicated function instead of the
generic table copier. Since we know what we're dealing with we
can speed up things a bit. The second argument is not to be used!</p>
--ldx]]--

-- local function copy(old)
--     if old then
--         local new = { }
--         for k,v in next, old do
--             if type(v) == "table" then
--                 new[k] = table.copy(v)
--             else
--                 new[k] = v
--             end
--         end
--         local mt = getmetatable(old)
--         if mt then
--             setmetatable(new,mt)
--         end
--         return new
--     else
--         return { }
--     end
-- end
--
-- We need to prevent __p__ recursio, so:

local function copy(old,p)
    if old then
        local new = { }
        for k, v in next, old do
            local t = type(v) == "table"
            if k == "at" then
                local t = { }
                for k, v in next, v do
                    t[k] = v
                end
                new[k] = t
            elseif k == "dt" then
                v.__p__ = nil
                v = copy(v,new)
                new[k] = v
                v.__p__ = p
            else
                new[k] = v -- so we also share entities, etc in root
            end
        end
        local mt = getmetatable(old)
        if mt then
            setmetatable(new,mt)
        end
        return new
    else
        return { }
    end
end

xml.copy = copy

--[[ldx--
<p>In <l n='context'/> serializing the tree or parts of the tree is a major
actitivity which is why the following function is pretty optimized resulting
in a few more lines of code than needed. The variant that uses the formatting
function for all components is about 15% slower than the concatinating
alternative.</p>
--ldx]]--

-- todo: add <?xml version='1.0' standalone='yes'?> when not present

function xml.checkbom(root) -- can be made faster
    if root.ri then
        local dt = root.dt
        for k=1,#dt do
            local v = dt[k]
            if type(v) == "table" and v.special and v.tg == "@pi@" and find(v.dt[1],"xml.*version=") then
                return
            end
        end
        insert(dt, 1, { special = true, ns = "", tg = "@pi@", dt = { "xml version='1.0' standalone='yes'" } } )
        insert(dt, 2, "\n" )
    end
end

--[[ldx--
<p>At the cost of some 25% runtime overhead you can first convert the tree to a string
and then handle the lot.</p>
--ldx]]--

-- new experimental reorganized serialize

local f_attribute = formatters['%s=%q']

-- we could reuse ats .. for high performance we could also
-- have a multiple handle calls instead of multiple arguments
-- but it's not that critical

local function verbose_element(e,handlers,escape) -- options
    local handle = handlers.handle
    local serialize = handlers.serialize
    local ens, etg, eat, edt, ern = e.ns, e.tg, e.at, e.dt, e.rn
    local ats = eat and next(eat) and { }
    if ats then
        -- we now sort attributes
        local n = 0
        for k in next, eat do
            n = n + 1
            ats[n] = k
        end
        if n == 1 then
            local k = ats[1]
            ats = f_attribute(k,escaped(eat[k]))
        else
            sort(ats)
            for i=1,n do
                local k = ats[i]
                ats[i] = f_attribute(k,escaped(eat[k]))
            end
            ats = concat(ats," ")
        end
    end
    if ern and trace_entities and ern ~= ens then
        ens = ern
    end
    local n = edt and #edt
    if ens ~= "" then
        if n and n > 0 then
            if ats then
                handle("<",ens,":",etg," ",ats,">")
            else
                handle("<",ens,":",etg,">")
            end
            for i=1,n do
                local e = edt[i]
                if type(e) == "string" then
                    handle(escaped(e))
                else
                    serialize(e,handlers)
                end
            end
            handle("</",ens,":",etg,">")
        else
            if ats then
                handle("<",ens,":",etg," ",ats,"/>")
            else
                handle("<",ens,":",etg,"/>")
            end
        end
    else
        if n and n > 0 then
            if ats then
                handle("<",etg," ",ats,">")
            else
                handle("<",etg,">")
            end
            for i=1,n do
                local e = edt[i]
                if type(e) == "string" then
                    handle(escaped(e)) -- option: hexify escaped entities
                else
                    serialize(e,handlers)
                end
            end
            handle("</",etg,">")
        else
            if ats then
                handle("<",etg," ",ats,"/>")
            else
                handle("<",etg,"/>")
            end
        end
    end
end

local function verbose_pi(e,handlers)
    handlers.handle("<?",e.dt[1],"?>")
end

local function verbose_comment(e,handlers)
    handlers.handle("<!--",e.dt[1],"-->")
end

local function verbose_cdata(e,handlers)
    handlers.handle("<![CDATA[", e.dt[1],"]]>")
end

local function verbose_doctype(e,handlers)
    handlers.handle("<!DOCTYPE",e.dt[1],">") -- has space at end of string
end

local function verbose_root(e,handlers)
    handlers.serialize(e.dt,handlers)
end

local function verbose_text(e,handlers)
    handlers.handle(escaped(e))
end

local function verbose_document(e,handlers)
    local serialize = handlers.serialize
    local functions = handlers.functions
    for i=1,#e do
        local ei = e[i]
        if type(ei) == "string" then
            functions["@tx@"](ei,handlers)
        else
            serialize(ei,handlers)
        end
    end
end

local function serialize(e,handlers,...)
    if e then
        local initialize = handlers.initialize
        local finalize   = handlers.finalize
        local functions  = handlers.functions
        if initialize then
            local state = initialize(...)
            if not state == true then
                return state
            end
        end
        local etg = e.tg
        if etg then
            (functions[etg] or functions["@el@"])(e,handlers)
     -- elseif type(e) == "string" then
     --     functions["@tx@"](e,handlers)
        else
            functions["@dc@"](e,handlers) -- dc ?
        end
        if finalize then
            return finalize()
        end
    end
end

local function xserialize(e,handlers)
    if e then
        local functions = handlers.functions
        local etg = e.tg
        if etg then
            (functions[etg] or functions["@el@"])(e,handlers)
     -- elseif type(e) == "string" then
     --     functions["@tx@"](e,handlers)
        else
            functions["@dc@"](e,handlers)
        end
    end
end

local handlers = { }

local function newhandlers(settings)
    local t = table.copy(handlers[settings and settings.parent or "verbose"] or { }) -- merge
    if settings then
        for k,v in next, settings do
            if type(v) == "table" then
                local tk = t[k] if not tk then tk = { } t[k] = tk end
                for kk, vv in next, v do
                    tk[kk] = vv
                end
            else
                t[k] = v
            end
        end
        if settings.name then
            handlers[settings.name] = t
        end
    end
    utilities.storage.mark(t)
    return t
end

local nofunction = function() end

function xml.sethandlersfunction(handler,name,fnc)
    handler.functions[name] = fnc or nofunction
end

function xml.gethandlersfunction(handler,name)
    return handler.functions[name]
end

function xml.gethandlers(name)
    return handlers[name]
end

newhandlers {
    name       = "verbose",
    initialize = false, -- faster than nil and mt lookup
    finalize   = false, -- faster than nil and mt lookup
    serialize  = xserialize,
    handle     = print,
    functions  = {
        ["@dc@"]   = verbose_document,
        ["@dt@"]   = verbose_doctype,
        ["@rt@"]   = verbose_root,
        ["@el@"]   = verbose_element,
        ["@pi@"]   = verbose_pi,
        ["@cm@"]   = verbose_comment,
        ["@cd@"]   = verbose_cdata,
        ["@tx@"]   = verbose_text,
    }
}

--[[ldx--
<p>How you deal with saving data depends on your preferences. For a 40 MB database
file the timing on a 2.3 Core Duo are as follows (time in seconds):</p>

<lines>
1.3 : load data from file to string
6.1 : convert string into tree
5.3 : saving in file using xmlsave
6.8 : converting to string using xml.tostring
3.6 : saving converted string in file
</lines>

<p>Beware, these were timing with the old routine but measurements will not be that
much different I guess.</p>
--ldx]]--

-- maybe this will move to lxml-xml

local result

local xmlfilehandler = newhandlers {
    name       = "file",
    initialize = function(name)
        result = io.open(name,"wb")
        return result
    end,
    finalize   = function()
        result:close()
        return true
    end,
    handle     = function(...)
        result:write(...)
    end,
}

-- no checking on writeability here but not faster either
--
-- local xmlfilehandler = newhandlers {
--     initialize = function(name)
--         io.output(name,"wb")
--         return true
--     end,
--     finalize   = function()
--         io.close()
--         return true
--     end,
--     handle     = io.write,
-- }

function xml.save(root,name)
    serialize(root,xmlfilehandler,name)
end

-- local result
--
-- local xmlstringhandler = newhandlers {
--     name       = "string",
--     initialize = function()
--         result = { }
--         return result
--     end,
--     finalize   = function()
--         return concat(result)
--     end,
--     handle     = function(...)
--         result[#result+1] = concat { ... }
--     end,
-- }

local result, r, threshold = { }, 0, 512

local xmlstringhandler = newhandlers {
    name       = "string",
    initialize = function()
        r = 0
        return result
    end,
    finalize   = function()
        local done = concat(result,"",1,r)
        r = 0
        if r > threshold then
            result = { }
        end
        return done
    end,
    handle     = function(...)
        for i=1,select("#",...) do
            r = r + 1
            result[r] = select(i,...)
        end
    end,
}

local function xmltostring(root) -- 25% overhead due to collecting
    if not root then
        return ""
    elseif type(root) == "string" then
        return root
    else -- if next(root) then -- next is faster than type (and >0 test)
        return serialize(root,xmlstringhandler) or ""
    end
end

local function __tostring(root) -- inline
    return (root and xmltostring(root)) or ""
end

initialize_mt = function(root) -- redefinition
    mt = { __tostring = __tostring, __index = root }
end

xml.defaulthandlers = handlers
xml.newhandlers     = newhandlers
xml.serialize       = serialize
xml.tostring        = xmltostring

--[[ldx--
<p>The next function operated on the content only and needs a handle function
that accepts a string.</p>
--ldx]]--

local function xmlstring(e,handle)
    if not handle or (e.special and e.tg ~= "@rt@") then
        -- nothing
    elseif e.tg then
        local edt = e.dt
        if edt then
            for i=1,#edt do
                xmlstring(edt[i],handle)
            end
        end
    else
        handle(e)
    end
end

xml.string = xmlstring

--[[ldx--
<p>A few helpers:</p>
--ldx]]--

--~ xmlsetproperty(root,"settings",settings)

function xml.settings(e)
    while e do
        local s = e.settings
        if s then
            return s
        else
            e = e.__p__
        end
    end
    return nil
end

function xml.root(e)
    local r = e
    while e do
        e = e.__p__
        if e then
            r = e
        end
    end
    return r
end

function xml.parent(root)
    return root.__p__
end

function xml.body(root)
    return root.ri and root.dt[root.ri] or root -- not ok yet
end

function xml.name(root)
    if not root then
        return ""
    end
    local ns = root.ns
    local tg = root.tg
    if ns == "" then
        return tg
    else
        return ns .. ":" .. tg
    end
end

--[[ldx--
<p>The next helper erases an element but keeps the table as it is,
and since empty strings are not serialized (effectively) it does
not harm. Copying the table would take more time. Usage:</p>
--ldx]]--

function xml.erase(dt,k)
    if dt then
        if k then
            dt[k] = ""
        else for k=1,#dt do
            dt[1] = { "" }
        end end
    end
end

--[[ldx--
<p>The next helper assigns a tree (or string). Usage:</p>

<typing>
dt[k] = xml.assign(root) or xml.assign(dt,k,root)
</typing>
--ldx]]--

function xml.assign(dt,k,root)
    if dt and k then
        dt[k] = type(root) == "table" and xml.body(root) or root
        return dt[k]
    else
        return xml.body(root)
    end
end

-- the following helpers may move

--[[ldx--
<p>The next helper assigns a tree (or string). Usage:</p>
<typing>
xml.tocdata(e)
xml.tocdata(e,"error")
</typing>
--ldx]]--

function xml.tocdata(e,wrapper) -- a few more in the aux module
    local whatever = type(e) == "table" and xmltostring(e.dt) or e or ""
    if wrapper then
        whatever = formatters["<%s>%s</%s>"](wrapper,whatever,wrapper)
    end
    local t = { special = true, ns = "", tg = "@cd@", at = { }, rn = "", dt = { whatever }, __p__ = e }
    setmetatable(t,getmetatable(e))
    e.dt = { t }
end

function xml.makestandalone(root)
    if root.ri then
        local dt = root.dt
        for k=1,#dt do
            local v = dt[k]
            if type(v) == "table" and v.special and v.tg == "@pi@" then
                local txt = v.dt[1]
                if find(txt,"xml.*version=") then
                    v.dt[1] = txt .. " standalone='yes'"
                    break
                end
            end
        end
    end
    return root
end

function xml.kind(e)
    local dt = e and e.dt
    if dt then
        local n = #dt
        if n == 1 then
            local d = dt[1]
            if d.special then
                local tg = d.tg
                if tg == "@cd@" then
                    return "cdata"
                elseif tg == "@cm" then
                    return "comment"
                elseif tg == "@pi@" then
                    return "instruction"
                elseif tg == "@dt@" then
                    return "declaration"
                end
            elseif type(d) == "string" then
                return "text"
            end
            return "element"
        elseif n > 0 then
            return "mixed"
        end
    end
    return "empty"
end
