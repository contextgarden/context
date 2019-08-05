if not modules then modules = { } end modules ['toks-scn'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Writing this kind of code (and completing the newtoken code base) is fun. I did
-- so with the brilliant film music from The Girl with the Dragon Tattoo running in a
-- loop in the background (three cd's by Trent Reznor and Atticus Ross). An alien
-- feeling helps with alien code.

-- todo: more \let's at the tex end

local type, next, tostring, tonumber = type, next, tostring, tonumber

local formatters     = string.formatters
local concat         = table.concat

local scanners       = tokens.scanners
local tokenbits      = tokens.bits

local scanstring     = scanners.string
local scanargument   = scanners.argument
local scanverbatim   = scanners.verbatim
local scantokenlist  = scanners.tokenlist
local scaninteger    = scanners.integer
local scannumber     = scanners.number
local scankeyword    = scanners.keyword
local scankeywordcs  = scanners.keywordcs
local scanword       = scanners.word
local scankey        = scanners.key
local scancode       = scanners.code
local scanboolean    = scanners.boolean
local scandimen      = scanners.dimen
local scancsname     = scanners.csname

local todimen        = number.todimen
local toboolean      = toboolean

local lpegmatch      = lpeg.match
local p_unquoted     = lpeg.Cs(lpeg.patterns.unquoted)

local trace_compile  = false  trackers.register("tokens.compile", function(v) trace_compile = v end)
local report_compile = logs.reporter("tokens","compile")
local report_scan    = logs.reporter("tokens","scan")

local open  = tokenbits.open
local close = tokenbits.close

local function scanopen()
    while true do
        local c = scancode(open)
        if c == 123 then
            return true
     -- elseif c ~= 32 then
        elseif not c then
            return
        end
    end
end

local function scanclose()
    while true do
        local c = scancode(close)
        if c == 125 then
            return true
     -- elseif c ~= 32 then
        elseif not c then
            return
        end
    end
end

scanners.scanopen  = scanopen
scanners.scanclose = scanclose

local function scanlist()
    local wrapped = scanopen()
    local list    = { }
    local size    = 0
    while true do
        local entry = scanstring()
        if entry then
            size = size + 1
            list[size] = entry
        else
            break
        end
    end
    if wrapped then
        scanclose()
    end
    return list
end

local function scanconditional()
    local kw = scanword()
    if kw == "true" then
        return true
    end
    if kw == "false" then
        return false
    end
    local c = scaninteger()
    if c then
        return c == 0 -- with a conditional 0=true
    end
    return nil
end

local function scantable(t,data)
    if not data then
        data = { }
    end
    local wrapped = scanopen()
    while true do
        local key = scanword()
        if key then
            local get = t[key]
            if get then
                data[key] = get()
            else
                -- catch all we can get
            end
        else
            break
        end
    end
    if wrapped then
        scanclose()
    end
    return data
end

function tokens.constant(s)
    if type(s) == "string" then
        return "'" .. s .. "'"
    else
        return s
    end
end

scanners.list        = scanlist
scanners.table       = scantable
scanners.conditional = scanconditional

function scanners.whd()
    local width, height, depth
    while true do
        if scankeyword("width") then
            width = scandimen()
        elseif scankeyword("height") then
            height = scandimen()
        elseif scankeyword("depth") then
            depth = scandimen()
        else
            break
        end
    end
    if width or height or depth then
        return width or 0, height or 0, depth or 0
    else
        -- we inherit
    end
end

local shortcuts = {
    tokens          = tokens,
    bits            = tokenbits,
    open            = open,
    close           = close,
    scanners        = scanners,
    scanstring      = scanstring,
    scanargument    = scanargument,
    scanverbatim    = scanverbatim,
    scantokenlist   = scantokenlist,
    scaninteger     = scaninteger,
    scannumber      = scannumber,
    scantable       = scantable,
    scankeyword     = scankeyword,
    scankeywordcs   = scankeywordcs,
    scanword        = scanword,
 -- scankey         = scankey,
    scancode        = scancode,
    scanboolean     = scanboolean,
    scandimen       = scandimen,
    scandimension   = scandimen,
    scanbox         = scanners.box,
    scanhbox        = scanners.hbox,
    scanvbox        = scanners.vbox,
    scanvtop        = scanners.vtop,
    scanconditional = scanconditional,
    scanopen        = scanopen,
    scanclose       = scanclose,
    scanlist        = scanlist,
    scancsname      = scancsname,
    todimen         = todimen,
    tonumber        = tonumber,
    tostring        = tostring,
    toboolean       = toboolean,
    inspect         = inspect,
    report          = report_scan,
}

tokens.shortcuts = shortcuts

local load = load
local dump = string.dump

local function loadstripped(code)
     return load(code,nil,nil,shortcuts)
  -- return load(dump(load(code),true),nil,nil,shortcuts)
end

tokens.converters = {
    tonumber  = "tonumber",
    tostring  = "tostring",
    toboolean = "toboolean",
    todimen   = "todimen",
    toglue    = "todimen",
}

-- We could just pickup a keyword but then we really need to make sure
-- that no number follows it when that is the assignment and adding
-- an optional = defeats the gain in speed. Currently we have sources
-- with no spaces (\startcontextdefinitioncode ...) so it fails there.
--
-- Another drawback is that we then need to use { } instead of ending
-- with \relax (as we can do now) but that is no big deal. It's just
-- that I then need to check the TeX end. More pain than gain and a bit
-- risky too.

local f_if       = formatters[    "  if scankeywordcs('%s') then data['%s'] = scan%s()"]
local f_elseif   = formatters["  elseif scankeywordcs('%s') then data['%s'] = scan%s()"]

----- f_if       = formatters["  local key = scanword() if key == '' then break elseif key == '%s' then data['%s'] = scan%s()"]
----- f_elseif   = formatters["  elseif key == '%s' then data['%s'] = scan%s()"]

----- f_if_x     = formatters[    "  if not data['%s'] and scankeywordcs('%s') then data['%s'] = scan%s()"]
----- f_elseif_x = formatters["  elseif not data['%s'] and scankeywordcs('%s') then data['%s'] = scan%s()"]

local f_local    = formatters["local scan%s = scanners.%s"]
local f_scan     = formatters["scan%s()"]
local f_shortcut = formatters["local %s = scanners.converters.%s"]

local f_if_c     = formatters[    "  if scankeywordcs('%s') then data['%s'] = %s(scan%s())"]
local f_elseif_c = formatters["  elseif scankeywordcs('%s') then data['%s'] = %s(scan%s())"]
local f_scan_c   = formatters["%s(scan%s())"]

-- see above
--
----- f_if_c     = formatters["  local key = scanword() if key == '' then break elseif key == '%s' then data['%s'] = %s(scan%s())"]
----- f_elseif_c = formatters["  elseif k == '%s' then data['%s'] = %s(scan%s())"]

local f_any      = formatters["  else local key = scanword() if key then data[key] = scan%s() else break end end"]
local f_any_c    = formatters["  else local key = scanword() if key then data[key] = %s(scan%s()) else break end end"]
local s_done     = "  else break end"

local f_any_all  = formatters["  local key = scanword() if key then data[key] = scan%s() else break end"]
local f_any_all_c= formatters["  local key = scanword() if key then data[key] = %s(scan%s()) else break end"]

local f_table    = formatters["%\nt\nreturn function()\n  local data = { }\n%s\n  return %s\nend\n"]
local f_sequence = formatters["%\nt\n%\nt\n%\nt\nreturn function()\n    return %s\nend\n"]
local f_simple   = formatters["%\nt\nreturn function()\n    return %s\nend\n"]
local f_string   = formatters["%q"]
local f_action_f = formatters["action%s(%s)"]
local f_action_s = formatters["local action%s = tokens._action[%s]"]
local f_nested   = formatters["local function scan%s()\n  local data = { }\n%s\n  return data\nend\n"]

-- local f_check = formatters[ [[
--   local wrapped = false
--   while true do
--     local c = scancode(open)
--     if c == 123 then
--       wrapped = true
--       break
--     elseif c ~= 32 then
--       break
--     end
--   end
--   while true do
--     ]] .. "%\nt\n" .. [[
--     %s
--   end
--   if wrapped then
--     while true do
--       local c = scancode(close)
--       if c == 125 then
--         break
--       elseif c ~= 32 then
--         break
--       end
--     end
--   end
-- ]] ]

local f_check = formatters[ [[
  local wrapped = scanopen()
  while true do
    ]] .. "%\nt\n" .. [[
    %s
  end
  if wrapped then
    scanclose()
  end
]] ]

-- using these shortcuts saves temporary small tables (okay, it looks uglier)

local presets = {
    ["1 string" ] = { "string" },
    ["2 strings"] = { "string", "string" },
    ["3 strings"] = { "string", "string", "string" },
    ["4 strings"] = { "string", "string", "string", "string" },
    ["5 strings"] = { "string", "string", "string", "string", "string" },
    ["6 strings"] = { "string", "string", "string", "string", "string", "string" },
    ["7 strings"] = { "string", "string", "string", "string", "string", "string", "string" },
    ["8 strings"] = { "string", "string", "string", "string", "string", "string", "string", "string" },
}

tokens.presets = presets

function tokens.compile(specification)
    local f = { }
    local n = 0
    local c = { }
    local t = specification.arguments or specification
    local a = specification.actions or nil
    if type(a) == "function" then
        a = { a }
    end
    local code
    local function compile(t,nested)
        local done = s_done
        local r = { }
        local m = 0
        for i=1,#t do
            local ti = t[i]
            if ti == "*" and i == 1 then
                done = f_any_all("string")
            else
                local t1 = ti[1]
                local t2 = ti[2] or "string"
                if type(t2) == "table" then
                    n = n + 1
                    f[n] = compile(t2,n)
                    t2 = n
                end
                local t3 = ti[3]
                if type(t3) == "function" then
                    -- todo: also create shortcut
                elseif t3 then
                    c[t3] = f_shortcut(t3,t3)
                    if t1 == "*" then
                        if i == 1 then
                            done = f_any_all_c(t3,t2)
                            break
                        else
                            done = f_any_c(t3,t2)
                        end
                    else
                        m = m + 1
                        r[m] = (m > 1 and f_elseif_c or f_if_c)(t1,t1,t3,t2)
                    end
                else
                    if t1 == "*" then
                        if i == 1 then
                            done = f_any_all(t2)
                            break
                        else
                            done = f_any(t2)
                        end
                    else
                        m = m + 1
                        r[m] = (m > 1 and f_elseif   or f_if  )(t1,t1,t2)
                     -- r[m] = (m > 1 and f_elseif_x or f_if_x)(t1,t1,t1,t2)
                    end
                end
            end
        end
        local c = f_check(r,done)
        if nested then
            return f_nested(nested,c)
        else
            return c
        end
    end
    local p = t and presets[t] -- already done in implement
    if p then
        t = p
    end
    local tt = type(t)
    if tt == "string" then
        if a then
            local s = lpegmatch(p_unquoted,t)
            if s and t ~= s then
                code = t
            else
                code = f_scan(t)
            end
            tokens._action = a
            for i=1,#a do
                code = f_action_f(i,code)
                n    = n + 1
                f[n] = f_action_s(i,i)
            end
            code = f_simple(f,code)
        else
            return scanners[t]
        end
    elseif tt ~= "table" then
        return
    elseif #t == 1 then
        local ti = t[1]
        if type(ti) == "table" then
            ti = compile(ti)
            code = "data"
            if a then
                tokens._action = a
                for i=1,#a do
                    code = f_action_f(i,code)
                    n    = n + 1
                    f[n] = f_action_s(i,i)
                end
            end
            code = f_table(f,ti,code)
        elseif a then
            code = f_scan(ti)
            tokens._action = a
            for i=1,#a do
                code = f_action_f(i,code)
                n    = n + 1
                f[n] = f_action_s(i,i)
            end
            code = f_simple(f,code)
        else
            return scanners[ti]
        end
    else
        local r = { }
        local p = { }
        local m = 0
        for i=1,#t do
            local ti = t[i]
            local tt = type(ti)
            if tt == "table" then
                if ti[1] == "_constant_" then
                    local v = ti[2]
                    if type(v) == "string" then
                        r[i] = f_string(v)
                    else
                        r[i] = tostring(v)
                    end
                else
                    m = m + 1
                    p[m] = compile(ti,100+m)
                    r[i] = f_scan(100+m)
                end
            elseif tt == "number" then
                r[i] = tostring(ti)
            elseif tt == "boolean" then
                r[i] = tostring(ti)
            else
                local s = lpegmatch(p_unquoted,ti)
                if s and ti ~= s then
                    r[i] = ti -- a string, given as "'foo'" or '"foo"'
                elseif scanners[ti] then
                    r[i] = f_scan(ti)
                else
                    report_compile("unknown scanner %a",ti)
                    r[i] = ti
                end
            end
        end
        code = concat(r,",")
        if a then
            tokens._action = a
            for i=1,#a do
                code = f_action_f(i,code)
                n    = n + 1
                f[n] = f_action_s(i,i)
            end
        end
        code = f_sequence(c,f,p,code)
    end
    if not code then
        return
    end
    if trace_compile then
        report_compile("code: %s",code)
    end
    local code, message = loadstripped(code)
    if code then
        code = code() -- sets action
    else
        report_compile("error in code: %s",code)
        report_compile("error message: %s",message)
    end
    if a then
        tokens._action = nil
    end
    if code then
        return code
    end
end

-- local fetch = tokens.compile {
--     "string",
--     "string",
--     {
--         { "data",    "string" },
--         { "tab",     "string" },
--         { "method",  "string" },
--         { "foo", {
--             { "method", "integer" },
--             { "compact", "number" },
--             { "nature" },
--             { "*" }, -- any key
--         } },
--         { "compact", "string", "tonumber" },
--         { "nature",  "boolean" },
--         { "escape",  "string" },
--         { "escape"  },
--     }
--     "boolean",
-- }
--
-- os.exit()
