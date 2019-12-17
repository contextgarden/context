if not modules then modules = { } end modules ['luat-fmt'] = {
    version   = 1.001,
    comment   = "companion to mtxrun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format
local concat = table.concat
local quoted = string.quoted
local luasuffixes = utilities.lua.suffixes

local report_format = logs.reporter("resolvers","formats")

-- this is a bit messy: we also handle flags in mtx-context so best we
-- can combine this some day (all here)

local function primaryflags(arguments)
    local flags      = { }
    if arguments.silent then
        flags[#flags+1] = "--interaction=batchmode"
    end
 -- if arguments.jit then
 --     flags[#flags+1] = "--jiton"
 -- end
    return concat(flags," ")
end

local function secondaryflags(arguments)
    local trackers   = arguments.trackers
    local directives = arguments.directives
    local flags      = { }
    if trackers and trackers ~= "" then
        flags[#flags+1] = "--c:trackers=" .. quoted(trackers)
    end
    if directives and directives ~= "" then
        flags[#flags+1] = "--c:directives=" .. quoted(directives)
    end
    if arguments.silent then
        flags[#flags+1] = "--c:silent"
    end
    if arguments.errors then
        flags[#flags+1] = "--c:errors"
    end
    if arguments.jit then
        flags[#flags+1] = "--c:jiton"
    end
    if arguments.ansi then
        flags[#flags+1] = "--c:ansi"
    end
    if arguments.ansilog then
        flags[#flags+1] = "--c:ansilog"
    end
    if arguments.strip then
        flags[#flags+1] = "--c:strip"
    end
    if arguments.lmtx then
        flags[#flags+1] = "--c:lmtx"
    end
    return concat(flags," ")
end

-- The silent option is for Taco. It's a bit of a hack because we cannot yet mess
-- with directives. In fact, I could probably clean up the maker a bit by now.

local template = [[--ini %primaryflags% --lua=%luafile% %texfile% %secondaryflags% %dump% %redirect%]]

local checkers = {
    primaryflags   = "verbose",  -- "flags"
    secondaryflags = "verbose",  -- "flags"
    luafile        = "readable", -- "cache"
    texfile        = "readable", -- "cache"
    redirect       = "string",
    dump           = "string",
    binarypath     = "string",
}

local runners = {
    luatex = sandbox.registerrunner {
        name     = "make luatex format",
        program  = "luatex",
        template = template,
        checkers = checkers,
        reporter = report_format,
    },
    luametatex = sandbox.registerrunner {
        name     = "make luametatex format",
        program  = "luametatex",
        template = template,
        checkers = checkers,
        reporter = report_format,
    },
    luajittex = sandbox.registerrunner {
        name     = "make luajittex format",
        program  = "luajittex",
        template = template,
        checkers = checkers,
        reporter = report_format,
    },
}

local function validbinarypath()
 -- if environment.arguments.addbinarypath then
    if not environment.arguments.nobinarypath then
        local path = environment.ownpath or file.dirname(environment.ownname)
        if path and path ~= "" then
            path = dir.expandname(path)
            if path ~= "" and lfs.isdir(path) then
                return path
            end
        end
    end
end

function environment.make_format(formatname)
    -- first we set up the engine and  normally that information is provided
    -- by the engine ... when we move to luametatex we could decide to simplfy
    -- all the following
    local arguments = environment.arguments
    local engine    = environment.ownmain or "luatex"
    local silent    = arguments.silent
    local errors    = arguments.errors
    -- now we locate the to be used source files ... there are some variants that we
    -- need to take care
    local texsourcename     = ""
    local texsourcepath     = ""
    local fulltexsourcename = ""
    if engine == "luametatex" then
        texsourcename     = file.addsuffix(formatname,"mkxl")
        fulltexsourcename = resolvers.findfile(texsourcename,"tex") or ""
    end
    if fulltexsourcename == "" then
        texsourcename     = file.addsuffix(formatname,"mkiv")
        fulltexsourcename = resolvers.findfile(texsourcename,"tex") or ""
    end
    if fulltexsourcename == "" then
        texsourcename     = file.addsuffix(formatname,"tex")
        fulltexsourcename = resolvers.findfile(texsourcename,"tex") or ""
    end
    if fulltexsourcename == "" then
        report_format("no tex source file with name %a (mkiv or tex)",formatname)
        return
    end
    report_format("using tex source file %a",fulltexsourcename)
    -- this is tricky: we normally have an expanded path but when we don't have one,
    -- the current path gets appended
    fulltexsourcename = dir.expandname(fulltexsourcename)
    texsourcepath     = file.dirname(fulltexsourcename)
    if not lfs.isfile(fulltexsourcename) then
        report_format("no accessible tex source file with name %a",fulltexsourcename)
        return
    end
    -- we're getting there, that is: we have a file that specifies the context format;
    -- in addition to that file we need a stub for setting up lua as we start rather
    -- minimalistic
    local specificationname     = "context.lus"
    local specificationpath     = ""
    local fullspecificationname = resolvers.findfile(specificationname) or ""
    if fullspecificationname == "" then
        report_format("unable to locate specification file %a",specificationname)
        return
    end
    report_format("using specification file %a",fullspecificationname)
    -- let's expand the found name and so an extra check
    fullspecificationname = dir.expandname(fullspecificationname)
    specificationpath     = file.dirname(fullspecificationname)
    if texsourcepath ~= specificationpath then
        report_format("tex source file and specification file are on different paths")
        return
    end
    -- let's do an additional check here, if only because we then have a bit better
    -- feedback on what goes wrong
    if not lfs.isfile(fulltexsourcename) then
        report_format("no accessible tex source file with name %a",fulltexsourcename)
        return
    end
    if not lfs.isfile(fullspecificationname) then
        report_format("no accessible specification file with name %a",fulltexsourcename)
        return
    end
    -- we're still going strong
    report_format("using tex source path %a",texsourcepath)
    -- we will change tot the format path because some local files will be created
    -- in the process and we don't want clutter
    local validformatpath = caches.getwritablepath("formats",engine) or ""
    local startupdir      = dir.current()
    if validformatpath == "" then
        report_format("invalid format path, insufficient write access")
        return
    end
    -- in case we have a qualified path, we need to do this before we change
    -- because we can have half qualified paths (in lxc)
    local binarypath = validbinarypath()
    report_format("changing to format path %a",validformatpath)
    lfs.chdir(validformatpath)
    if dir.current() ~= validformatpath then
        report_format("unable to change to format path %a",validformatpath)
        return
    end
    -- we're now ready for making the format which we do on the first found
    -- writable path
    local usedluastub = nil
    local usedlualibs = dofile(fullspecificationname)
    if type(usedlualibs) == "string" then
        usedluastub = file.join(specificationpath,usedlualibs)
    elseif type(usedlualibs) == "table" then
        report_format("using stub specification %a",fullspecificationname)
        local texbasename = file.basename(name)
        local luastubname = file.addsuffix(texbasename,luasuffixes.lua)
        local lucstubname = file.addsuffix(texbasename,luasuffixes.luc)
        -- pack libraries in stub
        report_format("creating initialization file %a",luastubname)
        utilities.merger.selfcreate(usedlualibs,specificationpath,luastubname)
        -- compile stub file (does not save that much as we don't use this stub at startup any more)
        if utilities.lua.compile(luastubname,lucstubname) and lfs.isfile(lucstubname) then
            report_format("using compiled initialization file %a",lucstubname)
            usedluastub = lucstubname
        else
            report_format("using uncompiled initialization file %a",luastubname)
            usedluastub = luastubname
        end
    else
        report_format("invalid stub specification %a",fullspecificationname)
        lfs.chdir(startupdir)
        return
    end
    -- we're ready to go now but first we check if we actually do have a runner
    -- for this engine ... we'd better have one
    local runner = runners[engine]
    if not runner then
        report_format("the format %a cannot be generated, no runner available for engine %a",name,engine)
        lfs.chdir(startupdir)
        return
    end
    -- now we can generate the format, where we use a couple of flags,
    -- split into two categories
    local primaryflags   = primaryflags(arguments)
    local secondaryflags = secondaryflags(arguments)
    local specification = {
        binarypath     = binarypath,
        primaryflags   = primaryflags,
        secondaryflags = secondaryflags,
        luafile        = quoted(usedluastub),
        texfile        = quoted(fulltexsourcename),
        dump           = os.platform == "unix" and "\\\\dump" or "\\dump",
    }
    if silent then
        specification.redirect = "> temp.log"
    end
    statistics.starttiming()
    local result  = runner(specification)
    local runtime = statistics.stoptiming()
    if silent then
        os.remove("temp.log")
    end
    -- some final report
    report_format()
  if binarypath and binarypath ~= "" then
    report_format("binary path      : %s",binarypath or "?")
  end
    report_format("format path      : %s",validformatpath)
    report_format("luatex engine    : %s",engine)
    report_format("lua startup file : %s",usedluastub)
  if primaryflags ~= "" then
    report_format("primary flags    : %s",primaryflags)
  end
  if secondaryflags ~= "" then
    report_format("secondary flags  : %s",secondaryflags)
  end
    report_format("context file     : %s",fulltexsourcename)
    report_format("run time         : %.3f seconds",runtime)
    report_format("return value     : %s",result == 0 and "okay" or "error")
    report_format()
    -- last we go back to the home base
    lfs.chdir(startupdir)
end

local template = [[%primaryflags% --fmt=%fmtfile% --lua=%luafile% %texfile% %secondaryflags%]]

local checkers = {
    primaryflags   = "verbose",
    secondaryflags = "verbose",
    fmtfile        = "readable", -- "cache"
    luafile        = "readable", -- "cache"
    texfile        = "readable", -- "cache"
}

local runners = {
    luatex = sandbox.registerrunner {
        name     = "run luatex format",
        program  = "luatex",
        template = template,
        checkers = checkers,
        reporter = report_format,
    },
    luametatex = sandbox.registerrunner {
        name     = "run luametatex format",
        program  = "luametatex",
        template = template,
        checkers = checkers,
        reporter = report_format,
    },
    luajittex = sandbox.registerrunner {
        name     = "run luajittex format",
        program  = "luajittex",
        template = template,
        checkers = checkers,
        reporter = report_format,
    },
}

function environment.run_format(formatname,scriptname,filename,primaryflags,secondaryflags,verbose)
    local engine = environment.ownmain or "luatex"
    if not formatname or formatname == "" then
        report_format("missing format name")
        return
    end
    if not scriptname or scriptname == "" then
        report_format("missing script name")
        return
    end
    if not lfs.isfile(formatname) or not lfs.isfile(scriptname) then
        formatname, scriptname = resolvers.locateformat(formatname)
    end
    if not formatname or formatname == "" then
        report_format("invalid format name")
        return
    end
    if not scriptname or scriptname == "" then
        report_format("invalid script name")
        return
    end
    local runner = runners[engine]
    if not runner then
        report_format("format %a cannot be run, no runner available for engine %a",file.nameonly(name),engine)
        return
    end
    if not filename then
        filename ""
    end
    local binarypath = validbinarypath()
    local specification = {
        binarypath     = binarypath,
        primaryflags   = primaryflags or "",
        secondaryflags = secondaryflags or "",
        fmtfile        = quoted(formatname),
        luafile        = quoted(scriptname),
        texfile        = filename ~= "" and quoted(filename) or "",
    }
    statistics.starttiming()
    local result  = runner(specification)
    local runtime = statistics.stoptiming()
    if verbose then
        report_format()
      if binarypath and binarypath ~= "" then
        report_format("binary path      : %s",binarypath)
      end
        report_format("luatex engine    : %s",engine)
        report_format("lua startup file : %s",scriptname)
        report_format("tex format file  : %s",formatname)
      if filename ~= "" then
        report_format("tex input file   : %s",filename)
      end
      if primaryflags ~= "" then
        report_format("primary flags    : %s",primaryflags)
      end
      if secondaryflags ~= "" then
        report_format("secondary flags  : %s",secondaryflags)
      end
        report_format("run time         : %.3f seconds",runtime)
        report_format("return value     : %s",result == 0 and "okay" or "error")
        report_format()
    end
    return result
end
