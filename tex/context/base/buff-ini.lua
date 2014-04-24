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
local splitlines, validstring = string.splitlines, string.valid
local P, Cs, patterns, lpegmatch = lpeg.P, lpeg.Cs, lpeg.patterns, lpeg.match

local trace_run         = false  trackers.register("buffers.run",       function(v) trace_run       = v end)
local trace_grab        = false  trackers.register("buffers.grab",      function(v) trace_grab      = v end)
local trace_visualize   = false  trackers.register("buffers.visualize", function(v) trace_visualize = v end)

local report_buffers    = logs.reporter("buffers","usage")
local report_typeset    = logs.reporter("buffers","typeset")
local report_grabbing   = logs.reporter("buffers","grabbing")

local context           = context
local commands          = commands

local variables         = interfaces.variables
local settings_to_array = utilities.parsers.settings_to_array
local formatters        = string.formatters
local addsuffix         = file.addsuffix
local replacesuffix     = file.replacesuffix

local registertempfile  = luatex.registertempfile

local v_yes             = variables.yes

local catcodenumbers    = catcodes.numbers

local ctxcatcodes       = catcodenumbers.ctxcatcodes
local txtcatcodes       = catcodenumbers.txtcatcodes

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
        local t, n = { }, 0
        for i=1,nnames do
            local c = getcontent(names[i])
            if c ~= "" then
                n = n + 1
                t[n] = c
            end
        end
        return concat(t,separator or "\n") -- was \r
    end
end

local function loadcontent(name) -- no print
    local content = collectcontent(name,"\n")
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

commands.erasebuffer  = erase
commands.assignbuffer = assign

local anything      = patterns.anything
local alwaysmatched = patterns.alwaysmatched

local function countnesting(b,e)
    local n
    local g = P(b) / function() n = n + 1 end
            + P(e) / function() n = n - 1 end
            + anything
    local p = alwaysmatched / function() n = 0 end
            * g^0
            * alwaysmatched / function() return n end
    return p
end

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

-- This fits the way we fetch verbatim: the indentatio before the sentinel
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

local getmargin = (Cs(P(" ")^1)*P(-1)+1)^1
local eol       = patterns.eol
local whatever  = (P(1)-eol)^0 * eol^1

local strippers = { }

local function undent(str) -- new version, needs testing
    local margin = lpegmatch(getmargin,str)
    if type(margin) ~= "string" then
        return str
    end
    local indent = #margin
    if indent == 0 then
        return str
    end
    local stripper = strippers[indent]
    if not stripper then
        stripper = Cs((P(margin)/"" * whatever + eol^1)^1)
        strippers[indent] = stripper
    end
    return lpegmatch(stripper,str) or str
end

