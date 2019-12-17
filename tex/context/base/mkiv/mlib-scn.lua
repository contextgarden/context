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

local type, next, rawget, getmetatable = type, next, rawget, getmetatable
local byte, gmatch = string.byte, string.gmatch
local insert, remove = table.insert, table.remove

local mplib    = mplib
local metapost = metapost

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
local scanpen             = scanners.pen

local mpprint             = mp.print
local mpnumeric           = mp.numeric
local mpstring            = mp.string
local mpquoted            = mp.quoted
local mpboolean           = mp.boolean
local mppair              = mp.pair
local mppath              = mp.path
local mptriplet           = mp.triplet
local mpquadruple         = mp.quadruple
local mptransform         = mp.transform
local mpvalue             = mp.value

local report              = logs.reporter("metapost")

local semicolon_code      <const> = codes.semicolon
local equals_code         <const> = codes.equals
local comma_code          <const> = codes.comma
local colon_code          <const> = codes.colon
local leftbrace_code      <const> = codes.leftbrace
local rightbrace_code     <const> = codes.rightbrace
local leftbracket_code    <const> = codes.leftbracket
local rightbracket_code   <const> = codes.rightbracket
local leftdelimiter_code  <const> = codes.leftdelimiter
local rightdelimiter_code <const> = codes.rightdelimiter
local numeric_code        <const> = codes.numeric
local string_code         <const> = codes.string
local capsule_code        <const> = codes.capsule
local nullary_code        <const> = codes.nullary
local tag_code            <const> = codes.tag
local definedmacro_code   <const> = codes.definedmacro

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

local function scan_pair     () return scanpair     (true) end
local function scan_color    () return scancolor    (true) end
local function scan_cmykcolor() return scancmykcolor(true) end
local function scan_transform() return scantransform(true) end

tokenscanners = {
    [leftbrace_code] = scanset,
    [numeric_code]   = scannumeric,
    [string_code]    = scanstring,
    [nullary_code]   = scanboolean,   -- todo
}

typescanners = {
    [types.known]     = scannumeric,
    [types.numeric]   = scannumeric,
    [types.string]    = scanstring,
    [types.boolean]   = scanboolean,
    [types.pair]      = scan_pair,
    [types.color]     = scan_color,
    [types.cmykcolor] = scan_cmykcolor,
    [types.transform] = scan_transform,
    [types.path]      = scanpath,
    [types.pen]       = scanpen,
}

table.setmetatableindex(tokenscanners,function()
    local e = scanexpression(true)
    return typescanners[e] or scanexpression
end)

-- a key like 'color' has code 'declare'

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
     -- local s = scansymbol()
        local s = scansymbol(false,false)
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
            local kind = scantoken(true)
            if kind == leftdelimiter_code or kind == tag_code or kind == capsule_code then
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
        local s = scansymbol(false,false)
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
            if kind == leftdelimiter_code or kind == tag_code or kind == capsule_code then
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
    local parent = nil
    local t = scantoken(true)
    if t == string_code then
        parent = presets[scanstring()]
    end
    local p = get_parameters()
    if parent then
        setmetatableindex(p,parent)
    end
    presets[namespace] = p
end

local function collectnames()
    local l = { } -- can be reused but then we can't nest
    local n = 0
    while true do
        local t = scantoken(true)
        -- (1) not really needed
        if t == numeric_code then
            n = n + 1 l[n] = scaninteger(1)
        elseif t == string_code then
            n = n + 1 l[n] = scanstring(1)
        elseif t == nullary_code then
            n = n + 1 l[n] = scanboolean(1)
        elseif t == leftdelimiter_code or t == tag_code or t == capsule_code then
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
        elseif n == 6 then
            return mptransform(v)
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

-- todo:

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

local function hasparameter()
    local list, n = collectnames()
    local v = namespaces
    for i=1,n do
        local l = list[i]
        local vl = rawget(v,l)
        if vl == nil then
            if type(l) == "number" then
                vl = rawget(v,1)
                if vl == nil then
                    return mpboolean(false)
                end
            else
                return mpboolean(false)
            end
        end
        v = vl
    end
    if v == nil then
        return mpboolean(false)
    else
        return mpboolean(true)
    end
end

