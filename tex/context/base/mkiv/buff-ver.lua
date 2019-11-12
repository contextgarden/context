if not modules then modules = { } end modules ['buff-ver'] = {
    version   = 1.001,
    comment   = "companion to buff-ver.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The default visualizers have reserved names starting with buff-imp-*. Users are
-- supposed to use different names for their own variants.
--
-- todo: skip=auto
--
-- todo: update to match context scite lexing

local type, next, rawset, rawget, setmetatable, getmetatable, tonumber = type, next, rawset, rawget, setmetatable, getmetatable, tonumber
local lower, upper,match, find, sub = string.lower, string.upper, string.match, string.find, string.sub
local splitlines = string.splitlines
local concat = table.concat
local C, P, R, S, V, Carg, Cc, Cs = lpeg.C, lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.Carg, lpeg.Cc, lpeg.Cs
local patterns, lpegmatch, is_lpeg = lpeg.patterns, lpeg.match, lpeg.is_lpeg

local trace_visualize      = false  trackers.register("buffers.visualize", function(v) trace_visualize = v end)
local report_visualizers   = logs.reporter("buffers","visualizers")

local allocate             = utilities.storage.allocate

visualizers                = visualizers or { }
local specifications       = allocate()
visualizers.specifications = specifications

local context              = context
local commands             = commands
local implement            = interfaces.implement

local formatters           = string.formatters

local tabtospace           = utilities.strings.tabtospace
local variables            = interfaces.variables
local settings_to_array    = utilities.parsers.settings_to_array
local variables            = interfaces.variables
local findfile             = resolvers.findfile
local addsuffix            = file.addsuffix

local v_yes                = variables.yes
local v_no                 = variables.no
local v_last               = variables.last
local v_all                = variables.all
local v_absolute           = variables.absolute
----- v_inline             = variables.inline  -- not !
----- v_display            = variables.display -- not !

-- beware, all macros have an argument:

local ctx_inlineverbatimnewline     = context.doinlineverbatimnewline
local ctx_inlineverbatimbeginline   = context.doinlineverbatimbeginline
local ctx_inlineverbatimemptyline   = context.doinlineverbatimemptyline
local ctx_inlineverbatimstart       = context.doinlineverbatimstart
local ctx_inlineverbatimstop        = context.doinlineverbatimstop

local ctx_displayverbatiminitialize = context.dodisplayverbatiminitialize -- the number of arguments might change over time
local ctx_displayverbatimnewline    = context.dodisplayverbatimnewline
local ctx_displayverbatimbeginline  = context.dodisplayverbatimbeginline
local ctx_displayverbatimemptyline  = context.dodisplayverbatimemptyline
local ctx_displayverbatimstart      = context.dodisplayverbatimstart
local ctx_displayverbatimstop       = context.dodisplayverbatimstop

local ctx_verbatim                  = context.verbatim
local ctx_verbatimspace             = context.doverbatimspace

local CargOne = Carg(1)

local function f_emptyline(s,settings)
    if settings and settings.nature == "inline" then
        ctx_inlineverbatimemptyline()
    else
        ctx_displayverbatimemptyline()
    end
end

local function f_beginline(s,settings)
    if settings and settings.nature == "inline" then
        ctx_inlineverbatimbeginline()
    else
        ctx_displayverbatimbeginline()
    end
end

local function f_newline(s,settings)
    if settings and settings.nature == "inline" then
        ctx_inlineverbatimnewline()
    else
        ctx_displayverbatimnewline()
    end
end

local function f_start(s,settings)
    if settings and settings.nature == "inline" then
        ctx_inlineverbatimstart()
    else
        ctx_displayverbatimstart()
    end
end

local function f_stop(s,settings)
    if settings and settings.nature == "inline" then
        ctx_inlineverbatimstop()
    else
        ctx_displayverbatimstop()
    end
end

local function f_default(s) -- (s,settings)
    ctx_verbatim(s)
end

local function f_space() -- (s,settings)
    ctx_verbatimspace()
end

local function f_signal() -- (s,settings)
    -- we use these for special purposes
end

local signal = "\000"

visualizers.signal        = signal
visualizers.signalpattern = P(signal)

local functions = {
    __index = {
        emptyline = f_emptyline,
        newline   = f_newline,
        default   = f_default,
        beginline = f_beginline,
        space     = f_space,
        start     = f_start,
        stop      = f_stop,
        signal    = f_signal,
    }
}

local handlers = { }

function visualizers.newhandler(name,data)
    local tname = type(name)
    local tdata = type(data)
    if tname == "table" then -- (data)
        setmetatable(name,getmetatable(name) or functions)
        return name
    elseif tname == "string" then
        if tdata == "string" then -- ("name","parent")
            local result = { }
            setmetatable(result,getmetatable(handlers[data]) or functions)
            handlers[name] = result
            return result
        elseif tdata == "table" then -- ("name",data)
            setmetatable(data,getmetatable(data) or functions)
            handlers[name] = data
            return data
        else -- ("name")
            local result = { }
            setmetatable(result,functions)
            handlers[name] = result
            return result
        end
    else -- ()
        local result = { }
        setmetatable(result,functions)
        return result
    end
end

function visualizers.newgrammar(name,t)
    name = lower(name)
    t = t or { }
    local g = visualizers.specifications[name]
    g = g and g.grammar
    if g then
        if trace_visualize then
            report_visualizers("cloning grammar %a",name)
        end
        for k,v in next, g do
            if not t[k] then
                t[k] = v
            end
            if is_lpeg(v) then
                t[name..":"..k] = v
            end
        end
    end
    return t
end

local function getvisualizer(method,nature)
    method = lower(method)
    local m = specifications[method] or specifications.default
    if nature then
        if trace_visualize then
            report_visualizers("getting visualizer %a with nature %a",method,nature)
        end
        return m and (m[nature] or m.parser) or nil
    else
        if trace_visualize then
            report_visualizers("getting visualizer %a",method)
        end
        return m and m.parser or nil
    end
end

local ctx_fallback = ctx_verbatim

local function makepattern(visualizer,replacement,pattern)
    if not pattern then
        report_visualizers("error in visualizer %a",replacement)
        return patterns.alwaystrue
    else
        if type(visualizer) == "table" and type(replacement) == "string" then
            replacement = visualizer[replacement] or ctx_fallback
        else
            replacement = ctx_fallback
        end
        return (C(pattern) * CargOne) / replacement
    end
end

local function makenested(handler,how,start,stop)
    local b, e, f = P(start), P(stop), how
    if type(how) == "string" then
        f = function(s) getvisualizer(how,"direct")(s) end
    end
    return makepattern(handler,"name",b)
         * ((1-e)^1/f)
         * makepattern(handler,"name",e)
end

visualizers.pattern     = makepattern
visualizers.makepattern = makepattern
visualizers.makenested  = makenested

function visualizers.load(name)
    name = lower(name)
    if rawget(specifications,name) == nil then
        name = lower(name)
        local impname = "buff-imp-"..name
        local texname = findfile(addsuffix(impname,"mkiv"))
        local luaname = findfile(addsuffix(impname,"lua"))
        if texname == "" or luaname == "" then
            -- assume a user specific file
            luaname = findfile(addsuffix(name,"mkiv"))
            texname = findfile(addsuffix(name,"lua"))
        end
        if texname == "" or luaname == "" then
            if trace_visualize then
                report_visualizers("unknown visualizer %a",name)
            end
        else
            if trace_visualize then
                report_visualizers("loading visualizer %a",name)
            end
            lua.registercode(luaname) -- only used here, end up in format
            context.input(texname)
        end
        if rawget(specifications,name) == nil then
            rawset(specifications,name,false)
        end
    end
end

function visualizers.register(name,specification)
    name = lower(name)
    if trace_visualize then
        report_visualizers("registering visualizer %a",name)
    end
    specifications[name] = specification
    local parser         = specification.parser
    local handler        = specification.handler
    local displayparser  = specification.display or parser
    local inlineparser   = specification.inline  or parser
    local isparser       = is_lpeg(parser)
    local start, stop
    if isparser then
        start = makepattern(handler,"start",patterns.alwaysmatched)
        stop  = makepattern(handler,"stop", patterns.alwaysmatched)
    end
    if handler then
        if isparser then
            specification.display = function(content,settings)
                if handler.startdisplay then handler.startdisplay(settings) end
                lpegmatch(start * displayparser * stop,content,1,settings)
                if handler.stopdisplay then handler.stopdisplay(settings) end
            end
            specification.inline = function(content,settings)
                if handler.startinline then handler.startinline(settings) end
                lpegmatch(start * inlineparser * stop,content,1,settings)
                if handler.stopinline then handler.stopinline(settings) end
            end
            specification.direct = function(content,settings)
                lpegmatch(parser,content,1,settings)
            end
        elseif parser then
            specification.display = function(content,settings)
                if handler.startdisplay then handler.startdisplay(settings) end
                parser(content,settings)
                if handler.stopdisplay then handler.stopdisplay(settings) end
            end
            specification.inline  = function(content,settings)
                if handler.startinline then handler.startinline(settings) end
                parser(content,settings)
                if handler.stopinline then handler.stopinline(settings) end
            end
            specification.direct = parser
        end
    elseif isparser then
        specification.display = function(content,settings)
            lpegmatch(start * displayparser * stop,content,1,settings)
        end
        specification.inline  = function(content,settings)
            lpegmatch(start * inlineparser * stop,content,1,settings)
        end
        specification.direct = function(content,settings)
            lpegmatch(parser,content,1,settings)
        end
    elseif parser then
        specification.display = parser
        specification.inline  = parser
        specification.direct  = parser
    end
    return specification
end

function visualizers.getspecification(name)
    return specifications[lower(name)]
end

local escapepatterns       = allocate()
visualizers.escapepatterns = escapepatterns

local function texmethod(s)
    context.bgroup()
    context(s)
    context.egroup()
end

local function texcommand(s)
    context[s]()
end

local function defaultmethod(s,settings)
    lpegmatch(getvisualizer("default"),lower(s),1,settings)
end

-- we can consider using a nested instead

local space_pattern = patterns.space^0
local name_pattern  = R("az","AZ")^1

-- the hack is needed in order to retain newlines when an escape happens at the
-- at the begin of a line; it also ensures proper line numbering; a bit messy

local function hack(pattern)
    return Cs(pattern * Cc(signal))
end

local split_processor = typesetters.processors.split
local apply_processor = typesetters.processors.apply

-- todo: { before = b, after = a, processor = p }, ...

function visualizers.registerescapepattern(name,befores,afters,normalmethod,escapemethod,processors)
    local escapepattern = escapepatterns[name]
    if not escapepattern then
        if type(befores)    ~= "table" then befores    = { befores    } end
        if type(afters)     ~= "table" then afters     = { afters     } end
        if type(processors) ~= "table" then processors = { processors } end
        for i=1,#befores do
            local before    = befores[i]
            local after     = afters[i]
            local processor = processors[i]
            if trace_visualize then
                report_visualizers("registering escape pattern, name %a, index %a, before %a, after %a, processor %a",
                    name,i,before,after,processor or "default")
            end
            before = P(before) * space_pattern
            after  = space_pattern * P(after)
            local action
            if processor then
                action = function(s) apply_processor(processor,s) end
            else
                action = escapemethod or texmethod
            end
            local ep = (before / "") * ((1 - after)^0 / action) * (after / "")
            if escapepattern then
                escapepattern = escapepattern + ep
            else
                escapepattern = ep
            end
        end
        escapepattern = (
            escapepattern
          + hack((1 - escapepattern)^1) / (normalmethod or defaultmethod)
        )^0
        escapepatterns[name] = escapepattern
    end
    return escapepattern
end

function visualizers.registerescapeline(name,befores,normalmethod,escapemethod,processors)
    local escapepattern = escapepatterns[name]
    if not escapepattern then
        if type(befores)    ~= "table" then befores    = { befores    } end
        if type(processors) ~= "table" then processors = { processors } end
        for i=1,#befores do
            local before    = befores[i]
            local processor = processors[i]
            if trace_visualize then
                report_visualizers("registering escape line pattern, name %a, before %a, after <<newline>>",name,before)
            end
            before = P(before) * space_pattern
            after = space_pattern * P("\n")
            local action
            if processor then
                action = function(s) apply_processor(processor,s) end
            else
                action = escapemethod or texmethod
            end
            local ep = (before / "") * ((1 - after)^0 / action) * (space_pattern / "")
            if escapepattern then
                escapepattern = escapepattern + ep
            else
                escapepattern = ep
            end
        end
        escapepattern = (
            escapepattern
          + hack((1 - escapepattern)^1) / (normalmethod or defaultmethod)
        )^0
        escapepatterns[name] = escapepattern
    end
    return escapepattern
end

function visualizers.registerescapecommand(name,token,normalmethod,escapecommand,processor)
    local escapepattern = escapepatterns[name]
    if not escapepattern then
        if trace_visualize then
            report_visualizers("registering escape token, name %a, token %a",name,token)
        end
        token = P(token)
        local notoken = hack((1 - token)^1)
        local cstoken = Cs(name_pattern * (space_pattern/""))
        escapepattern = (
            (token / "")
          * (cstoken / (escapecommand or texcommand))
          + (notoken / (normalmethod or defaultmethod))
        )^0
        escapepatterns[name] = escapepattern
    end
    return escapepattern
end

local escapedvisualizers  = { }
local f_escapedvisualizer = formatters["%s : %s"]

local function visualize(content,settings) -- maybe also method in settings
    if content and content ~= "" then
        local method = lower(settings.method or "default")
        local m = specifications[method] or specifications.default
        local e = settings.escape
        if e and e ~= "" and not m.handler.noescape then
            local newname = f_escapedvisualizer(method,e)
            local newspec = specifications[newname]
            if newspec then
                m = newspec
            else
                local starts, stops, processors = { }, { }, { }
                if e == v_yes then
                    starts[1] = "/BTEX"
                    stops [1] = "/ETEX"
                else
                    local s = settings_to_array(e,true)
                    for i=1,#s do
                        local si = s[i]
                        local processor, pattern = split_processor(si)
                        si = processor and pattern or si
                        local start, stop = match(si,"^(.-),(.-)$")
                        if start then
                            local n = #starts + 1
                            starts[n]     = start
                            stops [n]     = stop or ""
                            processors[n] = processor
                        end
                    end
                end
                local oldm       = m
                local oldparser  = oldm.direct
                local newhandler = oldm.handler
                local newparser  = oldm.parser -- nil
                if starts[1] and stops[1] ~= "" then
                    newparser = visualizers.registerescapepattern(newname,starts,stops,oldparser,nil,processors)
                elseif starts[1] then
                    newparser = visualizers.registerescapeline(newname,starts,oldparser,nil,processors)
                else -- for old times sake: /em
                    newparser = visualizers.registerescapecommand(newname,e,oldparser,nil,processors)
                end
                m = visualizers.register(newname, {
                    parser  = newparser,
                    handler = newhandler,
                })
            end
        else
            m = specifications[method] or specifications.default
        end
        local nature = settings.nature or "display"
        local n = m and m[nature]
        if n then
            if trace_visualize then
                report_visualizers("visualize using method %a and nature %a",method,nature)
            end
            n(content,settings)
        else
            if trace_visualize then
                report_visualizers("visualize using method %a",method)
            end
            ctx_fallback(content,1,settings)
        end
    end
end

visualizers.visualize     = visualize
visualizers.getvisualizer = getvisualizer

local fallbacks = { }  table.setmetatableindex(fallbacks,function(t,k) local v = { nature = k } t[k] = v return v end)

local function checkedsettings(settings,nature)
    if not settings then
        -- let's avoid dummy tables as much as possible
        return fallbacks[nature]
    else
        if not settings.nature then
            settings.nature = nature
        end
        return settings
    end
end

function visualizers.visualizestring(content,settings)
    visualize(content,checkedsettings(settings,"inline"))
end

function visualizers.visualizefile(name,settings)
    visualize(resolvers.loadtexfile(name),checkedsettings(settings,"display"))
end

function visualizers.visualizebuffer(name,settings)
    visualize(buffers.getcontent(name),checkedsettings(settings,"display"))
end

-- --

local space     = C(patterns.space)       * CargOne / f_space
local newline   = C(patterns.newline)     * CargOne / f_newline
local emptyline = C(patterns.emptyline)   * CargOne / f_emptyline
local beginline = C(patterns.beginline)   * CargOne / f_beginline
local anything  = C(patterns.somecontent) * CargOne / f_default

----- verbosed  = (space + newline * (emptyline^0) * beginline + anything)^0
local verbosed  = (space + newline * (emptyline^0) * beginline + newline * emptyline + newline + anything)^0

local function write(s,settings) -- bad name
    lpegmatch(verbosed,s,1,settings or false)
end

visualizers.write          = write
visualizers.writenewline   = f_newline
visualizers.writeemptyline = f_emptyline
visualizers.writespace     = f_space
visualizers.writedefault   = f_default

function visualizers.writeargument(...)
    context("{")  -- If we didn't have tracing then we could
    write(...)    -- use a faster print to tex variant for the
    context("}")  -- { } tokens as they always have ctxcatcodes.
end

-- helpers

local function realign(lines,strip) -- "yes", <number>
    local n
    if strip == v_yes then
        n = math.huge
        for i=1, #lines do
            local spaces = find(lines[i],"%S") -- can be lpeg
            if not spaces then
                -- empty line
            elseif spaces == 0 then
                n = 0
                break
            elseif spaces < n then
                n = spaces
            end
        end
        n = n - 1
    else
        n = tonumber(strip)
    end
    if n and n > 0 then
        local copy = { }
        for i=1,#lines do
            copy[i] = sub(lines[i],n+1)
        end
        return copy
    end
    return lines
end

local onlyspaces = S(" \t\f\n\r")^0 * P(-1)

local function getstrip(lines,first,last)
    if not first then
        first = 1
    end
    if not last then
        last = #lines
    end
    for i=first,last do
        local li = lines[i]
        if #li == 0 or lpegmatch(onlyspaces,li) then
            first = first + 1
        else
            break
        end
    end
    for i=last,first,-1 do
        local li = lines[i]
        if #li == 0 or lpegmatch(onlyspaces,li) then
            last = last - 1
        else
            break
        end
    end
    return first, last, last - first + 1
end

-- we look for text (todo):
--
-- "foo"  : start after line with "foo"
-- "="    : ignore first blob
-- "=foo" : start at "foo"
-- "!foo" : maybe a not "foo"

-- % - # lines start a comment

local comment = "^[%%%-#]"

local function getrange(lines,first,last,range) -- 1,3 1,+3 fromhere,tothere
    local noflines = #lines
    local first    = first or 1
    local last     = last or noflines
    if last < 0 then
        last = noflines + last
    end
    local what = settings_to_array(range) -- maybe also n:m
    local r_first = what[1]
    local r_last  = what[2]
    local f       = tonumber(r_first)
    local l       = tonumber(r_last)
    if r_first then
        if f then
            if f > first then
                first = f
            end
        elseif r_first == "=" then
            for i=first,last do
                if find(lines[i],comment) then
                    first = i + 1
                else
                    break
                end
            end
        elseif r_first ~= "" then
            local exact, r_first = match(r_first,"^([=]?)(.*)")
            for i=first,last do
                if find(lines[i],r_first) then
                    if exact == "=" then
                        first = i
                    else
                        first = i + 1
                    end
                    break
                else
                    first = i
                end
            end
        end
    end
    if r_last then
        if l then
            if l < 0 then
                l = noflines + l
            end
            if find(r_last,"^[%+]") then -- 1,+3
                l = first + l
            end
            if l < last then
                last = l
            end
        elseif r_first == "=" then
            for i=first,last do
                if find(lines[i],comment) then
                    break
                else
                    last = i
                end
            end
        elseif r_last ~= "" then
            local exact, r_last = match(r_last,"^([=]?)(.*)")
            for i=first,last do
                if find(lines[i],r_last) then
                    if exact == "=" then
                        last = i
                    end
                    break
                else
                    last = i
                end
            end
        end
    end
    return first, last
end

local tablength = 7

local function dotabs(content,settings)
    local tab = settings.tab
    tab = tab and (tab == v_yes and tablength or tonumber(tab))
    if tab then
        return tabtospace(content,tab)
    else
        return content
    end
end

local function filter(lines,settings) -- todo: inline or display in settings
    local strip = settings.strip
 -- if strip and strip == "" then
    if strip ~= v_no and strip ~= false then
        lines = realign(lines,strip)
    end
    local line  = 0
    local n     = 0
    local range = settings.range
    local first, last, m = getstrip(lines)
    if range then
        first, last = getrange(lines,first,last,range)
        first, last = getstrip(lines,first,last)
    end
    -- \r is \endlinechar but \n would is more generic so this choice is debatable
    local content = concat(lines,(settings.nature == "inline" and " ") or "\n",first,last)
    return content, m
end

local getlines = buffers.getlines

-- local decodecomment = resolvers.macros.decodecomment -- experiment

local function typebuffer(settings)
    local lines = getlines(settings.name)
    if lines then
        ctx_displayverbatiminitialize(#lines)
        local content, m = filter(lines,settings)
        if content and content ~= "" then
         -- content = decodecomment(content)
            content = dotabs(content,settings)
            visualize(content,checkedsettings(settings,"display"))
        end
    end
end

local function processbuffer(settings)
    local lines = getlines(settings.name)
    if lines then
        local content, m = filter(lines,settings)
        if content and content ~= "" then
            content = dotabs(content,settings)
            visualize(content,checkedsettings(settings,"direct"))
        end
    end
end

-- not really buffers but it's closely related

-- A string.gsub(str,"(\\.-) +$","%1") is faster than an lpeg when there is a
-- match but slower when there is no match. But anyway, we need a more clever
-- parser so we use lpeg.
--
-- [[\text ]]  [[\text{}]]  [[\foo\bar .tex]] [[\text \text ]]  [[\text \\ \text ]]
--
-- needed in e.g. tabulate (manuals)

local fences    = S([[[{]])
local symbols   = S([[!#"$%&'*()+,-./:;<=>?@[]^_`{|}~]])
local space     = S([[ ]])
local backslash = S([[\]])
local nospace   = space^1/""
local endstring = P(-1)

local compactors = {
    [v_all]      = Cs((backslash * (1-backslash-space)^1 * nospace * (endstring+fences) + 1)^0),
    [v_absolute] = Cs((backslash * (1-symbols  -space)^1 * nospace * (symbols +backslash) + 1) ^0),
    [v_last]     = Cs((space^1   * endstring/"" + 1)^0),
}

local function typestring(settings)
    local content = settings.data
    if content and content ~= "" then
        local compact   = settings.compact
        local compactor = compact and compactors[compact]
        if compactor then
            content = lpegmatch(compactor,content) or content
        end
     -- content = decodecomment(content)
     -- content = dotabs(content,settings)
        visualize(content,checkedsettings(settings,"inline"))
    end
end

local function typefile(settings)
    local filename = settings.name
    local foundname = resolvers.findtexfile(filename)
    if foundname and foundname ~= "" then
        local str = resolvers.loadtexfile(foundname)
        if str and str ~= "" then
            local regime = settings.regime
            if regime and regime ~= "" then
                str = regimes.translate(str,regime)
            end
            if str and str~= "" then
             -- content = decodecomment(content)
                local lines = splitlines(str)
                local content, m = filter(lines,settings)
                if content and content ~= "" then
                    content = dotabs(content,settings)
                    visualize(content,checkedsettings(settings,"display"))
                end
            end
        end
    end
end

implement {
    name      = "type",
    actions   = typestring,
    arguments = {
        {
            { "data" },
            { "tab"     },
            { "method"  },
            { "compact" },
            { "nature"  },
            { "escape"  },
        }
    }
}

-- implement {
--     name      = "type_x",
--     actions   = typestring,
--     arguments = {
--         {
--             { "data", "verbatim" },
--             { "tab"     },
--             { "method"  },
--             { "compact" },
--             { "nature"  },
--             { "escape"  },
--         }
--     }
-- }

-- local function typestring_y(settings)
--     local content = tex.toks[settings.n]
--     if content and content ~= "" then
--         local compact   = settings.compact
--         local compactor = compact and compactors[compact]
--         if compactor then
--             content = lpegmatch(compactor,content)
--         end
--      -- content = decodecomment(content)
--      -- content = dotabs(content,settings)
--         visualize(content,checkedsettings(settings,"inline"))
--     end
-- end

-- implement {
--     name      = "type_y",
--     actions   = typestring_y,
--     arguments = {
--         {
--             { "n", "integer" },
--             { "tab"     },
--             { "method"  },
--             { "compact" },
--             { "nature"  },
--             { "escape"  },
--         }
--     }
-- }

implement {
    name      = "processbuffer",
    actions   = processbuffer,
    arguments = {
        {
             { "name" },
             { "strip" },
             { "tab" },
             { "method" },
             { "nature" },
        }
    }
}

implement {
    name    = "typebuffer",
    actions = typebuffer,
    arguments = {
        {
             { "name" },
             { "strip" },
             { "range" },
             { "regime" },
             { "tab" },
             { "method" },
             { "escape" },
             { "nature" },
        }
    }
}

implement {
    name    = "typefile",
    actions = typefile,
    arguments = {
        {
             { "name" },
             { "strip" },
             { "range" },
             { "regime" },
             { "tab" },
             { "method" },
             { "escape" },
             { "nature" },
        }
    }
}

implement {
    name      = "doifelsevisualizer",
    actions   = { visualizers.getspecification, commands.doifelse },
    arguments = "string"
}

implement {
    name      = "loadvisualizer",
    actions   = visualizers.load,
    arguments = "string"
}
