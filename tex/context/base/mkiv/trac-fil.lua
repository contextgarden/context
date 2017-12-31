if not modules then modules = { } end modules ['trac-fil'] = {
    version   = 1.001,
    comment   = "for the moment for myself",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local rawset, tonumber, type, pcall, next = rawset, tonumber, type, pcall, next
local format, concat = string.format, table.concat
local openfile = io.open
local date = os.date
local sortedpairs = table.sortedpairs

local P, C, Cc, Cg, Cf, Ct, Cs, Carg = lpeg.P, lpeg.C, lpeg.Cc, lpeg.Cg, lpeg.Cf, lpeg.Ct, lpeg.Cs, lpeg.Carg
local lpegmatch = lpeg.match

local patterns   = lpeg.patterns
local cardinal   = patterns.cardinal
local whitespace = patterns.whitespace^0

local timestamp = Cf(Ct("") * (
      Cg (Cc("year")    * (cardinal/tonumber)) * P("-")
    * Cg (Cc("month")   * (cardinal/tonumber)) * P("-")
    * Cg (Cc("day")     * (cardinal/tonumber)) * P(" ")
    * Cg (Cc("hour")    * (cardinal/tonumber)) * P(":")
    * Cg (Cc("minute")  * (cardinal/tonumber)) * P(":")
    * Cg (Cc("second")  * (cardinal/tonumber)) * P("+")
    * Cg (Cc("thour")   * (cardinal/tonumber)) * P(":")
    * Cg (Cc("tminute") * (cardinal/tonumber))
)^0, rawset)

local keysvalues = Cf(Ct("") * (
    Cg(C(patterns.letter^0) * whitespace * "=" * whitespace * Cs(patterns.unquoted) * whitespace)
)^0, rawset)

local statusline = Cf(Ct("") * (
      whitespace * P("[") * Cg(Cc("timestamp") * timestamp ) * P("]")
    * whitespace *          Cg(Cc("status"   ) * keysvalues)
),rawset)

patterns.keysvalues = keysvalues
patterns.statusline = statusline
patterns.timestamp  = timestamp

loggers = loggers or { }

local timeformat = format("[%%s%s]",os.timezone(true))
local dateformat = "!%Y-%m-%d %H:%M:%S"

function loggers.makeline(t)
    local result = { } -- minimize time that file is open
    result[#result+1] = format(timeformat,date(dateformat))
    for k, v in sortedpairs(t) do
        local tv = type(v)
        if tv == "string" then
            if v ~= "password" then
                result[#result+1] = format(" %s=%q",k,v)
            end
        elseif tv == "number" or tv == "boolean" then
            result[#result+1] = format(" %s=%q",k,tostring(v))
        end
    end
    return concat(result," ")
end

local function append(filename,...)
    local f = openfile(filename,"a+")
    if not f then
        dir.mkdirs(file.dirname(filename))
        f = openfile(filename,"a+")
    end
    if f then
        f:write(...)
        f:close()
        return true
    else
        return false
    end
end

function loggers.store(filename,data) -- a log service is nicer
    if type(data) == "table"then
        data = loggers.makeline(data)
    end
    pcall(append,filename,data,"\n")
end

function loggers.collect(filename,result)
    if lfs.isfile(filename) then
        local r = lpegmatch(Ct(statusline^0),io.loaddata(filename))
        if result then -- append
            local nofresult = #result
            for i=1,#r do
                nofresult = nofresult + 1
                result[nofresult] = r[i]
            end
            return result
        else
            return r
        end
    else
        return result or { }
    end
end

function loggers.fields(results) -- returns hash of fields with counts so that we can decide on importance
    local fields = { }
    if results then
        for i=1,#results do
            local r = results[i]
            for k, v in next, r do
                local f = fields[k]
                if not f then
                    fields[k] = 1
                else
                    fields[k] = f + 1
                end
            end
        end
    end
    return fields
end

local template = [[<!-- log entries: begin --!>
<table>
<tr>%s</tr>
%s
</table>
<!-- log entries: end --!>
]]

function loggers.tohtml(entries,fields)
    if not fields or #fields == 0 then
        return ""
    end
    if type(entries) == "string" then
        entries = loggers.collect(entries)
    end
    local scratch, lines = { }, { }
    for i=1,#entries do
        local entry = entries[i]
        local status = entry.status
        for i=1,#fields do
            local field = fields[i]
            local v = status[field.name]
            if v ~= nil then
                v = tostring(v)
                local f = field.format
                if f then
                    v = format(f,v)
                end
                scratch[i] = format("<td nowrap='nowrap' align='%s'>%s</td>",field.align or "left",v)
            else
                scratch[i] = "<td/>"
            end
        end
        lines[i] = format("<tr>%s</tr>",concat(scratch))
    end
    for i=1,#fields do
        local field = fields[i]
        scratch[i] = format("<th nowrap='nowrap' align='left'>%s</th>", field.label or field.name)
    end
    local result = format(template,concat(scratch),concat(lines,"\n"))
    return result, entries
end

-- loggers.store("test.log", { name = "whatever", more = math.random(1,100) })

-- local fields = {
--     { name = "name", align = "left"  },
--     { name = "more", align = "right" },
-- }

-- local entries = loggers.collect("test.log")
-- local html    = loggers.tohtml(entries,fields)

-- inspect(entries)
-- inspect(fields)
-- inspect(html)

