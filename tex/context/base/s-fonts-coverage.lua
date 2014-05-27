if not modules then modules = { } end modules ['s-fonts-coverage'] = {
    version   = 1.001,
    comment   = "companion to s-fonts-coverage.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.fonts          = moduledata.fonts          or { }
moduledata.fonts.coverage = moduledata.fonts.coverage or { }

local upper, format = string.upper, string.format
local lpegmatch = lpeg.match
local concat = table.concat

local context = context
local NC, NR, HL = context.NC, context.NR, context.HL
local char, bold, getvalue = context.char, context.bold, context.getvalue

local chardata = characters.data

function moduledata.fonts.coverage.showcomparison(specification)

    specification = interfaces.checkedspecification(specification)

    local fontfiles = utilities.parsers.settings_to_array(specification.list or "")
    local pattern   = upper(specification.pattern or "")

    local present = { }
    local names   = { }
    local files   = { }

    if not pattern then
        -- skip
    elseif pattern == "" then
        pattern = nil
    elseif tonumber(pattern) then
        pattern = tonumber(pattern)
    else
        pattern = lpeg.oneof(utilities.parsers.settings_to_array(pattern))
        pattern = (1-pattern)^0 * pattern
    end

    for i=1,#fontfiles do
        local fontname = format("testfont-%s",i)
        local fontfile = fontfiles[i]
        local fontsize = tex.dimen.bodyfontsize
        local id, fontdata = fonts.definers.define {
            name = fontfile,
            size = fontsize,
            cs   = fontname,
        }
        if id and fontdata then
            for k, v in next, fontdata.characters do
                present[k] = true
            end
            names[#names+1] = fontname
            files[#files+1] = fontfile
        end
    end

    local t = { }

    context.starttabulate { "|Tr" .. string.rep("|l",#names) .. "|" }
    for i=1,#files do
        local file = files[i]
        t[#t+1] = i .. "=" .. file
        NC()
            context(i)
        NC()
            context(file)
        NC()
        NR()
    end
    context.stoptabulate()

    context.setupfootertexts {
        table.concat(t," ")
    }

    context.starttabulate { "|Tl" .. string.rep("|c",#names) .. "|Tl|" }
    NC()
    bold("unicode")
    NC()
    for i=1,#names do
        bold(i)
        NC()
    end
    bold("description")
    NC()
    NR()
    HL()
    for k, v in table.sortedpairs(present) do
        if k > 0 then
            local description = chardata[k].description
            if not pattern or (pattern == k) or (description and lpegmatch(pattern,description)) then
                NC()
                    context("%05X",k)
                NC()
                for i=1,#names do
                    getvalue(names[i])
if k < 0x110000 then
                    char(k)
else
    logs.report("warning","weird character %U",k)
end
                    NC()
                end
                    context(description)
                NC()
                NR()
            end
        end
    end
    context.stoptabulate()

end
