if not modules then modules = { } end modules ['mlib-run'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- todo mpx :execute -> mlib.execute(mpx,)

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
local striplines = utilities.strings.striplines
local concat, insert, remove = table.concat, table.insert, table.remove

local emptystring = string.is_empty
local P = lpeg.P

local trace_graphics   = false  trackers.register("metapost.graphics",   function(v) trace_graphics   = v end)
local trace_tracingall = false  trackers.register("metapost.tracingall", function(v) trace_tracingall = v end)

local report_metapost = logs.reporter("metapost")
local texerrormessage = logs.texerrormessage

local starttiming     = statistics.starttiming
local stoptiming      = statistics.stoptiming

local formatters      = string.formatters

local mplib           = mplib
metapost              = metapost or { }
local metapost        = metapost

metapost.showlog      = false
metapost.lastlog      = ""
metapost.collapse     = true -- currently mplib cannot deal with begingroup/endgroup mismatch in stepwise processing
metapost.texerrors    = false
metapost.exectime     = metapost.exectime or { } -- hack

-- metapost.collapse  = false

directives.register("mplib.texerrors",  function(v) metapost.texerrors = v end)
trackers.register  ("metapost.showlog", function(v) metapost.showlog   = v end)

function metapost.resetlastlog()
    metapost.lastlog = ""
end

----- mpbasepath = lpeg.instringchecker(lpeg.append { "/metapost/context/", "/metapost/base/" })
local mpbasepath = lpeg.instringchecker(P("/metapost/") * (P("context") + P("base")) * P("/"))

-- local function i_finder(askedname,mode,ftype) -- fake message for mpost.map and metafun.mpvi
--     local foundname = file.is_qualified_path(askedname) and askedname or resolvers.findfile(askedname,ftype)
--     if not mpbasepath(foundname) then
--         -- we could use the via file but we don't have a complete io interface yet
--         local data, found, forced = metapost.checktexts(io.loaddata(foundname) or "")
--         if found then
--             local tempname = luatex.registertempfile(foundname,true)
--             io.savedata(tempname,data)
--             foundname = tempname
--         end
--     end
--     return foundname
-- end

-- mplib has no real io interface so we have a different mechanism than
-- tex (as soon as we have more control, we will use the normal code)
--
-- for some reason mp sometimes calls this function twice which is inefficient
-- but we cannot catch this

do

    local finders = { }
    mplib.finders = finders -- also used in meta-lua.lua

    local new_instance = mplib.new

    local function preprocessed(name)
        if not mpbasepath(name) then
            -- we could use the via file but we don't have a complete io interface yet
            local data, found, forced = metapost.checktexts(io.loaddata(name) or "")
            if found then
                local temp = luatex.registertempfile(name,true)
                io.savedata(temp,data)
                return temp
            end
        end
        return name
    end

    mplib.preprocessed = preprocessed -- helper

    local function validftype(ftype)
        if ftype == "" then
            -- whatever
        elseif ftype == 0 then
            -- mplib bug
        else
            return ftype
        end
    end

    finders.file = function(specification,name,mode,ftype)
        return preprocessed(resolvers.findfile(name,validftype(ftype)))
    end

    local function i_finder(name,mode,ftype) -- fake message for mpost.map and metafun.mpvi
        local specification = url.hashed(name)
        local finder = finders[specification.scheme] or finders.file
        local found = finder(specification,name,mode,validftype(ftype))
     -- print(found)
        return found
    end

    local function o_finder(name,mode,ftype)
        return name
    end

    o_finder = sandbox.register(o_finder,sandbox.filehandlerone,"mplib output finder")

    local function finder(name,mode,ftype)
        return (mode == "w" and o_finder or i_finder)(name,mode,validftype(ftype))
    end

    function mplib.new(specification)
        specification.find_file = finder -- so we block an overload
        return new_instance(specification)
    end

    mplib.finder = finder

end

local new_instance = mplib.new
local find_file    = mplib.finder

function metapost.reporterror(result)
    if not result then
        report_metapost("error: no result object returned")
    elseif result.status > 0 then
        local t, e, l = result.term, result.error, result.log
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
    else
        return false
    end
    return true
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
    binary  = "binary",
    decimal = "decimal",
    default = "scaled",
}

