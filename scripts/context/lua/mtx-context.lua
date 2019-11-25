if not modules then modules = { } end modules['mtx-context'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: more local functions
-- todo: pass jobticket/ctxdata table around

local type, next, tostring, tonumber = type, next, tostring, tonumber
local format, gmatch, match, gsub, find = string.format, string.gmatch, string.match, string.gsub, string.find
local quote, validstring = string.quote, string.valid
local sort, concat, insert, sortedhash, tohash = table.sort, table.concat, table.insert, table.sortedhash, table.tohash
local settings_to_array = utilities.parsers.settings_to_array
local appendtable = table.append
local lpegpatterns, lpegmatch, Cs, P = lpeg.patterns, lpeg.match, lpeg.Cs, lpeg.P

local getargument   = environment.getargument or environment.argument
local setargument   = environment.setargument

local filejoinname  = file.join
local filebasename  = file.basename
local filepathpart  = file.pathpart
local filesuffix    = file.suffix
local fileaddsuffix = file.addsuffix
local filenewsuffix = file.replacesuffix
local removesuffix  = file.removesuffix
local validfile     = lfs.isfile
local removefile    = os.remove
local renamefile    = os.rename
local formatters    = string.formatters

local application = logs.application {
    name     = "mtx-context",
    banner   = "ConTeXt Process Management 1.03",
 -- helpinfo = helpinfo, -- table with { category_a = text_1, category_b = text_2 } or helpstring or xml_blob
    helpinfo = "mtx-context.xml",
}

-- local luatexflags = {
--     ["8bit"]                        = true,  -- ignored, input is assumed to be in UTF-8 encoding
--     ["default-translate-file"]      = true,  -- ignored, input is assumed to be in UTF-8 encoding
--     ["translate-file"]              = true,  -- ignored, input is assumed to be in UTF-8 encoding
--     ["etex"]                        = true,  -- ignored, the etex extensions are always active
--     ["parse-first-line"]            = true,  -- ignored, enable parsing of the first line of the input file
--     ["no-parse-first-line"]         = true,  -- ignored, disable parsing of the first line of the input file
--
--     ["credits"]                     = true,  -- display credits and exit
--     ["debug-format"]                = true,  -- enable format debugging
--     ["disable-write18"]             = true,  -- disable \write18{SHELL COMMAND}
--     ["draftmode"]                   = true,  -- switch on draft mode (generates no output PDF)
--     ["enable-write18"]              = true,  -- enable \write18{SHELL COMMAND}
--     ["file-line-error"]             = true,  -- enable file:line:error style messages
--     ["file-line-error-style"]       = true,  -- aliases of --file-line-error
--     ["no-file-line-error"]          = true,  -- disable file:line:error style messages
--     ["no-file-line-error-style"]    = true,  -- aliases of --no-file-line-error
--     ["fmt"]                         = true,  -- load the format file FORMAT
--     ["halt-on-error"]               = true,  -- stop processing at the first error
--     ["help"]                        = true,  -- display help and exit
--     ["ini"]                         = true,  -- be iniluatex, for dumping formats
--     ["interaction"]                 = true,  -- set interaction mode (STRING=batchmode/nonstopmode/scrollmode/errorstopmode)
--     ["jobname"]                     = true,  -- set the job name to STRING
--     ["kpathsea-debug"]              = true,  -- set path searching debugging flags according to the bits of NUMBER
--     ["lua"]                         = true,  -- load and execute a lua initialization script
--     ["mktex"]                       = true,  -- enable mktexFMT generation (FMT=tex/tfm)
--     ["no-mktex"]                    = true,  -- disable mktexFMT generation (FMT=tex/tfm)
--     ["nosocket"]                    = true,  -- disable the lua socket library
--     ["output-comment"]              = true,  -- use STRING for DVI file comment instead of date (no effect for PDF)
--     ["output-directory"]            = true,  -- use existing DIR as the directory to write files in
--     ["output-format"]               = true,  -- use FORMAT for job output; FORMAT is 'dvi' or 'pdf'
--     ["progname"]                    = true,  -- set the program name to STRING
--     ["recorder"]                    = true,  -- enable filename recorder
--     ["safer"]                       = true,  -- disable easily exploitable lua commands
--     ["shell-escape"]                = true,  -- enable \write18{SHELL COMMAND}
--     ["no-shell-escape"]             = true,  -- disable \write18{SHELL COMMAND}
--     ["shell-restricted"]            = true,  -- restrict \write18 to a list of commands given in texmf.cnf
--     ["nodates"]                     = true,  -- no production dates in pdf file
--     ["trailerid"]                   = true,  -- alternative trailer id
--     ["synctex"]                     = true,  -- enable synctex
--     ["version"]                     = true,  -- display version and exit
--     ["luaonly"]                     = true,  -- run a lua file, then exit
--     ["luaconly"]                    = true,  -- byte-compile a lua file, then exit
--     ["jiton"]                       = false, -- not supported (makes no sense, slower)
-- }

local report = application.report

scripts         = scripts         or { }
scripts.context = scripts.context or { }

-- for the moment here

if jit then -- already luajittex
    setargument("engine","luajittex")
    setargument("jit",nil)
elseif getargument("jit") then -- relaunch luajittex
    -- bonus shortcut, we assume that --jit also indicates the engine
    -- although --jit and --engine=luajittex are independent
    setargument("engine","luajittex")
end

-- -- The way we use stubs will change in a bit in 2019 (mtxrun and context). We also normalize
-- -- the platforms to use a similar approach to this.

local engine_new = file.nameonly(getargument("engine") or directives.value("system.engine"))
local engine_old = file.nameonly(environment.ownbin)

local function restart(engine_old,engine_new)
    local command = format("%s --luaonly %q %s --redirected",engine_new,environment.ownname,environment.reconstructcommandline())
    report(format("redirect %s -> %s: %s",engine_old,engine_new,command))
    local result = os.execute(command)
    os.exit(result == 0 and 0 or 1)
end

-- if getargument("redirected") then
--     setargument("engine",engine_old) -- later on we need this
-- elseif engine_new == engine_old then
--     setargument("engine",engine_new) -- later on we need this
-- elseif environment.validengines[engine_new] and engine_new ~= environment.basicengines[engine_old] then
--     restart(engine_old,engine_new)
-- else
--     setargument("engine",engine_new) -- later on we need this
-- end

-- so far

-- constants

local usedfiles = {
    nop = "cont-nop.mkiv",
    yes = "cont-yes.mkiv",
}

local usedsuffixes = {
    before = {
        "tuc"
    },
    after = {
        "pdf", "tuc", "log"
    },
    keep = {
        "log"
    },
}

local formatofinterface = {
    en = "cont-en",
    uk = "cont-uk",
    de = "cont-de",
    fr = "cont-fr",
    nl = "cont-nl",
    cs = "cont-cs",
    it = "cont-it",
    ro = "cont-ro",
    pe = "cont-pe",
}

local defaultformats = {
    "cont-en",
 -- "cont-nl",
}

-- purging files (we should have an mkii and mkiv variants)

local generic_files = {
    "texexec.tex", "texexec.tui", "texexec.tuo",
    "texexec.tuc", "texexec.tua",
    "texexec.ps", "texexec.pdf", "texexec.dvi",
    "cont-opt.tex", "cont-opt.bak"
}

local obsolete_results = {
    "dvi",
}

local temporary_runfiles = {
    "tui",                             -- mkii two pass file
    "tua",                             -- mkiv obsolete
    "tup", "ted", "tes",               -- texexec
    "top",                             -- mkii options file
    "log",                             -- tex log file
    "tmp",                             -- mkii buffer file
    "run",                             -- mkii stub
    "bck",                             -- backup (obsolete)
    "rlg",                             -- resource log
    "ctl",                             --
    "mpt", "mpx", "mpd", "mpo", "mpb", -- metafun
    "prep",                            -- context preprocessed
    "pgf",                             -- tikz
    "aux", "blg",                      -- bibtex
}

local temporary_suffixes = {
    "prep",                            -- context preprocessed
}

local synctex_runfiles = {
    "synctex", "synctex.gz", "syncctx" -- synctex
}

local persistent_runfiles = {
    "tuo", -- mkii two pass file
    "tub", -- mkii buffer file
    "top", -- mkii options file
    "tuc", -- mkiv two pass file
    "bbl", -- bibtex
}

local special_runfiles = {
    "%-mpgraph", "%-mprun", "%-temp%-",
}

local extra_runfiles = {
    "^l_m_t_x_.-%.pdf$",
}

local function purge_file(dfile,cfile)
    if cfile and validfile(cfile) then
        if removefile(dfile) then
            return filebasename(dfile)
        end
    elseif dfile then
        if removefile(dfile) then
            return filebasename(dfile)
        end
    end
end

-- process information

local ctxrunner = { } -- namespace will go

local ctx_locations = { '..', '../..' }

function ctxrunner.new()
    return {
        ctxname   = "",
        jobname   = "",
        flags     = { },
    }
end

function ctxrunner.checkfile(ctxdata,ctxname,defaultname)

    if not ctxdata.jobname or ctxdata.jobname == "" or getargument("noctx") then
        return
    end

    ctxdata.ctxname = ctxname or removesuffix(ctxdata.jobname) or ""

    if ctxdata.ctxname == "" then
        return
    end

    ctxdata.jobname = fileaddsuffix(ctxdata.jobname,'tex')
    ctxdata.ctxname = fileaddsuffix(ctxdata.ctxname,'ctx')

    report("jobname: %s",ctxdata.jobname)
    report("ctxname: %s",ctxdata.ctxname)

    -- mtxrun should resolve kpse: and file:

    local usedname = ctxdata.ctxname
    local found    = validfile(usedname)

    -- no further test if qualified path

    if not found then
        for _, path in next, ctx_locations do
            local fullname = filejoinname(path,ctxdata.ctxname)
            if validfile(fullname) then
                usedname = fullname
                found    = true
                break
            end
        end
    end

    if not found then
        usedname = resolvers.findfile(ctxdata.ctxname,"tex")
        found    = usedname ~= ""
    end

    if not found and defaultname and defaultname ~= "" and validfile(defaultname) then
        usedname = defaultname
        found    = true
    end

    if not found then
        return
    end

    local xmldata = xml.load(usedname)

    if not xmldata then
        return
    else
        -- test for valid, can be text file
    end

    local ctxpaths = table.append({'.', filepathpart(ctxdata.ctxname)}, ctx_locations)

    xml.include(xmldata,'ctx:include','name', ctxpaths)

    local flags = ctxdata.flags

    for e in xml.collected(xmldata,"/ctx:job/ctx:flags/ctx:flag") do
        local flag = xml.text(e) or ""
        local key, value = match(flag,"^(.-)=(.+)$")
        if key and value then
            flags[key] = value
        else
            flags[flag] = true
        end
    end

end

function ctxrunner.checkflags(ctxdata)
    if ctxdata then
        for k,v in next, ctxdata.flags do
            if getargument(k) == nil then
                setargument(k,v)
            end
        end
    end
end

-- multipass control

local multipass_suffixes   = { ".tuc" }
local multipass_nofruns    = 9 -- better for tracing oscillation
local multipass_forcedruns = false

local function multipass_hashfiles(jobname)
    local hash = { }
    for i=1,#multipass_suffixes do
        local suffix = multipass_suffixes[i]
        local full = jobname .. suffix
        hash[full] = md5.hex(io.loaddata(full) or "unknown")
    end
    return hash
end

local function multipass_changed(oldhash, newhash)
    for k,v in next, oldhash do
        if v ~= newhash[k] then
            return true
        end
    end
    return false
end

local f_tempfile = formatters["%s-%s-%02d.tmp"]

local function backup(jobname,run,kind,filename)
    if run == 1 then
        for i=1,10 do
            local tmpname = f_tempfile(jobname,kind,i)
            if validfile(tmpname) then
                removefile(tmpname)
                report("removing %a",tmpname)
            end
        end
    end
    if validfile(filename) then
        local tmpname = f_tempfile(jobname,kind,run or 1)
        report("copying %a into %a",filename,tmpname)
        file.copy(filename,tmpname)
    else
        report("no file %a, nothing kept",filename)
    end
end

local function multipass_copyluafile(jobname,run)
    local tuaname, tucname = jobname..".tua", jobname..".tuc"
    if validfile(tuaname) then
        if run then
            backup(jobname,run,"tuc",tucname)
            report("copying %a into %a",tuaname,tucname)
            report()
        end
        removefile(tucname)
        renamefile(tuaname,tucname)
    end
end

local function multipass_copylogfile(jobname,run)
    local logname = jobname..".log"
    if validfile(logname) then
        if run then
            backup(jobname,run,"log",logname)
            report()
        end
    end
end

--

local pattern = lpegpatterns.utfbom^-1 * (P("%% ") + P("% ")) * Cs((1-lpegpatterns.newline)^1)

local prefile = nil
local predata = nil

local function preamble_analyze(filename) -- only files on current path
    filename = fileaddsuffix(filename,"tex") -- to be sure
    if predata and prefile == filename then
        return predata
    end
    prefile = filename
    predata = { }
    local line = io.loadlines(prefile)
    if line then
        local preamble = lpegmatch(pattern,line)
        if preamble then
            utilities.parsers.options_to_hash(preamble,predata)
            predata.type = "tex"
        elseif find(line,"^<?xml ") then
            predata.type = "xml"
        end
        if predata.nofruns then
            multipass_nofruns = predata.nofruns
        end
        if not predata.engine then
            predata.engine = environment.basicengines[engine_old] --'luatex'
        end
        if predata.engine ~= engine_old then -- hack
            if environment.validengines[predata.engine] and predata.engine ~= environment.basicengines[engine_old] then
                restart(engine_old,predata.engine)
            end
        end
    end
    return predata
end

-- automatically opening and closing pdf files

local pdfview -- delayed

local function pdf_open(name,method)
    statistics.starttiming("pdfview")
    pdfview = pdfview or dofile(resolvers.findfile("l-pdfview.lua","tex"))
    pdfview.setmethod(method)
    report(pdfview.status())
    local pdfname = filenewsuffix(name,"pdf")
    if not lfs.isfile(pdfname) then
        pdfname = name .. ".pdf" -- agressive
    end
    pdfview.open(pdfname)
    statistics.stoptiming("pdfview")
    report("pdfview overhead: %s seconds",statistics.elapsedtime("pdfview"))
end

local function pdf_close(name,method)
    statistics.starttiming("pdfview")
    pdfview = pdfview or dofile(resolvers.findfile("l-pdfview.lua","tex"))
    pdfview.setmethod(method)
    local pdfname = filenewsuffix(name,"pdf")
    if lfs.isfile(pdfname) then
        pdfview.close(pdfname)
    end
    pdfname = name .. ".pdf" -- agressive
    pdfview.close(pdfname)
    statistics.stoptiming("pdfview")
end

-- result file handling

local function result_push_purge(oldbase,newbase)
    for _, suffix in next, usedsuffixes.after do
        local oldname = fileaddsuffix(oldbase,suffix)
        local newname = fileaddsuffix(newbase,suffix)
        removefile(newname)
        removefile(oldname)
    end
end

local function result_push_keep(oldbase,newbase)
    for _, suffix in next, usedsuffixes.before do
        local oldname = fileaddsuffix(oldbase,suffix)
        local newname = fileaddsuffix(newbase,suffix)
        local tmpname = "keep-"..oldname
        removefile(tmpname)
        renamefile(oldname,tmpname)
        removefile(oldname)
        renamefile(newname,oldname)
    end
end

local function result_save_error(oldbase,newbase)
    for _, suffix in next, usedsuffixes.keep do
        local oldname = fileaddsuffix(oldbase,suffix)
        local newname = fileaddsuffix(newbase,suffix)
        removefile(newname) -- to be sure
        renamefile(oldname,newname)
    end
end

local function result_save_purge(oldbase,newbase)
    for _, suffix in next, usedsuffixes.after do
        local oldname = fileaddsuffix(oldbase,suffix)
        local newname = fileaddsuffix(newbase,suffix)
        removefile(newname) -- to be sure
        renamefile(oldname,newname)
    end
end

local function result_save_keep(oldbase,newbase)
    for _, suffix in next, usedsuffixes.after do
        local oldname = fileaddsuffix(oldbase,suffix)
        local newname = fileaddsuffix(newbase,suffix)
        local tmpname = "keep-"..oldname
        removefile(newname)
        renamefile(oldname,newname)
        renamefile(tmpname,oldname)
    end
end

-- use mtx-plain instead

local plain_formats = {
    ["plain"]        = "plain",
    ["luatex-plain"] = "luatex-plain",
}

local function plain_format(plainformat)
    return plainformat and plain_formats[plainformat]
end

local function run_plain(plainformat,filename)
    local plainformat = plain_formats[plainformat]
    if plainformat then
        local command = format("mtxrun --script --texformat=%s plain %s",plainformat,filename)
        report("running command: %s\n\n",command)
        -- todo: load and run
        local resultname = filenewsuffix(filename,"pdf")
        local pdfview = getargument("autopdf") or getargument("closepdf")
        if pdfview then
            pdf_close(resultname,pdfview)
            os.execute(command) -- maybe also a proper runner
            pdf_open(resultname,pdfview)
        else
            os.execute(command) -- maybe also a proper runner
        end
    end
end

local function run_texexec(filename,a_purge,a_purgeall)
    if false then
        -- we need to write a top etc too and run mp etc so it's not worth the
        -- trouble, so it will take a while before the next is finished
        --
        -- context --extra=texutil --convert myfile
    else
        local texexec = resolvers.findfile("texexec.rb") or ""
        if texexec ~= "" then
            os.setenv("RUBYOPT","")
            local options = environment.reconstructcommandline(environment.arguments_after)
            options = gsub(options,"--purge","")
            options = gsub(options,"--purgeall","")
            local command = format("ruby %s %s",texexec,options)
            report("running command: %s\n\n",command)
            if a_purge then
                os.execute(command)
                scripts.context.purge_job(filename,false,true)
            elseif a_purgeall then
                os.execute(command)
                scripts.context.purge_job(filename,true,true)
            else
                os.execute(command) -- we can use os.exec but that doesn't give back timing
            end
        end
    end
end

-- executing luatex

local function flags_to_string(flags,prefix)
    -- context flags get prepended by c: ... this will move to the sbx module
    local t = { }
    for k, v in table.sortedhash(flags) do
        if prefix then
            k = format("c:%s",k)
        end
        if not v or v == "" or v == '""' then
            -- no need to flag false
        elseif v == true then
            t[#t+1] = format('--%s',k)
        elseif type(v) == "string" then
            t[#t+1] = format('--%s=%s',k,quote(v))
        else
            t[#t+1] = format('--%s=%s',k,tostring(v))
        end
    end
    return concat(t," ")
end

function scripts.context.run(ctxdata,filename)
    --
    local verbose  = false
    --
    local a_nofile = getargument("nofile")
    local a_engine = getargument("engine")
    --
    local files    = environment.filenames or { }
    --
    local filelist, mainfile
    --
    if filename then
        -- the given forced name is processed, the filelist is passed to context
        mainfile = filename
        filelist = { filename }
     -- files    = files
    elseif a_nofile then
        -- the list of given files is processed using the dummy file
        mainfile = usedfiles.nop
        filelist = { usedfiles.nop }
     -- files    = { }
    elseif #files > 0 then
        -- the list of given files is processed using the stub file
        mainfile = usedfiles.yes
        filelist = files
        files    = { }
    else
        return
    end
    --
    local interface  = validstring(getargument("interface")) or "en"
    local formatname = formatofinterface[interface] or "cont-en"
    local formatfile,
          scriptfile = resolvers.locateformat(formatname) -- regular engine !
    if not formatfile or not scriptfile then
        report("warning: no format found, forcing remake (commandline driven)")
        scripts.context.make(formatname)
        formatfile, scriptfile = resolvers.locateformat(formatname) -- variant
    end
    if formatfile and scriptfile then
        -- okay
    elseif formatname then
        report("error, no format found with name: %s, aborting",formatname)
        return
    else
        report("error, no format found (provide formatname or interface)")
        return
    end
    --
    local a_mkii          = getargument("mkii") or getargument("pdftex") or getargument("xetex")
    local a_purge         = getargument("purge")
    local a_purgeall      = getargument("purgeall")
    local a_purgeresult   = getargument("purgeresult")
    local a_global        = getargument("global")
    local a_timing        = getargument("timing")
    local a_profile       = getargument("profile")
    local a_batchmode     = getargument("batchmode")
    local a_nonstopmode   = getargument("nonstopmode")
    local a_scollmode     = getargument("scrollmode")
    local a_once          = getargument("once")
    local a_backend       = getargument("backend")
    local a_arrange       = getargument("arrange")
    local a_noarrange     = getargument("noarrange")
    local a_jithash       = getargument("jithash")
    local a_texformat     = getargument("texformat")
    local a_keeptuc       = getargument("keeptuc")
    local a_keeplog       = getargument("keeplog")
    local a_export        = getargument("export")
    local a_nodates       = getargument("nodates")
    local a_trailerid     = getargument("trailerid")
    local a_nocompression = getargument("nocompression")
    --
    a_batchmode = (a_batchmode and "batchmode") or (a_nonstopmode and "nonstopmode") or (a_scrollmode and "scrollmode") or nil
    --
    for i=1,#filelist do
        --
        local filename = filelist[i]

        if filename == "" then
            report("warning: bad filename")
            break
        end

        local basename = filebasename(filename) -- use splitter
        local pathname = filepathpart(filename)
        --
        if pathname == "" and not a_global and filename ~= usedfiles.nop then
            filename = "./" .. filename
            if not validfile(filename) and not validfile(filename..".tex") then
                report("warning: no (local) file %a, proceeding",filename)
            end
        end
        --
        local jobname  = removesuffix(basename)
     -- local jobname  = removesuffix(filename)
        local ctxname  = ctxdata and ctxdata.ctxname
        --
        local analysis = preamble_analyze(filename)
        --
        if a_mkii or analysis.engine == 'pdftex' or analysis.engine == 'xetex' then
            run_texexec(filename,a_purge,a_purgeall)
        elseif plain_format(a_texformat or analysis.texformat) then
            run_plain(a_texformat or analysis.texformat,filename)
        else
            if analysis.interface and analysis.interface ~= interface then
                formatname = formatofinterface[analysis.interface] or formatname
                formatfile, scriptfile = resolvers.locateformat(formatname)
            end
            --
            a_jithash = validstring(a_jithash or analysis.jithash) or nil
            --
            if not formatfile or not scriptfile then
                report("warning: no format found, forcing remake (source driven)")
                scripts.context.make(formatname,a_engine)
                formatfile, scriptfile = resolvers.locateformat(formatname)
            end
            --
            local function combine(key)
                local flag = validstring(environment[key])
                local plus = analysis[key]
                if flag and plus then
                    return plus .. "," .. flag -- flag wins
                else
                    return flag or plus -- flag wins
                end
            end
            local a_trackers    = analysis.trackers
            local a_experiments = analysis.experiments
            local directives    = combine("directives")
            local trackers      = combine("trackers")
            local experiments   = combine("experiments")
            --
            if formatfile and scriptfile then
                local suffix     = validstring(getargument("suffix"))
                local resultname = validstring(getargument("result"))
                local resultpath = file.pathpart(resultname)
                if resultpath ~= "" then
                    resultname  = nil
                elseif suffix then
                    resultname = removesuffix(jobname) .. suffix
                end
                local oldbase = ""
                local newbase = ""
                if resultname then
                    oldbase = removesuffix(jobname)
                    newbase = removesuffix(resultname)
                    if oldbase ~= newbase then
                        if a_purgeresult then
                            result_push_purge(oldbase,newbase)
                        else
                            result_push_keep(oldbase,newbase)
                        end
                    else
                        resultname = nil
                    end
                end
                --
                local pdfview = getargument("autopdf") or getargument("closepdf")
                if pdfview then
                    pdf_close(filename,pdfview)
                    if resultname then
                        pdf_close(resultname,pdfview)
                    end
                end
                --
                -- we could do this when locating the format and exit from luatex when
                -- there is a version mismatch .. that way we can use stock luatex
                -- plus mtxrun to run luajittex instead .. this saves a restart but is
                -- also cleaner as then mtxrun only has to check for a special return
                -- code (signaling a make + rerun) .. maybe some day
                --
                local okay = statistics.checkfmtstatus(formatfile,a_engine)
                if okay ~= true then
                    report("warning: %s, forcing remake",tostring(okay))
                    scripts.context.make(formatname)
                end
                --
                local oldhash     = multipass_hashfiles(jobname)
                local newhash     = { }
                local maxnofruns  = once and 1 or multipass_nofruns
                local fulljobname = validstring(filename)
                --
                local c_flags = {
                    directives     = directives,   -- gets passed via mtxrun
                    trackers       = trackers,     -- gets passed via mtxrun
                    experiments    = experiments,  -- gets passed via mtxrun
                    --
                    result         = validstring(resultname),
                    input          = validstring(getargument("input") or filename), -- alternative input
                    fulljobname    = fulljobname,
                    files          = concat(files,","),
                    ctx            = validstring(ctxname),
                    export         = a_export and true or nil,
                    nocompression  = a_nocompression and true or nil,
                    texmfbinpath   = os.selfdir,
                }
                --
                for k, v in next, environment.arguments do
                    -- the raw arguments
                    if c_flags[k] == nil then
                        c_flags[k] = v
                    end
                end
                --
                -- todo: --output-file=... in luatex
                --
                local l_flags = {
                    ["interaction"]           = a_batchmode,
                 -- ["synctex"]               = false,       -- context has its own way
                 -- ["no-parse-first-line"]   = true,        -- obsolete
                 -- ["safer"]                 = a_safer,     -- better use --sandbox
                 -- ["no-mktex"]              = true,
                 -- ["file-line-error-style"] = true,
--                     ["fmt"]                   = formatfile,
--                     ["lua"]                   = scriptfile,
                    ["jobname"]               = jobname,
                    ["jithash"]               = a_jithash,
                }
                --
                if not a_timing then
                    -- okay
                elseif c_flags.usemodule then
                    c_flags.usemodule = format("timing,%s",c_flags.usemodule)
                else
                    c_flags.usemodule = "timing"
                end
                --
                local directives = { }
                --
                if a_nodates then
                    directives[#directives+1] = format("backend.date=%s",type(a_nodates) == "string" and a_nodates or " no")
                end
                --
                if type(a_trailerid) == "string" then
                    directives[#directives+1] = format("backend.trailerid=%s",a_trailerid)
                end
                --
                if a_profile then
                    directives[#directives+1] = format("system.profile=%s",tonumber(a_profile) or 0)
                end
                --
                for i=1,#synctex_runfiles do
                    removefile(fileaddsuffix(jobname,synctex_runfiles[i]))
                end
                --
                if #directives > 0 then
                    c_flags.directives = concat(directives,",")
                end
                --
                -- kindofrun: 1:first run, 2:successive run, 3:once, 4:last of maxruns
                --
                for currentrun=1,maxnofruns do
                    --
                    c_flags.final      = false
                    c_flags.kindofrun  = (a_once and 3) or (currentrun==1 and 1) or (currentrun==maxnofruns and 4) or 2
                    c_flags.maxnofruns = maxnofruns
                    c_flags.forcedruns = multipass_forcedruns and multipass_forcedruns > 0 and multipass_forcedruns or nil
                    c_flags.currentrun = currentrun
                    c_flags.noarrange  = a_noarrange or a_arrange or nil
                    c_flags.profile    = a_profile and (tonumber(a_profile) or 0) or nil
                    --
                    print("") -- cleaner, else continuation on same line
                    local returncode = environment.run_format(
                        formatfile,
                        scriptfile,
                        mainfile,
                        flags_to_string(l_flags),
                        flags_to_string(c_flags,true),
                        verbose
                    )
                    -- todo: remake format when no proper format is found
                    if not returncode then
                        report("fatal error: no return code")
                        if resultname then
                            result_save_error(oldbase,newbase)
                        end
                        os.exit(1)
                        break
                    elseif returncode == 0 then
                        multipass_copyluafile(jobname,a_keeptuc and currentrun)
                        multipass_copylogfile(jobname,a_keeplog and currentrun)
                        if not multipass_forcedruns then
                            newhash = multipass_hashfiles(jobname)
                            if multipass_changed(oldhash,newhash) then
                                oldhash = newhash
                            else
                                break
                            end
                        elseif currentrun == multipass_forcedruns then
                            report("quitting after force %i runs",multipass_forcedruns)
                            break
                        end
                    else
                        report("fatal error: return code: %s",returncode or "?")
                        if resultname then
                            result_save_error(oldbase,newbase)
                        end
                        os.exit(1) -- (returncode)
                        break
                    end
                    --
                end
                --
                if environment.arguments["ansilog"] then
                    local logfile = file.replacesuffix(jobname,"log")
                    local logdata = io.loaddata(logfile) or ""
                    if logdata ~= "" then
                        io.savedata(logfile,(gsub(logdata,"%[.-m","")))
                    end
                end
                --
                --
                --  this will go away after we update luatex
                --
                local syncctx = fileaddsuffix(jobname,"syncctx")
                if validfile(syncctx) then
                    renamefile(syncctx,fileaddsuffix(jobname,"synctex"))
                end
                --
                if a_arrange then
                    --
                    c_flags.final      = true
                    c_flags.kindofrun  = 3
                    c_flags.currentrun = c_flags.currentrun + 1
                    c_flags.noarrange  = nil
                    --
                    report("arrange run: %s",command)
                    --
                    local returncode = environment.run_format(
                        formatfile,
                        scriptfile,
                        mainfile,
                        flags_to_string(l_flags),
                        flags_to_string(c_flags,true),
                        verbose
                    )
                    --
                    if not returncode then
                        report("fatal error: no return code, message: %s",errorstring or "?")
                        os.exit(1)
                    elseif returncode > 0 then
                        report("fatal error: return code: %s",returncode or "?")
                        os.exit(returncode)
                    end
                    --
                end
                --
                if a_purge then
                    scripts.context.purge_job(jobname,false,false,fulljobname)
                elseif a_purgeall then
                    scripts.context.purge_job(jobname,true,false,fulljobname)
                end
                --
                if resultname then
                    if a_purgeresult then
                        -- so, if there is no result then we don't get the old one, but
                        -- related files (log etc) are still there for tracing purposes
                        result_save_purge(oldbase,newbase)
                    else
                        result_save_keep(oldbase,newbase)
                    end
                    report("result renamed to: %s",newbase)
                elseif resultpath ~= "" then
                    report()
                    report("results are to be on the running path, not on %a, ignoring --result",resultpath)
                    report()
                end
                --
             -- -- needs checking
             --
             -- if a_purge then
             --     scripts.context.purge_job(resultname)
             -- elseif a_purgeall then
             --     scripts.context.purge_job(resultname,true)
             -- end
                --
                local pdfview = getargument("autopdf")
                if pdfview then
                    pdf_open(resultname or jobname,pdfview)
                end
                --
                local epub = analysis.epub
                if epub then
                    if type(epub) == "string" then
                        local t = settings_to_array(epub)
                        for i=1,#t do
                            t[i] = "--" .. gsub(t[i],"^%-*","")
                        end
                        epub = concat(t," ")
                    else
                        epub = "--make"
                    end
                    local command = "mtxrun --script epub " .. epub .. " " .. jobname
                    report()
                    report("making epub file: ",command)
                    report()
                    os.execute(command) -- todo: also a runner
                end
                --
                if a_timing then
                    report()
                    report("you can process (timing) statistics with:",jobname)
                    report()
                    report("context --extra=timing '%s'",jobname)
                    report("mtxrun --script timing --xhtml [--launch --remove] '%s'",jobname)
                    report()
                end
            else
                if formatname then
                    report("error, no format found with name: %s, skipping",formatname)
                else
                    report("error, no format found (provide formatname or interface)")
                end
                break
            end
        end
    end
    --
end

function scripts.context.pipe() -- still used?
    -- context --pipe
    -- context --pipe --purge --dummyfile=whatever.tmp
    local interface = getargument("interface")
    interface = (type(interface) == "string" and interface) or "en"
    local formatname = formatofinterface[interface] or "cont-en"
    local formatfile, scriptfile = resolvers.locateformat(formatname)
    if not formatfile or not scriptfile then
        report("warning: no format found, forcing remake (commandline driven)")
        scripts.context.make(formatname)
        formatfile, scriptfile = resolvers.locateformat(formatname)
    end
    if formatfile and scriptfile then
        local okay = statistics.checkfmtstatus(formatfile)
        if okay ~= true then
            report("warning: %s, forcing remake",tostring(okay))
            scripts.context.make(formatname)
        end
        local l_flags = {
            interaction = "scrollmode",
            fmt         = formatfile,
            lua         = scriptfile,
        }
        local c_flags = {
            backend     = "pdf",
            final       = false,
            kindofrun   = 3,
            currentrun  = 1,
        }
        local filename = getargument("dummyfile") or ""
        if filename == "" then
            filename = "\\relax"
            report("entering scrollmode, end job with \\end")
        else
            filename = fileaddsuffix(filename,"tmp")
            io.savedata(filename,"\\relax")
            report("entering scrollmode using '%s' with optionfile, end job with \\end",filename)
        end
        local returncode = environment.run_format(
            formatfile,
            scriptfile,
            filename,
            flags_to_string(l_flags),
            flags_to_string(c_flags,true),
            verbose
        )
        if getargument("purge") then
            scripts.context.purge_job(filename)
        elseif getargument("purgeall") then
            scripts.context.purge_job(filename,true)
            removefile(filename)
        end
    elseif formatname then
        report("error, no format found with name: %s, aborting",formatname)
    else
        report("error, no format found (provide formatname or interface)")
    end
end

local function make_mkiv_format(name,engine)
    environment.make_format(name) -- jit is picked up later
end

local make_mkii_format

do -- more or less copied from mtx-plain.lua:

    local function mktexlsr()
        if environment.arguments.silent then
            local result = os.execute("mktexlsr --quiet > temp.log")
            if result ~= 0 then
                print("mktexlsr silent run > fatal error") -- we use a basic print
            else
                print("mktexlsr silent run") -- we use a basic print
            end
            removefile("temp.log")
        else
            report("running mktexlsr")
            os.execute("mktexlsr")
        end
    end

    local function engine(texengine,texformat)
        local command = string.format('%s --ini --etex --8bit %s \\dump',texengine,fileaddsuffix(texformat,"mkii"))
        if environment.arguments.silent then
            statistics.starttiming()
            local command = format("%s > temp.log",command)
            local result  = os.execute(command)
            local runtime = statistics.stoptiming()
            if result ~= 0 then
                print(format("%s silent make > fatal error when making format %q",texengine,texformat)) -- we use a basic print
            else
                print(format("%s silent make > format %q made in %.3f seconds",texengine,texformat,runtime)) -- we use a basic print
            end
            removefile("temp.log")
        else
            report("running command: %s",command)
            os.execute(command)
        end
    end

    local function resultof(...)
        local command = string.format(...)
        report("running command %a",command)
        return string.strip(os.resultof(command) or "")
    end

    local function make(texengine,texformat)
        report("generating kpse file database")
        mktexlsr()
        local fmtpathspec = resultof("kpsewhich --var-value=TEXFORMATS --engine=%s",texengine)
        if fmtpathspec ~= "" then
            report("using path specification %a",fmtpathspec)
            fmtpathspec = resultof('kpsewhich -expand-braces="%s"',fmtpathspec)
        end
        if fmtpathspec ~= "" then
            report("using path expansion %a",fmtpathspec)
        else
            report("no valid path reported, trying alternative")
            fmtpathspec = resultof("kpsewhich --show-path=fmt --engine=%s",texengine)
            if fmtpathspec ~= "" then
                report("using path expansion %a",fmtpathspec)
            else
                report("no valid path reported, falling back to current path")
                fmtpathspec = "."
            end
        end
        fmtpathspec = string.splitlines(fmtpathspec)[1] or fmtpathspec
        fmtpathspec = fmtpathspec and file.splitpath(fmtpathspec)
        local fmtpath = nil
        if fmtpathspec then
            for i=1,#fmtpathspec do
                local path = fmtpathspec[i]
                if path ~= "." then
                    dir.makedirs(path)
                    if lfs.isdir(path) and file.is_writable(path) then
                        fmtpath = path
                        break
                    end
                end
            end
        end
        if not fmtpath or fmtpath == "" then
            fmtpath = "."
        else
            lfs.chdir(fmtpath)
        end
        engine(texengine,texformat)
        report("generating kpse file database")
        mktexlsr()
        report("format %a saved on path %a",texformat,fmtpath)
    end

    local function run(texengine,texformat,filename)
        local t = { }
        for k, v in next, environment.arguments do
            t[#t+1] = string.format("--mtx:%s=%s",k,v)
        end
        execute('%s --fmt=%s %s "%s"',texengine,removesuffix(texformat),table.concat(t," "),filename)
    end

    make_mkii_format = function(name,engine)

        -- let the binary sort it out

        os.setenv('SELFAUTOPARENT', "")
        os.setenv('SELFAUTODIR',    "")
        os.setenv('SELFAUTOLOC',    "")
        os.setenv('TEXROOT',        "")
        os.setenv('TEXOS',          "")
        os.setenv('TEXMFOS',        "")
        os.setenv('TEXMFCNF',       "")

        make(engine,name)
    end

end

function scripts.context.generate()
    resolvers.renewcache()
    trackers.enable("resolvers.locating")
    resolvers.load()
end

function scripts.context.make(name)
    if not getargument("fast") then -- as in texexec
        scripts.context.generate()
    end
    local list = (name and { name }) or (environment.filenames[1] and environment.filenames) or defaultformats
    local engine = getargument("engine") or (status and status.luatex_engine) or "luatex"
    if getargument("jit") then
        engine = "luajittex"
    end
    for i=1,#list do
        local name = list[i]
        name = formatofinterface[name] or name or ""
        if name == "" then
            -- nothing
        elseif engine == "luametatex" or engine == "luatex" or engine == "luajittex" then
            make_mkiv_format(name,engine)
        elseif engine == "pdftex" or engine == "xetex" then
            make_mkii_format(name,engine)
        end
    end
end

function scripts.context.ctx()
    local ctxdata = ctxrunner.new()
    ctxdata.jobname = environment.filenames[1]
    ctxrunner.checkfile(ctxdata,getargument("ctx"))
    ctxrunner.checkflags(ctxdata)
    scripts.context.run(ctxdata)
end

function scripts.context.autoctx()
    local ctxdata   = nil
    local files     = environment.filenames
    local firstfile = #files > 0 and files[1]
    if firstfile then
        local suffix  = filesuffix(firstfile)
        local ctxname = nil
        if suffix == "xml" then
            local chunk = io.loadchunk(firstfile) -- 1024
            if chunk then
                ctxname = match(chunk,"<%?context%-directive%s+job%s+ctxfile%s+([^ ]-)%s*?>")
            end
        elseif suffix == "tex" or suffix == "mkiv" or suffix == "mkxl" then
            local analysis = preamble_analyze(firstfile)
            ctxname = analysis.ctxfile or analysis.ctx
        end
        if ctxname then
            ctxdata = ctxrunner.new()
            ctxdata.jobname = firstfile
            ctxrunner.checkfile(ctxdata,ctxname)
            ctxrunner.checkflags(ctxdata)
        end
    end
    scripts.context.run(ctxdata)
end

function scripts.context.version()
    local list = { "context.mkiv", "context.mkxl" }
    for i=1,#list do
        local base = list[i]
        local name = resolvers.findfile(base)
        if name ~= "" then
            report("main context file: %s",name)
            local data = io.loaddata(name)
            if data then
                local version = match(data,"\\edef\\contextversion{(.-)}")
                if version then
                    report("current version: %s",version)
                else
                    report("context version: unknown, no timestamp found")
                end
            else
                report("context version: unknown, load error")
            end
        else
            report("main context file: unknown, %a not found",base)
        end
    end
end

function scripts.context.purge_job(jobname,all,mkiitoo,fulljobname)
    if jobname and jobname ~= "" then
        jobname = filebasename(jobname)
        local filebase = removesuffix(jobname)
        if mkiitoo then
            scripts.context.purge(all,filebase,true) -- leading "./"
        else
            local deleted = { }
            for i=1,#obsolete_results do
                deleted[#deleted+1] = purge_file(fileaddsuffix(filebase,obsolete_results[i]),fileaddsuffix(filebase,"pdf"))
            end
            for i=1,#temporary_runfiles do
                deleted[#deleted+1] = purge_file(fileaddsuffix(filebase,temporary_runfiles[i]))
            end
            if fulljobname and fulljobname ~= jobname then
                for i=1,#temporary_suffixes do
                    deleted[#deleted+1] = purge_file(fileaddsuffix(fulljobname,temporary_suffixes[i],true))
                end
            end
            if all then
                for i=1,#persistent_runfiles do
                    deleted[#deleted+1] = purge_file(fileaddsuffix(filebase,persistent_runfiles[i]))
                end
            end
            if #deleted > 0 then
                report("purged files: %s", concat(deleted,", "))
            end
        end
    end
end

function scripts.context.purge(all,pattern,mkiitoo)
    local all        = all or getargument("all")
    local pattern    = getargument("pattern") or (pattern and (pattern.."*")) or "*.*"
    local files      = dir.glob(pattern)
    local obsolete   = tohash(obsolete_results)
    local temporary  = tohash(temporary_runfiles)
    local synctex    = tohash(synctex_runfiles)
    local persistent = tohash(persistent_runfiles)
    local generic    = tohash(generic_files)
    local deleted    = { }
    for i=1,#files do
        local name = files[i]
        local suffix = filesuffix(name)
        local basename = filebasename(name)
        if obsolete[suffix] or temporary[suffix] or synctex[suffix] or persistent[suffix] or generic[basename] then
            deleted[#deleted+1] = purge_file(name)
        elseif mkiitoo then
            for i=1,#special_runfiles do
                if find(name,special_runfiles[i]) then
                    deleted[#deleted+1] = purge_file(name)
                end
            end
        end
        for i=1,#extra_runfiles do
            if find(basename,extra_runfiles[i]) then
                deleted[#deleted+1] = purge_file(name)
            end
        end
    end
    if #deleted > 0 then
        report("purged files: %s", concat(deleted,", "))
    end
end

-- touching files (signals regeneration of formats)

local function touch(path,name,versionpattern,kind,kindpattern)
    if path and path ~= "" then
        name = filejoinname(path,name)
    else
        name = resolvers.findfile(name)
    end
    local olddata = io.loaddata(name)
    if olddata then
        local oldkind, newkind = "", kind or ""
        local oldversion, newversion = "", os.date("%Y.%m.%d %H:%M")
        local newdata
        if versionpattern then
            newdata = gsub(olddata,versionpattern,function(pre,mid,post)
                oldversion = mid
                return pre .. newversion .. post
            end) or olddata
        end
        if kind and kindpattern then
            newdata = gsub(newdata,kindpattern,function(pre,mid,post)
                oldkind = mid
                return pre .. newkind .. post
            end) or newdata
        end
        if newdata ~= "" and (oldversion ~= newversion or oldkind ~= newkind or newdata ~= olddata) then
            local backup = filenewsuffix(name,"tmp")
            removefile(backup)
            renamefile(name,backup)
            io.savedata(name,newdata)
            return name, oldversion, newversion, oldkind, newkind
        end
    end
end

local p_contextkind       = "(\\edef\\contextkind%s*{)(.-)(})"
local p_contextversion    = "(\\edef\\contextversion%s*{)(.-)(})"
local p_newcontextversion = "(\\newcontextversion%s*{)(.-)(})"

local function touchfiles(suffix,kind,path)
    local foundname, oldversion, newversion, oldkind, newkind = touch(path,fileaddsuffix("context",suffix),p_contextversion,kind,p_contextkind)
    if foundname then
        report("old version  : %s (%s)",oldversion,oldkind)
        report("new version  : %s (%s)",newversion,newkind)
        report("touched file : %s",foundname)
        local foundname = touch(path,fileaddsuffix("cont-new",suffix),p_newcontextversion)
        if foundname then
            report("touched file : %s", foundname)
        end
    else
        report("nothing touched")
    end
end

local tobetouched = tohash { "mkii", "mkiv", "mkvi", "mkxl", "mklx" }

function scripts.context.touch()
    if getargument("expert") then
        local touch = getargument("touch")
        local kind  = getargument("kind")
        local path  = getargument("basepath")
        if tobetouched[touch] then -- mkix mkxi ctix ctxi
            touchfiles(touch,kind,path)
        else
            for touch in sortedhash(tobetouched) do
                touchfiles(touch,kind,path)
            end
        end
    else
        report("touching needs --expert")
    end
end

-- modules

local labels = { "title", "comment", "status" }
local cards  = { "*.mkiv", "*.mkvi",  "*.mkix", "*.mkxi", "*.mkxl", "*.mklx", "*.tex" }
local valid  = tohash { "mkiv", "mkvi", "mkix", "mkxi", "mkxl", "mklx", "tex" }

function scripts.context.modules(pattern)
    local list = { }
    local found = resolvers.findfile("context.mkiv")
    if not pattern or pattern == "" then
        -- official files in the tree
        for i=1,#cards do
            resolvers.findwildcardfiles(cards[i],list)
        end
        -- my dev path
        for i=1,#cards do
            dir.glob(filejoinname(filepathpart(found),cards[i]),list)
        end
    else
        resolvers.findwildcardfiles(pattern,list)
        dir.glob(filejoinname(filepathpart(found,pattern)),list)
    end
    local done = { } -- todo : sort
    local none = { x = { }, m = { }, s = { }, t = { } }
    for i=1,#list do
        local v = list[i]
        local base = filebasename(v)
        if not done[base] then
            done[base] = true
            local suffix = filesuffix(base)
            if valid[suffix] then
                local prefix, rest = match(base,"^([xmst])%-(.*)")
                if prefix then
                    v = resolvers.findfile(base) -- so that files on my dev path are seen
                    local data = io.loaddata(v) or ""
                    data = match(data,"%% begin info(.-)%% end info")
                    if data then
                        local info = { }
                        for label, text in gmatch(data,"%% +([^ ]+) *: *(.-)[\n\r]") do
                            info[label] = text
                        end
                        report()
                        report("%-7s : %s","module",base)
                        report()
                        for i=1,#labels do
                            local l = labels[i]
                            if info[l] then
                                report("%-7s : %s",l,info[l])
                            end
                        end
                        report()
                    else
                        insert(none[prefix],rest)
                    end
                end
            end
        end
    end

    local function show(k,v)
        sort(v)
        if #v > 0 then
            report()
            for i=1,#v do
                report("%s : %s",k,v[i])
            end
        end
    end
    for k, v in sortedhash(none) do
        show(k,v)
    end
end

-- extras

function scripts.context.extras(pattern)
    -- only in base path, i.e. only official ones
    if type(pattern) ~= "string" then
        pattern = "*"
    end
    local found = resolvers.findfile("context.mkiv")
    if found ~= "" then
        pattern = filejoinname(dir.expandname(filepathpart(found)),format("mtx-context-%s.tex",pattern or "*"))
        local list = dir.glob(pattern)
        for i=1,#list do
            local v = list[i]
            local data = io.loaddata(v) or ""
            data = match(data,"%% begin help(.-)%% end help")
            if data then
                report()
                report("extra: %s (%s)",(gsub(v,"^.*mtx%-context%-(.-)%.tex$","%1")),v)
                for s in gmatch(data,"%% *(.-)[\n\r]") do
                    report(s)
                end
                report()
            end
        end
    end
end

function scripts.context.extra()
    local extra = getargument("extra")
    if type(extra) ~= "string" then
        scripts.context.extras()
    elseif getargument("help") then
        scripts.context.extras(extra)
    else
        local fullextra = extra
        if not find(fullextra,"mtx%-context%-") then
            fullextra = "mtx-context-" .. extra
        end
        local foundextra = resolvers.findfile(fullextra)
        if foundextra == "" then
            scripts.context.extras()
            return
        else
            report("processing extra: %s", foundextra)
        end
        setargument("purgeall",true)
        local result = getargument("result") or ""
        if result == "" then
            setargument("result","context-extra")
        end
        scripts.context.run(nil,foundextra)
    end
end

-- todo: we need to do a dummy run

function scripts.context.trackers()
    environment.files = { resolvers.findfile("m-trackers.mkiv") }
    multipass_nofruns = 1
    setargument("purgeall",true)
    scripts.context.run()
end

function scripts.context.directives()
    environment.files = { resolvers.findfile("m-directives.mkiv") }
    multipass_nofruns = 1
    setargument("purgeall",true)
    scripts.context.run()
end

function scripts.context.logcategories()
    environment.files = { resolvers.findfile("m-logcategories.mkiv") }
    multipass_nofruns = 1
    setargument("purgeall",true)
    scripts.context.run()
end

function scripts.context.timed(action)
    statistics.timed(action,true)
end

-- getting it done

if getargument("timedlog") then
    logs.settimedlog()
end

if getargument("nostats") then
    setargument("nostatistics",true)
    setargument("nostat",nil)
end

if getargument("batch") then
    setargument("batchmode",true)
    setargument("batch",nil)
end

if getargument("nonstop") then
    setargument("nonstopmode",true)
    setargument("nonstop",nil)
end

do

    local htmlerrorpage = getargument("htmlerrorpage")
    if htmlerrorpage == "scite" then
        directives.enable("system.showerror=scite")
    elseif htmlerrorpage then
        directives.enable("system.showerror")
    end

end

do

    local silent = getargument("silent")
    if type(silent) == "string" then
        directives.enable(format("logs.blocked={%s}",silent))
    elseif silent then
        directives.enable("logs.blocked")
    end

    local errors = getargument("errors")
    if type(errors) == "errors" then
        directives.enable(format("logs.errors={%s}",silent))
    elseif errors then
        directives.enable("logs.errors")
    end

end

if getargument("once") then
    multipass_nofruns = 1
else
    if getargument("runs") then
        multipass_nofruns = tonumber(getargument("runs")) or nil
    end
    multipass_forcedruns = tonumber(getargument("forcedruns")) or nil
end

if getargument("run") then
    scripts.context.timed(scripts.context.autoctx)
elseif getargument("make") then
    scripts.context.timed(function() scripts.context.make() end)
elseif getargument("generate") then
    scripts.context.timed(function() scripts.context.generate() end)
elseif getargument("ctx") and not getargument("noctx") then
    scripts.context.timed(scripts.context.ctx)
elseif getargument("version") then
    application.identify()
    scripts.context.version()
elseif getargument("touch") then
    scripts.context.touch()
elseif getargument("expert") then
    application.help("expert", "special")
elseif getargument("showmodules") or getargument("modules") then
    scripts.context.modules()
elseif getargument("showextras") or getargument("extras") then
    scripts.context.extras(environment.filenames[1] or getargument("extras"))
elseif getargument("extra") then
    scripts.context.extra()
elseif getargument("exporthelp") then
 -- application.export(getargument("exporthelp"),environment.filenames[1])
    application.export()
elseif getargument("help") then
    if environment.filenames[1] == "extras" then
        scripts.context.extras()
    else
        application.help("basic")
    end
elseif getargument("showtrackers") or getargument("trackers") == true then
    scripts.context.trackers()
elseif getargument("showdirectives") or getargument("directives") == true then
    scripts.context.directives()
elseif getargument("showlogcategories") then
    scripts.context.logcategories()
elseif environment.filenames[1] or getargument("nofile") then
    scripts.context.timed(scripts.context.autoctx)
elseif getargument("pipe") then
    scripts.context.timed(scripts.context.pipe)
elseif getargument("purge") then
    -- only when no filename given, supports --pattern
    scripts.context.purge()
elseif getargument("purgeall") then
    -- only when no filename given, supports --pattern
    scripts.context.purge(true,nil,true)
else
    application.help("basic")
end
