if not modules then modules = { } end modules ['util-fmt'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

utilities            = utilities or { }
utilities.formatters = utilities.formatters or { }
local formatters     = utilities.formatters

local concat, format = table.concat, string.format
local tostring, type, unpack = tostring, type, unpack
local strip = string.strip

local lpegmatch = lpeg.match
local stripper  = lpeg.patterns.stripzeros

function formatters.stripzeros(str)
    return lpegmatch(stripper,str)
end

function formatters.formatcolumns(result,between,header)
    if result and #result > 0 then
        local widths    = { }
        local numbers   = { }
        local templates = { }
        local first     = result[1]
        local n         = #first
              between   = between or "   "
        --
        for i=1,n do
            widths[i] = 0
        end
        for i=1,#result do
            local r = result[i]
            for j=1,n do
                local rj = r[j]
                local tj = type(rj)
                if tj == "number" then
                    numbers[j] = true
                    rj = tostring(rj)
                elseif tj ~= "string" then
                    rj = tostring(rj)
                    r[j] = rj
                end
                local w = #rj
                if w > widths[j] then
                    widths[j] = w
                end
            end
        end
        if header then
            for i=1,#header do
                local h = header[i]
                for j=1,n do
                    local hj = tostring(h[j])
                    h[j] = hj
                    local w = #hj
                    if w > widths[j] then
                        widths[j] = w
                    end
                end
            end
        end
        for i=1,n do
            local w = widths[i]
            if numbers[i] then
                if w > 80 then
                    templates[i] = "%s" .. between
                else
                    templates[i] = "% " .. w .. "i" .. between
                end
            else
                if w > 80 then
                    templates[i] = "%s" .. between
                elseif w > 0 then
                    templates[i] = "%-" .. w .. "s" .. between
                else
                    templates[i] = "%s"
                end
            end
        end
        local template = strip(concat(templates))
        for i=1,#result do
            local str = format(template,unpack(result[i]))
            result[i] = strip(str)
        end
        if header then
            for i=1,n do
                local w = widths[i]
                if w > 80 then
                    templates[i] = "%s" .. between
                elseif w > 0 then
                    templates[i] = "%-" .. w .. "s" .. between
                else
                    templates[i] = "%s"
                end
            end
            local template = strip(concat(templates))
            for i=1,#header do
                local str = format(template,unpack(header[i]))
                header[i] = strip(str)
            end
        end
    end
    return result, header
end