function metapost.runscript(code)
    return code
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
    }
    report_metapost("initializing number mode %a",method)
    local result
    if not mpx then
        result = { status = 99, error = "out of memory"}
    else
        result = mpx:execute(f_preamble(file.addsuffix(name,"mp"),seed)) -- addsuffix is redundant
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
    if foundfile == "" then
        foundfile  = find_file(file.replacesuffix(mpsinput,"mpvi")) or ""
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

-- The flatten hack is needed because the library currently barks on \n\n and the
-- collapse because mp cannot handle snippets due to grouping issues.

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

local function prepareddata(data,collapse)
    if data and data ~= "" then
        if type(data) == "table" then
            data = flatten(data,{ })
            if collapse then
                data = #data > 1 and concat(data,"\n") or data[1]
            end
        end
        return data
    end
end

metapost.use_one_pass    = LUATEXFUNCTIONALITY >= 6789 -- for a while

metapost.defaultformat   = "metafun"
metapost.defaultinstance = "metafun"
metapost.defaultmethod   = "default"

local mpxformats   = { }
local nofformats   = 0
local mpxpreambles = { }

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
    local mpx = mpxformats[usedinstance]
    local mpp = mpxpreambles[instance] or ""
    if preamble then
        preamble = prepareddata(preamble,true)
        mpp = mpp .. "\n" .. preamble
        mpxpreambles[instance] = mpp
    end
    if not mpx then
        report_metapost("initializing instance %a using format %a and method %a",usedinstance,format,method)
        mpx = metapost.checkformat(format,method)
        mpxformats[usedinstance] = mpx
        if mpp ~= "" then
            preamble = mpp
        end
    end
    if preamble then
        mpx:execute(preamble)
    end
    specification.mpx = mpx
    return mpx
end

function metapost.popformat()
    nofformats = nofformats - 1
end

function metapost.reset(mpx)
    if not mpx then
        -- nothing
    elseif type(mpx) == "string" then
        if mpxformats[mpx] then
            mpxformats[mpx]:finish()
            mpxformats[mpx] = nil
        end
    else
        for name, instance in next, mpxformats do
            if instance == mpx then
                mpx:finish()
                mpxformats[name] = nil
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
--     trialrun     boolean
--     flusher      table with flush methods
--     multipass    boolean
--     isextrapass  boolean
--     askedfig     string ("all" etc) or number
--     incontext    boolean
--     plugmode     boolean

local function makebeginbanner(specification)
    return formatters
        ["%% begin graphic: n=%s, trialrun=%l, multipass=%l, isextrapass=%l\n\n"]
        (metapost.n, specification.trialrun, specification.multipass, specification.isextrapass)
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
        starttiming(metapost)
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
        local data = prepareddata(data,metapost.collapse)
        local function process(d,i)
            if d then
                if trace_graphics then
                    if i then
                        tra.inp:write(formatters["\n%% begin snippet %s\n"](i))
                    end
                    tra.inp:write(d)
                    if i then
                        tra.inp:write(formatters["\n%% end snippet %s\n"](i))
                    end
                end
                starttiming(metapost.exectime)
                result = mpx:execute(d)
                stoptiming(metapost.exectime)
                if trace_graphics and result then
                    local str = result.log or result.error
                    if str and str ~= "" then
                        tra.log:write(str)
                    end
                end
                if not metapost.reporterror(result) then
                    if metapost.showlog then
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

        if type(data) == "table" then
            if trace_tracingall then
                mpx:execute("tracingall;")
            end
            for i=1,#data do
                process(data[i],i)
            end
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

