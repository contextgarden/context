if not modules then modules = { } end modules ['luat-cod'] = {
    version   = 1.001,
    comment   = "companion to luat-cod.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, loadfile = type, loadfile
local match, gsub, find, format = string.match, string.gsub, string.find, string.format

local texconfig, lua = texconfig, lua

-- some basic housekeeping

texconfig.kpse_init      = false
texconfig.shell_escape   = 't'
texconfig.max_print_line = 100000
texconfig.max_in_open    = 1000

-- registering bytecode chunks

local bytecode    = lua.bytecode or { }
local bytedata    = lua.bytedata or { }
local bytedone    = lua.bytedone or { }

lua.bytecode      = bytecode -- built in anyway
lua.bytedata      = bytedata
lua.bytedone      = bytedone

lua.firstbytecode = 501
lua.lastbytecode  = lua.lastbytecode or (lua.firstbytecode - 1) -- as we load ourselves again ... maybe return earlier

function lua.registeredcodes()
    return lua.lastbytecode - lua.firstbytecode + 1
end

-- no file.* functions yet

function lua.registercode(filename,version)
    local barename = gsub(filename,"%.[%a%d]+$","")
    if barename == filename then filename = filename .. ".lua" end
    local basename = match(barename,"^.+[/\\](.-)$") or barename
    if not bytedone[basename] then
        local code = environment.luafilechunk(filename)
        if code then
            bytedone[basename] = true
            if environment.initex then
                local n = lua.lastbytecode + 1
                bytedata[n] = { barename, version or "0.000" }
                bytecode[n] = code
                lua.lastbytecode = n
            end
        elseif environment.initex then
            texio.write_nl("\nerror loading file: " .. filename .. " (aborting)")
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

environment.initex  = tex.formatname == ""

if not environment.luafilechunk then

    function environment.luafilechunk(filename)
        if sourcepath ~= "" then
            filename = sourcepath .. "/" .. filename
        end
        local data = loadfile(filename)
        texio.write("term and log","<",data and "+ " or "- ",filename,">")
        if data then
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

local function open_read_file(name)
    local f = io.open(name,'rb')
    return {
        reader = function()
            return f:read("*line")
        end
    }
end

callback.register('find_read_file' , find_read_file )
callback.register('open_read_file' , open_read_file )
callback.register('find_write_file', find_write_file)
