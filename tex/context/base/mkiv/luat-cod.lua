if not modules then modules = { } end modules ['luat-cod'] = {
    version   = 1.001,
    comment   = "companion to luat-cod.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, loadfile, tonumber = type, loadfile, tonumber
local match, gsub, find, format, gmatch = string.match, string.gsub, string.find, string.format, string.gmatch

local texconfig, lua = texconfig, lua

-- maybe pick up from commandline:
--
-- texconfig.interaction: 0=batchmode 1=nonstopmode 2=scrollmode 3=errornonstopmode 4=normal

-- some basic housekeeping

texconfig.kpse_init       = false
texconfig.shell_escape    = 't'

texconfig.error_line      =     79 -- frozen / large values can crash
texconfig.expand_depth    =  10000
texconfig.half_error_line =     50 -- frozen
texconfig.max_in_open     =   1000
texconfig.max_print_line  = 100000
texconfig.max_strings     = 500000
texconfig.nest_size       =   1000
texconfig.param_size      =  25000
texconfig.save_size       = 100000
texconfig.stack_size      =  10000
texconfig.function_size   =  32768
texconfig.properties_size =  10000
texconfig.fix_mem_init    = 750000

-- registering bytecode chunks

local bytedata    = lua.bytedata or { }
local bytedone    = lua.bytedone or { }

---.bytecode      = bytecode
lua.bytedata      = bytedata
lua.bytedone      = bytedone

local setbytecode = lua.setbytecode
----- getbytecode = lua.getbytecode

lua.firstbytecode = 501
lua.lastbytecode  = lua.lastbytecode or (lua.firstbytecode - 1) -- as we load ourselves again ... maybe return earlier

function lua.registeredcodes()
    return lua.lastbytecode - lua.firstbytecode + 1
end

-- no file.* and utilities.parsers.* functions yet

local strip = false if arg then for i=-1,#arg do if arg[i] == "--c:strip" then strip = true break end end end

function lua.registercode(filename,options)
    local barename = gsub(filename,"%.[%a%d]+$","")
    if barename == filename then
        filename = filename .. ".lua"
    end
    local basename = match(barename,"^.+[/\\](.-)$") or barename
    if not bytedone[basename] then
        local opts = { }
        if type(options) == "string" and options ~= "" then
            for s in gmatch(options,"([a-z]+)") do
                opts[s] = true
            end
        end
        local code = environment.luafilechunk(filename,false,opts.optimize)
        if code then
            bytedone[basename] = true
            if environment.initex then
                local n = lua.lastbytecode + 1
                bytedata[n] = { name = barename, options = opts }
                if strip or opts.strip then
                    setbytecode(n,code,true)
                else
                    setbytecode(n,code)
                end
                lua.lastbytecode = n
            end
        elseif environment.initex then
            texio.write_nl(format("\nerror loading file: %s (aborting)",filename))
            os.exit()
        end
    end
end

local finalizers = { }

function lua.registerfinalizer(f,comment)
    comment = comment or "unknown"
    if type(f) == "function" then
        finalizers[#finalizers+1] = { action = f, comment = comment }
    else
        print(format("\nfatal error: invalid finalizer, action: %s\n",comment))
        os.exit()
    end
end

function lua.finalize(logger)
    for i=1,#finalizers do
        local finalizer = finalizers[i]
        finalizer.action()
        if logger then
            logger("finalize action: %s",finalizer.comment)
        end
    end
end

-- A first start with environments. This will be overloaded later.

environment       = environment or { }
local environment = environment

-- no string.unquoted yet

local sourcefile = gsub(arg and arg[1] or "","^\"(.*)\"$","%1")
local sourcepath = find(sourcefile,"/",1,true) and gsub(sourcefile,"/[^/]+$","") or ""
local targetpath = "."

-- delayed (via metatable):
--
-- environment.jobname = tex.jobname
-- environment.version = tostring(tex.toks.contextversiontoks)

-- traditionally the revision has been a one character string and only
-- pdftex went beyond "9" but anyway we test for it

if LUATEXENGINE == nil then
    LUATEXENGINE = status.luatex_engine and string.lower(status.luatex_engine)
                or (find(status.banner,"LuajitTeX",1,true) and "luajittex" or "luatex")
end

if LUATEXVERSION == nil then
    LUATEXVERSION = status.luatex_revision
    LUATEXVERSION = status.luatex_version/100
               -- + tonumber(LUATEXVERSION)/1000
                  + (tonumber(LUATEXVERSION) or (string.byte(LUATEXVERSION)-string.byte("a")+10))/1000
end

if CONTEXTLMTXMODE == nil then
    CONTEXTLMTXMODE = LUATEXENGINE == "luametatex" and 1 or 0
end

if LUATEXFUNCTIONALITY == nil then
    LUATEXFUNCTIONALITY = status.development_id or 6346
end

if LUATEXFORMATID == nil then
    LUATEXFORMATID = status.format_id or 0
end

if JITSUPPORTED == nil then
    JITSUPPORTED = LUATEXENGINE == "luajittex" or jit
end

if INITEXMODE == nil then
    INITEXMODE = status.ini_version
end

environment.luatexengine        = LUATEXENGINE
environment.luatexversion       = LUATEXVERSION
environment.luatexfunctionality = LUATEXFUNCTIONALITY
environment.jitsupported        = JITSUPPORTED
environment.initex              = INITEXMODE
environment.initexmode          = INITEXMODE

if not environment.luafilechunk then

    function environment.luafilechunk(filename)
        local fullname = filename
        if sourcepath ~= "" then
            fullname = sourcepath .. "/" .. filename
        end
        local data = loadfile(fullname)
        texio.write("term and log","<",data and "+ " or "- ",fullname,">")
        if data then
-- package.loaded[gsub(filename,"%..-$"] =
            data()
        end
        return data
    end

end

if not environment.engineflags then -- raw flags

    local engineflags = { }

    for i=-10,#arg do
        local a = arg[i]
        if a then
            local flag, content = match(a,"^%-%-([^=]+)=?(.-)$")
            if flag then
                engineflags[flag] = content or ""
            end
        end
    end

    environment.engineflags = engineflags

end

-- We need a few premature callbacks in the format generator. We
-- also do this when the format is loaded as otherwise we get
-- a kpse error when disabled. This is an engine issue that will
-- be sorted out in due time.

if not lfs.isfile then

    local attributes = lfs.attributes

    function lfs.isdir(name)
        return attributes(name,"mode") == "directory"
    end

    function lfs.isfile(name)
        local a = attributes(name,"mode")
        return a == "file" or a == "link" or nil
    end

end

local isfile = lfs.isfile

local function source_file(name)
    local fullname = sourcepath .. "/" .. name
    if isfile(fullname) then
        return fullname
    end
    fullname = fullname .. ".tex"
    if isfile(fullname) then
        return fullname
    end
    if isfile(name) then
        return name
    end
    name = name .. ".tex"
    if isfile(name) then
        return name
    end
    return nil
end

local function target_file(name)
    return targetpath .. "/" .. name
end

local function find_read_file(id,name)
    return source_file(name)
end

local function find_write_file(id,name)
    return target_file(name)
end

local function find_log_file(name)
    return target_file(name)
end

local function open_read_file(name)
    local f = io.open(name,'rb')
    return {
        reader = function()
            return f:read("*line")
        end
    }
end

local function find_data_file(name)
    return source_file(name)
end

local open_data_file = open_read_file

callback.register('find_read_file' , find_read_file )
callback.register('open_read_file' , open_read_file )
callback.register('find_write_file', find_write_file)
callback.register('find_log_file',   find_log_file)

callback.register('find_data_file' , find_data_file )
callback.register('open_data_file' , open_data_file )
