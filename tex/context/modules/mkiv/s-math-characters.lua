if not modules then modules = { } end modules['s-math-characters'] = {
    version   = 1.001,
    comment   = "companion to s-math-characters.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is one of the oldest cld files but I'm not going to clean it up.

moduledata.math            = moduledata.math            or { }
moduledata.math.characters = moduledata.math.characters or { }

local concat = table.concat
local lower = string.lower
local utfchar = utf.char
local round = math.round
local setmetatableindex = table.setmetatableindex
local sortedhash = table.sortedhash

local context        = context

local fontdata       = fonts.hashes.identifiers
local chardata       = characters.data
local blocks         = characters.blocks

local no_description = "no description, private to font"

local limited        = true
local fillinthegaps  = true
local upperlimit     = 0x0007F
local upperlimit     = 0xF0000

local f_unicode      = string.formatters["%U"]
local f_slot         = string.formatters["%s/%0X"]

-- do
--
--     local chardata = characters.data
--     local blocks   = characters.blocks
--
--     local ismath = { }
--
--     setmetatableindex(ismath,function(t,k)
--         local function add(t,b)
--             local m = blocks[b]
--             for i=m.first,m.last do
--                 t[i] = b
--             end
--         end
-- --         add(t,"mathematicaloperators")
-- --         add(t,"miscellaneousmathematicalsymbolsa")
-- --         add(t,"miscellaneousmathematicalsymbolsb")
-- --         add(t,"miscellaneoussymbolsandarrows")
-- --         add(t,"miscellaneoustechnical")
-- --         add(t,"supplementalarrowsa")
-- --         add(t,"supplementalarrowsb")
-- --         add(t,"supplementalarrowsc")
-- --         add(t,"supplementalmathematicaloperators")
--         setmetatableindex(ismath)
--         return ismath[k]
--     end)
--
--     local s = lpeg.P(" ")
-- --         local p = lpeg.Cs(lpeg.Cc("unim") * (lpeg.P(1) * ((1 - s)^0/"") * (s^0/""))^1)
--     local p = lpeg.Cs((lpeg.P(1) * ((1 - s)^0/"") * (s^0/""))^1)
--
--     local function fakename(description)
--         return lpeg.match(p,description)
--     end
--
--     local hash = { }
--
--     for k,v in next, chardata do
--         if ismath[k] then
--             local description = v.description
--             if description then
--                 local description = lower(description)
--                 local somename = "unum" .. v.category .. fakename(description)
--                 if hash[somename] then
--                     print("!!!!!!!!!!!!!!!!!",somename,hash[somename],description)
--                 else
--                     hash[somename] = description
--                 end
--         --         print(description,somename)
--             end
--         end
--     end
--
-- end

function moduledata.math.characters.showlist(specification)
    specification     = interfaces.checkedspecification(specification)
    local id          = specification.number -- or specification.id
    local list        = specification.list
    local showvirtual = specification.virtual == "all"
    local method      = specification.method
    if not id then
        id = font.current()
    end
    if list == "" then
        list = nil
    end
    local blocks       = characters.blocks
    local tfmdata      = fontdata[id]
    local characters   = tfmdata.characters
    local descriptions = tfmdata.descriptions
    local resources    = tfmdata.resources
    local lookuptypes  = resources.lookuptypes
    local virtual      = tfmdata.properties.virtualized
    local names        = { }
    local gaps         = mathematics.gaps
    local sorted       = { }
    if type(list) == "string" then
        -- also accept list
        local b = blocks[list]
        if b then
            sorted = { }
            for i=b.first,b.last do
                sorted[#sorted+1] = gaps[i] or i
            end
        else
            sorted = utilities.parsers.settings_to_array(list)
            for i=1,#sorted do
                sorted[i] = tonumber(sorted[i])
            end
        end
    elseif type(list) == "table" then
        sorted = list
        for i=1,#sorted do
            sorted[i] = tonumber(sorted[i])
        end
    elseif fillinthegaps then
        sorted = table.keys(characters)
        for k, v in next, gaps do
            if characters[v] then
                sorted[#sorted+1] = k
            end
        end
        table.sort(sorted)
    else
        sorted = table.sortedkeys(characters)
    end
    if virtual then
        local fonts = tfmdata.fonts
        for i=1,#fonts do
            local id = fonts[i].id
            local name = fontdata[id].properties.name
            names[i] = (name and file.basename(name)) or id
        end
    end
    if check then
        for k, v in sortedhash(blocks) do
            if v.math then
                local first = v.first
                local last  = v.last
                local f, l  = 0, 0
                if first and last then
                    for unicode=first,last do
                        local code = gaps[unicode] or unicode
                        local char = characters[code]
                        if char and not (char.commands and not showvirtual) then
                            f = unicode
                            break
                        end
                    end
                    for unicode=last,first,-1 do
                        local code = gaps[unicode] or unicode
                        local char = characters[code]
                        if char and not (char.commands and not showvirtual) then
                            l = unicode
                            break
                        end
                    end
                    context.showmathcharacterssetrange(k,f,l)
                end
            end
        end
    else

        local function collectalllookups(tfmdata,script,language)
            local all     = setmetatableindex(function(t,k) local v = setmetatableindex("table") t[k] = v return v end)
            local shared  = tfmdata.shared
            local rawdata = shared and shared.rawdata
            if rawdata then
                local features = rawdata.resources.features
                if features.gsub then
                    for kind, feature in next, features.gsub do
                        local validlookups, lookuplist = fonts.handlers.otf.collectlookups(rawdata,kind,script,language)
                        if validlookups then
                            for i=1,#lookuplist do
                                local lookup = lookuplist[i]
                                local steps  = lookup.steps
                                for i=1,lookup.nofsteps do
                                    local coverage = steps[i].coverage
                                    if coverage then
                                        for k, v in next, coverage do
                                            all[k][lookup.type][kind] = v
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            return all
        end

        local alllookups = collectalllookups(tfmdata,"math","dflt")

        local luametatex = LUATEXENGINE == "luametatex"

        -- todo: first create sparser table so no test needed

if method == "manual" then

        context.starttabulate { "|T||||pl|" }
        for _, unicode in next, sorted do
            if not limited or unicode < upperlimit then
                local code = gaps[unicode] or unicode -- move up
                local char = characters[code]
                local desc = descriptions[code]
                local info = chardata[unicode] or chardata[code]
                if char then
                    local mathclass   = info.mathclass
                    local mathspec    = info.mathspec
                    local mathsymbol  = info.mathsymbol
                    local description = lower(info.description or no_description)
                    local names       = { }
                    if mathclass or mathspec then
                        if mathclass then
                            names[info.mathname or ""] = mathclass
                        end
                        if mathspec then
                            for i=1,#mathspec do
                                local mi = mathspec[i]
                                names[mi.name or ""] = mi.class
                            end
                        end
                    end
--                     print(description,fakename(description))
                    if next(names) then
                        local doit = true
                        for k, v in sortedhash(names) do
                            context.NC() if doit then context("%U",unicode) end
                            context.NC() if doit then context.char(unicode) end
                            context.NC() if k ~= "" then context.tex(k) end
                            context.NC() context.ex(v)
                            context.NC() if doit then context(description) end
                            context.NC() context.NR()
                            doit = false
                        end
                    else
                        local mathname = info.mathname
                        context.NC() context("%U",unicode)
                        context.NC() context.char(unicode)
                        context.NC() if mathname then context.tex(mathname) end
                        context.NC() context("ordinary")
                        context.NC() context(lower(description))
                        context.NC() context.NR()
                    end
                end
            end
        end
        context.stoptabulate()

else

        context.showmathcharactersstart()
        for _, unicode in next, sorted do
            if not limited or unicode < upperlimit then
                local code = gaps[unicode] or unicode -- move up
                local char = characters[code]
                local desc = descriptions[code]
                local info = chardata[code]
                if char then
-- context(utf.char(char.smaller))
                    local commands = char.commands
                    if commands and not showvirtual then
                        -- skip
                    else
                        local next_sizes  = char.next
                        local vparts      = char.vparts or char.vert_variants
                        local hparts      = char.hparts or char.horiz_variants
                        local mathclass   = info.mathclass
                        local mathspec    = info.mathspec
                        local mathsymbol  = info.mathsymbol
                        local description = info.description or no_description
                        context.showmathcharactersstartentry(
                        )
                        context.showmathcharactersreference(
                            f_unicode(unicode)
                        )
                        context.showmathcharactersentryhexdectit(
                            f_unicode(code),
                            code,
                            lower(description)
                        )
                        if luametatex then
                            context.showmathcharactersentrywdhtdpicta(
                                code
                            )
                        else
                            context.showmathcharactersentrywdhtdpicta(
                                round(char.width     or 0),
                                round(char.height    or 0),
                                round(char.depth     or 0),
                                round(char.italic    or 0),
                                round(char.topanchor or char.topaccent or 0)
                            )
                        end
                        if virtual and commands then
                            local t = { }
                            for i=1,#commands do
                                local ci = commands[i]
                                if ci[1] == "slot" then
                                    local fnt, idx = ci[2], ci[3]
                                    t[#t+1] = f_slot(names[fnt] or fnt,idx)
                                end
                            end
                            if #t > 0 then
                                context.showmathcharactersentryresource(concat(t,", "))
                            end
                        end
                        if mathclass or mathspec then
                            context.showmathcharactersstartentryclassspec()
                            if mathclass then
                                context.showmathcharactersentryclassname(mathclass,info.mathname or "no name")
                            end
                            if mathspec then
                                for i=1,#mathspec do
                                    local mi = mathspec[i]
                                    context.showmathcharactersentryclassname(mi.class,mi.name or "no name")
                                end
                            end
                            context.showmathcharactersstopentryclassspec()
                        end
                        if mathsymbol then
                            context.showmathcharactersentrysymbol(f_unicode(mathsymbol),mathsymbol)
                        end
                        if next_sizes then
                            local n, done = 0, { }
                            context.showmathcharactersstartnext()
                            while next_sizes do
                                n = n + 1
                                if done[next_sizes] then
                                    context.showmathcharactersnextcycle(n)
                                    break
                                else
                                    done[next_sizes] = true
                                    context.showmathcharactersnextentry(n,f_unicode(next_sizes),next_sizes)
                                    next_sizes = characters[next_sizes]
                                    vparts = next_sizes.vparts or next_sizes.vert_variants  or vparts
                                    hparts = next_sizes.hparts or next_sizes.horiz_variants or hparts
                                    if next_sizes then
                                        next_sizes = next_sizes.next
                                    end
                                end
                            end
                            context.showmathcharactersstopnext()
                            if vparts or hparts then
                                context.showmathcharactersbetweennextandvariants()
                            end
                        end
                        if vparts then
                            context.showmathcharactersstartvparts()
                            for i=1,#vparts do -- we might go top-down in the original
                                local vi = vparts[i]
                                context.showmathcharactersvpartsentry(i,f_unicode(vi.glyph),vi.glyph)
                            end
                            context.showmathcharactersstopvparts()
                        end
                        if hparts then
                            context.showmathcharactersstarthparts()
                            for i=1,#hparts do
                                local hi = hparts[#hparts-i+1]
                                context.showmathcharactershpartsentry(i,f_unicode(hi.glyph),hi.glyph)
                            end
                            context.showmathcharactersstophparts()
                        end
                        local lookups = alllookups[unicode]
                        if lookups then
                            local variants   = { }
                            local singles    = lookups.gsub_single
                            local alternates = lookups.gsub_alternate
                            if singles then
                                for lookupname, code in next, singles do
                                    variants[code] = lookupname
                                end
                            end
                            if singles then
                                for lookupname, codes in next, alternates do
                                    for i=1,#codes do
                                        variants[codes[i]] = lookupname .. " : " .. i
                                    end
                                end
                            end
                            if next(variants) then
                                context.showmathcharactersstartlookupvariants()
                                local i = 0
                                for variant, lookuptype in sortedhash(variants) do
                                    i = i + 1
                                    context.showmathcharacterslookupvariant(i,f_unicode(variant),variant,lookuptype)
                                end
                                context.showmathcharactersstoplookupvariants()
                            end
                        end
                        context.showmathcharactersstopentry()
                    end
                end
            end
        end
        context.showmathcharactersstop()

end

    end
end
