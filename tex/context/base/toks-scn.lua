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
local loadstring     = loadstring

local scanners       = tokens.scanners
local tokenbits      = tokens.bits

if not scanners then return end -- for now

local scanstring     = scanners.string
local scaninteger    = scanners.integer
local scannumber     = scanners.number
local scankeyword    = scanners.keyword
local scanword       = scanners.word
local scancode       = scanners.code
local scanboolean    = scanners.boolean
local scandimen      = scanners.dimen

if not scanstring then return end -- for now

local todimen        = number.todimen

local lpegmatch      = lpeg.match
local p_unquoted     = lpeg.patterns.unquoted

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

local shortcuts = {
    tokens        = tokens,
    bits          = tokenbits,
    open          = open,
    close         = close,
    scanners      = scanners,
    scanstring    = scanstring,
    scaninteger   = scaninteger,
    scannumber    = scannumber,
    scankeyword   = scankeyword,
    scanword      = scanword,
    scancode      = scancode,
    scanboolean   = scanboolean,
    scandimen     = scandimen,
    scandimension = scandimen,
    scanopen      = scanopen,
    scanclose     = scanclose,
    todimen       = todimen,
    tonumber      = tonumber,
    tostring      = tostring,
    inspect       = inspect,
    report        = report_scan,
}

tokens.shortcuts = shortcuts

local load = load
local dump = string.dump

local function loadstripped(code)
     return load(code,nil,nil,shortcuts)
  -- return load(dump(load(code),true),nil,nil,shortcuts)
end

tokens.converters = {
    tonumber = "tonumber",
    todimen  = "todimen",
    toglue   = "todimen",
    tostring = "tostring",
}

local f_if       = formatters[    "  if scankeyword('%s') then data['%s'] = scan%s()"]
local f_elseif   = formatters["  elseif scankeyword('%s') then data['%s'] = scan%s()"]
local f_local    = formatters["local scan%s = scanners.%s"]
local f_scan     = formatters["scan%s()"]
local f_shortcut = formatters["local %s = scanners.converters.%s"]

local f_if_c     = formatters[    "  if scankeyword('%s') then data['%s'] = %s(scan%s())"]
local f_elseif_c = formatters["  elseif scankeyword('%s') then data['%s'] = %s(scan%s())"]
local f_scan_c   = formatters["%s(scan%s())"]

local f_any      = formatters["  else local key = scanword() if key then data[key] = scan%s() else break end end"]
local f_any_c    = formatters["  else local key = scanword() if key then data[key] = %s(scan%s()) else break end end"]
local s_done     = "  else break end"

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
                    done = f_any_c(t3,t2)
                else
                    m = m + 1
                    r[m] = (m > 1 and f_elseif_c or f_if_c)(t1,t1,t3,t2)
                end
            else
                if t1 == "*" then
                    done = f_any(t2)
                else
                    m = m + 1
                    r[m] = (m > 1 and f_elseif   or f_if  )(t1,t1,t2)
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
    local tt = type(t)
    if tt == "string" then
        if a then
            code = f_scan(t)
            tokens._action = a
            for i=1,#a do
                code    = f_action_f(i,code)
                f[#f+1] = f_action_s(i,i)
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
                    code    = f_action_f(i,code)
                    f[#f+1] = f_action_s(i,i)
                end
            end
            code = f_table(f,ti,code)
        elseif a then
            code = f_scan(ti)
            tokens._action = a
            for i=1,#a do
                code    = f_action_f(i,code)
                f[#f+1] = f_action_s(i,i)
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
                code    = f_action_f(i,code)
                f[#f+1] = f_action_s(i,i)
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

function tokens.scantable(t,data)
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
