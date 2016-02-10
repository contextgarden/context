if not modules then modules = { } end modules ['luat-cnf'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next, tostring, tonumber =  type, next, tostring, tonumber
local format, concat, find, lower, gsub = string.format, table.concat, string.find, string.lower, string.gsub

local report = logs.reporter("system")

local allocate = utilities.storage.allocate

texconfig.kpse_init    = false
texconfig.shell_escape = 't'

luatex       = luatex or { }
local luatex = luatex

texconfig.max_print_line  = 100000 -- frozen
texconfig.max_in_open     =    127 -- frozen
texconfig.error_line      =     79 -- frozen
texconfig.half_error_line =     50 -- frozen

texconfig.expand_depth    =  10000 -- 10000
texconfig.hash_extra      = 100000 --     0
texconfig.nest_size       =   1000 --    50
texconfig.max_in_open     =    500 --    15 -- in fact it's limited to 127
texconfig.max_print_line  =  10000 --    79
texconfig.max_strings     = 500000 -- 15000
texconfig.param_size      =  25000 --    60
texconfig.save_size       =  50000 --  4000
texconfig.save_size       = 100000 --  4000
texconfig.stack_size      =  10000 --   300

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
            "token",
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
    error_line      = false,
    half_error_line = false,
    max_print_line  = false,
    max_in_open     = false,
    expand_depth    = true,
    hash_extra      = true,
    nest_size       = true,
    max_strings     = true,
    param_size      = true,
    save_size       = true,
    stack_size      = true,
}

local function makestub()
    name = name or (environment.jobname .. ".lui")
    report("creating stub file %a using directives:",name)
    report()
    firsttable = firsttable or lua.firstbytecode
    local t = {
        "-- this file is generated, don't change it\n",
        "-- configuration (can be overloaded later)\n"
    }
    for v, permitted in table.sortedhash(variablenames) do
        local d = "luatex." .. gsub(lower(v),"[^%a]","")
        local dv = directives.value(d)
        local tv = texconfig[v]
        if dv then
            if not tv then
                report("  %s = %s (%s)",d,dv,"configured")
                tv = dv
            elseif not permitted then
                report("  %s = %s (%s)",d,tv,"frozen")
            elseif tonumber(dv) >= tonumber(tv) then
                report("  %s = %s (%s)",d,dv,"overloaded")
                tv = dv
            else
                report("  %s = %s (%s)",d,tv,"preset kept")
            end
        elseif tv then
            report("  %s = %s (%s)",d,tv,permitted and "preset" or "frozen")
        else
            report("  %s = <unset>",d)
        end
        if tv then
            t[#t+1] = format("texconfig.%s=%s",v,tv)
        end
    end
    io.savedata(name,format("%s\n\n%s",concat(t,"\n"),format(stub,firsttable)))
    logs.newline()
end

lua.registerfinalizer(makestub,"create stub file")
