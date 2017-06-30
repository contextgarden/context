if not modules then modules = { } end modules ['x-ldx'] = {
    version   = 1.001,
    comment   = "companion to x-ldx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- --[[ldx--
-- <topic>Introduction</topic>
-- --ldx]]--

--[[ldx--
<source>Lua Documentation Module</source>

This file is part of the <logo label='context'/> documentation suite and
itself serves as an example of using <logo label='lua'/> in combination
with <logo label='tex'/>.

I will rewrite this using lpeg. On the other hand, we cannot expect proper
<logo label='tex'/> and for educational purposed the syntax might be wrong.

Todo: use the scite parser.
--ldx]]--

local banner = "version 1.0.1 - 2007+ - PRAGMA ADE / CONTEXT"

local report = logs.reporter("x-ldx")

--[[
This script needs a few libraries. Instead of merging the code here
we can use

<typing>
mtxrun --internal x-ldx.lua
</typing>

That way, the libraries included in the runner will be used.
]]--

-- libraries l-string.lua l-table.lua l-io.lua l-file.lua

-- begin library merge
-- end library merge

local gsub, find, sub = string.gsub, string.find, string.sub
local splitstring, emptystring = string.split, string.is_empty
local concat = table.concat

--[[
Just a demo comment line. We will handle such multiline comments but
only when they start and end at the beginning of a line. More rich
comments are tagged differently.
]]--

--[[ldx--
First we define a proper namespace for this module. The <q>l</q> stands for
<logo label='lua'/>, the <q>d</q> for documentation and the <q>x</q> for
<logo label='xml'/>.
--ldx]]--

if not ldx then ldx = { } end

--[[ldx--
We load the lua file into a table. The entries in this table themselves are
tables and have keys like <t>code</t> and <t>comment</t>.
--ldx]]--