local function hasoption()
    local list, n = collectnames()
    if n > 1 then
        local v = namespaces
        if n > 2 then
            for i=1,n-1 do
                local l = list[i]
                local vl = v[l]
                if vl == nil then
                    return mpboolean(false)
                end
                v = vl
            end
        else
            v = v[list[1]]
        end
        if type(v) == "string" then
            -- no caching .. slow anyway
            local o = list[n]
            if v == o then
                return mpboolean(true)
            end
            for vv in gmatch(v,"[^%s,]+") do
                for oo in gmatch(o,"[^%s,]+") do
                    if vv == oo then
                        return mpboolean(true)
                    end
                end
            end
        end
    end
    return mpboolean(false)
end

local function getparameterdefault()
    local list, n = collectnames()
    local v = namespaces
    if n == 1 then
        local l = list[1]
        local vl = v[l]
        if vl == nil then
            -- maybe backtrack
            local top = stack[#stack]
            if top then
                vl = top[l]
            end
        end
        if vl == nil then
            return mpnumeric(0)
        else
            return get(vl)
        end
    else
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
                    local last = list[n]
                    if last == "*" then
                        -- so, only when not pushed
                        local m = getmetatable(namespaces[list[1]])
                        if n then
                            m = m.__index -- can also be a _m_
                        end
                        if m then
                            local v = m
                            for i=2,n-1 do
                                local l = list[i]
                                local vl = v[l]
                                if vl == nil then
                                    return mpnumeric(0)
                                end
                                v = vl
                            end
                            if v == nil then
                                return mpnumeric(0)
                            else
                                return get(v)
                            end
                        end
                        return mpnumeric(0)
                    else
                        return get(last)
                    end
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

local function getmaxparametercount()
    local list, n = collectnames()
    local v = namespaces
    for i=1,n do
        v = v[list[i]]
        if not v then
            break
        end
    end
    local n = 0
    if type(v) == "table" then
        local v1 = v[1]
        if type(v1) == "table" then
            n = #v1
            for i=2,#v do
                local vi = v[i]
                if type(vi) == "table" then
                    local vn = #vi
                    if vn > n then
                        n = vn
                    end
                else
                    break;
                end
            end
        end

    end
    return mpnumeric(n)
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

local function getparameterpen()
    local list, n = collectnames()
    local v = namespaces
    for i=1,n do
        v = v[list[i]]
        if not v then
            break
        end
    end
    if type(v) == "table" then
        return mppath(v,"..",true)
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

-- local function getparameteroption()
--     local list, n = collectnames()
--     local last = list[n]
--     if type(last) == "string" then
--         n = n - 1
--     else
--         return false
--     end
--     local v = namespaces
--     for i=1,n do
--         v = v[list[i]]
--         if not v then
--             break
--         end
--     end
--     if type(v) == "string" and v ~= "" then
--         for s in gmatch(v,"[^ ,]+") do
--             if s == last then
--                 return true
--             end
--         end
--     end
--     return false
-- end

function metapost.scanparameters()
--     scantoken() -- we scan the semicolon
    return get_parameters()
end

metapost.registerscript("getparameters",       getparameters)
metapost.registerscript("applyparameters",     applyparameters)
metapost.registerscript("presetparameters",    presetparameters)
metapost.registerscript("hasparameter",        hasparameter)
metapost.registerscript("hasoption",           hasoption)
metapost.registerscript("getparameter",        getparameter)
metapost.registerscript("getparameterdefault", getparameterdefault)
metapost.registerscript("getparametercount",   getparametercount)
metapost.registerscript("getmaxparametercount",getmaxparametercount)
metapost.registerscript("getparameterpath",    getparameterpath)
metapost.registerscript("getparameterpen",     getparameterpen)
metapost.registerscript("getparametertext",    getparametertext)
--------.registerscript("getparameteroption",  getparameteroption)
metapost.registerscript("pushparameters",      pushparameters)
metapost.registerscript("popparameters",       popparameters)

function metapost.getparameter(list)
    local n = #list
    local v = namespaces
    for i=1,n do
        local l = list[i]
        local vl = v[l]
        if vl == nil then
            return
        end
        v = vl
    end
    return v
end

function metapost.getparameterset(namespace)
    return namespace and namespaces[namespace] or namespaces
end

function metapost.setparameterset(namespace,t)
    namespaces[namespace] = t
end

-- goodies

metapost.registerscript("definecolor", function()
    scantoken() -- we scan the semicolon
    local s = get_parameters()
    attributes.colors.defineprocesscolordirect(s)
end)

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

local bpfactor      <const> = number.dimenfactors.bp
local comma         <const> = byte(",")
local close         <const> = byte("]")

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
