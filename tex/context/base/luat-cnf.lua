if not modules then modules = { } end modules ['luat-cnf'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next, tostring, tonumber =  type, next, tostring, tonumber
local format, concat, find = string.format, table.concat, string.find

local allocate = utilities.storage.allocate

texconfig.kpse_init    = false
texconfig.shell_escape = 't'

luatex       = luatex or { }
local luatex = luatex

texconfig.error_line      =     79 --    79 -- obsolete
texconfig.half_error_line =     50 --    50 -- obsolete

texconfig.expand_depth    =  10000 -- 10000
texconfig.hash_extra      = 100000 --     0
texconfig.nest_size       =   1000 --    50
texconfig.max_in_open     =    500 --    15 -- in fact it's limited to 127
texconfig.max_print_line  =  10000 --    79
texconfig.max_strings     = 500000 -- 15000
texconfig.param_size      =  25000 --    60
texconfig.save_size       =  50000 --  4000
texconfig.stack_size      =  10000 --   300

-- local function initialize()
--     local t, variable = allocate(), resolvers.variable
--     for name, default in next, variablenames do
--         local name = variablenames[i]
--         local value = variable(name)
--         value = tonumber(value)
--         if not value or value == "" or value == 0 then
--             value = default
--         end
--         texconfig[name], t[name] = value, value
--     end
--     initialize = nil
--     return t
-- end
--
-- luatex.variables = initialize()

local stub = [[

-- checking

storage = storage or { }
luatex  = luatex  or { }

-- we provide our own file handling

texconfig.kpse_init    = false
texconfig.shell_escape = 't'

-- as soon as possible

luatex.starttime = os.gettimeofday()

-- this will happen after the format is loaded

function texconfig.init()

    -- development

    local builtin, globals = { }, { }

    libraries = { -- we set it here as we want libraries also 'indexed'
        basiclua = {
            "string", "table", "coroutine", "debug", "file", "io", "lpeg", "math", "os", "package", "bit32",
        },
        basictex = { -- noad
            "callback", "font", "img", "lang", "lua", "node", "pdf", "status", "tex", "texconfig", "texio", "token",
        },
        extralua = {
            "gzip",  "zip", "zlib", "lfs", "ltn12", "mime", "socket", "md5", "profiler", "unicode", "utf",
        },
        extratex = {
            "epdf", "fontloader", "kpse", "mplib",
        },
        obsolete = {
            "fontforge", -- can be filled by luat-log
            "kpse",
        },
        functions = {
            "assert", "pcall", "xpcall", "error", "collectgarbage",
            "dofile", "load","loadfile", "require", "module",
            "getmetatable", "setmetatable",
            "ipairs", "pairs", "rawequal", "rawget", "rawset", "next",
            "tonumber", "tostring",
            "type", "unpack", "select", "print",
        },
        builtin = builtin, -- to be filled
        globals = globals, -- to be filled
    }

    for k, v in next, _G do
        globals[k] = tostring(v)
    end

    local function collect(t,fnc)
        local lib = { }
        for k, v in next, t do
            if fnc then
                lib[v] = _G[v]
            else
                local keys = { }
                local gv = _G[v]
                local tv = type(gv)
                if tv == "table" then
                    for k, v in next, gv do
                        keys[k] = tostring(v) -- true -- by tostring we cannot call overloades functions (security)
                    end
                end
                lib[v] = keys
                builtin[v] = keys
            end
        end
        return lib
    end

    libraries.basiclua  = collect(libraries.basiclua)
    libraries.basictex  = collect(libraries.basictex)
    libraries.extralua  = collect(libraries.extralua)
    libraries.extratex  = collect(libraries.extratex)
    libraries.functions = collect(libraries.functions,true)
    libraries.obsolete  = collect(libraries.obsolete)

    -- shortcut and helper

    local bytecode = lua.bytecode

    local function init(start)
        local i = start
        local t = os.clock()
        while bytecode[i] do
            bytecode[i]() ;
            bytecode[i] = nil ;
            i = i + 1
         -- collectgarbage('step')
        end
        return i - start, os.clock() - t
    end

    -- the stored tables and modules

    storage.noftables , storage.toftables  = init(0)
    storage.nofmodules, storage.tofmodules = init(%s)

    if modules then
        local loaded = package.loaded
        for module, _ in next, modules do
            loaded[module] = true
        end
    end

    texconfig.init = function() end

end

-- we provide a qualified path

callback.register('find_format_file',function(name)
    texconfig.formatname = name
    return name
end)

-- done, from now on input and callbacks are internal
]]

local variablenames = {
    "error_line", "half_error_line",
    "expand_depth", "hash_extra", "nest_size",
    "max_in_open", "max_print_line", "max_strings",
    "param_size", "save_size", "stack_size",
}

local function makestub()
    name = name or (environment.jobname .. ".lui")
    firsttable = firsttable or lua.firstbytecode
    local t = {
        "-- this file is generated, don't change it\n",
        "-- configuration (can be overloaded later)\n"
    }
    for _,v in next, variablenames do
        local tv = texconfig[v]
        if tv and tv ~= "" then
            t[#t+1] = format("texconfig.%s=%s",v,tv)
        end
    end
    io.savedata(name,format("%s\n\n%s",concat(t,"\n"),format(stub,firsttable)))
end

lua.registerfinalizer(makestub,"create stub file")