-- handy

function metapost.directrun(formatname,filename,outputformat,astable,mpdata)
    local fullname = file.addsuffix(filename,"mp")
    local data = mpdata or io.loaddata(fullname)
    if outputformat ~= "svg" then
        outputformat = "mps"
    end
    if not data then
        report_metapost("unknown file %a",filename)
    else
        local mpx = metapost.checkformat(formatname)
        if not mpx then
            report_metapost("unknown format %a",formatname)
        else
            report_metapost("processing %a",(mpdata and (filename or "data")) or fullname)
            local result = mpx:execute(data)
            if not result then
                report_metapost("error: no result object returned")
            elseif result.status > 0 then
                report_metapost("error: %s",(result.term or "no-term") .. "\n" .. (result.error or "no-error"))
            else
                if metapost.showlog then
                    metapost.lastlog = metapost.lastlog .. "\n" .. result.term
                    report_metapost("info: %s",result.term or "no-term")
                end
                local figures = result.fig
                if figures then
                    local sorted = table.sortedkeys(figures)
                    if astable then
                        local result = { }
                        report_metapost("storing %s figures in table",#sorted)
                        for k=1,#sorted do
                            local v = sorted[k]
                            if outputformat == "mps" then
                                result[v] = figures[v]:postscript()
                            else
                                result[v] = figures[v]:svg() -- (3) for prologues
                            end
                        end
                        return result
                    else
                        local basename = file.removesuffix(file.basename(filename))
                        for k=1,#sorted do
                            local v = sorted[k]
                            local output
                            if outputformat == "mps" then
                                output = figures[v]:postscript()
                            else
                                output = figures[v]:svg() -- (3) for prologues
                            end
                            local outname = formatters["%s-%s.%s"](basename,v,outputformat)
                            report_metapost("saving %s bytes in %a",#output,outname)
                            io.savedata(outname,output)
                        end
                        return #sorted
                    end
                end
            end
        end
    end
end

-- goodie

function metapost.quickanddirty(mpxformat,data,incontext)
    if not data then
        mpxformat = "metafun"
        data      = mpxformat
    end
    local code, bbox
    local flusher = {
        startfigure = function(n,llx,lly,urx,ury)
            code = { }
            bbox = { llx, lly, urx, ury }
        end,
        flushfigure = function(t)
            for i=1,#t do
                code[#code+1] = t[i]
            end
        end,
        stopfigure = function()
        end
    }
    local data = formatters["; beginfig(1) ;\n %s\n ; endfig ;"](data)
    metapost.process {
        mpx        = mpxformat,
        flusher    = flusher,
        askedfig   = "all",
        useplugins = incontext,
        incontext  = incontext,
        data       = { data },
    }
    if code then
        return {
            bbox = bbox or { 0, 0, 0, 0 },
            code = code,
            data = data,
        }
    else
        report_metapost("invalid quick and dirty run")
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

do

    local result = { }
    local width  = 0
    local height = 0
    local depth  = 0

    local flusher = {
        startfigure = function(n,llx,lly,urx,ury)
            result = { }
            width  = urx - llx
            height = ury
            depth  = -lly
        end,
        flushfigure = function(t)
            for i=1,#t do
                result[#result+1] = t[i]
            end
        end,
        stopfigure = function()
        end
    }

    function metapost.simple(format,code)   -- even less than metapost.quickcanddirty
        local mpx = metapost.pushformat { } -- takes defaults
     -- metapost.setoutercolor(2)
        metapost.process {
            mpx        = mpx,
            flusher    = flusher,
            askedfig   = 1,
            useplugins = false,
            incontext  = false,
            data       = { "beginfig(1);", code, "endfig;" },
        }
        metapost.popformat()
        if result then
            local stream = concat(result," ")
            result = nil -- cleanup
            return stream, width, height, depth
        else
            return "", 0, 0, 0
        end
    end

end
