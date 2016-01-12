if not modules then modules = { } end modules ['util-sbx'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Note: we use expandname and collapsepath and these use chdir
-- which is overloaded so we need to use originals there. Just
-- something to keep in mind.

if not sandbox then require("l-sandbox") end -- for testing

local next, type = next, type

local replace        = utilities.templates.replace
local collapsepath   = file.collapsepath
local expandname     = dir.expandname
local sortedhash     = table.sortedhash
local lpegmatch      = lpeg.match
local platform       = os.type
local P, S, C        = lpeg.P, lpeg.S, lpeg.C
local gsub           = string.gsub
local lower          = string.lower
local unquoted       = string.unquoted
local optionalquoted = string.optionalquoted

local sandbox        = sandbox
local validroots     = { }
local validrunners   = { }
local validbinaries  = { }
local validators     = { }
local p_validroot    = nil
local finalized      = nil
local norunners      = false
local trace          = false
local p_split        = lpeg.tsplitat(" ") -- more spaces?

local report         = logs.reporter("sandbox")

trackers.register("sandbox",function(v) trace = v end) -- often too late anyway

sandbox.setreporter(report)

sandbox.finalizer(function()
    finalized = true
end)

local function registerroot(root,what) -- what == read|write
    if finalized then
        report("roots are already finalized")
    else
        root = collapsepath(expandname(root))
        if platform == "windows" then
            root = lower(root) -- we assume ascii names
        end
        -- true: read & write | false: read
        validroots[root] = what == "write" or false
    end
end

sandbox.finalizer(function() -- initializers can set the path
    if p_validroot then
        report("roots are already initialized")
    else
        sandbox.registerroot(".","write") -- always ok
        -- also register texmf as read
        for name in sortedhash(validroots) do
            if p_validroot then
                p_validroot = P(name) + p_validroot
            else
                p_validroot = P(name)
            end
        end
        p_validroot = p_validroot / validroots
    end
end)

local function registerrunner(specification)
    if finalized then
        report("runners are already finalized")
    else
        local name = specification.name
        if not name then
            report("no runner name specified")
            return
        end
        local program = specification.program
        if type(program) == "string" then
            -- common for all platforms
        elseif type(program) == "table" then
            program = program[platform]
        end
        if type(program) ~= "string" or program == "" then
            report("invalid runner %a specified for platform %a",name,platform)
            return
        end
        specification.program = program
        validrunners[name] = specification
    end
end

local function registerbinary(name)
    if finalized then
        report("binaries are already finalized")
    elseif type(name) == "string" and name ~= "" then
        validbinaries[name] = true
    end
end

-- begin of validators

local p_write = S("wa")       p_write = (1 - p_write)^0 * p_write
local p_path  = S("\\/~$%:")  p_path  = (1 - p_path )^0 * p_path  -- be easy on other arguments

local function normalized(name) -- only used in executers
    if platform == "windows" then
        name = gsub(name,"/","\\")
    end
    return name
end

function sandbox.possiblepath(name)
    return lpegmatch(p_path,name) and true or false
end

local filenamelogger = false

function sandbox.setfilenamelogger(l)
    filenamelogger = type(l) == "function" and l or false
end

local function validfilename(name,what)
    if p_validroot and type(name) == "string" and lpegmatch(p_path,name) then
        local asked = collapsepath(expandname(name))
        if platform == "windows" then
            asked = lower(asked) -- we assume ascii names
        end
        local okay = lpegmatch(p_validroot,asked)
        if okay == true then
            -- read and write access
            if filenamelogger then
                filenamelogger(name,"w",asked,true)
            end
            return name
        elseif okay == false then
            -- read only access
            if not what then
                -- no further argument to io.open so a readonly case
                if filenamelogger then
                    filenamelogger(name,"r",asked,true)
                end
                return name
            elseif lpegmatch(p_write,what) then
                if filenamelogger then
                    filenamelogger(name,"w",asked,false)
                end
                return -- we want write access
            else
                if filenamelogger then
                    filenamelogger(name,"r",asked,true)
                end
                return name
            end
        else
            if filenamelogger then
                filenamelogger(name,"*",name,false)
            end
        end
    else
        return name
    end
end

local function readable(name)
    if platform == "windows" then
        name = lower(name) -- we assume ascii names
    end
    local valid = validfilename(name,"r")
    if valid then
        return normalized(valid)
    end
end

local function writeable(name)
    if platform == "windows" then
        name = lower(name) -- we assume ascii names
    end
    local valid = validfilename(name,"w")
    if valid then
        return normalized(valid)
    end
end

validators.readable  = readable
validators.writeable = writeable
validators.filename  = readable

table.setmetatableindex(validators,function(t,k)
    if k then
        t[k] = readable
    end
    return readable
end)

function validators.string(s)
    return s -- can be used to prevent filename checking
end

-- end of validators

sandbox.registerroot   = registerroot
sandbox.registerrunner = registerrunner
sandbox.registerbinary = registerbinary
sandbox.validfilename  = validfilename

local function filehandlerone(action,one,...)
    local checkedone = validfilename(one)
    if checkedone then
        return action(one,...)
    else
-- report("file %a is unreachable",one)
    end
end

local function filehandlertwo(action,one,two,...)
    local checkedone = validfilename(one)
    if checkedone then
        local checkedtwo = validfilename(two)
        if checkedtwo then
            return action(one,two,...)
        else
-- report("file %a is unreachable",two)
        end
    else
-- report("file %a is unreachable",one)
    end
end

local function iohandler(action,one,...)
    if type(one) == "string" then
        local checkedone = validfilename(one)
        if checkedone then
            return action(one,...)
        end
    elseif one then
        return action(one,...)
    else
        return action()
    end
end

-- runners can be strings or tables
--
-- os.execute : string
-- os.exec    : table with program in [0|1]
-- os.spawn   : table with program in [0|1]
--
-- our execute: registered program with specification

local function runhandler(action,name,specification)
    local kind = type(name)
    if kind ~= "string" then
        return
    end
    if norunners then
        report("no runners permitted, ignoring command: %s",name)
        return
    end
    local spec = validrunners[name]
    if not spec then
        report("unknown runner: %s",name)
        return
    end
    -- specs are already checked
    local program   = spec.program
    local variables = { }
    local checkers  = spec.checkers or { }
    if specification then
        -- we only handle runners that are defined before the sandbox is
        -- closed so in principle we cannot have user runs with no files
        -- while for context runners we assume a robust specification
        for k, v in next, specification do
            local checker = validators[checkers[k]]
            local value = checker(unquoted(v)) -- todo: write checkers
            if value then
                variables[k] = optionalquoted(value)
            else
                report("suspicious argument found, run blocked: %s",v)
                return
            end
        end
    end
    local command = replace(program,variables)
    if trace then
        report("executing runner: %s",command)
    end
    return action(command)
end

-- only registered (from list) -- no checking on writable so let's assume harmless
-- runs

local function binaryhandler(action,name)
    local kind = type(name)
    local list = name
    if kind == "string" then
        list = lpegmatch(p_split,name)
    end
    local program = name[0] or name[1]
    if type(program) ~= "string" or program == "" then
        return --silently ignore
    end
    if norunners then
        report("no binaries permitted, ignoring command: %s",program)
        return
    end
    if not validbinaries[program] then
        report("binary is not permitted: %s",program)
        return
    end
    for i=0,#list do
        local n = list[i]
        if n then
            local v = readable(unquoted(n))
            if v then
                list[i] = optionalquoted(v)
            else
                report("suspicious argument found, run blocked: %s",n)
                return
            end
        end
    end
    return action(name)
end

sandbox.filehandlerone = filehandlerone
sandbox.filehandlertwo = filehandlertwo
sandbox.iohandler      = iohandler
sandbox.runhandler     = runhandler
sandbox.binaryhandler  = binaryhandler

function sandbox.disablerunners()
    norunners = true
end

local execute = sandbox.original(os.execute)

function sandbox.run(name,specification)
    return runhandler(execute,name,specification)
end

-------------------

local overload = sandbox.overload
local register = sandbox.register

    overload(loadfile,             filehandlerone,"loadfile") -- todo

if io then
    overload(io.open,              filehandlerone,"io.open")
    overload(io.popen,             filehandlerone,"io.popen")
    overload(io.input,             iohandler,     "io.input")
    overload(io.output,            iohandler,     "io.output")
    overload(io.lines,             filehandlerone,"io.lines")
end

if os then
    overload(os.execute,           binaryhandler, "os.execute")
    overload(os.spawn,             binaryhandler, "os.spawn")
    overload(os.exec,              binaryhandler, "os.exec")
    overload(os.rename,            filehandlertwo,"os.rename")
    overload(os.remove,            filehandlerone,"os.remove")
end

if lfs then
    overload(lfs.chdir,            filehandlerone,"lfs.chdir")
    overload(lfs.mkdir,            filehandlerone,"lfs.mkdir")
    overload(lfs.rmdir,            filehandlerone,"lfs.rmdir")
    overload(lfs.isfile,           filehandlerone,"lfs.isfile")
    overload(lfs.isdir,            filehandlerone,"lfs.isdir")
    overload(lfs.attributes,       filehandlerone,"lfs.attributes")
    overload(lfs.dir,              filehandlerone,"lfs.dir")
    overload(lfs.lock_dir,         filehandlerone,"lfs.lock_dir")
    overload(lfs.touch,            filehandlerone,"lfs.touch")
    overload(lfs.link,             filehandlertwo,"lfs.link")
    overload(lfs.setmode,          filehandlerone,"lfs.setmode")
    overload(lfs.readlink,         filehandlerone,"lfs.readlink")
    overload(lfs.shortname,        filehandlerone,"lfs.shortname")
    overload(lfs.symlinkattributes,filehandlerone,"lfs.symlinkattributes")
end

-- these are used later on

if zip then
    zip.open        = register(zip.open,       filehandlerone,"zip.open")
end

if fontloader then
    fontloader.open = register(fontloader.open,filehandlerone,"fontloader.open")
    fontloader.info = register(fontloader.info,filehandlerone,"fontloader.info")
end

if epdf then
    epdf.open       = register(epdf.open,      filehandlerone,"epdf.open")
end

-- not used in a normal mkiv run : os.spawn = os.execute
-- not used in a normal mkiv run : os.exec  = os.exec

-- print(io.open("test.log"))
-- sandbox.enable()
-- print(io.open("test.log"))
-- print(io.open("t:/test.log"))
