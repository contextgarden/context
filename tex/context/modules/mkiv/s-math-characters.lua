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

function moduledata.math.characters.showlist(specification)
    specification     = interfaces.checkedspecification(specification)
    local id          = specification.number -- or specification.id
    local list        = specification.list
    local showvirtual = specification.virtual == "all"
    local check       = specification.check == "yes"
    if not id then
        id = font.current()
    end
    if list == "" then
        list = nil
    end
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
        sorted = utilities.parsers.settings_to_array(list)
        for i=1,#sorted do
            sorted[i] = tonumber(sorted[i])
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
        for k, v in table.sortedhash(blocks) do
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
        context.showmathcharactersstart()
        for _, unicode in next, sorted do
            if not limited or unicode < upperlimit then
                local code = gaps[unicode] or unicode
                local char = characters[code]
                local desc = descriptions[code]
                local info = chardata[code]
                if char then
                    local commands    = char.commands
                    if commands and not showvirtual then
                        -- skip
                    else
                        local next_sizes  = char.next
                        local v_variants  = char.vert_variants
                        local h_variants  = char.horiz_variants
                        local slookups    = desc and desc.slookups
                        local mlookups    = desc and desc.mlookups
                        local mathclass   = info.mathclass
                        local mathspec    = info.mathspec
                        local mathsymbol  = info.mathsymbol
                        local description = info.description or no_description
                        context.showmathcharactersstartentry()
                        context.showmathcharactersreference(f_unicode(unicode))
                        context.showmathcharactersentryhexdectit(f_unicode(code),code,lower(description))
                        context.showmathcharactersentrywdhtdpic(round(char.width or 0),round(char.height or 0),round(char.depth or 0),round(char.italic or 0))
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
                                    v_variants = next_sizes.vert_variants  or v_variants
                                    h_variants = next_sizes.horiz_variants or h_variants
                                    if next_sizes then
                                        next_sizes = next_sizes.next
                                    end
                                end
                            end
                            context.showmathcharactersstopnext()
                            if h_variants or v_variants then
                                context.showmathcharactersbetweennextandvariants()
                            end
                        end
                        if h_variants then
                            context.showmathcharactersstarthvariants()
                            for i=1,#h_variants do -- we might go top-down in the original
                                local vi = h_variants[i]
                                context.showmathcharactershvariantsentry(i,f_unicode(vi.glyph),vi.glyph)
                            end
                            context.showmathcharactersstophvariants()
                        elseif v_variants then
                            context.showmathcharactersstartvvariants()
                            for i=1,#v_variants do
                                local vi = v_variants[#v_variants-i+1]
                                context.showmathcharactersvvariantsentry(i,f_unicode(vi.glyph),vi.glyph)
                            end
                            context.showmathcharactersstopvvariants()
                        end
                        if slookups or mlookups then
                            local variants = { }
                            if slookups then
                                for lookupname, lookupdata in next, slookups do
                                    local lookuptype = lookuptypes[lookupname]
                                    if lookuptype == "substitution" then
                                        variants[lookupdata] = "sub"
                                    elseif lookuptype == "alternate" then
                                        for i=1,#lookupdata do
                                            variants[lookupdata[i]] = "alt"
                                        end
                                    end
                                end
                            end
                            if mlookups then
                                for lookupname, lookuplist in next, mlookups do
                                    local lookuptype = lookuptypes[lookupname]
                                    for i=1,#lookuplist do
                                        local lookupdata = lookuplist[i]
                                        local lookuptype = lookuptypes[lookupname]
                                        if lookuptype == "substitution" then
                                            variants[lookupdata] = "sub"
                                        elseif lookuptype == "alternate" then
                                            for i=1,#lookupdata do
                                                variants[lookupdata[i]] = "alt"
                                            end
                                        end
                                    end
                                end
                            end
                            context.showmathcharactersstartlookupvariants()
                            local i = 0
                            for variant, lookuptype in table.sortedpairs(variants) do
                                i = i + 1
                                context.showmathcharacterslookupvariant(i,f_unicode(variant),variant,lookuptype)
                            end
                            context.showmathcharactersstoplookupvariants()
                        end
                        context.showmathcharactersstopentry()
                    end
                end
            end
        end
        context.showmathcharactersstop()
    end
end
