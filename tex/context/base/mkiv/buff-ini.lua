if not modules then modules = { } end modules ['buff-ini'] = {
    version   = 1.001,
    comment   = "companion to buff-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat = table.concat
local type, next, load = type, next, load
local sub, format = string.sub, string.format
local splitlines, validstring, replacenewlines = string.splitlines, string.valid, string.replacenewlines
local P, Cs, patterns, lpegmatch = lpeg.P, lpeg.Cs, lpeg.patterns, lpeg.match
local utfchar  = utf.char
local nameonly = file.nameonly
local totable  = string.totable
local md5hex = md5.hex
local isfile = lfs.isfile
local savedata = io.savedata

local trace_run         = false  trackers.register("buffers.run",       function(v) trace_run       = v end)
local trace_grab        = false  trackers.register("buffers.grab",      function(v) trace_grab      = v end)
local trace_visualize   = false  trackers.register("buffers.visualize", function(v) trace_visualize = v end)

local report_buffers    = logs.reporter("buffers","usage")
local report_typeset    = logs.reporter("buffers","typeset")
----- report_grabbing   = logs.reporter("buffers","grabbing")

local context           = context
local commands          = commands

local implement         = interfaces.implement

local scanners          = tokens.scanners
local scanstring        = scanners.string
local scaninteger       = scanners.integer
local scanboolean       = scanners.boolean
local scancode          = scanners.code
local scantokencode     = scanners.tokencode
----- scantoken         = scanners.token

local getters           = tokens.getters
local gettoken          = getters.token

local scanners          = interfaces.scanners

local variables         = interfaces.variables
local settings_to_array = utilities.parsers.settings_to_array
local formatters        = string.formatters
local addsuffix         = file.addsuffix
local replacesuffix     = file.replacesuffix

local registertempfile  = luatex.registertempfile

local v_yes             = variables.yes

local eol               = patterns.eol
local space             = patterns.space
local whitespace        = patterns.whitespace
local blackspace        = whitespace - eol
local whatever          = (1-eol)^1 * eol^0
local emptyline         = space^0 * eol

local catcodenumbers    = catcodes.numbers

local ctxcatcodes       = catcodenumbers.ctxcatcodes
local txtcatcodes       = catcodenumbers.txtcatcodes

local setdata           = job.datasets.setdata
local getdata           = job.datasets.getdata

local ctx_viafile          = context.viafile
local ctx_getbuffer        = context.getbuffer
local ctx_pushcatcodetable = context.pushcatcodetable
local ctx_popcatcodetable  = context.popcatcodetable
local ctx_setcatcodetable  = context.setcatcodetable
local ctx_printlines       = context.printlines

buffers       = buffers or { }
local buffers = buffers

local cache = { }

local function erase(name)
    cache[name] = nil
end

local function assign(name,str,catcodes)
    cache[name] = {
        data     = str,
        catcodes = catcodes,
        typeset  = false,
    }
end

local function combine(name,str,prepend)
    local buffer = cache[name]
    if buffer then
        buffer.data    = prepend and (str .. buffer.data) or (buffer.data .. str)
        buffer.typeset = false
    else
        cache[name] = {
            data     = str,
            typeset  = false,
        }
    end
end

local function prepend(name,str)
    combine(name,str,true)
end

local function append(name,str)
    combine(name,str)
end

local function exists(name)
    return cache[name]
end

local function getcontent(name)
    local buffer = name and cache[name]
    return buffer and buffer.data or ""
end

local function getlines(name)
    local buffer = name and cache[name]
    return buffer and splitlines(buffer.data)
end

local function getnames(name)
    if type(name) == "string" then
        return settings_to_array(name)
    else
        return name
    end
end

local function istypeset(name)
    local names = getnames(name)
    if #names == 0 then
        return false
    end
    for i=1,#names do
        local c = cache[names[i]]
        if c and not c.typeset then
            return false
        end
    end
    return true
end

local function markastypeset(name)
    local names  = getnames(name)
    for i=1,#names do
        local c = cache[names[i]]
        if c then
            c.typeset = true
        end
    end
end

local function collectcontent(name,separator) -- no print
    local names  = getnames(name)
    local nnames = #names
    if nnames == 0 then
        return getcontent("") -- default buffer
    elseif nnames == 1 then
        return getcontent(names[1])
    else
        local t = { }
        local n = 0
        for i=1,nnames do
            local c = getcontent(names[i])
            if c ~= "" then
                n = n + 1
                t[n] = c
            end
        end
        -- the default separator was \r, then \n and is now os.newline because buffers
        -- can be loaded in other applications
        return concat(t,separator or os.newline)
    end
end

local function loadcontent(name) -- no print
    local content = collectcontent(name,"\n") -- tex likes \n hm, elsewhere \r
    local ok, err = load(content)
    if ok then
        return ok()
    else
        report_buffers("invalid lua code in buffer %a: %s",name,err or "unknown error")
    end
end

buffers.raw            = getcontent
buffers.erase          = erase
buffers.assign         = assign
buffers.prepend        = prepend
buffers.append         = append
buffers.exists         = exists
buffers.getcontent     = getcontent
buffers.getlines       = getlines
buffers.collectcontent = collectcontent
buffers.loadcontent    = loadcontent

-- the context interface

implement {
    name      = "assignbuffer",
    actions   = assign,
    arguments = { "string", "string", "integer" }
}

implement {
    name      = "erasebuffer",
    actions   = erase,
    arguments = "string"
}

-- local anything      = patterns.anything
-- local alwaysmatched = patterns.alwaysmatched
-- local utf8character = patterns.utf8character
--
-- local function countnesting(b,e)
--     local n
--     local g = P(b) / function() n = n + 1 end
--             + P(e) / function() n = n - 1 end
--          -- + anything
--             + utf8character
--     local p = alwaysmatched / function() n = 0 end
--             * g^0
--             * alwaysmatched / function() return n end
--     return p
-- end

local counters   = { }
local nesting    = 0
local autoundent = true
local continue   = false

-- Beware: the first character of bufferdata has to be discarded as it's there to
-- prevent gobbling of newlines in the case of nested buffers. The last one is
-- a newlinechar and is removed too.
--
-- An \n is unlikely to show up as \r is the endlinechar but \n is more generic
-- for us.

-- This fits the way we fetch verbatim: the indentation before the sentinel
-- determines the stripping.

-- str = [[
--     test test test test test test test
--       test test test test test test test
--     test test test test test test test
--
--     test test test test test test test
--       test test test test test test test
--     test test test test test test test
--     ]]

-- local function undent(str)
--     local margin = match(str,"[\n\r]( +)[\n\r]*$") or ""
--     local indent = #margin
--     if indent > 0 then
--         local lines = splitlines(str)
--         local ok = true
--         local pattern = "^" .. margin
--         for i=1,#lines do
--             local l = lines[i]
--             if find(l,pattern) then
--                 lines[i] = sub(l,indent+1)
--             else
--                 ok = false
--                 break
--             end
--         end
--         if ok then
--             return concat(lines,"\n")
--         end
--     end
--     return str
-- end

-- how about tabs

local strippers  = { }
local nofspaces  = 0

local normalline = space^0 / function(s) local n = #s if n < nofspaces then nofspaces = n end end
                 * whatever

local getmargin = (emptyline + normalline)^1

local function undent(str) -- new version, needs testing: todo: not always needed, like in xtables
    nofspaces = #str
    local margin = lpegmatch(getmargin,str)
    if nofspaces == #str or nofspaces == 0 then
        return str
    end
    local stripper = strippers[nofspaces]
    if not stripper then
        stripper = Cs(((space^-nofspaces)/"" * whatever + emptyline)^1)
        strippers[nofspaces] = stripper
    end
    return lpegmatch(stripper,str) or str
end

buffers.undent = undent

-- function commands.grabbuffer(name,begintag,endtag,bufferdata,catcodes,doundent) -- maybe move \\ to call
--     local dn = getcontent(name)
--     if dn == "" then
--         nesting  = 0
--         continue = false
--     end
--     if trace_grab then
--         if #bufferdata > 30 then
--             report_grabbing("%s => |%s..%s|",name,sub(bufferdata,1,10),sub(bufferdata,-10,#bufferdata))
--         else
--             report_grabbing("%s => |%s|",name,bufferdata)
--         end
--     end
--     local counter = counters[begintag]
--     if not counter then
--         counter = countnesting(begintag,endtag)
--         counters[begintag] = counter
--     end
--     nesting = nesting + lpegmatch(counter,bufferdata)
--     local more = nesting > 0
--     if more then
--         dn       = dn .. sub(bufferdata,2,-1) .. endtag
--         nesting  = nesting - 1
--         continue = true
--     else
--         if continue then
--             dn = dn .. sub(bufferdata,2,-2) -- no \r, \n is more generic
--         elseif dn == "" then
--             dn = sub(bufferdata,2,-2)
--         else
--             dn = dn .. "\n" .. sub(bufferdata,2,-2) -- no \r, \n is more generic
--         end
--         local last = sub(dn,-1)
--         if last == "\n" or last == "\r" then -- \n is unlikely as \r is the endlinechar
--             dn = sub(dn,1,-2)
--         end
--         if doundent or (autoundent and doundent == nil) then
--             dn = undent(dn)
--         end
--     end
--     assign(name,dn,catcodes)
--     commands.doifelse(more)
-- end

local split = table.setmetatableindex(function(t,k)
    local v = totable(k)
    t[k] = v
    return v
end)

local tochar = {
    [ 0] = "\\",
    [ 1] = "{",
    [ 2] = "}",
    [ 3] = "$",
    [ 4] = "&",
    [ 5] = "\n",
    [ 6] = "#",
    [ 7] = "^",
    [ 8] = "_",
    [10] = " ",
    [14] = "%",
}

local experiment = false
local experiment = scantokencode and true

function tokens.pickup(start,stop)
    local stoplist     = split[stop] -- totable(stop)
    local stoplength   = #stoplist
    local stoplast     = stoplist[stoplength]
    local startlist    = split[start] -- totable(start)
    local startlength  = #startlist
    local startlast    = startlist[startlength]
    local list         = { }
    local size         = 0
    local depth        = 0
--  local done         = 32
    local scancode     = experiment and scantokencode or scancode
    while true do -- or use depth
        local char = scancode()
        if char then
--             if char < done then
--                 -- we skip leading control characters so that we can use them to
--                 -- obey spaces (a dirty trick)
--             else
--                 done = 0
                char = utfchar(char)
                size = size + 1
                list[size] = char
                if char == stoplast and size >= stoplength then
                    local done = true
                    local last = size
                    for i=stoplength,1,-1 do
                        if stoplist[i] ~= list[last] then
                            done = false
                            break
                        end
                        last = last - 1
                    end
                    if done then
                        if depth > 0 then
                            depth = depth - 1
                        else
                            break
                        end
                        char = false -- trick: let's skip the next (start) test
                    end
                end
                if char == startlast and size >= startlength then
                    local done = true
                    local last = size
                    for i=startlength,1,-1 do
                        if startlist[i] ~= list[last] then
                            done = false
                            break
                        end
                        last = last - 1
                    end
                    if done then
                        depth = depth + 1
                    end
                end
--             end
        else
         -- local t = scantoken()
            local t = gettoken()
            if t then
                -- we're skipping leading stuff, like obeyedlines and relaxes
                if experiment and size > 0 then
                    -- we're probably in a macro
                    local char = tochar[token.get_command(t)] -- could also be char(token.get_mode(t))
                    if char then
                        size = size + 1 ; list[size] = char
                    else
                        local csname = token.get_csname(t)
                        if csname == stop then
                            stoplength = 0
                            break
                        else
                            size = size + 1 ; list[size] = "\\"
                            size = size + 1 ; list[size] = csname
                            size = size + 1 ; list[size] = " "
                        end
                    end
                else
                    -- ignore and hope for the best
                end
            else
                break
            end
        end
    end
    local start = 1
    local stop  = size - stoplength - 1
    -- not good enough: only empty lines, but even then we miss the leading
    -- for verbatim
    --
    -- the next is not yet adapted to the new scanner ... we don't need lpeg here
    --
    for i=start,stop do
        local li = list[i]
        if lpegmatch(blackspace,li) then
            -- keep going
        elseif lpegmatch(eol,li) then
            -- okay
            start = i + 1
        else
            break
        end
    end
    for i=stop,start,-1 do
        if lpegmatch(whitespace,list[i]) then
            stop = i - 1
        else
            break
        end
    end
    --
    if start <= stop then
        return concat(list,"",start,stop)
    else
        return ""
    end
end

-- function buffers.pickup(name,start,stop,finish,catcodes,doundent)
--     local data = tokens.pickup(start,stop)
--     if doundent or (autoundent and doundent == nil) then
--         data = buffers.undent(data)
--     end
--     buffers.assign(name,data,catcodes)
--     context(finish)
-- end

-- commands.pickupbuffer = buffers.pickup

scanners.pickupbuffer = function()
    local name     = scanstring()
    local start    = scanstring()
    local stop     = scanstring()
    local finish   = scanstring()
    local catcodes = scaninteger()
    local doundent = scanboolean()
    local data = tokens.pickup(start,stop)
    if doundent or (autoundent and doundent == nil) then
        data = undent(data)
    end
    buffers.assign(name,data,catcodes)
 -- context[finish]()
    context(finish)
end

local function savebuffer(list,name,prefix) -- name is optional
    if not list or list == "" then
        list = name
    end
    if not name or name == "" then
        name = list
    end
    local content = collectcontent(list,nil) or ""
    if content == "" then
        content = "empty buffer"
    end
    if prefix == v_yes then
        name = addsuffix(tex.jobname .. "-" .. name,"tmp")
    end
    io.savedata(name,replacenewlines(content))
end

implement {
    name      = "savebuffer",
    actions   = savebuffer,
    arguments = "3 strings",
}

-- we can consider adding a size to avoid unlikely clashes

local olddata   = nil
local newdata   = nil
local getrunner = sandbox.getrunner

local runner = sandbox.registerrunner {
    name     = "run buffer",
    program  = "context",
    method   = "execute",
    template = jit and "--purgeall --jit %filename%" or "--purgeall %filename%",
    reporter = report_typeset,
    checkers = {
        filename = "readable",
    }
}

local function runbuffer(name,encapsulate,runnername,suffixes)
    if not runnername or runnername == "" then
        runnername = "run buffer"
    end
    local suffix = "pdf"
    if type(suffixes) == "table" then
        suffix = suffixes[1]
    elseif type(suffixes) == "string" and suffixes ~= "" then
        suffix   = suffixes
        suffixes = { suffix }
    else
        suffixes = { suffix }
    end
    local runner = getrunner(runnername)
    if not runner then
        report_typeset("unknown runner %a",runnername)
        return
    end
    if not olddata then
        olddata = getdata("buffers","runners") or { }
        local suffixes = olddata.suffixes
        local hashes   = olddata.hashes
        if hashes and suffixes then
            for k, hash in next, hashes do
                for h, v in next, hash do
                    for s, v in next, suffixes do
                        local tmp = addsuffix(h,s)
                     -- report_typeset("mark for deletion: %s",tmp)
                        registertempfile(tmp)
                    end
                end
            end
        end
    end
    if not newdata then
        newdata = {
            version  = environment.version,
            suffixes = { },
            hashes   = { },
        }
        setdata {
            name = "buffers",
            tag  = "runners",
            data = newdata,
        }
    end
    local oldhashes = olddata.hashes or { }
    local newhashes = newdata.hashes or { }
    local old = oldhashes[suffix]
    local new = newhashes[suffix]
    if not old then
        old = { }
        oldhashes[suffix] = old
        for hash, n in next, old do
            local tag = formatters["%s-t-b-%s"](tex.jobname,hash)
            local tmp = addsuffix(tag,"tmp")
         -- report_typeset("mark for deletion: %s",tmp)
            registertempfile(tmp) -- to be sure
        end
    end
    if not new then
        new = { }
        newhashes[suffix] = new
    end
    local names   = getnames(name)
    local content = collectcontent(names,nil) or ""
    if content == "" then
        content = "empty buffer"
    end
    if encapsulate then
        content = formatters["\\starttext\n%s\n\\stoptext\n"](content)
    end
    --
    local hash = md5hex(content)
    local tag  = formatters["%s-t-b-%s"](nameonly(tex.jobname),hash) -- make sure we run on the local path
    --
    local filename   = addsuffix(tag,"tmp")
    local resultname = addsuffix(tag,suffix)
    --
    if new[tag] then
        -- done
    elseif not old[tag] or olddata.version ~= newdata.version or not isfile(resultname) then
        if trace_run then
            report_typeset("changes in %a, processing forced",name)
        end
        savedata(filename,content)
        report_typeset("processing saved buffer %a\n",filename)
        runner { filename = filename }
    end
    new[tag] = (new[tag] or 0) + 1
    report_typeset("no changes in %a, processing skipped",name)
    registertempfile(filename)
 -- report_typeset("mark for persistence: %s",filename)
    for i=1,#suffixes do
        local suffix = suffixes[i]
        newdata.suffixes[suffix] = true
        local tmp = addsuffix(tag,suffix)
     -- report_typeset("mark for persistance: %s",tmp)
        registertempfile(tmp,nil,true)
    end
    --
    return resultname -- first result
end

local f_getbuffer = formatters["buffer.%s"]

local function getbuffer(name)
    local str = getcontent(name)
    if str ~= "" then
     -- characters.showstring(str)
        ctx_viafile(str,f_getbuffer(validstring(name,"noname")))
    end
end

local function getbuffermkvi(name) -- rather direct !
    ctx_viafile(resolvers.macros.preprocessed(getcontent(name)),formatters["buffer.%s.mkiv"](validstring(name,"noname")))
end

local function gettexbuffer(name)
    local buffer = name and cache[name]
    if buffer and buffer.data ~= "" then
        ctx_pushcatcodetable()
        if buffer.catcodes == txtcatcodes then
            ctx_setcatcodetable(txtcatcodes)
        else
            ctx_setcatcodetable(ctxcatcodes)
        end
     -- context(function() ctx_viafile(buffer.data) end)
        ctx_getbuffer { name } -- viafile flushes too soon
        ctx_popcatcodetable()
    end
end

buffers.get          = getbuffer
buffers.getmkiv      = getbuffermkiv
buffers.gettexbuffer = gettexbuffer
buffers.run          = runbuffer

implement { name = "getbufferctxlua", actions = loadcontent,   arguments = "string" }
implement { name = "getbuffer",       actions = getbuffer,     arguments = "string" }
implement { name = "getbuffermkvi",   actions = getbuffermkvi, arguments = "string" }
implement { name = "gettexbuffer",    actions = gettexbuffer,  arguments = "string" }

interfaces.implement {
    name      = "getbuffercontent",
    arguments = "string",
    actions   = { getcontent, context },
}

implement {
    name      = "typesetbuffer",
    actions   = { runbuffer, context },
    arguments = { "string", true }
}

implement {
    name      = "runbuffer",
    actions   = { runbuffer, context },
    arguments = { "string", false, "string" }
}

implement {
    name      = "doifelsebuffer",
    actions   = { exists, commands.doifelse },
    arguments = "string"
}

-- This only used for mp buffers and is a kludge. Don't change the
-- texprint into texsprint as it fails because "p<nl>enddef" becomes
-- "penddef" then.

implement {
    name      = "feedback", -- bad name, maybe rename to injectbuffercontent
    actions   = { collectcontent, ctx_printlines },
    arguments = "string"
}

do

    local context             = context
    local ctxcore             = context.core

    local ctx_startbuffer     = ctxcore.startbuffer
    local ctx_stopbuffer      = ctxcore.stopbuffer

    local ctx_startcollecting = context.startcollecting
    local ctx_stopcollecting  = context.stopcollecting

    function ctxcore.startbuffer(...)
        ctx_startcollecting()
        ctx_startbuffer(...)
    end

    function ctxcore.stopbuffer()
        ctx_stopbuffer()
        ctx_stopcollecting()
    end

end

-- moved here:

function buffers.samplefile(name)
    if not buffers.exists(name) then
        buffers.assign(name,io.loaddata(resolvers.findfile(name)))
    end
    buffers.get(name)
end

implement {
    name      = "samplefile", -- bad name, maybe rename to injectbuffercontent
    actions   = buffers.samplefile,
    arguments = "string"
}
