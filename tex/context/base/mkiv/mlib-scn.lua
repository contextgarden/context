if not modules then modules = { } end modules ['mlib-scn'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- Very experimental, for Alan and me.

-- for i = 1 upto 32000 : % 0.062
--     ts := 5mm / 20;
-- endfor ;
--
-- for i = 1 upto 32000 : % 0.219
--     ts := (getparameter "axis" "sy") / 20;
-- endfor ;
--
-- for i = 1 upto 32000 : % 0.266
--     ts := (getparameterx "axis" "sy") / 20;
-- endfor ;
--
-- pushparameters "axis";
-- for i = 1 upto 32000 : % 0.250
--     ts := (getparameterx "sy") / 20;
-- endfor ;
-- popparameters;

local type, next = type, next
local byte = string.byte
local insert, remove = table.insert, table.remove

local codes = mplib.codes()
local types = mplib.types()

table.hashed(codes)
table.hashed(types)

metapost.codes = codes
metapost.types = types

local setmetatableindex   = table.setmetatableindex

local scanners            = mp.scan

local scannext            = scanners.next
local scanexpression      = scanners.expression
local scantoken           = scanners.token
local scansymbol          = scanners.symbol
local scannumeric         = scanners.numeric
local scannumber          = scanners.number
local scaninteger         = scanners.integer
local scanboolean         = scanners.boolean
local scanstring          = scanners.string
local scanpair            = scanners.pair
local scancolor           = scanners.color
local scancmykcolor       = scanners.cmykcolor
local scantransform       = scanners.transform
local scanpath            = scanners.path

local mpprint             = mp.print
local mpnumeric           = mp.numeric
local mpstring            = mp.string
local mpquoted            = mp.quoted
local mpboolean           = mp.boolean
local mppair              = mp.pair
local mppath              = mp.path
local mptriplet           = mp.triplet
local mpquadruple         = mp.quadruple
local mpvalue             = mp.value

local report              = logs.reporter("metapost")

local <const> semicolon_code      = codes.semicolon
local <const> equals_code         = codes.equals
local <const> comma_code          = codes.comma
local <const> colon_code          = codes.colon
local <const> leftbrace_code      = codes.leftbrace
local <const> rightbrace_code     = codes.rightbrace
local <const> leftbracket_code    = codes.leftbracket
local <const> rightbracket_code   = codes.rightbracket
local <const> leftdelimiter_code  = codes.leftdelimiter
local <const> rightdelimiter_code = codes.rightdelimiter
local <const> numeric_code        = codes.numeric
local <const> string_code         = codes.string
local <const> capsule_code        = codes.capsule
local <const> nullary_code        = codes.nullary
local <const> tag_code            = codes.tag

local typescanners   = nil
local tokenscanners  = nil
local scanset        = nil
local scanparameters = nil

scanset = function() -- can be optimized, we now read twice
    scantoken()
    if scantoken(true) == rightbrace_code then
        scantoken()
        return { }
    else
        local l = { }
        local i = 0
        while true do
            i = i + 1
            local s = scansymbol(true)
            if s == "{" then
                l[i] = scanset()
            elseif s == "[" then
                local d = { }
                scansymbol()
                while true do
                    local s = scansymbol()
                    if s == "]" then
                        break;
                    elseif s == "," then
                        -- continue
                    else
                        local t = scantoken(true)
                        if t == equals_code or t == colon_code then
                            scantoken()
                        end
                        d[s] = tokenscanners[scantoken(true)]()
                    end
                end
                l[i] = d
            else
                local e = scanexpression(true)
                l[i] = (typescanners[e] or scanexpression)()
            end
            if scantoken() == rightbrace_code then
                break
            else
             -- whatever
            end
        end
        return l
    end
end

tokenscanners = {
    [leftbrace_code] = scanset,
    [numeric_code]   = scannumeric,
    [string_code]    = scanstring,
    [nullary_code]   = scanboolean, -- todo
}

typescanners = {
    [types.known]     = scannumeric,
    [types.numeric]   = scannumeric,
    [types.string]    = scanstring,
    [types.boolean]   = scanboolean,
    [types.pair]      = function() return scanpair     (true) end,
    [types.color]     = function() return scancolor    (true) end,
    [types.cmykcolor] = function() return scancmykcolor(true) end,
    [types.transform] = function() return scantransform(true) end,
    [types.path]      = function() return scanpath     ()     end,
}

table.setmetatableindex(tokenscanners,function()
    local e = scanexpression(true)
    return typescanners[e] or scanexpression
end)

local function scanparameters(fenced)
    local data  = { }
    local close = "]"
    if not fenced then
        close = ";"
    elseif scansymbol(true) == "[" then
        scansymbol()
    else
        return data
    end
    while true do
        local s = scansymbol()
        if s == close then
            break;
        elseif s == "," then
            -- continue
        else
            local t = scantoken(true)
            if t == equals_code or t == colon_code then
                -- optional equal or :
                scantoken()
            end
            data[s] = tokenscanners[scantoken(true)]()
        end
    end
    return data
end

local namespaces = { }
local presets    = { }
local passed     = { }

local function get_parameters(nested)
    local data = { }
    if nested or scansymbol(true) == "[" then
        scansymbol()
    else
        return data
    end
    while true do
        -- a key like 'color' has code 'declare'
        -- print(scansymbol(true),scantoken(true),codes[scantoken(true)])
        local s = scansymbol()
        if s == "]" then
            break;
        elseif s == "," then
            -- continue
        else
            local t = scantoken(true)
            if t == equals_code or t == colon_code then
                -- optional equal or :
                scantoken()
            end
            local kind = scantoken(true)
            if kind == leftdelimiter_code or kind == tag_code then
                kind = scanexpression(true)
                data[s] = (typescanners[kind] or scanexpression)()
            elseif kind == leftbracket_code then
                data[s] = get_parameters(true)
            else
                data[s] = tokenscanners[kind]()
            end
        end
    end
    return data
end

local function getparameters()
    local namespace  = scanstring()
    -- same as below
    local parameters = get_parameters()
    local presets    = presets[namespace]
    local passed     = passed[namespace]
    if passed then
        if presets then
            setmetatableindex(passed,presets)
        end
        setmetatableindex(parameters,passed)
    elseif presets then
        setmetatableindex(parameters,presets)
    end
    namespaces[namespace] = parameters
    --
end

local function applyparameters()
    local saved      = namespaces
    local namespace  = scanstring()
    local action     = scanstring() -- before we scan the parameters
    -- same as above
    local parameters = get_parameters()
    local presets    = presets[namespace]
    local passed     = passed[namespace]
    if passed then
        if presets then
            setmetatableindex(passed,presets)
        end
        setmetatableindex(parameters,passed)
    elseif presets then
        setmetatableindex(parameters,presets)
    end
    namespaces[namespace] = parameters
    -- till here
    mpprint(action)
    namespaces = saved
end

local function presetparameters()
    local namespace = scanstring()
    presets[namespace] = get_parameters()
end

local function collectnames()
    local l = { } -- can be reused but then we can't nest
    local n = 0
    while true do
        local t = scantoken(true)
        -- (1) not really needed
        if t == numeric_code or t == capsule_code then
            n = n + 1 l[n] = scaninteger(1)
        elseif t == string_code then
            n = n + 1 l[n] = scanstring(1)
        elseif t == nullary_code then
            n = n + 1 l[n] = scanboolean(1)
        elseif t == leftdelimiter_code then
            t = scanexpression(true)
            n = n + 1 l[n] = (typescanners[t] or scanexpression)()
        else
            break
        end
    end
    return l, n
end

local function get(v)
    local t = type(v)
    if t == "number" then
        return mpnumeric(v)
    elseif t == "boolean" then
        return mpboolean(v)
    elseif t == "string" then
        return mpquoted(v)
    elseif t == "table" then
        local n = #v
        if type(v[1]) == "table" then
            return mppath(v) -- cycle ?
        elseif n == 2 then
            return mppair(v)
        elseif n == 3 then
            return mptriplet(v)
        elseif n == 4 then
            return mpquadruple(v)
        end
    end
    return mpnumeric(0)
end

local stack = { }

local function pushparameters()
    local l, n = collectnames()
    insert(stack,namespaces)
    for i=1,n do
        local n = namespaces[l[i]]
        if type(n) == "table" then
            namespaces = n
        else
            break
        end
    end
end

local function popparameters()
    local n = remove(stack)
    if n then
        namespaces = n
    else
        report("stack error")
    end
end

local function getparameter()
    local list, n = collectnames()
    local v = namespaces
    for i=1,n do
        local l = list[i]
        local vl = v[l]
        if vl == nil then
            if type(l) == "number" then
                vl = v[1]
                if vl == nil then
                    return mpnumeric(0)
                end
            else
                return mpnumeric(0)
            end
        end
        v = vl
    end
    if v == nil then
        return mpnumeric(0)
    else
        return get(v)
    end
end

local function getparameterdefault()
    local list, n = collectnames()
    local v = namespaces
    for i=1,n-1 do
        local l = list[i]
        local vl = v[l]
        if vl == nil then
            if type(l) == "number" then
                vl = v[1]
                if vl == nil then
                    return get(list[n])
                end
            else
                return get(list[n])
            end
        end
        v = vl
    end
    if v == nil then
        return get(list[n])
    else
        return get(v)
    end
end

local function getparametercount()
    local list, n = collectnames()
    local v = namespaces
    for i=1,n do
        v = v[list[i]]
        if not v then
            break
        end
    end
    return mpnumeric(type(v) == "table" and #v or 0)
end

local validconnectors = {
    [".."]  = true,
    ["..."] = true,
    ["--"]  = true,
}

local function getparameterpath()
    local list, n = collectnames()
    local close = list[n]
    if type(close) == "boolean" then
        n = n - 1
    else
        close = false
    end
    local connector = list[n]
    if type(connector) == "string" and validconnectors[connector] then
        n = n - 1
    else
        connector = "--"
    end
    local v = namespaces
    for i=1,n do
        v = v[list[i]]
        if not v then
            break
        end
    end
    if type(v) == "table" then
        return mppath(v,connector,close)
    else
        return mppair(0,0)
    end
end

local function getparametertext()
    local list, n = collectnames()
    local strut = list[n]
    if type(strut) == "boolean" then
        n = n - 1
    else
        strut = false
    end
    local v = namespaces
    for i=1,n do
        v = v[list[i]]
        if not v then
            break
        end
    end
    if type(v) == "string" then
        return mpquoted("\\strut " .. v)
    else
        return mpquoted("")
    end
end

metapost.registerscript("getparameters",       getparameters)
metapost.registerscript("applyparameters",     applyparameters)
metapost.registerscript("presetparameters",    presetparameters)
metapost.registerscript("getparameter",        getparameter)
metapost.registerscript("getparameterdefault", getparameterdefault)
metapost.registerscript("getparametercount",   getparametercount)
metapost.registerscript("getparameterpath",    getparameterpath)
metapost.registerscript("getparametertext",    getparametertext)
metapost.registerscript("pushparameters",      pushparameters)
metapost.registerscript("popparameters",       popparameters)

-- tex scanners

local scanners      = tokens.scanners
local scanhash      = scanners.hash
local scanstring    = scanners.string
local scanvalue     = scanners.value
local scaninteger   = scanners.integer
local scanboolean   = scanners.boolean
local scanfloat     = scanners.float
local scandimension = scanners.dimension

local definitions   = { }

local <const> bpfactor = number.dimenfactors.bp
local <const> comma    = byte(",")
local <const> close    = byte("]")

local scanrest      = function() return scanvalue(comma,close) or "" end
local scandimension = function() return scandimension() * bpfactor end

local scanners = {
    ["integer"]   = scaninteger,
    ["number"]    = scanfloat,
    ["numeric"]   = scanfloat,
    ["boolean"]   = scanboolean,
    ["string"]    = scanrest,
    ["dimension"] = scandimension,
}

interfaces.implement {
    name      = "lmt_parameters_define",
    arguments = "string",
    actions   = function(namespace)
        local d = scanhash()
        for k, v in next, d do
            d[k] = scanners[v] or scanrest
        end
        definitions[namespace] = d
    end,
}

interfaces.implement {
    name      = "lmt_parameters_preset",
    arguments = "string",
    actions   = function(namespace)
        passed[namespace] = scanhash(definitions[namespace])
    end,
}

interfaces.implement {
    name      = "lmt_parameters_reset",
    arguments = "string",
    actions   = function(namespace)
        passed[namespace] = nil
    end,
}
