if not modules then modules = { } end modules ['mlib-run'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- cmyk       -> done, native
-- spot       -> done, but needs reworking (simpler)
-- multitone  ->
-- shade      -> partly done, todo: cm
-- figure     -> done
-- hyperlink  -> low priority, easy

-- new * run
-- or
-- new * execute^1 * finish

-- a*[b,c] == b + a * (c-b)

--[[ldx--
<p>The directional helpers and pen analysis are more or less translated from the
<l n='c'/> code. It really helps that Taco know that source so well. Taco and I spent
quite some time on speeding up the <l n='lua'/> and <l n='c'/> code. There is not
much to gain, especially if one keeps in mind that when integrated in <l n='tex'/>
only a part of the time is spent in <l n='metapost'/>. Of course an integrated
approach is way faster than an external <l n='metapost'/> and processing time
nears zero.</p>
--ldx]]--

local type, tostring, tonumber, next = type, tostring, tonumber, next
local find, striplines = string.find, utilities.strings.striplines
local concat, insert, remove = table.concat, table.insert, table.remove

local emptystring = string.is_empty
local P = lpeg.P

local trace_graphics   = false  trackers.register("metapost.graphics",   function(v) trace_graphics   = v end)
local trace_tracingall = false  trackers.register("metapost.tracingall", function(v) trace_tracingall = v end)
local trace_terminal   = false  trackers.register("metapost.terminal",   function(v) trace_terminal   = v end)

local report_metapost = logs.reporter("metapost")
local report_terminal = logs.reporter("metapost","terminal")
local texerrormessage = logs.texerrormessage

local starttiming     = statistics.starttiming
local stoptiming      = statistics.stoptiming

local formatters      = string.formatters

local mplib           = mplib
metapost              = metapost or { }
local metapost        = metapost

metapost.showlog      = false
metapost.lastlog      = ""
metapost.texerrors    = false
metapost.exectime     = metapost.exectime or { } -- hack
metapost.nofruns      = 0

local mpxformats      = { }
local mpxterminals    = { }
local nofformats      = 0
local mpxpreambles    = { }
local mpxextradata    = { }

-- The flatten hack is needed because the library currently barks on \n\n and the
-- collapse because mp cannot handle snippets due to grouping issues.

-- todo: pass tables to executempx instead of preparing beforehand,
-- as it's more efficient for the terminal

local function flatten(source,target)
    for i=1,#source do
        local d = source[i]
        if type(d) == "table" then
            flatten(d,target)
        elseif d and d ~= "" then
            target[#target+1] = d
        end
    end
    return target
end

local function prepareddata(data)
    if data and data ~= "" then
        if type(data) == "table" then
            data = flatten(data,{ })
            data = #data > 1 and concat(data,"\n") or data[1]
        end
        return data
    end
end

local function executempx(mpx,data)
    local terminal = mpxterminals[mpx]
    if terminal then
        terminal.writer(data)
        data = ""
    elseif type(data) == "table" then
        data = prepareddata(data,collapse)
    end
    metapost.nofruns = metapost.nofruns + 1
    return mpx:execute(data)
end

directives.register("mplib.texerrors",  function(v) metapost.texerrors = v end)
trackers.register  ("metapost.showlog", function(v) metapost.showlog   = v end)

function metapost.resetlastlog()
    metapost.lastlog = ""
end

----- mpbasepath = lpeg.instringchecker(lpeg.append { "/metapost/context/", "/metapost/base/" })
local mpbasepath = lpeg.instringchecker(P("/metapost/") * (P("context") + P("base")) * P("/"))

-- mplib has no real io interface so we have a different mechanism than
-- tex (as soon as we have more control, we will use the normal code)
--
-- for some reason mp sometimes calls this function twice which is inefficient
-- but we cannot catch this

local realtimelogging  do

    local finders = { }
    mplib.finders = finders -- also used in meta-lua.lua

    local new_instance = mplib.new

    local function validftype(ftype)
        if ftype == "mp" then
            return "mp"
        else
            return nil
        end
    end

    finders.file = function(specification,name,mode,ftype)
        return resolvers.findfile(name,validftype(ftype))
    end

    -- this will be redone in lmtx

    local function i_finder(name,mode,ftype) -- fake message for mpost.map and metafun.mpvi
        local specification = url.hashed(name)
        local finder = finders[specification.scheme] or finders.file
        local found = finder(specification,name,mode,validftype(ftype))
        return found
    end

    local function o_finder(name,mode,ftype)
        return name
    end

    o_finder = sandbox.register(o_finder,sandbox.filehandlerone,"mplib output finder")

    local function finder(name,mode,ftype)
        return (mode == "w" and o_finder or i_finder)(name,mode,validftype(ftype))
    end

    local report_logger = logs.reporter("metapost log")
    local report_error  = logs.reporter("metapost error")

    local l, nl, dl = { }, 0, false
    local t, nt, dt = { }, 0, false
    local e, ne, de = { }, 0, false

    local function logger(target,str)
        if target == 1 then
            -- log
        elseif target == 2 or target == 3 then
            -- term
            if str == "\n" then
                realtimelogging = true
                if nl > 0 then
                    report_logger(concat(l,"",1,nl))
                    nl, dl = 0, false
                elseif not dl then
                    report_logger("")
                    dl = true
                end
            else
                nl = nl + 1
                l[nl] = str
            end
        elseif target == 4 then
            report_error(str)
        end
    end

    -- experiment, todo: per instance, just a push / pop ?

    local findtexfile = resolvers.findtexfile
    local opentexfile = resolvers.opentexfile
    local splitlines  = string.splitlines

    local function writetoterminal(terminaldata,maxterm,d)
        local t = type(d)
        local n = 0
        if t == "string" then
            d = splitlines(d)
            n = #d
            for i=1,#d do
                maxterm = maxterm + 1
                terminaldata[maxterm] = d[i]
            end
        elseif t == "table" then
            for i=1,#d do
                local l = d[i]
                if find(l,"[\n\r]") then
                    local s = splitlines(l)
                    local m = #s
                    for i=1,m do
                        maxterm = maxterm + 1
                        terminaldata[maxterm] = s[i]
                    end
                    n = n + m
                else
                    maxterm = maxterm + 1
                    terminaldata[maxterm] = d[i]
                    n = 1
                end
            end
        end
        if trace_terminal then
            report_metapost("writing %i lines, in cache %s",n,maxterm)
        end
        return maxterm
    end

    local function readfromterminal(terminaldata,maxterm,nowterm)
        if nowterm >= maxterm then
            terminaldata[nowterm] = false
            maxterm = 0
            nowterm = 0
            if trace_terminal then
                report_metapost("resetting, maxcache %i",#terminaldata)
            end
            return maxterm, nowterm, nil
        else
            if nowterm > 0 then
                terminaldata[nowterm] = false
            end
            nowterm = nowterm + 1
            local s = terminaldata[nowterm]
            if trace_terminal then
                report_metapost("reading line %i: %s",nowterm,s)
            end
            return maxterm, nowterm, s
        end
    end

    local function fileopener()

        -- these can go into the table itself

        local terminaldata = { }
        local maxterm      = 0
        local nowterm      = 0

        local terminal = {
            name   = "terminal",
            close  = function()
             -- terminal = { }
             -- maxterm  = 0
             -- nowterm  = 0
            end,
            reader = function()
                local line
                maxterm, nowterm, line = readfromterminal(terminaldata,maxterm,nowterm)
                return line
            end,
            writer = function(d)
                maxterm = writetoterminal(terminaldata,maxterm,d)
            end,
        }

        return function(name,mode,kind)
            if name == "terminal" then
             -- report_metapost("opening terminal")
                return terminal
            elseif mode == "w" then
                local f = io.open(name,"wb")
                if f then
                 -- report_metapost("opening file %a for writing",full)
                    return {
                        name   = full,
                        writer = function(s) return f:write(s) end, -- io.write(f,s)
                        close  = function()  f:close() end,
                    }
                end
            else
                local full = findtexfile(name,validftype(ftype))
                if full then
                 -- report_metapost("opening file %a for reading",full)
                    return opentexfile(full)
                end
            end
        end

    end

    -- end of experiment

    if CONTEXTLMTXMODE > 0 then

        function mplib.new(specification)
            local openfile = fileopener()
            specification.find_file     = finder
            specification.run_logger    = logger
            specification.open_file     = openfile
            specification.interaction   = "silent"
            specification.halt_on_error = true
            local instance = new_instance(specification)
            mpxterminals[instance] = openfile("terminal")
            return instance
        end

    else

        function mplib.new(specification)
            specification.find_file  = finder
            specification.run_logger = logger
            return new_instance(specification)
        end

    end

    mplib.finder = finder

end

local new_instance = mplib.new
local find_file    = mplib.finder

function metapost.reporterror(result)
    if not result then
        report_metapost("error: no result object returned")
        return true
    elseif result.status == 0 then
        return false
    elseif realtimelogging then
        return false -- we already reported
    else
        local t = result.term
        local e = result.error
        local l = result.log
        local report = metapost.texerrors and texerrormessage or report_metapost
        if t and t ~= "" then
            report("mp error: %s",striplines(t))
        end
        if e == "" or e == "no-error" then
            e = nil
        end
        if e then
            report("mp error: %s",striplines(e))
        end
        if not t and not e and l then
            metapost.lastlog = metapost.lastlog .. "\n" .. l
            report_metapost("log: %s",l)
        else
            report_metapost("error: unknown, no error, terminal or log messages")
        end
        return true
    end
end

local f_preamble = formatters [ [[
    boolean mplib ; mplib := true ;
    let dump = endinput ;
    input "%s" ;
    randomseed:=%s;
]] ]

local methods = {
    double  = "double",
    scaled  = "scaled",
 -- binary  = "binary",
    binary  = "double",
    decimal = "decimal",
    default = "scaled",
}

function metapost.runscript(code)
    return ""
end

function metapost.scripterror(str)
    report_metapost("script error: %s",str)
end

-- todo: random_seed

local seed = nil

function metapost.load(name,method)
    starttiming(mplib)
    if not seed then
        seed = job.getrandomseed()
        if seed <= 1 then
            seed = seed % 1000
        elseif seed > 4095 then
            seed = seed % 4096
        end
    end
    method = method and methods[method] or "scaled"
    local mpx = new_instance {
        ini_version  = true,
        math_mode    = method,
        run_script   = metapost.runscript,
        script_error = metapost.scripterror,
        make_text    = metapost.maketext,
        extensions   = 1,
     -- random_seed  = seed,
        utf8_mode    = true,
    }
    report_metapost("initializing number mode %a",method)
    local result
    if not mpx then
        result = { status = 99, error = "out of memory"}
    else
        -- pushing permits advanced features
        metapost.pushscriptrunner(mpx)
        result = executempx(mpx,f_preamble(file.addsuffix(name,"mp"),seed))
        metapost.popscriptrunner()
    end
    stoptiming(mplib)
    metapost.reporterror(result)
    return mpx, result
end

function metapost.checkformat(mpsinput,method)
    local mpsinput  = mpsinput or "metafun"
    local foundfile = ""
    if file.suffix(mpsinput) ~= "" then
        foundfile  = find_file(mpsinput) or ""
    end
 -- if foundfile == "" then
 --     foundfile  = find_file(file.replacesuffix(mpsinput,"mpvi")) or ""
 -- end
    if CONTEXTLMTXMODE > 0 and foundfile == "" then
        foundfile  = find_file(file.replacesuffix(mpsinput,"mpxl")) or ""
    end
    if foundfile == "" then
        foundfile  = find_file(file.replacesuffix(mpsinput,"mpiv")) or ""
    end
    if foundfile == "" then
        foundfile  = find_file(file.replacesuffix(mpsinput,"mp")) or ""
    end
    if foundfile == "" then
        report_metapost("loading %a fails, format not found",mpsinput)
    else
        report_metapost("loading %a as %a using method %a",mpsinput,foundfile,method or "default")
        local mpx, result = metapost.load(foundfile,method)
        if mpx then
            return mpx
        else
            report_metapost("error in loading %a",mpsinput)
            metapost.reporterror(result)
        end
    end
end

function metapost.unload(mpx)
    starttiming(mplib)
    if mpx then
        mpx:finish()
    end
    stoptiming(mplib)
end

metapost.defaultformat   = "metafun"
metapost.defaultinstance = "metafun"
metapost.defaultmethod   = "default"

function metapost.getextradata(mpx)
    return mpxextradata[mpx]
end

function metapost.pushformat(specification,f,m) -- was: instance, name, method
    if type(specification) ~= "table" then
        specification = {
            instance = specification,
            format   = f,
            method   = m,
        }
    end
    local instance    = specification.instance
    local format      = specification.format
    local method      = specification.method
    local definitions = specification.definitions
    local extensions  = specification.extensions
    local preamble    = nil
    if not instance or instance == "" then
        instance = metapost.defaultinstance
        specification.instance = instance
    end
    if not format or format == "" then
        format = metapost.defaultformat
        specification.format = format
    end
    if not method or method == "" then
        method = metapost.defaultmethod
        specification.method = method
    end
    if definitions and definitions ~= "" then
        preamble = definitions
    end
    if extensions and extensions ~= "" then
        if preamble then
            preamble = preamble .. "\n" .. extensions
        else
            preamble = extensions
        end
    end
    nofformats = nofformats + 1
    local usedinstance = instance .. ":" .. nofformats
    local mpx = mpxformats  [usedinstance]
    local mpp = mpxpreambles[instance] or ""
 -- report_metapost("push instance %a (%S)",usedinstance,mpx)
    if preamble then
        preamble = prepareddata(preamble)
        mpp = mpp .. "\n" .. preamble
        mpxpreambles[instance] = mpp
    end
    if not mpx then
        report_metapost("initializing instance %a using format %a and method %a",usedinstance,format,method)
        mpx = metapost.checkformat(format,method)
        mpxformats  [usedinstance] = mpx
        mpxextradata[mpx] = { }
        if mpp ~= "" then
            preamble = mpp
        end
    end
    if preamble then
        executempx(mpx,preamble)
    end
    specification.mpx = mpx
    return mpx
end

-- luatex.wrapup(function()
--     for k, mpx in next, mpxformats do
--         mpx:finish()
--     end
-- end)

function metapost.popformat()
    nofformats = nofformats - 1
end

function metapost.reset(mpx)
    if not mpx then
        -- nothing
    elseif type(mpx) == "string" then
        if mpxformats[mpx] then
            local instance = mpxformats[mpx]
            instance:finish()
            mpxterminals[instance] = nil
            mpxextradata[mpx]      = nil
            mpxformats  [mpx]      = nil
        end
    else
        for name, instance in next, mpxformats do
            if instance == mpx then
                mpx:finish()
                mpxextradata[mpx] = nil
                mpxformats  [mpx] = nil
                mpxterminals[mpx] = nil
                break
            end
        end
    end
end

local mp_tra = { }
local mp_tag = 0

-- key/values

do

    local stack, top = { }, nil

    function metapost.setvariable(k,v)
        if top then
            top[k] = v
        else
            metapost.variables[k] = v
        end
    end

    function metapost.pushvariable(k)
        local t = { }
        if top then
            insert(stack,top)
            top[k] = t
        else
            metapost.variables[k] = t
        end
        top = t
    end

    function metapost.popvariable()
        top = remove(stack)
    end

    local stack = { }

    function metapost.pushvariables()
        insert(stack,metapost.variables)
        metapost.variables = { }
    end

    function metapost.popvariables()
        metapost.variables = remove(stack) or metapost.variables
    end

end


if not metapost.process then

    function metapost.process(specification)
        metapost.run(specification)
    end

end

-- run, process, convert and flush all work with a specification with the
-- following (often optional) fields
--
--     mpx          string or mp object
--     data         string or table of strings
--     flusher      table with flush methods
--     askedfig     string ("all" etc) or number
--     incontext    boolean
--     plugmode     boolean

local function makebeginbanner(specification)
    return formatters["%% begin graphic: n=%s\n\n"](metapost.n)
end

local function makeendbanner(specification)
    return "\n% end graphic\n\n"
end

function metapost.run(specification)
    local mpx       = specification.mpx
    local data      = specification.data
    local converted = false
    local result    = { }
    local mpxdone   = type(mpx) == "string"
    if mpxdone then
        mpx = metapost.pushformat { instance = mpx, format = mpx }
    end
    if mpx and data then
        local tra = nil
        starttiming(metapost) -- why not at the outer level ...
        metapost.variables = { } -- todo also push / pop
        metapost.pushscriptrunner(mpx)
        if trace_graphics then
            tra = mp_tra[mpx]
            if not tra then
                mp_tag = mp_tag + 1
                local jobname = tex.jobname
                tra = {
                    inp = io.open(formatters["%s-mplib-run-%03i.mp"] (jobname,mp_tag),"w"),
                    log = io.open(formatters["%s-mplib-run-%03i.log"](jobname,mp_tag),"w"),
                }
                mp_tra[mpx] = tra
            end
            local banner = makebeginbanner(specification)
            tra.inp:write(banner)
            tra.log:write(banner)
        end
        local function process(d,i)
            if d then
                if trace_graphics then
                    if i then
                        tra.inp:write(formatters["\n%% begin snippet %s\n"](i))
                    end
                    if type(d) == "table" then
                        for i=1,#d do
                            tra.inp:write(d[i])
                        end
                    else
                        tra.inp:write(d)
                    end
                    if i then
                        tra.inp:write(formatters["\n%% end snippet %s\n"](i))
                    end
                end
                starttiming(metapost.exectime)
                result = executempx(mpx,d)
                stoptiming(metapost.exectime)
                if trace_graphics and result then
                    local str = result.log or result.error
                    if str and str ~= "" then
                        tra.log:write(str)
                    end
                end
                if not metapost.reporterror(result) then
                    if metapost.showlog then
                        -- make function and overload in lmtx
                        local str = result.term ~= "" and result.term or "no terminal output"
                        if not emptystring(str) then
                            metapost.lastlog = metapost.lastlog .. "\n" .. str
                            report_metapost("log: %s",str)
                        end
                    end
                    if result.fig then
                        converted = metapost.convert(specification,result)
                    end
                end
            elseif i then
                report_metapost("error: invalid graphic component %s",i)
            else
                report_metapost("error: invalid graphic")
            end
        end

--         local data = prepareddata(data)
        if type(data) == "table" then
            if trace_tracingall then
                executempx(mpx,"tracingall;")
            end
                process(data)
--             for i=1,#data do
--                 process(data[i],i)
--             end
        else
            if trace_tracingall then
                data = "tracingall;" .. data
            end
            process(data)
        end
        if trace_graphics then
            local banner = makeendbanner(specification)
            tra.inp:write(banner)
            tra.log:write(banner)
        end
        stoptiming(metapost)
        metapost.popscriptrunner(mpx)
    end
    if mpxdone then
        metapost.popformat()
    end
    return converted, result
end

if not metapost.convert then

    function metapost.convert()
        report_metapost('warning: no converter set')
    end

end

-- This will be redone as we no longer output svg of ps!

-- function metapost.directrun(formatname,filename,outputformat,astable,mpdata)
--     local fullname = file.addsuffix(filename,"mp")
--     local data = mpdata or io.loaddata(fullname)
--     if outputformat ~= "svg" then
--         outputformat = "mps"
--     end
--     if not data then
--         report_metapost("unknown file %a",filename)
--     else
--         local mpx = metapost.checkformat(formatname)
--         if not mpx then
--             report_metapost("unknown format %a",formatname)
--         else
--             report_metapost("processing %a",(mpdata and (filename or "data")) or fullname)
--             local result = executempx(mpx,data)
--             if not result then
--                 report_metapost("error: no result object returned")
--             elseif result.status > 0 then
--                 report_metapost("error: %s",(result.term or "no-term") .. "\n" .. (result.error or "no-error"))
--             else
--                 if metapost.showlog then
--                     metapost.lastlog = metapost.lastlog .. "\n" .. result.term
--                     report_metapost("info: %s",result.term or "no-term")
--                 end
--                 local figures = result.fig
--                 if figures then
--                     local sorted = table.sortedkeys(figures)
--                     if astable then
--                         local result = { }
--                         report_metapost("storing %s figures in table",#sorted)
--                         for k=1,#sorted do
--                             local v = sorted[k]
--                             if outputformat == "mps" then
--                                 result[v] = figures[v]:postscript()
--                             else
--                                 result[v] = figures[v]:svg() -- (3) for prologues
--                             end
--                         end
--                         return result
--                     else
--                         local basename = file.removesuffix(file.basename(filename))
--                         for k=1,#sorted do
--                             local v = sorted[k]
--                             local output
--                             if outputformat == "mps" then
--                                 output = figures[v]:postscript()
--                             else
--                                 output = figures[v]:svg() -- (3) for prologues
--                             end
--                             local outname = formatters["%s-%s.%s"](basename,v,outputformat)
--                             report_metapost("saving %s bytes in %a",#output,outname)
--                             io.savedata(outname,output)
--                         end
--                         return #sorted
--                     end
--                 end
--             end
--         end
--     end
-- end

function metapost.directrun(formatname,filename,outputformat,astable,mpdata)
    report_metapost("producing postscript and svg is no longer supported")
end

do

    local result = { }
    local width  = 0
    local height = 0
    local depth  = 0
    local bbox   = { 0, 0, 0, 0 }

    local flusher = {
        startfigure = function(n,llx,lly,urx,ury)
            result = { }
            width  = urx - llx
            height = ury
            depth  = -lly
            bbox   = { llx, lly, urx, ury }
        end,
        flushfigure = function(t)
            local r = #result
            for i=1,#t do
                r = r + 1
                result[r] = t[i]
            end
        end,
        stopfigure = function()
        end,
    }

    -- make table variant:

    function metapost.simple(instance,code,useextensions,dontwrap)
        -- can we pickup the instance ?
        local mpx = metapost.pushformat {
            instance = instance or "simplefun",
            format   = "metafun", -- or: minifun
            method   = "double",
        }
        metapost.process {
            mpx        = mpx,
            flusher    = flusher,
            askedfig   = 1,
            useplugins = useextensions,
            data       = dontwrap and { code } or { "beginfig(1);", code, "endfig;" },
            incontext  = false,
        }
        metapost.popformat()
        if result then
            local stream = concat(result," ")
            result = { } -- nil -- cleanup .. weird, we can have a dangling q
            return stream, width, height, depth, bbox
        else
            return "", 0, 0, 0, { 0, 0, 0, 0 }
        end
    end

end

function metapost.getstatistics(memonly)
    if memonly then
        local n, m = 0, 0
        for name, mpx in next, mpxformats do
            n = n + 1
            m = m + mpx:statistics().memory
        end
        return n, m
    else
        local t = { }
        for name, mpx in next, mpxformats do
            t[name] = mpx:statistics()
        end
        return t
    end
end

