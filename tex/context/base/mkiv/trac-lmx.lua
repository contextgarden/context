if not modules then modules = { } end modules ['trac-lmx'] = {
    version   = 1.002,
    comment   = "companion to trac-lmx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this one will be adpated to the latest helpers

local type, tostring, rawget, loadstring, pcall = type, tostring, rawget, loadstring, pcall
local format, sub, gsub = string.format, string.sub, string.gsub
local concat = table.concat
local collapsespaces = string.collapsespaces
local P, Cc, Cs, C, Carg, lpegmatch = lpeg.P, lpeg.Cc, lpeg.Cs, lpeg.C, lpeg.Carg, lpeg.match
local joinpath, replacesuffix, pathpart, filesuffix = file.join, file.replacesuffix, file.pathpart, file.suffix

local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex

----- trace_templates   = false  trackers  .register("lmx.templates",      function(v) trace_templates = v end)
local trace_variables   = false  trackers  .register("lmx.variables",      function(v) trace_variables = v end)

local cache_templates   = true   directives.register("lmx.cache.templates",function(v) cache_templates = v end)
local cache_files       = true   directives.register("lmx.cache.files",    function(v) cache_files     = v end)

local report_lmx        = logs.reporter("lmx")
local report_error      = logs.reporter("lmx","error")

lmx                     = lmx or { }
local lmx               = lmx

-- This will change: we will just pass the global defaults as argument, but then we need
-- to rewrite some older code or come up with an ugly trick.

local lmxvariables = {
    ['title-default']           = 'ConTeXt LMX File',
    ['color-background-green']  = '#4F6F6F',
    ['color-background-blue']   = '#6F6F8F',
    ['color-background-yellow'] = '#8F8F6F',
    ['color-background-purple'] = '#8F6F8F',
    ['color-background-body']   = '#808080',
    ['color-background-main']   = '#3F3F3F',
}

local lmxinherited = {
    ['title']                   = 'title-default',
    ['color-background-one']    = 'color-background-green',
    ['color-background-two']    = 'color-background-blue',
    ['color-background-three']  = 'color-background-one',
    ['color-background-four']   = 'color-background-two',
}

lmx.variables = lmxvariables
lmx.inherited = lmxinherited

setmetatableindex(lmxvariables,function(t,k)
    k = lmxinherited[k]
    while k do
        local v = rawget(lmxvariables,k)
        if v then
            return v
        end
        k = lmxinherited[k]
    end
end)

function lmx.set(key,value)
    lmxvariables[key] = value
end

function lmx.get(key)
    return lmxvariables[key] or ""
end

lmx.report = report_lmx

-- helpers

-- the variables table is an empty one that gets linked to a defaults table
-- that gets passed with a creation (first time only) and that itself links
-- to one that gets passed to the converter

local variables = { }  -- we assume no nesting
local result    = { }  -- we assume no nesting

local function do_print(one,two,...)
    if two then
        result[#result+1] = concat { one, two, ... }
    else
        result[#result+1] = one
    end
end

-- Although it does not make much sense for most elements, we provide a mechanism
-- to print wrapped content, something that is more efficient when we are constructing
-- tables.

local html = { }
lmx.html   = html

function html.td(str)
    if type(str) == "table" then
        for i=1,#str do -- spoils t !
            str[i] = format("<td>%s</td>",str[i] or "")
        end
        result[#result+1] = concat(str)
    else
        result[#result+1] = format("<td>%s</td>",str or "")
    end
end

function html.th(str)
    if type(str) == "table" then
        for i=1,#str do -- spoils t !
            str[i] = format("<th>%s</th>",str[i])
        end
        result[#result+1] = concat(str)
    else
        result[#result+1] = format("<th>%s</th>",str or "")
    end
end

function html.a(text,url)
    result[#result+1] = format("<a href=%q>%s</a>",url,text)
end

setmetatableindex(html,function(t,k)
    local f = format("<%s>%%s</%s>",k,k)
    local v = function(str) result[#result+1] = format(f,str or "") end
    t[k] = v
    return v
end)

-- Loading templates:

local function loadedfile(name)
    name = resolvers and resolvers.findfile and resolvers.findfile(name) or name
    local data = io.loaddata(name)
    if not data or data == "" then
        report_lmx("file %a is empty",name)
    end
    return data
end

local function loadedsubfile(name)
    return io.loaddata(resolvers and resolvers.findfile and resolvers.findfile(name) or name)
end

lmx.loadedfile = loadedfile

-- A few helpers (the next one could end up in l-lpeg):

local usedpaths = { }
local givenpath = nil

local do_nested_include = nil

local pattern = lpeg.replacer {
    ["&"] = "&amp;",
    [">"] = "&gt;",
    ["<"] = "&lt;",
    ['"'] = "&quot;",
}

local function do_escape(str)
    return lpegmatch(pattern,str) or str
end

local function do_variable(str)
    local value = variables[str]
    if not trace_variables then
        -- nothing
    elseif type(value) == "string" then
        if #value > 80 then
            report_lmx("variable %a is set to: %s ...",str,collapsespaces(sub(value,1,80)))
        else
            report_lmx("variable %a is set to: %s",str,collapsespaces(value))
        end
    elseif type(value) == "nil" then
        report_lmx("variable %a is set to: %s",str,"<!-- unset -->")
    else
        report_lmx("variable %a is set to: %S",str,value)
    end
    if type(value) == "function" then -- obsolete ... will go away
        return value(str)
    else
        return value
    end
end

local function do_type(str)
    if str and str ~= "" then
        result[#result+1] = format("<tt>%s</tt>",do_escape(str))
    end
end

local function do_fprint(str,...)
    if str and str ~= "" then
        result[#result+1] = format(str,...)
    end
end

local function do_eprint(str,...)
    if str and str ~= "" then
        result[#result+1] = lpegmatch(pattern,format(str,...))
    end
end

local function do_print_variable(str)
    local str = do_variable(str) -- variables[str]
    if str and str ~= "" then
        result[#result+1] = str
    end
end

local function do_type_variable(str)
    local str = do_variable(str) -- variables[str]
    if str and str ~= "" then
        result[#result+1] = format("<tt>%s</tt>",do_escape(str))
    end
end

local function do_include(filename,option)
    local data = loadedsubfile(filename)
    if (not data or data == "") and givenpath then
        data = loadedsubfile(joinpath(givenpath,filename))
    end
    if (not data or data == "") and type(usedpaths) == "table" then
        for i=1,#usedpaths do
            data = loadedsubfile(joinpath(usedpaths[i],filename))
            if data and data ~= "" then
                break
            end
        end
    end
    if not data or data == "" then
        data = format("<!-- unknown lmx include file: %s -->",filename)
        report_lmx("include file %a is empty",filename)
    else
     -- report_lmx("included file: %s",filename)
        data = do_nested_include(data)
    end
    if filesuffix(filename,"css") and option == "strip" then -- new
        data = lmx.stripcss(data)
    end
    return data
end

-- Flushers:

lmx.print     = do_print
lmx.type      = do_type
lmx.eprint    = do_eprint
lmx.fprint    = do_fprint

lmx.escape    = do_escape
lmx.urlescape = url.escape
lmx.variable  = do_variable
lmx.include   = do_include

lmx.inject    = do_print
lmx.finject   = do_fprint
lmx.einject   = do_eprint

lmx.pv        = do_print_variable
lmx.tv        = do_type_variable

-- The next functions set up the closure.

function lmx.initialize(d,v)
    if not v then
        setmetatableindex(d,lmxvariables)
        if variables ~= d then
            setmetatableindex(variables,d)
            if trace_variables then
                report_lmx("using chain: variables => given defaults => lmx variables")
            end
        elseif trace_variables then
            report_lmx("using chain: variables == given defaults => lmx variables")
        end
    elseif d ~= v then
        setmetatableindex(v,d)
        if d ~= lmxvariables then
            setmetatableindex(d,lmxvariables)
            if variables ~= v then
                setmetatableindex(variables,v)
                if trace_variables then
                    report_lmx("using chain: variables => given variables => given defaults => lmx variables")
                end
            elseif trace_variables then
                report_lmx("using chain: variables == given variables => given defaults => lmx variables")
            end
        else
            if variables ~= v then
                setmetatableindex(variables,v)
                if trace_variables then
                    report_lmx("using chain: variabes => given variables => given defaults")
                end
            elseif trace_variables then
                report_lmx("using chain: variables == given variables => given defaults")
            end
        end
    else
        setmetatableindex(v,lmxvariables)
        if variables ~= v then
            setmetatableindex(variables,v)
            if trace_variables then
                report_lmx("using chain: variables => given variables => lmx variables")
            end
        elseif trace_variables then
            report_lmx("using chain: variables == given variables => lmx variables")
        end
    end
    result = { }
end

function lmx.finalized()
    local collapsed = concat(result)
    result = { } -- free memory
    return collapsed
end

function lmx.getvariables()
    return variables
end

function lmx.reset()
    -- obsolete
end

-- Creation: (todo: strip <!-- -->)

-- local template = [[
-- return function(defaults,variables)
--
-- -- initialize
--
-- lmx.initialize(defaults,variables)
--
-- -- interface
--
-- local definitions = { }
-- local variables   = lmx.getvariables()
-- local html        = lmx.html
-- local inject      = lmx.print
-- local finject     = lmx.fprint
-- local einject     = lmx.eprint
-- local escape      = lmx.escape
-- local verbose     = lmx.type
--
-- -- shortcuts (sort of obsolete as there is no gain)
--
-- local p  = lmx.print
-- local f  = lmx.fprint
-- local v  = lmx.variable
-- local e  = lmx.escape
-- local t  = lmx.type
-- local pv = lmx.pv
-- local tv = lmx.tv
--
-- -- generator
--
-- %s
--
-- -- finalize
--
-- return lmx.finalized()
--
-- end
-- ]]

local template = [[
-- interface

local html        = lmx.html
local inject      = lmx.print
local finject     = lmx.fprint -- better use the following
local einject     = lmx.eprint -- better use the following
local injectf     = lmx.fprint
local injecte     = lmx.eprint
local injectfmt   = lmx.fprint
local injectesc   = lmx.eprint
local escape      = lmx.escape
local verbose     = lmx.type

local i_n_j_e_c_t = lmx.print

-- shortcuts (sort of obsolete as there is no gain)

local p  = lmx.print
local f  = lmx.fprint
local v  = lmx.variable
local e  = lmx.escape
local t  = lmx.type
local pv = lmx.pv
local tv = lmx.tv

local lmx_initialize   = lmx.initialize
local lmx_finalized    = lmx.finalized
local lmx_getvariables = lmx.getvariables

-- generator

return function(defaults,variables)

    lmx_initialize(defaults,variables)

    local definitions = { }
    local variables   = lmx_getvariables()

    %s -- the action: appends to result

    return lmx_finalized()

end
]]

local function savedefinition(definitions,tag,content)
    definitions[tag] = content
    return ""
end

local function getdefinition(definitions,tag)
    return definitions[tag] or ""
end

local whitespace     = lpeg.patterns.whitespace
local optionalspaces = whitespace^0

local dquote         = P('"')

local begincomment   = P("<!--") -- only makes sense when we in intercept pre|script|style
local endcomment     = P("-->")

local beginembedxml  = P("<?")
local endembedxml    = P("?>")

local beginembedcss  = P("/*")
local endembedcss    = P("*/")

local gobbledendxml  = (optionalspaces * endembedxml) / ""
----- argumentxml    = (1-gobbledendxml)^0
local argumentxml    = (whitespace^1 + dquote * C((1-dquote)^1) * dquote + C((1-gobbledendxml-whitespace)^1))^0

local gobbledendcss  = (optionalspaces * endembedcss) / ""
----- argumentcss    = (1-gobbledendcss)^0
local argumentcss    = (whitespace^1 + dquote * C((1-dquote)^1) * dquote + C((1-gobbledendcss-whitespace)^1))^0

local commentxml     = (begincomment * (1-endcomment)^0 * endcomment) / ""

local beginluaxml    = (beginembedxml * P("lua")) / ""
local endluaxml      = endembedxml / ""

local luacodexml     = beginluaxml
                     * (1-endluaxml)^1
                     * endluaxml

local beginluacss    = (beginembedcss * P("lua")) / ""
local endluacss      = endembedcss / ""

local luacodecss     = beginluacss
                     * (1-endluacss)^1
                     * endluacss

local othercode      = (1-beginluaxml-beginluacss)^1 / " i_n_j_e_c_t[==[%0]==] "

local includexml     = ((beginembedxml * P("lmx-include") * optionalspaces) / "")
                     * (argumentxml / do_include)
                     * gobbledendxml

local includecss     = ((beginembedcss * P("lmx-include") * optionalspaces) / "")
                     * (argumentcss / do_include)
                     * gobbledendcss

local definexml_b    = ((beginembedxml * P("lmx-define-begin") * optionalspaces) / "")
                     * argumentxml
                     * gobbledendxml

local definexml_e    = ((beginembedxml * P("lmx-define-end") * optionalspaces) / "")
                     * argumentxml
                     * gobbledendxml

local definexml_c    = C((1-definexml_e)^0)

local definexml      = (Carg(1) * C(definexml_b) * definexml_c * definexml_e) / savedefinition

local resolvexml     = ((beginembedxml * P("lmx-resolve") * optionalspaces) / "")
                     * ((Carg(1) * C(argumentxml)) / getdefinition)
                     * gobbledendxml

local definecss_b    = ((beginembedcss * P("lmx-define-begin") * optionalspaces) / "")
                     * argumentcss
                     * gobbledendcss

local definecss_e    = ((beginembedcss * P("lmx-define-end") * optionalspaces) / "")
                     * argumentcss
                     * gobbledendcss

local definecss_c    = C((1-definecss_e)^0)

local definecss      = (Carg(1) * C(definecss_b) * definecss_c * definecss_e) / savedefinition

local resolvecss     = ((beginembedcss * P("lmx-resolve") * optionalspaces) / "")
                     * ((Carg(1) * C(argumentcss)) / getdefinition)
                     * gobbledendcss

----- pattern_1      = Cs((commentxml + includexml + includecss + P(1))^0) -- get rid of xml comments asap .. not good enough: embedded css and script is in <!--  .. also <pre>
local pattern_1      = Cs((includexml + includecss + P(1))^0)
local pattern_2      = Cs((definexml + resolvexml + definecss + resolvecss + P(1))^0)
local pattern_3      = Cs((luacodexml + luacodecss + othercode)^0)

local cache = { }

local function lmxerror(str)
    report_error(str)
    return html.tt(str)
end

local function wrapper(converter,defaults,variables)
    local outcome, message = pcall(converter,defaults,variables)
    if not outcome then
        return lmxerror(format("error in conversion: %s",message))
    else
        return message
    end
end

do_nested_include = function(data) -- also used in include
    return lpegmatch(pattern_1,data)
end

local function lmxnew(data,defaults,nocache,path) -- todo: use defaults in calling routines
    data = data or ""
    local known = cache[data]
    if not known then
        givenpath = path
        usedpaths = lmxvariables.includepath or { }
        if type(usedpaths) == "string" then
            usedpaths = { usedpaths }
        end
        data = lpegmatch(pattern_1,data)
        data = lpegmatch(pattern_2,data,1,{})
        data = lpegmatch(pattern_3,data)
        local converted = loadstring(format(template,data))
        if converted then
            converted = converted()
        end
        defaults = defaults or { }
        local converter
        if converted then
            converter = function(variables)
                return wrapper(converted,defaults,variables)
            end
        else
            report_error("error in:\n%s\n:",data)
            converter = function() lmxerror("error in template") end
        end
        known = {
            data      = defaults.trace and data or "",
            variables = defaults,
            converter = converter,
        }
        if cache_templates and nocache ~= false then
            cache[data] = known
        end
    elseif variables then
        known.variables = variables
    end
    return known, known.variables
end

local function lmxresult(self,variables)
    if self then
        local converter = self.converter
        if converter then
            local converted = converter(variables)
            if trace_variables then -- will become templates
                report_lmx("converted size: %s",#converted)
            end
            return converted or lmxerror("no result from converter")
        else
            return lmxerror("invalid converter")
        end
    else
        return lmxerror("invalid specification")
    end
end

lmx.new    = lmxnew
lmx.result = lmxresult

local loadedfiles = { }

function lmx.convertstring(templatestring,variables,nocache,path)
    return lmxresult(lmxnew(templatestring,nil,nocache,path),variables)
end

function lmx.convertfile(templatefile,variables,nocache)
    if trace_variables then -- will become templates
        report_lmx("converting file %a",templatefile)
    end
    local converter = loadedfiles[templatefile]
    if not converter then
        converter = lmxnew(loadedfile(templatefile),nil,nocache,pathpart(templatefile))
        loadedfiles[templatefile] = converter
    end
    return lmxresult(converter,variables)
end

local function lmxconvert(templatefile,resultfile,variables,nocache) -- or (templatefile,variables)
    if trace_variables then -- will become templates
        report_lmx("converting file %a",templatefile)
    end
    if not variables and type(resultfile) == "table" then
        variables = resultfile
    end
    local converter = loadedfiles[templatefile]
    if not converter then
        converter = lmxnew(loadedfile(templatefile),nil,nocache,pathpart(templatefile))
        if cache_files then
            loadedfiles[templatefile] = converter
        end
    end
    local result = lmxresult(converter,variables)
    if resultfile then
        io.savedata(resultfile,result)
    else
        return result
    end
end

lmx.convert = lmxconvert

-- helpers

local nocomment    = (beginembedcss * (1 - endembedcss)^1 * endembedcss) / ""
local nowhitespace = whitespace^1 / " " -- ""
local semistripped = whitespace^1 / "" * P(";")
local stripper     = Cs((nocomment + semistripped + nowhitespace + 1)^1)

function lmx.stripcss(str)
    return lpegmatch(stripper,str)
end

function lmx.color(r,g,b,a)
    if r > 1 then
        r = 1
    end
    if g > 1 then
        g = 1
    end
    if b > 1 then
        b = 1
    end
    if not a then
        a= 0
    elseif a > 1 then
        a = 1
    end
    if a > 0 then
        return format("rgba(%s%%,%s%%,%s%%,%s)",r*100,g*100,b*100,a)
    else
        return format("rgb(%s%%,%s%%,%s%%)",r*100,g*100,b*100)
    end
end

-- these can be overloaded

lmx.lmxfile   = string.itself
lmx.htmfile   = string.itself
lmx.popupfile = os.launch

local function lmxmake(name,variables)
    local lmxfile = lmx.lmxfile(name)
    local htmfile = lmx.htmfile(name)
    if lmxfile == htmfile then
        htmfile = replacesuffix(lmxfile,"html")
    end
    lmxconvert(lmxfile,htmfile,variables)
    return htmfile
end

lmx.make = lmxmake

function lmx.show(name,variables)
    -- todo: pcall
    local htmfile = lmxmake(name,variables)
    -- lmx.popupfile(htmfile)
    return htmfile
end

-- Command line (will become mtx-lmx):

if arg then
    if     arg[1] == "--show"    then if arg[2] then lmx.show   (arg[2])                        end
    elseif arg[1] == "--convert" then if arg[2] then lmx.convert(arg[2], arg[3] or "temp.html") end
    end
else
    return lmx
end

-- Test 1:

-- inspect(lmx.result(lmx.new(io.loaddata("t:/sources/context-timing.lmx"))))

-- Test 2:

-- local str = [[
--     <?lmx-include context.css strip ?>
--     <test>
--         <?lmx-define-begin whatever?>some content a<?lmx-define-end ?>
--         <?lmx-define-begin somemore?>some content b<?lmx-define-end ?>
--         <more>
--             <?lmx-resolve whatever ?>
--             <?lua
--                 for i=1,10 do end
--             ?>
--             <?lmx-resolve somemore ?>
--         </more>
--         <td><?lua p(100) ?></td>
--         <td><?lua p(variables.a) ?></td>
--         <td><?lua p(variables.b) ?></td>
--         <td><?lua p(variables.c) ?></td>
--         <td><?lua pv('title-default') ?></td>
--     </test>
-- ]]

-- local defaults = { trace = true, a = 3, b = 3 }
-- local result = lmx.new(str,defaults)
-- inspect(result.data)
-- inspect(result.converter(defaults))
-- inspect(result.converter { a = 1 })
-- inspect(lmx.result(result, { b = 2 }))
-- inspect(lmx.result(result, { a = 20000, b = 40000 }))
