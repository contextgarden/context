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

local type, tostring, tonumber = type, tostring, tonumber
local gsub, match, find = string.gsub, string.match, string.find
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

local f_textext = formatters[ [[rawtextext("%s")]] ]

function metapost.maketext(s,mode)
    if mode and mode == 1 then
     -- report_metapost("ignoring verbatimtex: %s",s)
    else
     -- report_metapost("handling btex ... etex: %s",s)
        s = gsub(s,'"','"&ditto&"')
        return f_textext(s)
    end
end

function metapost.load(name,method)
    starttiming(mplib)
    method = method and methods[method] or "scaled"
    local mpx = new_instance {
        ini_version  = true,
        math_mode    = method,
        run_script   = metapost.runscript,
        script_error = metapost.scripterror,
        make_text    = metapost.maketext,
        extensions   = 1,
    }
    report_metapost("initializing number mode %a",method)
    local result
    if not mpx then
        result = { status = 99, error = "out of memory"}
    else
        result = mpx:execute(f_preamble(file.addsuffix(name,"mp"))) -- addsuffix is redundant
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

local mpxformats = { }

function metapost.format(instance,name,method)
    if not instance or instance == "" then
        instance = "metafun" -- brrr
    end
    name = name or instance
    local mpx = mpxformats[instance]
    if not mpx then
        report_metapost("initializing instance %a using format %a",instance,name)
        mpx = metapost.checkformat(name,method)
        mpxformats[instance] = mpx
    end
    return mpx
end

function metapost.instance(instance)
    return mpxformats[instance]
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

if not metapost.initializescriptrunner then
    function metapost.initializescriptrunner() end
end

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

function metapost.process(mpx, data, trialrun, flusher, multipass, isextrapass, askedfig)
    local converted, result = false, { }
    if type(mpx) == "string" then
        mpx = metapost.format(mpx) -- goody
    end
    if mpx and data then
        local tra = nil
        starttiming(metapost)
        metapost.variables = { }
        metapost.initializescriptrunner(mpx,trialrun)
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
            local banner = formatters["%% begin graphic: n=%s, trialrun=%s, multipass=%s, isextrapass=%s\n\n"](
                metapost.n, tostring(trialrun), tostring(multipass), tostring(isextrapass))
            tra.inp:write(banner)
            tra.log:write(banner)
        end
        if type(data) == "table" then
            -- this hack is needed because the library currently barks on \n\n
            -- eventually we can text for "" in the next loop
            local n = 0
            local nofsnippets = #data
            for i=1,nofsnippets do
                local d = data[i]
                if d ~= "" then
                    n = n + 1
                    data[n] = d
                end
            end
            for i=nofsnippets,n+1,-1 do
                data[i] = nil
            end
            -- and this one because mp cannot handle snippets due to grouping issues
            if metapost.collapse then
                if #data > 1 then
                    data = concat(data,"\n")
                else
                    data = data[1]
                end
            end
            -- end of hacks
        end

        local function process(d,i)
         -- d = string.gsub(d,"\r","")
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
                result = mpx:execute(d) -- some day we wil use a coroutine with textexts
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
                        converted = metapost.convert(result, trialrun, flusher, multipass, askedfig)
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
         -- table.insert(data,2,"")
            for i=1,#data do
                process(data[i],i)
--                 local d = data[i]
--              -- d = string.gsub(d,"\r","")
--                 if d then
--                     if trace_graphics then
--                         tra.inp:write(formatters["\n%% begin snippet %s\n"](i))
--                         tra.inp:write(d)
--                         tra.inp:write(formatters["\n%% end snippet %s\n"](i))
--                     end
--                     starttiming(metapost.exectime)
--                     result = mpx:execute(d) -- some day we wil use a coroutine with textexts
--                     stoptiming(metapost.exectime)
--                     if trace_graphics and result then
--                         local str = result.log or result.error
--                         if str and str ~= "" then
--                             tra.log:write(str)
--                         end
--                     end
--                     if not metapost.reporterror(result) then
--                         if metapost.showlog then
--                             local str = result.term ~= "" and result.term or "no terminal output"
--                             if not emptystring(str) then
--                                 metapost.lastlog = metapost.lastlog .. "\n" .. str
--                                 report_metapost("log: %s",str)
--                             end
--                         end
--                         if result.fig then
--                             converted = metapost.convert(result, trialrun, flusher, multipass, askedfig)
--                         end
--                     end
--                 else
--                     report_metapost("error: invalid graphic component %s",i)
--                 end
            end
       else
            if trace_tracingall then
                data = "tracingall;" .. data
            end
            process(data)
--             starttiming(metapost.exectime)
--             result = mpx:execute(data)
--             stoptiming(metapost.exectime)
--             if trace_graphics and result then
--                 local str = result.log or result.error
--                 if str and str ~= "" then
--                     tra.log:write(str)
--                 end
--             end
--             -- todo: error message
--             if not result then
--                 report_metapost("error: no result object returned")
--             elseif result.status > 0 then
--                 report_metapost("error: %s",(result.term or "no-term") .. "\n" .. (result.error or "no-error"))
--             else
--                 if metapost.showlog then
--                     metapost.lastlog = metapost.lastlog .. "\n" .. result.term
--                     report_metapost("info: %s",result.term or "no-term")
--                 end
--                  if result.fig then
--                     converted = metapost.convert(result, trialrun, flusher, multipass, askedfig)
--                 end
--             end
        end
        if trace_graphics then
            local banner = "\n% end graphic\n\n"
            tra.inp:write(banner)
            tra.log:write(banner)
        end
        stoptiming(metapost)
    end
    return converted, result
end

function metapost.convert()
    report_metapost('warning: no converter set')
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

function metapost.quickanddirty(mpxformat,data,plugmode)
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
    metapost.process(mpxformat, { data }, false, flusher, false, false, "all", plugmode)
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
    local mpx    = false

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

    function metapost.simple(format,code) -- even less than metapost.quickcanddirty
        local mpx = metapost.format(format or "metafun","metafun")
     -- metapost.setoutercolor(2)
        metapost.process(mpx,
            { "beginfig(1);", code, "endfig;" },
            false, flusher, false, false, 1, true -- last true is plugmode !
        )
        if result then
            local stream = concat(result," ")
            result = nil -- cleanup
            return stream, width, height, depth
        else
            return "", 0, 0, 0
        end
    end

end