function ldx.load(filename)
    local data = file.readdata(filename)
    local expr = "%s*%-%-%[%[ldx%-*%s*(.-)%s*%-%-ldx%]%]%-*%s*"
    local i, j, t = 0, 0, { }
    while true do
        local comment, ni
        ni, j, comment = find(data, expr, j)
        if not ni then break end
        t[#t+1] = { code = sub(data, i, ni-1) }
        t[#t+1] = { comment = comment }
        i = j + 1
    end
    local str = sub(data, i, #data)
    str = gsub(str, "^%s*(.-)%s*$", "%1")
    if str ~= "" then
        t[#t+1] = { code = str }
    end
    return t
end

--[[ldx--
We will tag keywords so that we can higlight them using a special font
or color. Users can extend this list when needed.
--ldx]]--

ldx.keywords = { }

--[[ldx--
Here come the reserved words:
--ldx]]--

ldx.keywords.reserved = {
    ["and"]      = 1,
    ["break"]    = 1,
    ["do"]       = 1,
    ["else"]     = 1,
    ["elseif"]   = 1,
    ["end"]      = 1,
    ["false"]    = 1,
    ["for"]      = 1,
    ["function"] = 1,
    ["if"]       = 1,
    ["in"]       = 1,
    ["local"]    = 1,
    ["nil"]      = 1,
    ["not"]      = 1,
    ["or"]       = 1,
    ["repeat"]   = 1,
    ["return"]   = 1,
    ["then"]     = 1,
    ["true"]     = 1,
    ["until"]    = 1,
    ["while"]    = 1
}

--[[ldx--
We need to escape a few tokens. We keep the hash local to the
definition but set it up only once, hence the <key>do</key>
construction.
--ldx]]--

do
    local e = { [">"] = "&gt;", ["<"] = "&lt;", ["&"] = "&amp;" }
    function ldx.escape(str)
        return (gsub(str, "([><&])",e))
    end
end

--[[ldx--
Enhancing the code is a bit tricky due to the fact that we have to
deal with strings and escaped quotes within these strings. Before we
mess around with the code, we hide the strings, and after that we
insert them again. Single and double quoted strings are tagged so
that we can use a different font to highlight them.
--ldx]]--

ldx.make_index = true

function ldx.enhance(data) -- i need to use lpeg and then we can properly autoindent -)
    local e = ldx.escape
    for k=1,#data do
        local v = data[k]
        if v.code then
            local dqs, sqs, com, cmt, cod = { }, { }, { }, { }, e(v.code)
            cod = gsub(cod, '\\"', "##d##")
            cod = gsub(cod, "\\'", "##s##")
            cod = gsub(cod, "%-%-%[%[.-%]%]%-%-", function(s)
                cmt[#cmt+1] = s
                return "<l<<<".. #cmt ..">>>l>"
            end)
            cod = gsub(cod, "%-%-([^\n]*)", function(s)
                com[#com+1] = s
                return "<c<<<".. #com ..">>>c>"
            end)
            cod = gsub(cod, "(%b\"\")", function(s)
                dqs[#dqs+1] = sub(s,2,-2) or ""
                return "<d<<<".. #dqs ..">>>d>"
            end)
            cod = gsub(cod, "(%b\'\')", function(s)
                sqs[#sqs+1] = sub(s,2,-2) or ""
                return "<s<<<".. #sqs ..">>>s>"
            end)
            cod = gsub(cod, "(%a+)",function(key)
                local class = ldx.keywords.reserved[key]
                if class then
                    return "<key class='" .. class .. "'>" .. key .. "</key>"
                else
                    return key
                end
            end)
            cod = gsub(cod, "<s<<<(%d+)>>>s>", function(s)
                return "<sqs>" .. sqs[tonumber(s)] .. "</sqs>"
            end)
            cod = gsub(cod, "<d<<<(%d+)>>>d>", function(s)
                return "<dqs>" .. dqs[tonumber(s)] .. "</dqs>"
            end)
            cod = gsub(cod, "<c<<<(%d+)>>>c>", function(s)
                return "<com>" .. com[tonumber(s)] .. "</com>"
            end)
            cod = gsub(cod, "<l<<<(%d+)>>>l>", function(s)
                return cmt[tonumber(s)]
            end)
            cod = gsub(cod, "##d##", "\\\"")
            cod = gsub(cod, "##s##", "\\\'")
            if ldx.make_index then
                local lines = splitstring(cod,"\n")
                local f = "(<key class='1'>function</key>)%s+([%w%.]+)%s*%("
                for k=1,#lines do
                    local v = lines[k]
                    -- functies
                    v = gsub(v,f,function(key, str)
                        return "<function>" .. str .. "</function>("
                    end)
                    -- variables
                    v = gsub(v,"^([%w][%w%,%s]-)(=[^=])",function(str, rest)
                        local t = splitstring(str,",%s*")
                        for k=1,#t do
                            t[k] = "<variable>" .. t[k] .. "</variable>"
                        end
                        return concat(t,", ") .. rest
                    end)
                    -- so far
                    lines[k] = v
                end
                v.code = concat(lines,"\n")
            else
                v.code = cod
            end
        end
    end
end

--[[ldx--
We're now ready to save the file in <logo label='xml'/> format. This boils
down to wrapping the code and comment as well as the whole document. We tag
lines in the code as such so that we don't need messy <t>CDATA</t> constructs
and by calculating the indentation we also avoid space troubles. It also makes
it possible to change the indentation afterwards.
--ldx]]--

local newmethod = true

function ldx.as_xml(data) -- ldx: not needed
    local t, cmode = { }, false
    t[#t+1] = "<?xml version='1.0' standalone='yes'?>\n"
    t[#t+1] = "\n<document xmlns:ldx='http://www.pragma-ade.com/schemas/ldx.rng' xmlns='http://www.pragma-ade.com/schemas/ldx.rng'>\n"
    for k=1,#data do
        local v = data[k]
        if v.code and not emptystring(v.code) then
            if newmethod then
                t[#t+1] = "\n<luacode><![CDATA[\n"
                t[#t+1] = v.code
                t[#t+1] = "]]></luacode>\n"
            else
                t[#t+1] = "\n<code>\n"
                local split = splitstring(v.code,"\n")
                for k=1,#split do -- make this faster
                    local v = split[k]
                    local a, b = find(v,"^(%s+)")
                    if v then v = gsub(v,"[\n\r ]+$","") end
                    if a and b then
                        v = sub(v,b+1,#v)
                        if cmode then
                            t[#t+1] = "<line comment='yes' n='" .. b .. "'>" .. v .. "</line>\n"
                        else
                            t[#t+1] = "<line n='" .. b .. "'>" .. v .. "</line>\n"
                        end
                    elseif emptystring(v) then
                        if cmode then
                            t[#t+1] = "<line comment='yes'/>\n"
                        else
                            t[#t+1] = "<line/>\n"
                        end
                    elseif find(v,"^%-%-%[%[") then
                        t[#t+1] = "<line comment='yes'>" .. v .. "</line>\n"
                        cmode= true
                    elseif find(v,"^%]%]%-%-") then
                        t[#t+1] = "<line comment='yes'>" .. v .. "</line>\n"
                        cmode= false
                    elseif cmode then
                        t[#t+1] = "<line comment='yes'>" .. v .. "</line>\n"
                    else
                        t[#t+1] = "<line>" .. v .. "</line>\n"
                    end
                end
                t[#t+1] = "</code>\n"
            end
        elseif v.comment then
            t[#t+1] = "\n<comment>\n" .. v.comment .. "\n</comment>\n"
        else
            -- cannot happen
        end
    end
    t[#t+1] = "\n</document>\n"
    return concat(t,"")
end

--[[ldx--
Saving the result is a trivial effort.
--ldx]]--

function ldx.save(filename,data)
    file.savedata(filename,ldx.as_xml(data))
end

--[[ldx--
The next function wraps it all in one call:
--ldx]]--

function ldx.convert(luaname,ldxname)
    if not lfs.isfile(luaname) then
        file.addsuffix(luaname,"lua")
    end
    if lfs.isfile(luaname) then
        if not ldxname then
            ldxname = file.replacesuffix(luaname,"ldx")
        end
        report("converting file %a to %a",luaname,ldxname)
        local data = ldx.load(luaname)
        if data then
--             ldx.enhance(data)
            if ldxname ~= luaname then
                ldx.save(ldxname,data)
            end
        else
            report("invalid file %a",luaname)
        end
    else
        report("unknown file %a",luaname)
    end
end

--[[ldx--
This module can be used directly:

<typing>
mtxrun --internal x-ldx somefile.lua
</typing>

will produce an ldx file that can be processed with <logo label='context'/>
by running:

<typing>
context --use=x-ldx --forcexml somefile.ldx
</typing>

You can do this in one step by saying:

<typing>
context --ctx=x-ldx somefile.lua
</typing>

This will trigger <logo label='context'/> into loading the mentioned
<logo label='ctx'/> file. That file describes the conversion as well
as the module to be used.

The main conversion call is:
--ldx]]--

-- todo: assume usage of "mtxrun --script x-ldx", maybe make it mtx-ldx

if environment.files and environment.files[1] then
    ldx.convert(environment.files[1],environment.files[2])
else
    report("no file given")
end