function commands.grabbuffer(name,begintag,endtag,bufferdata,catcodes) -- maybe move \\ to call
    local dn = getcontent(name)
    if dn == "" then
        nesting  = 0
        continue = false
    end
    if trace_grab then
        if #bufferdata > 30 then
            report_grabbing("%s => |%s..%s|",name,sub(bufferdata,1,10),sub(bufferdata,-10,#bufferdata))
        else
            report_grabbing("%s => |%s|",name,bufferdata)
        end
    end
    local counter = counters[begintag]
    if not counter then
        counter = countnesting(begintag,endtag)
        counters[begintag] = counter
    end
    nesting = nesting + lpegmatch(counter,bufferdata)
    local more = nesting > 0
    if more then
        dn       = dn .. sub(bufferdata,2,-1) .. endtag
        nesting  = nesting - 1
        continue = true
    else
        if continue then
            dn = dn .. sub(bufferdata,2,-2) -- no \r, \n is more generic
        elseif dn == "" then
            dn = sub(bufferdata,2,-2)
        else
            dn = dn .. "\n" .. sub(bufferdata,2,-2) -- no \r, \n is more generic
        end
        local last = sub(dn,-1)
        if last == "\n" or last == "\r" then -- \n is unlikely as \r is the endlinechar
            dn = sub(dn,1,-2)
        end
        if autoundent then
            dn =  undent(dn)
        end
    end
    assign(name,dn,catcodes)
    commands.doifelse(more)
end

function commands.savebuffer(list,name,prefix) -- name is optional
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
    io.savedata(name,content)
end

-- local files = { }
-- local last  = 0
--
-- function commands.runbuffer(name,encapsulate) -- we used to compare the saved file with content
--     local names    = getnames(name)
--     local filename = files[name]
--     local tobedone = not istypeset(names)
--     if tobedone or not filename then
--         last        = last + 1
--         filename    = formatters["%s-typeset-buffer-%03i"](tex.jobname,last)
--         files[name] = filename
--     end
--     if tobedone then
--         if trace_run then
--             report_typeset("changes in %a, processing forced",name)
--         end
--         local filename = addsuffix(filename,"tmp")
--         local content = collectcontent(names,nil) or ""
--         if content == "" then
--             content = "empty buffer"
--         end
--         if encapsulate then
--             content = formatters["\\starttext\n%s\n\\stoptext\n"](content)
--         end
--         io.savedata(filename,content)
--         local command = formatters["context %s %s"](jit and "--jit" or "",filename)
--         report_typeset("running: %s\n",command)
--         os.execute(command)
--         markastypeset(names)
--     elseif trace_run then
--         report_typeset("no changes in %a, not processed",name)
--     end
--     context(replacesuffix(filename,"pdf"))
-- end

-- we can consider adding a size to avoid unlikely clashes

local oldhashes = nil
local newhashes = nil

function commands.runbuffer(name,encapsulate)
    if not oldhashes then
        oldhashes = job.datasets.getdata("typeset buffers","hashes") or { }
        for hash, n in next, oldhashes do
            local tag  = formatters["%s-t-b-%s"](tex.jobname,hash)
            registertempfile(addsuffix(tag,"tmp")) -- to be sure
            registertempfile(addsuffix(tag,"pdf"))
        end
        newhashes = { }
        job.datasets.setdata {
            name = "typeset buffers",
            tag  = "hashes",
            data = newhashes,
        }
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
    local hash = md5.hex(content)
    local tag  = formatters["%s-t-b-%s"](tex.jobname,hash)
    --
    local filename   = addsuffix(tag,"tmp")
    local resultname = addsuffix(tag,"pdf")
    --
    if newhashes[hash] then
        -- done
    elseif not oldhashes[hash] or not lfs.isfile(resultname) then
        if trace_run then
            report_typeset("changes in %a, processing forced",name)
        end
        io.savedata(filename,content)
        local command = formatters["context --purgeall %s %s"](jit and "--jit" or "",filename)
        report_typeset("running: %s\n",command)
        os.execute(command)
    end
    newhashes[hash] = (newhashes[hash] or 0) + 1
    report_typeset("no changes in %a, processing skipped",name)
    registertempfile(filename)
    registertempfile(resultname,nil,true)
    --
    context(resultname)
end

function commands.getbuffer(name)
    local str = getcontent(name)
    if str ~= "" then
     -- characters.showstring(str)
        context.viafile(str,formatters["buffer.%s"](validstring(name,"noname")))
    end
end

function commands.getbuffermkvi(name) -- rather direct !
    context.viafile(resolvers.macros.preprocessed(getcontent(name)),formatters["buffer.%s.mkiv"](validstring(name,"noname")))
end

function commands.gettexbuffer(name)
    local buffer = name and cache[name]
    if buffer and buffer.data ~= "" then
        context.pushcatcodetable()
        if buffer.catcodes == txtcatcodes then
            context.setcatcodetable(txtcatcodes)
        else
            context.setcatcodetable(ctxcatcodes)
        end
     -- context(function() context.viafile(buffer.data) end)
        context.getbuffer { name } -- viafile flushes too soon
        context.popcatcodetable()
    end
end

commands.getbufferctxlua = loadcontent

function commands.doifelsebuffer(name)
    commands.doifelse(exists(name))
end

-- This only used for mp buffers and is a kludge. Don't change the
-- texprint into texsprint as it fails because "p<nl>enddef" becomes
-- "penddef" then.

-- function commands.feedback(names)
--     texprint(ctxcatcodes,splitlines(collectcontent(names)))
-- end

function commands.feedback(names) -- bad name, maybe rename to injectbuffercontent
    context.printlines(collectcontent(names))
end
