if not modules then modules = { } end modules ['m-spreadsheet'] = {
    version   = 1.001,
    comment   = "companion to m-spreadsheet.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local byte, format, gsub, find = string.byte, string.format, string.gsub, string.find
local R, P, S, C, V, Cs, Cc, Ct, Cg, Cf, Carg = lpeg.R, lpeg.P, lpeg.S, lpeg.C, lpeg.V, lpeg.Cs, lpeg.Cc, lpeg.Ct, lpeg.Cg, lpeg.Cf, lpeg.Carg
local lpegmatch, patterns = lpeg.match, lpeg.patterns
local setmetatable, loadstring, next, tostring, tonumber,rawget = setmetatable, loadstring, next, tostring, tonumber, rawget
local formatters = string.formatters

local context = context

local splitthousands = utilities.parsers.splitthousands
local variables      = interfaces.variables

local v_yes = variables.yes

moduledata = moduledata or { }

local spreadsheets      = { }
moduledata.spreadsheets = spreadsheets

local data = {
    -- nothing yet
}

local settings = {
    period = ".",
    comma  = ",",
}

spreadsheets.data     = data
spreadsheets.settings = settings

local defaultname = "default"
local stack       = { }
local current     = defaultname

local d_mt ; d_mt = {
    __index = function(t,k)
        local v = { }
        setmetatable(v,d_mt)
        t[k] = v
        return v
    end,
}

local s_mt ; s_mt = {
    __index = function(t,k)
        local v = settings[k]
        t[k] = v
        return v
    end,
}

function spreadsheets.setup(t)
    for k, v in next, t do
        settings[k] = v
    end
end

local function emptydata(name,settings)
    local data = { }
    local specifications = { }
    local settings = settings or { }
    setmetatable(data,d_mt)
    setmetatable(specifications,d_mt)
    setmetatable(settings,s_mt)
    return {
        name           = name,
        data           = data,
        maxcol         = 0,
        maxrow         = 0,
        settings       = settings,
        temp           = { }, -- for local usage
        specifications = specifications,
    }
end

function spreadsheets.reset(name)
    if not name or name == "" then name = defaultname end
    data[name] = emptydata(name,data[name] and data[name].settings)
end

function spreadsheets.start(name,s)
    if not name or name == "" then
        name = defaultname
    end
    if not s then
        s = { }
    end
    table.insert(stack,current)
    current = name
    if data[current] then
        setmetatable(s,s_mt)
        data[current].settings = s
    else
        data[current] = emptydata(name,s)
    end
end

function spreadsheets.stop()
    current = table.remove(stack)
end

spreadsheets.reset()

local offset = byte("A") - 1

local function assign(s,n)
    return formatters["moduledata.spreadsheets.data['%s'].data[%s]"](n,byte(s)-offset)
end

function datacell(a,b,...)
    local n = 0
    if b then
        local t = { a, b, ... }
        for i=1,#t do
            n = n * (i-1) * 26 + byte(t[i]) - offset
        end
    else
        n = byte(a) - offset
    end
    return formatters["dat[%s]"](n)
end

local function checktemplate(s)
    if find(s,"%",1,true) then
        -- normal template
        return s
    elseif find(s,"@",1,true) then
        -- tex specific template
        return gsub(s,"@","%%")
    else
        -- tex specific quick template
        return "%" .. s
    end
end

local quoted = Cs(patterns.unquoted)
local spaces = patterns.whitespace^0
local cell   = C(R("AZ"))^1 / datacell * (Cc("[") * (R("09")^1) * Cc("]") + #P(1))

-- A nasty aspect of lpeg: Cf ( spaces * Cc("") * { "start" ... this will create a table that will
-- be reused, so we accumulate!

local pattern = Cf ( spaces * Ct("") * { "start",
    start  = V("value") + V("set") + V("format") + V("string") + V("code"),
    value  = Cg(P([[=]]) * spaces * Cc("kind") * Cc("value")) * V("code"),
    set    = Cg(P([[!]]) * spaces * Cc("kind") * Cc("set")) * V("code"),
    format = Cg(P([[@]]) * spaces * Cc("kind") * Cc("format")) * spaces * Cg(Cc("template") * Cs(quoted/checktemplate)) * V("code"),
    string = Cg(#S([["']]) * Cc("kind") * Cc("string")) * Cg(Cc("content") * quoted),
    code   = spaces * Cg(Cc("code") * Cs((cell + P(1))^0)),
}, rawset)

local functions        = { }
spreadsheets.functions = functions

function functions._s_(row,col,c,f,t)
    local r = 0
    if f and t then -- f..t
        -- ok
    elseif f then -- 1..f
        f, t = 1, f
    else
        f, t = 1, row - 1
    end
    for i=f,t do
        local ci = c[i]
        if type(ci) == "number" then
            r = r + ci
        end
    end
    return r
end

functions.fmt = string.tformat

local f_code = formatters [ [[
    local _m_ = moduledata.spreadsheets
    local dat = _m_.data['%s'].data
    local tmp = _m_.temp
    local fnc = _m_.functions
    local row = %s
    local col = %s
    function fnc.sum(...) return fnc._s_(row,col,...) end
    local sum = fnc.sum
    local fmt = fnc.fmt
    return %s
]] ]

-- to be considered: a weak cache

local function propername(name)
    if name ~= "" then
        return name
    elseif current ~= "" then
        return current
    else
        return defaultname
    end
end

-- if name == "" then name = current if name == "" then name = defaultname end end

local function execute(name,r,c,str)
    if str ~= "" then
        local d = data[name]
        if c > d.maxcol then
            d.maxcol = c
        end
        if r > d.maxrow then
            d.maxrow = r
        end
        local specification = lpegmatch(pattern,str,1,name)
        d.specifications[c][r] = specification
        local kind = specification.kind
        if kind == "string" then
            return specification.content or ""
        else
            local code = specification.code
            if code and code ~= "" then
                code = f_code(name,r,c,code or "")
                local result = loadstring(code) -- utilities.lua.strippedloadstring(code,true) -- when tracing
                result = result and result()
                if type(result) == "function" then
                    result = result()
                end
                if type(result) == "number" then
                    d.data[c][r] = result
                end
                if not result then
                    -- nothing
                elseif kind == "set" then
                    -- no return
                elseif kind == "format" then
                    return formatters[specification.template](result)
                else
                    return result
                end
            end
        end
    end
end

function spreadsheets.set(name,r,c,str)
    name = propername(name)
    execute(name,r,c,str)
end

function spreadsheets.get(name,r,c,str)
    name = propername(name)
    local dname = data[name]
    if not dname then
        -- nothing
    elseif not str or str == "" then
        context(dname.data[c][r] or 0)
    else
        local result = execute(name,r,c,str)
        if result then
--             if type(result) == "number" then
--                 dname.data[c][r] = result
--                 result = tostring(result)
--             end
            local settings = dname.settings
            local split  = settings.split
            local period = settings.period
            local comma  = settings.comma
            if split == v_yes then
                result = splitthousands(result)
            end
            if period == "" then period = nil end
            if comma  == "" then comma = nil end
            result = gsub(result,".",{ ["."] = period, [","] = comma })
            context(result)
        end
    end
end

function spreadsheets.doifelsecell(name,r,c)
    name = propername(name)
    local d = data[name]
    local d = d and d.data
    local r = d and rawget(d,r)
    local c = r and rawget(r,c)
    commands.doifelse(c)
end

local function simplify(name)
    name = propername(name)
    local data = data[name]
    if data then
        data = data.data
        local temp = { }
        for k, v in next, data do
            local t = { }
            temp[k] = t
            for kk, vv in next, v do
                if type(vv) == "function" then
                    t[kk] = "<function>"
                else
                    t[kk] = vv
                end
            end
        end
        return temp
    end
end

local function serialize(name)
    local s = simplify(name)
    if s then
        return table.serialize(s,name)
    else
        return formatters["<unknown spreadsheet %a>"](name)
    end
end

spreadsheets.simplify  = simplify
spreadsheets.serialize = serialize

function spreadsheets.inspect(name)
    inspect(serialize(name))
end

function spreadsheets.tocontext(name)
    context.tocontext(simplify(name))
end
