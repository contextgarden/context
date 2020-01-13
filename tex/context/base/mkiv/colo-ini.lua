if not modules then modules = { } end modules ['colo-ini'] = {
    version   = 1.000,
    comment   = "companion to colo-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, tonumber, tostring = type, tonumber, tostring
local concat, insert, remove = table.concat, table.insert, table.remove
local format, gmatch, gsub, lower, match, find = string.format, string.gmatch, string.gsub, string.lower, string.match, string.find
local P, R, C, Cc = lpeg.P, lpeg.R, lpeg.C, lpeg.Cc
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local formatters = string.formatters

local trace_define = false  trackers.register("colors.define",function(v) trace_define = v end)
local trace_pgf    = false  trackers.register("colors.pgf",   function(v) trace_pgf    = v end)

local report_colors = logs.reporter("colors","defining")
local report_pgf    = logs.reporter("colors","pgf")

local attributes          = attributes
local backends            = backends
local storage             = storage
local context             = context
local commands            = commands

local implement           = interfaces.implement
local getnamespace        = interfaces.getnamespace

local mark                = utilities.storage.mark

local settings_to_hash_strict = utilities.parsers.settings_to_hash_strict

local colors              = attributes.colors
local transparencies      = attributes.transparencies
local colorintents        = attributes.colorintents
local registrations       = backends.registrations

local v_reset             = interfaces.variables.reset

local texsetattribute     = tex.setattribute
local texgetattribute     = tex.getattribute
local texgetcount         = tex.getcount
local texgettoks          = tex.gettoks
local texgetmacro         = tokens.getters.macro

local a_color             = attributes.private('color')
local a_transparency      = attributes.private('transparency')
local a_colormodel        = attributes.private('colormodel')

local register_color      = colors.register
local attributes_list     = attributes.list

local colorvalues         = colors.values
local transparencyvalues  = transparencies.values

colors.sets               = mark(colors.sets or { }) -- sets are mostly used for
local colorsets           = colors.sets        -- showing lists of defined
local colorset            = { }                -- colors
colorsets.default         = colorset
local valid               = mark(colors.valid or { })
colors.valid              = valid
local counts              = mark(colors.counts or { })
colors.counts             = counts

storage.register("attributes/colors/sets",   colorsets, "attributes.colors.sets")
storage.register("attributes/colors/valid",  valid,     "attributes.colors.valid")
storage.register("attributes/colors/counts", counts,    "attributes.colors.counts")

local function currentmodel()
    return texgetattribute(a_colormodel)
end

colors.currentmodel = currentmodel

local function synccolor(name)
    valid[name] = true
end

local function synccolorclone(name,clone)
    valid[name] = clone
end

local function synccolorcount(name,n)
    counts[name] = n
end

local stack = { }

local function pushset(name)
    insert(stack,colorset)
    colorset = colorsets[name]
    if not colorset then
        colorset = { }
        colorsets[name] = colorset
    end
end

local function popset()
    colorset = remove(stack)
end

local function setlist(name)
    return table.sortedkeys(name and name ~= "" and colorsets[name] or colorsets.default or {})
end

colors.pushset = pushset
colors.popset  = popset
colors.setlist = setlist

-- todo: set at the lua end

local ctx_colordefagc = context.colordefagc
local ctx_colordefagt = context.colordefagt
local ctx_colordefalc = context.colordefalc
local ctx_colordefalt = context.colordefalt
local ctx_colordeffgc = context.colordeffgc
local ctx_colordeffgt = context.colordeffgt
local ctx_colordefflc = context.colordefflc
local ctx_colordefflt = context.colordefflt
local ctx_colordefrgc = context.colordefrgc
local ctx_colordefrgt = context.colordefrgt
local ctx_colordefrlc = context.colordefrlc
local ctx_colordefrlt = context.colordefrlt

local function definecolor(name, ca, global)
    if ca and ca > 0 then
        if global then
            if trace_define then
                report_colors("define global color %a with attribute %a",name,ca)
            end
            ctx_colordefagc(name,ca)
        else
            if trace_define then
                report_colors("define local color %a with attribute %a",name,ca)
            end
            ctx_colordefalc(name,ca)
        end
    else
        if global then
            ctx_colordefrgc(name)
        else
            ctx_colordefrlc(name)
        end
    end
    colorset[name] = true-- maybe we can store more
end

local function inheritcolor(name, ca, global)
    if ca and ca ~= "" then
        if global then
            if trace_define then
                report_colors("inherit global color %a with attribute %a",name,ca)
            end
            ctx_colordeffgc(name,ca) -- some day we will set the macro directly
        else
            if trace_define then
                report_colors("inherit local color %a with attribute %a",name,ca)
            end
            ctx_colordefflc(name,ca)
        end
    else
        if global then
            ctx_colordefrgc(name)
        else
            ctx_colordefrlc(name)
        end
    end
    colorset[name] = true-- maybe we can store more
end

local function definetransparent(name, ta, global)
    if ta and ta > 0 then
        if global then
            if trace_define then
                report_colors("define global transparency %a with attribute %a",name,ta)
            end
            ctx_colordefagt(name,ta)
        else
            if trace_define then
                report_colors("define local transparency %a with attribute %a",name,ta)
            end
            ctx_colordefalt(name,ta)
        end
    else
        if global then
            ctx_colordefrgt(name)
        else
            ctx_colordefrlt(name)
        end
    end
end

local function inherittransparent(name, ta, global)
    if ta and ta ~= "" then
        if global then
            if trace_define then
                report_colors("inherit global transparency %a with attribute %a",name,ta)
            end
            ctx_colordeffgt(name,ta)
        else
            if trace_define then
                report_colors("inherit local transparency %a with attribute %a",name,ta)
            end
            ctx_colordefflt(name,ta)
        end
    else
        if global then
            ctx_colordefrgt(name)
        else
            ctx_colordefrlt(name)
        end
    end
end

local transparent = {
    none       =  0,
    normal     =  1,
    multiply   =  2,
    screen     =  3,
    overlay    =  4,
    softlight  =  5,
    hardlight  =  6,
    colordodge =  7,
    colorburn  =  8,
    darken     =  9,
    lighten    = 10,
    difference = 11,
    exclusion  = 12,
    hue        = 13,
    saturation = 14,
    color      = 15,
    luminosity = 16,
}

transparencies.names = transparent

local gray_okay   = true
local rgb_okay    = true
local cmyk_okay   = true
local spot_okay   = true
local multi_okay  = true
local forced      = false

function colors.forcesupport(gray,rgb,cmyk,spot,multi) -- pdfx driven
    gray_okay, rgb_okay, cmyk_okay, spot_okay, multi_okay, forced = gray, rgb, cmyk, spot, multi, true
    report_colors("supported models: gray %a, rgb %a, cmyk %a, spot %a",gray,rgb,cmyk,spot)
end

local function forcedmodel(model) -- delayed till the backend but mp directly
    if not forced then
        return model
    elseif model == 2 then -- gray
        if gray_okay then
            -- okay
        elseif cmyk_okay then
            return 4
        elseif rgb_okay then
            return 3
        end
    elseif model == 3 then -- rgb
        if rgb_okay then
            -- okay
        elseif cmyk_okay then
            return 4
        elseif gray_okay then
            return 2
        end
    elseif model == 4 then -- cmyk
        if cmyk_okay then
            -- okay
        elseif rgb_okay then
            return 3
        elseif gray_okay then
            return 2
        end
    elseif model == 5 then -- spot
        if spot_okay then
            return 5
        elseif cmyk_okay then
            return 4
        elseif rgb_okay then
            return 3
        elseif gray_okay then
            return 2
        end
    end
    return model
end

colors.forcedmodel = forcedmodel

-- By coupling we are downward compatible. When we decouple we need to do more tricky
-- housekeeping (e.g. persist color independent transparencies when color bound ones
-- are nil.)

colors.couple = true

local function definetransparency(name,n,global)
    if n == v_reset then
        definetransparent(name, 0, global) -- or attributes.unsetvalue
        return
    end
    local a = tonumber(n)
    if a then
        transparent[name] = a -- 0 .. 16
        return
    end
    local a = transparent[name]
    if a then
        transparent[name] = a
        return
    end
    local settings = settings_to_hash_strict(n)
    if settings then
        local a = settings.a
        local t = settings.t
        if a and t then
            definetransparent(name, transparencies.register(name,transparent[a] or tonumber(a) or 1,tonumber(t) or 1), global)
        else
            definetransparent(name, 0, global)
        end
    else
        inherittransparent(name, n, global)
    end
end

colors.definetransparency = definetransparency

local registered = { }

local function do_registerspotcolor(parent,parentnumber,e,f,d,p)
    if not registered[parent] then
        local v = colorvalues[parentnumber]
        if v then
            local model = currentmodel()
            if model == 1 then
                model = v[1]
            end
            if e and e ~= "" then
                registrations.spotcolorname(parent,e) -- before registration of the color
            end
            if     model == 2 then -- name noffractions names p's r g b
                registrations.grayspotcolor(parent,f,d,p,v[2])
            elseif model == 3 then
                registrations.rgbspotcolor (parent,f,d,p,v[3],v[4],v[5])
            elseif model == 4 then
                registrations.cmykspotcolor(parent,f,d,p,v[6],v[7],v[8],v[9])
            end
        end
        registered[parent] = true
    end
end

-- local function do_registermultitonecolor(parent,name,parentnumber,e,f,d,p) -- same as spot but different template
--     if not registered[parent] then
--         local v = colorvalues[parentnumber]
--         if v then
--             local model = currentmodel()
--             if model == 1 then
--                 model = v[1]
--             end
--             if     model == 2 then
--                 registrations.grayindexcolor(parent,f,d,p,v[2])
--             elseif model == 3 then
--                 registrations.rgbindexcolor (parent,f,d,p,v[3],v[4],v[5])
--             elseif model == 4 then
--                 registrations.cmykindexcolor(parent,f,d,p,v[6],v[7],v[8],v[9])
--             end
--         end
--         registered[parent] = true
--     end
-- end

function colors.definesimplegray(name,s)
    return register_color(name,'gray',s) -- we still need to get rid of 'color'
end

local hexdigit    = R("09","AF","af")
local hexnumber   = hexdigit * hexdigit / function(s) return tonumber(s,16)/255 end
local hexpattern  = hexnumber * (P(-1) + hexnumber * hexnumber * P(-1))
local hexcolor    = Cc("H") * P("#") * hexpattern

local left        = P("(")
local right       = P(")")
local comma       = P(",")
local mixnumber   = lpegpatterns.number / tonumber
                  + P("-") / function() return -1 end
local mixname     = C(P(1-left-right-comma)^1)
----- mixcolor    = Cc("M") * mixnumber * left * mixname * (comma * mixname)^-1 * right * P(-1)
local mixcolor    = Cc("M") * mixnumber * left * mixname * (comma * mixname)^0 * right * P(-1) -- one is also ok

local exclamation = P("!")
local pgfnumber   = lpegpatterns.digit^0 / function(s) return tonumber(s)/100 end
local pgfname     = C(P(1-exclamation)^1)
local pgfcolor    = Cc("P") * pgfname * exclamation * pgfnumber * (exclamation * pgfname)^-1 * P(-1)

local specialcolor = hexcolor + mixcolor

local l_color        = attributes.list[a_color]
local l_transparency = attributes.list[a_transparency]

directives.register("colors.pgf",function(v)
    if v then
        specialcolor = hexcolor + mixcolor + pgfcolor
    else
        specialcolor = hexcolor + mixcolor
    end
end)

local defineintermediatecolor

local function resolvedname(name)
    local color
    if valid[name] then
        color = counts[name]
        if color then
            color = texgetcount(color)
        else
            color = l_color[name] -- fall back on old method
        end
    else
        color = l_color[name] -- fall back on old method
    end
    return color, l_transparency[name]
end

local function defineprocesscolor(name,str,global,freeze) -- still inconsistent color vs transparent
    local what, one, two, three = lpegmatch(specialcolor,str)
    if what == "H" then
        -- for old times sake (if we need to feed from xml or so)
        definecolor(name, register_color(name,'rgb',one,two,three),global)
    elseif what == "M" then
        -- intermediate
     -- return defineintermediatecolor(name,one,l_color[two],l_color[three],l_transparency[two],l_transparency[three],"",global,freeze)
        local c1, t1 = resolvedname(two)
        local c2, t2 = resolvedname(three)
        return defineintermediatecolor(name,one,c1,c2,t1,t2,"",global,freeze)
    elseif what == "P" then
        -- pgf for tikz
     -- return defineintermediatecolor(name,two,l_color[one],l_color[three],l_transparency[one],l_transparency[three],"",global,freeze)
        local c1, t1 = resolvedname(one)
        local c2, t2 = resolvedname(three)
        return defineintermediatecolor(name,two,c1,c2,t1,t2,"",global,freeze)
    else
        local settings = settings_to_hash_strict(str)
        if settings then
            local r = settings.r
            local g = settings.g
            local b = settings.b
            if r or g or b then
                -- we can consider a combined rgb cmyk s definition
                definecolor(name, register_color(name,'rgb', tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0), global)
            else
                local c = settings.c
                local m = settings.m
                local y = settings.y
                local k = settings.k
                if c or m or y or k then
                    definecolor(name, register_color(name,'cmyk',tonumber(c) or 0, tonumber(m) or 0, tonumber(y) or 0, tonumber(k) or 0), global)
                else
                    local h = settings.h
                    local s = settings.s
                    local v = settings.v
                    if v then
                        r, g, b = colors.hsvtorgb(tonumber(h) or 0, tonumber(s) or 1, tonumber(v) or 1) -- maybe later native
                        definecolor(name, register_color(name,'rgb',r,g,b), global)
                    else
                        local x = settings.x or h
                        if x then
                            r, g, b = lpegmatch(hexpattern,x) -- can be inlined
                            if r and g and b then
                                definecolor(name, register_color(name,'rgb',r,g,b), global)
                            else
                                definecolor(name, register_color(name,'gray',r or 0), global)
                            end
                        else
                            definecolor(name, register_color(name,'gray',tonumber(s) or 0), global)
                        end
                    end
                end
            end
            local a = settings.a
            local t = settings.t
            if a and t then
                definetransparent(name, transparencies.register(name,transparent[a] or tonumber(a) or 1,tonumber(t) or 1), global)
            elseif colors.couple then
            --  definetransparent(name, transparencies.register(nil, 1, 1), global) -- can be sped up
                definetransparent(name, 0, global) -- can be sped up
            end
        elseif freeze then
            local ca = attributes_list[a_color]       [str]
            local ta = attributes_list[a_transparency][str]
            if ca then
                definecolor(name, ca, global)
            end
            if ta then
                definetransparent(name, ta, global)
            end
        else
            inheritcolor(name, str, global)
            inherittransparent(name, str, global)
        --  if global and str ~= "" then -- For Peter Rolf who wants access to the numbers in Lua. (Currently only global is supported.)
        --      attributes_list[a_color]       [name] = attributes_list[a_color]       [str] or attributes.unsetvalue  -- reset
        --      attributes_list[a_transparency][name] = attributes_list[a_transparency][str] or attributes.unsetvalue
        --  end
        end
    end
    colorset[name] = true-- maybe we can store more
end

-- You cannot overload a local color so one then has to use some prefix, like
-- mp:red. Kind of protection.

local function defineprocesscolordirect(settings)
    if settings then
        local name = settings.name
        if name then
            local r = settings.r
            local g = settings.g
            local b = settings.b
            if r or g or b then
                -- we can consider a combined rgb cmyk s definition
                register_color(name,'rgb', r or 0, g or 0, b or 0)
            else
                local c = settings.c
                local m = settings.m
                local y = settings.y
                local k = settings.k
                if c or m or y or k then
                    register_color(name,'cmyk',c or 0, m or 0, y or 0, k or 0)
                else
                    local h = settings.h
                    local s = settings.s
                    local v = settings.v
                    if v then
                        r, g, b = colors.hsvtorgb(h or 0, s or 1, v or 1) -- maybe later native
                        register_color(name,'rgb',r,g,b)
                    else
                        local x = settings.x or h
                        if x then
                            r, g, b = lpegmatch(hexpattern,x) -- can be inlined
                            if r and g and b then
                                register_color(name,'rgb',r,g,b)
                            else
                                register_color(name,'gray',r or 0)
                            end
                        else
                            register_color(name,'gray',s or 0)
                        end
                    end
                end
            end
            local a = settings.a
            local t = settings.t
            if a and t then
                transparencies.register(name,transparent[a] or a or 1,t or 1)
            end
            colorset[name] = true-- maybe we can store more
            valid[name] = true
        end
    end
end

local function isblack(ca) -- maybe commands
    local cv = ca > 0 and colorvalues[ca]
    return (cv and cv[2] == 0) or false
end

colors.isblack = isblack

-- local m, c, t = attributes.colors.namedcolorattributes(parent)
-- if c and c > 1 then -- 1 is black
-- local v = attributes.colors.values[c]

local function definespotcolor(name,parent,str,global)
    if parent == "" or find(parent,"=",1,true) then
        colors.registerspotcolor(name, parent) -- does that work? no attr
    elseif name ~= parent then
        local cp = attributes_list[a_color][parent]
        if cp then
            local t = settings_to_hash_strict(str)
            if t then
                local tp = tonumber(t.p) or 1
                do_registerspotcolor(parent,cp,t.e,1,"",tp) -- p not really needed, only diagnostics
                if name and name ~= "" then
                    definecolor(name,register_color(name,'spot',parent,1,"",tp),true)
                    local ta = t.a
                    local tt = t.t
                    if ta and tt then
                        definetransparent(name, transparencies.register(name,transparent[ta] or tonumber(ta) or 1,tonumber(tt) or 1), global)
                    elseif colors.couple then
                     -- definetransparent(name, transparencies.register(nil, 1, 1), global) -- can be sped up
                        definetransparent(name, 0, global) -- can be sped up
                    end
                end
            end
        end
    end
    colorset[name] = true-- maybe we can store more
end

function colors.registerspotcolor(parent, str)
    local cp = attributes_list[a_color][parent]
    if cp then
        local e = ""
        if str then
            local t = settings_to_hash_strict(str)
            e = (t and t.e) or ""
        end
        do_registerspotcolor(parent, cp, e, 1, "", 1) -- p not really needed, only diagnostics
    end
end

local function f(i,colors,fraction)
    local otf = 0
    if type(fraction) == "table" then
        for c=1,#colors do
            otf = otf + (tonumber(fraction[c]) or 1) * colors[c][i]
        end
    else
        fraction = tonumber(fraction)
        for c=1,#colors do
            otf = otf + fraction * colors[c]
        end
    end
    if otf > 1 then
        otf = 1
    end
    return otf
end

local function definemixcolor(makecolor,name,fractions,cs,global,freeze)
    local values = { }
    for i=1,#cs do -- do fraction in here
        local v = colorvalues[cs[i]]
        if not v then
            return
        end
        values[i] = v
    end
    if #values > 0 then
        csone = values[1][1]
        local ca
        if csone == 2 then
            ca = register_color(name,'gray',f(2,values,fractions))
        elseif csone == 3 then
            ca = register_color(name,'rgb', f(3,values,fractions),
                                            f(4,values,fractions),
                                            f(5,values,fractions))
        elseif csone == 4 then
            ca = register_color(name,'cmyk',f(6,values,fractions),
                                            f(7,values,fractions),
                                            f(8,values,fractions),
                                            f(9,values,fractions))
        else
            ca = register_color(name,'gray',f(2,values,fractions))
        end
        definecolor(name,ca,global,freeze)
    else
        report_colors("invalid specification of components for color %a",makecolor)
    end
end

local function definemultitonecolor(name,multispec,colorspec,selfspec)
    local dd  = { }
    local pp  = { }
    local nn  = { }
    local max = 0
    for k,v in gmatch(multispec,"([^=,]+)=([^%,]*)") do -- use settings_to_array
        max = max + 1
        dd[max] = k
        pp[max] = v
        nn[max] = formatters["%s_%1.3g"](k,tonumber(v) or 0) -- 0 can't happen
    end
    if max > 0 then
        nn = concat(nn,'_')
        local parent = gsub(lower(nn),"[^%d%a%.]+","_")
        if not colorspec or colorspec == "" then
            -- this can happens when we come from metapost
            local cc = { }
            for i=1,max do
                cc[i] = resolvedname(dd[i])
            end
            definemixcolor(name,parent,pp,cc,true,true)
        else
            if selfspec ~= "" then
                colorspec = colorspec .. "," .. selfspec
            end
            defineprocesscolor(parent,colorspec,true,true)
        end
        local cp = attributes_list[a_color][parent]
        dd, pp = concat(dd,','), concat(pp,',')
        if cp then
            do_registerspotcolor(parent, cp, "", max, dd, pp)
            definecolor(name, register_color(name, 'spot', parent, max, dd, pp), true)
            local t = settings_to_hash_strict(selfspec)
            if t and t.a and t.t then
                definetransparent(name, transparencies.register(name,transparent[t.a] or tonumber(t.a) or 1,tonumber(t.t) or 1), global)
            elseif colors.couple then
            --  definetransparent(name, transparencies.register(nil, 1, 1), global) -- can be sped up
                definetransparent(name, 0, global) -- can be sped up
            end
        end
    end
    colorset[name] = true-- maybe we can store more
end

colors.defineprocesscolor   = defineprocesscolor
colors.definespotcolor      = definespotcolor
colors.definemultitonecolor = definemultitonecolor

colors.defineprocesscolordirect = defineprocesscolordirect -- test for mp

-- will move to mlib-col as colors in mp are somewhat messy due to the fact
-- that we cannot cast .. so we really need to use (s,s,s) for gray in order
-- to be able to map onto 'color'

local function mpcolor(model,ca,ta,default,name)
    local cv = colorvalues[ca]
    if cv then
        local tv = transparencyvalues[ta]
        -- maybe move the 5 logic into the forcedmodel call
        local cm = cv[1]
        if model == 1 then
            model = cm
        end
        model = forcedmodel(model)
        if cm == 5 and model == 4 then
            model = 5 -- a cheat but ok as spot colors have a representation
        end
        if tv then
            if model == 2 then
                return formatters["transparent(%s,%s,(%s,%s,%s))"](tv[1],tv[2],cv[3],cv[4],cv[5])
            elseif model == 3 then
                return formatters["transparent(%s,%s,(%s,%s,%s))"](tv[1],tv[2],cv[3],cv[4],cv[5])
            elseif model == 4 then
                return formatters["transparent(%s,%s,(%s,%s,%s,%s))"](tv[1],tv[2],cv[6],cv[7],cv[8],cv[9])
            elseif model == 5 then
             -- return formatters['transparent(%s,%s,multitonecolor("%s",%s,"%s","%s"))'](tv[1],tv[2],cv[10],cv[11],cv[12],cv[13])
                return formatters['transparent(%s,%s,namedcolor("%s"))'](tv[1],tv[2],name or cv[10])
            else -- see ** in meta-ini.mkiv: return formatters["transparent(%s,%s,(%s))"](tv[1],tv[2],cv[2])
                return formatters["transparent(%s,%s,(%s,%s,%s))"](tv[1],tv[2],cv[3],cv[4],cv[5])
            end
        else
            if model == 2 then
                return formatters["(%s,%s,%s)"](cv[3],cv[4],cv[5])
            elseif model == 3 then
                return formatters["(%s,%s,%s)"](cv[3],cv[4],cv[5])
            elseif model == 4 then
                return formatters["(%s,%s,%s,%s)"](cv[6],cv[7],cv[8],cv[9])
            elseif model == 5 then
                return formatters['namedcolor("%s")'](name or cv[10])
            else -- see ** in meta-ini.mkiv: return formatters["%s"]((cv[2]))
                return formatters["(%s,%s,%s)"](cv[3],cv[4],cv[5])
            end
        end
    end
    local tv = transparencyvalues[ta]
    if tv then
        return formatters["(%s,%s)"](tv[1],tv[2])
    end
    default = default or 0 -- rgb !
    return formatters["(%s,%s,%s)"](default,default,default)
end

-- local function mpnamedcolor(name)
--     return mpcolor(texgetattribute(a_colormodel),l_color[name] or l_color.black,l_transparency[name] or false)
-- end

local colornamespace  = getnamespace("colornumber")
local paletnamespace  = getnamespace("colorpalet")

local function namedcolorattributes(name)
    local space  = texgetattribute(a_colormodel)
    ----- prefix = texgettoks("t_colo_prefix")
    local prefix = texgetmacro("currentcolorprefix")
    local color
    if prefix ~= "" then
        color = valid[prefix..name]
        if not color then
            local n = paletnamespace .. prefix .. name
            color = valid[n]
            if not color then
                color = name
            elseif color == true then
                color = n
            end
        elseif color == true then
            color = paletnamespace .. prefix .. name
        end
    else
        color = valid[name]
        if not color then
            return space, l_color.black
        elseif color == true then
            color = name
        end
    end
    color = counts[color]
    if color then
        color = texgetcount(color)
    else
        color = l_color[name] -- fall back on old method
    end
    if color then
        return space, color, l_transparency[name]
    else
        return space, l_color.black
    end
end

colors.namedcolorattributes = namedcolorattributes -- can be used local

local function mpnamedcolor(name)
    local model, ca, ta = namedcolorattributes(name)
    return mpcolor(model,ca,ta,nil,name)
end

local function mpoptions(model,ca,ta,default) -- will move to mlib-col .. not really needed
    return formatters["withcolor %s"](mpcolor(model,ca,ta,default))
end

colors.mpcolor      = mpcolor
colors.mpnamedcolor = mpnamedcolor
colors.mpoptions    = mpoptions

-- elsewhere:
--
-- mp.NamedColor = function(str)
--     mpprint(mpnamedcolor(str))
-- end

-- local function formatcolor(ca,separator)
--     local cv = colorvalues[ca]
--     if cv then
--         local c, cn, f, t, model = { }, 0, 13, 13, cv[1]
--         if model == 2 then
--             return c[2]
--         elseif model == 3 then
--             return concat(c,separator,3,5)
--         elseif model == 4 then
--             return concat(c,separator,6,9)
--         end
--     else
--         return 0
--     end
-- end

local function formatcolor(ca,separator)
    local cv = colorvalues[ca]
    if cv then
        local c, cn, f, t, model = { }, 0, 13, 13, cv[1]
        if model == 2 then
            f, t = 2, 2
        elseif model == 3 then
            f, t = 3, 5
        elseif model == 4 then
            f, t = 6, 9
        end
        for i=f,t do
            cn = cn + 1
            c[cn] = format("%0.3f",cv[i])
        end
        return concat(c,separator)
    else
        return format("%0.3f",0)
    end
end

local function formatgray(ca,separator)
    local cv = colorvalues[ca]
    return format("%0.3f",(cv and cv[2]) or 0)
end

colors.formatcolor = formatcolor
colors.formatgray  = formatgray

local f_gray         = formatters["s=%1.3f"]
local f_rgb          = formatters["r=%1.3f%sg=%1.3f%sb=%1.3f"]
local f_cmyk         = formatters["c=%1.3f%sm=%1.3f%sy=%1.3f%sk=%1.3f"]
local f_spot_name    = formatters["p=%s"]
local f_spot_value   = formatters["p=%1.3f"]
local f_transparency = formatters["a=%1.3f%st=%1.3f"]
local f_both         = formatters["%s%s%s"]

local function colorcomponents(ca,separator) -- return list
    local cv = colorvalues[ca]
    if cv then
        local model = cv[1]
        if model == 2 then
            return f_gray(cv[2])
        elseif model == 3 then
            return f_rgb(cv[3],separator or " ",cv[4],separator or " ",cv[5])
        elseif model == 4 then
            return f_cmyk(cv[6],separator or " ",cv[7],separator or " ",cv[8],separator or " ",cv[9])
        elseif type(cv[13]) == "string" then
            return f_spot_name(cv[13])
        else
            return f_spot_value(cv[13])
        end
    else
        return ""
    end
end

local function transparencycomponents(ta,separator)
    local tv = transparencyvalues[ta]
    if tv then
        return f_transparency(tv[1],separator or " ",tv[2])
    else
        return ""
    end
end

local function processcolorcomponents(ca,separator)
    local cs = colorcomponents(ca,separator)
    local ts = transparencycomponents(ca,separator)
    if cs == "" then
        return ts
    elseif ts == "" then
        return cs
    else
        return f_both(cs,separator or " ",ts)
    end
end

local function spotcolorname(ca,default)
    local cv, v = colorvalues[ca], "unknown"
    if not cv and type(ca) == "string" then
        ca = resolvedname(ca) -- we could metatable colorvalues
        cv = colorvalues[ca]
    end
    if cv and cv[1] == 5 then
        v = cv[10]
    end
    return tostring(v)
end

local function spotcolorparent(ca,default)
    local cv, v = colorvalues[ca], "unknown"
    if not cv and type(ca) == "string" then
        ca = resolvedname(ca) -- we could metatable colorvalues
        cv = colorvalues[ca]
    end
    if cv and cv[1] == 5 then
        v = cv[12]
        if v == "" then
            v = cv[10]
        end
    end
    return tostring(v)
end

local function spotcolorvalue(ca,default)
    local cv, v = colorvalues[ca], 0
    if not cv and type(ca) == "string" then
        ca = resolvedname(ca) -- we could metatable colorvalues
        cv = colorvalues[ca]
    end
    if cv and cv[1] == 5 then
       v = cv[13]
    end
    return tostring(v)
end

colors.colorcomponents        = colorcomponents
colors.transparencycomponents = transparencycomponents
colors.processcolorcomponents = processcolorcomponents
colors.spotcolorname          = spotcolorname
colors.spotcolorparent        = spotcolorparent
colors.spotcolorvalue         = spotcolorvalue

-- experiment  (a bit of a hack, as we need to get the attribute number)

local min = math.min

-- a[b,c] -> b+a*(c-b)

local function inbetween(one,two,i,fraction)
    local o, t = one[i], two[i]
    local c = fraction < 0
    if c then
        fraction = - fraction
    end
    local otf = o + fraction * (t - o)
    if otf > 1 then
        otf = 1
    end
    if c then
        return 1 - otf
    else
        return otf
    end
end

local function justone(one,fraction,i)
    local otf = fraction * one[i]
    if otf > 1 then
        otf = 1
    end
    return otf
end

local function complement(one,fraction,i)
    local otf = - fraction * (1 - one[i])
    if otf > 1 then
        otf = 1
    end
    return otf
end

colors.helpers = {
    inbetween  = inbetween,
    justone    = justone,
    complement = complement,
}

defineintermediatecolor = function(name,fraction,c_one,c_two,a_one,a_two,specs,global,freeze)
    fraction = tonumber(fraction) or 1
    local one, two = colorvalues[c_one], colorvalues[c_two] -- beware, it uses the globals
    if one then
        if two then
            local csone, cstwo = one[1], two[1]
         -- if csone == cstwo then
                -- actually we can set all 8 values at once here but this is cleaner as we avoid
                -- problems with weighted gray conversions and work with original values
                local ca
                if csone == 2 then
                    ca = register_color(name,'gray',inbetween(one,two,2,fraction))
                elseif csone == 3 then
                    ca = register_color(name,'rgb', inbetween(one,two,3,fraction),
                                                    inbetween(one,two,4,fraction),
                                                    inbetween(one,two,5,fraction))
                elseif csone == 4 then
                    ca = register_color(name,'cmyk',inbetween(one,two,6,fraction),
                                                    inbetween(one,two,7,fraction),
                                                    inbetween(one,two,8,fraction),
                                                    inbetween(one,two,9,fraction))
                else
                    ca = register_color(name,'gray',inbetween(one,two,2,fraction))
                end
                definecolor(name,ca,global,freeze)
         -- end
        else
            local inbetween = fraction < 0 and complement or justone
            local csone = one[1]
            local ca
            if csone == 2 then
                ca = register_color(name,'gray',inbetween(one,fraction,2))
            elseif csone == 3 then
                ca = register_color(name,'rgb', inbetween(one,fraction,3),
                                                inbetween(one,fraction,4),
                                                inbetween(one,fraction,5))
            elseif csone == 4 then
                ca = register_color(name,'cmyk',inbetween(one,fraction,6),
                                                inbetween(one,fraction,7),
                                                inbetween(one,fraction,8),
                                                inbetween(one,fraction,9))
            else
                ca = register_color(name,'gray',inbetween(one,fraction,2))
            end
            definecolor(name,ca,global,freeze)
        end
    end
    local one, two = transparencyvalues[a_one], transparencyvalues[a_two]
    local t = settings_to_hash_strict(specs)
    local ta = tonumber((t and t.a) or (one and one[1]) or (two and two[1]))
    local tt = tonumber((t and t.t) or (one and two and f(one,two,2,fraction)))
    if ta and tt then
        definetransparent(name,transparencies.register(name,ta,tt),global)
    end
end

colors.defineintermediatecolor = defineintermediatecolor

-- for the moment downward compatible

local patterns = {
    CONTEXTLMTXMODE > 0 and "colo-imp-%s.mkxl" or "",
    "colo-imp-%s.mkiv",
    "colo-imp-%s.tex",
    -- obsolete:
    "colo-%s.mkiv",
    "colo-%s.tex"
}

local function action(name,foundname)
    context.loadfoundcolorsetfile(name,foundname)
end

local function failure(name)
 -- context.showmessage("colors",5,name)
    report_colors("unknown library %a",name)
end

local function usecolors(name)
    resolvers.uselibrary {
        category = "color definition",
        name     = name,
        patterns = patterns,
        action   = action,
        failure  = failure,
        onlyonce = true,
    }
end

colors.usecolors = usecolors

-- backend magic

local currentpagecolormodel

function colors.setpagecolormodel(model)
    currentpagecolormodel = model
end

function colors.getpagecolormodel()
    return currentpagecolormodel
end

-- interface

local setcolormodel = colors.setmodel

implement {
    name      = "synccolorcount",
    actions   = synccolorcount,
    arguments = { "string", "integer" }
}

implement {
    name      = "synccolor",
    actions   = synccolor,
    arguments = "string",
}

implement {
    name      = "synccolorclone",
    actions   = synccolorclone,
    arguments = "2 strings",
}

implement {
    name      = "setcolormodel",
    arguments = "2 strings",
    actions   = function(model,weight)
        texsetattribute(a_colormodel,setcolormodel(model,weight))
    end
}

implement {
    name      = "setpagecolormodel",
    actions   = colors.setpagecolormodel,
    arguments = "string",
}

implement {
    name      = "defineprocesscolorlocal",
    actions   = defineprocesscolor,
    arguments = { "string", "string", false, "boolean" }
}

implement {
    name      = "defineprocesscolorglobal",
    actions   = defineprocesscolor,
    arguments = { "string", "string", true, "boolean" }
}

implement {
    name      = "defineprocesscolordummy",
    actions   = defineprocesscolor,
    arguments = { "'c_o_l_o_r'", "string", false, false }
}

implement {
    name      = "definespotcolorglobal",
    actions   = definespotcolor,
    arguments = { "string", "string", "string", true }
}

implement {
    name      = "definemultitonecolorglobal",
    actions   = definemultitonecolor,
    arguments = { "string", "string", "string", "string", true }
}

implement {
    name      = "registermaintextcolor",
    actions   = function(main)
        colors.main = main
    end,
    arguments = "integer"
}

implement {
    name      = "definetransparency",
    actions   = definetransparency,
    arguments = "2 strings"
}

implement {
    name      = "definetransparencyglobal",
    actions   = definetransparency,
    arguments = { "string", "string", true }
}

implement {
    name      = "defineintermediatecolor",
    actions   = defineintermediatecolor,
    arguments = { "string", "string", "integer", "integer", "integer", "integer", "string", false, "boolean" }
}

implement { name = "spotcolorname",          actions = { spotcolorname,          context }, arguments = "integer" }
implement { name = "spotcolorparent",        actions = { spotcolorparent,        context }, arguments = "integer" }
implement { name = "spotcolorvalue",         actions = { spotcolorvalue,         context }, arguments = "integer" }
implement { name = "colorcomponents",        actions = { colorcomponents,        context }, arguments = { "integer", tokens.constant(",") } }
implement { name = "transparencycomponents", actions = { transparencycomponents, context }, arguments = { "integer", tokens.constant(",") } }
implement { name = "processcolorcomponents", actions = { processcolorcomponents, context }, arguments = { "integer", tokens.constant(",") } }
implement { name = "formatcolor",            actions = { formatcolor,            context }, arguments = { "integer", "string" } }
implement { name = "formatgray",             actions = { formatgray,             context }, arguments = { "integer", "string" } }

implement {
    name      = "mpcolor",
    actions   = { mpcolor, context },
    arguments = { "integer", "integer", "integer" }
}

implement {
    name      = "mpoptions",
    actions   = { mpoptions, context },
    arguments = { "integer", "integer", "integer" }
}

local ctx_doifelse = commands.doifelse

implement {
    name      = "doifelsedrawingblack",
    actions   = function() ctx_doifelse(isblack(texgetattribute(a_color))) end
}

implement {
    name      = "doifelseblack",
    actions   = { isblack, ctx_doifelse },
    arguments = "integer"
}

-- function commands.withcolorsinset(name,command)
--     local set
--     if name and name ~= "" then
--         set = colorsets[name]
--     else
--         set = colorsets.default
--     end
--     if set then
--         if command then
--             for name in table.sortedhash(set) do
--                 context[command](name)
--             end
--         else
--             context(concat(table.sortedkeys(set),","))
--         end
--     end
-- end

implement { name = "startcolorset", actions = pushset,   arguments = "string" }
implement { name = "stopcolorset",  actions = popset }
implement { name = "usecolors",     actions = usecolors, arguments = "string" }

-- bonus

do

    local function pgfxcolorspec(model,ca) -- {}{}{colorspace}{list}
     -- local cv = attributes.colors.values[ca]
        local cv = colorvalues[ca]
        local str
        if cv then
            if model and model ~= 0 then
                model = model
            else
                model = forcedmodel(texgetattribute(a_colormodel))
                if model == 1 then
                    model = cv[1]
                end
            end
            if model == 3 then
                str = formatters["{rgb}{%1.3f,%1.3f,%1.3f}"](cv[3],cv[4],cv[5])
            elseif model == 4 then
                str = formatters["{cmyk}{%1.3f,%1.3f,%1.3f,%1.3f}"](cv[6],cv[7],cv[8],cv[9])
            else -- there is no real gray
                str = formatters["{rgb}{%1.3f,%1.3f,%1.3f}"](cv[2],cv[2],cv[2])
            end
        else
            str = "{rgb}{0,0,0}"
        end
        if trace_pgf then
            report_pgf("model %a, string %a",model,str)
        end
        return str
    end

    implement {
        name      = "pgfxcolorspec",
        actions   = { pgfxcolorspec, context },
        arguments = { "integer", "integer" }
    }

end

-- handy

local models = storage.allocate { "all", "gray", "rgb", "cmyk", "spot" }

colors.models = models -- check for usage elsewhere

function colors.spec(name)
    local l = attributes_list[a_color]
    local t = colorvalues[l[name]] or colorvalues[l.black]
    return {
        model = models[t[1]] or models[1],
        s = t[2],
        r = t[3], g = t[4], b = t[5],
        c = t[6], m = t[7], y = t[8], k = t[9],
    }
end

function colors.currentnamedmodel()
    return models[texgetattribute(a_colormodel)] or "gray"
end

-- inspect(attributes.colors.spec("red"))
-- inspect(attributes.colors.spec("red socks"))

implement {
    name      = "negatedcolorcomponent",
    arguments = "string",
    actions   = function(s)
        s = 1 - (tonumber(s) or 0)
        context((s < 0 and 0) or (s > 1 and 1) or s)
    end
}
