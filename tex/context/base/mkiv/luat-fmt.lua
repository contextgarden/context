if not modules then modules = { } end modules ['luat-fmt'] = {
    version   = 1.001,
    comment   = "companion to mtxrun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The original idea was to have a generic format builder and as a result the code
-- here (and some elsewhere) is bit more extensive that we really need for context.
-- For instance, in the real beginning we had runtime loading because we had no
-- bytecode registers yet. We also had multiple files as stubs and the context.lus
-- file specified these. More than a decade only the third method was used, just
-- loading luat-cod, so in the end we cpould get rid of the lus file. In due time
-- I'll strip the code here because something generic will never take of and we
-- moved on to luametatex anyway.

local format = string.format
local concat = table.concat
local quoted = string.quoted
local luasuffixes = utilities.lua.suffixes

local report_format = logs.reporter("resolvers","formats")

local function primaryflags(arguments)
    local flags      = { }
    if arguments.silent then
        flags[#flags+1] = "--interaction=batchmode"
    end
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
    luametatex = sandbox.registerrunner {
        name     = "make luametatex format",
        program  = "luametatex",
        template = template,
        checkers = checkers,
        reporter = report_format,
    },
    luatex = sandbox.registerrunner {
        name     = "make luatex format",
        program  = "luatex",
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

local stubfiles = {
    luametatex = "luat-cod.lmt",
    luatex     = "luat-cod.lua",
    luajittex  = "luat-cod.lua",
}

local suffixes = {
    luametatex = "mkxl",
    luatex     = "mkiv",
    luajittex  = "mkiv",
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

local function fatalerror(startupdir,...)
    report_format(...)
    lfs.chdir(startupdir)
end

function environment.make_format(formatname)
    local arguments  = environment.arguments
    local engine     = environment.ownmain or "luatex"
    local silent     = arguments.silent
    local errors     = arguments.errors
    local runner     = runners[engine]
    local startupdir = dir.current()
    if not runner then
        return fatalerror(startupdir,"the format %a cannot be generated, no runner available for engine %a",name,engine)
    end
    -- now we locate the to be used source files ... there are some variants that we
    -- need to take care
    local luasourcename = stubfiles[engine]
    if not luasourcename then
        return fatalerror(startupdir,"no lua stub file specified for %a",engine)
    end
    local texsourcename     = file.addsuffix(formatname,suffixes[engine])
    local fulltexsourcename = resolvers.findfile(texsourcename,"tex") or ""
    if fulltexsourcename == "" then
        return fatalerror(startupdir,"no tex source file with name %a (mkiv or tex)",formatname)
    end
    -- this is tricky: we normally have an expanded path but when we don't have one,
    -- the current path gets appended
    local fulltexsourcename = dir.expandname(fulltexsourcename)
    local texsourcepath     = file.dirname(fulltexsourcename)
    if lfs.isfile(fulltexsourcename) then
        report_format("using tex source file %a",fulltexsourcename)
    else
        return fatalerror(startupdir,"no accessible tex source file with name %a",fulltexsourcename)
    end
    -- we're getting there, that is: we have a file that specifies the context format;
    -- in addition to that file we need a stub for setting up lua as we start rather
    -- minimalistic ..
    local fullluasourcename = dir.expandname(file.join(texsourcepath,luasourcename) or "")
    if lfs.isfile(fullluasourcename) then
        report_format("using lua stub file %a",fullluasourcename)
    else
        return fatalerror(startupdir,"no accessible lua stub file with name %a",fulltexsourcename)
    end
    -- we will change tot the format path because some local files will be created
    -- in the process and we don't want clutter
    local validformatpath = caches.getwritablepath("formats",engine) or ""
    if validformatpath == "" then
        return fatalerror(startupdir,"invalid format path, insufficient write access")
    end
    -- in case we have a qualified path, we need to do this before we change
    -- because we can have half qualified paths (in lxc)
    local binarypath = validbinarypath()
    report_format("changing to format path %a",validformatpath)
    lfs.chdir(validformatpath)
    if dir.current() ~= validformatpath then
        return fatalerror(startupdir,"unable to change to format path %a",validformatpath)
    end
    -- now we can generate the format, where we use a couple of flags,
    -- split into two categories
    local primaryflags   = primaryflags(arguments)
    local secondaryflags = secondaryflags(arguments)
    local specification  = {
        binarypath     = binarypath,
        primaryflags   = primaryflags,
        secondaryflags = secondaryflags,
        luafile        = quoted(fullluasourcename),
        texfile        = quoted(fulltexsourcename),
        dump           = os.platform == "unix" and "\\\\dump" or "\\dump",
    }
    if silent then
        specification.redirect = "> temp.log"
    end
    statistics.starttiming("format")
    local result  = runner(specification)
    statistics.stoptiming("format")
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
    report_format("lua startup file : %s",fullluasourcename)
  if primaryflags ~= "" then
    report_format("primary flags    : %s",primaryflags)
  end
  if secondaryflags ~= "" then
    report_format("secondary flags  : %s",secondaryflags)
  end
    report_format("context file     : %s",fulltexsourcename)
    report_format("run time         : %.3f seconds",statistics.elapsed("format"))
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
