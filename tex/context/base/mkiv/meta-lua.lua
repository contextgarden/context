if not modules then modules = { } end modules ['meta-lua'] = {
    version   = 1.001,
    comment   = "companion to meta-lua.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- Don't use this code yet. I use it in some experimental rendering of graphics
-- based on output from database queries. It's not that pretty but will be
-- considered when the (similar) lmx code is redone. Also, dropping the print
-- variant makes it nicer. This experiment is part of playing with several template
-- mechanisms. (Also see trac-lmx.)

local P, V, Cs, lpegmatch = lpeg.P, lpeg.V, lpeg.Cs, lpeg.match
local formatters = string.formatters
local concat = table.concat
local load, pcall = load, pcall

local errorformatter  = formatters[ [[draw textext("\tttf error in template '%s'") ;]] ]
local concatformatter = formatters[ [[local _t = { } local _n = 0 local p = function(s) _n = _n + 1 _t[_n] = s end %s return table.concat(_t," ")]] ]
local appendformatter = formatters[ [[_n=_n+1 _t[_n]=%q]] ]

local blua     = P("blua ")  / " "
local elua     = P(" elua")  / " "
local bluacode = P("<?lua ") / " "
local eluacode = P(" ?>")    / " "

local plua     = (blua * (1 - elua)^1 * elua)
local pluacode = (bluacode * (1 - eluacode)^1 * eluacode)

-- local methods = {
--     both = Cs { "start",
--         start    = (V("bluacode") + V("blua") + V("rest"))^0,
--         blua     = plua,
--         bluacode = pluacode,
--         rest     = (1 - V("blua") - V("bluacode"))^1 / appendformatter,
--     },
--     xml = Cs { "start",
--         start    = (V("bluacode") + V("rest"))^0,
--         bluacode = pluacode,
--         rest     = (1 - V("bluacode"))^1 / appendformatter,
--     },
--     xml = Cs ((pluacode + (1 - pluacode)^1 / appendformatter)^0),
--     metapost = Cs { "start",
--         start    = (V("blua") + V("rest"))^0,
--         blua     = plua,
--         rest     = (1 - V("blua"))^1 / appendformatter,
--     },
-- }

local methods = {
    both     = Cs ((pluacode + plua + (1 - plua - pluacode)^1 / appendformatter)^0),
    xml      = Cs ((pluacode        + (1 -        pluacode)^1 / appendformatter)^0),
    metapost = Cs ((           plua + (1 - plua           )^1 / appendformatter)^0),
}

methods.mp = methods.metapost

-- Unfortunately mp adds a suffix ... also weird is that successive loading
-- of the same file gives issues. Maybe some weird buffering goes on (smells
-- similar to older write / read issues).

mplib.finders.mpstemplate = function(specification,name,mode,ftype)
    local authority = specification.authority
    local queries   = specification.queries
    local nameonly  = file.nameonly(queries.name   or "")
    local method    = file.nameonly(queries.method or "")
    local pattern   = methods[method] or methods.both
    local data      = nil
    if nameonly == "" then
        data = errorformatter("no name")
    elseif authority == "file" then
        local foundname = resolvers.findfile(nameonly)
        if foundname ~= "" then
            data = io.loaddata(foundname)
        end
    elseif authority == "buffer" then
        data = buffers.getcontent(nameonly)
    end
    data = data and lpegmatch(pattern,data)
    data = data and concatformatter(data)
    data = data and load(data)
    if data then
        local okay
        okay, data = pcall(data)
    end
    if not data or data == "" then
        data = errorformatter(nameonly)
    end
    local name = luatex.registertempfile(nameonly,true)
    local data = metapost.checktexts(data)
    io.savedata(name,data)
    return name
end

