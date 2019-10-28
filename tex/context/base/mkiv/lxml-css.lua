if not modules then modules = { } end modules ['lxml-css'] = {
    version   = 1.001,
    comment   = "companion to lxml-css.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber, rawset, type, select = tonumber, rawset, type, select
local lower, format, find, gmatch = string.lower, string.format, string.find, string.gmatch
local topattern, is_empty =  string.topattern, string.is_empty
local P, S, C, R, Cb, Cg, Carg, Ct, Cc, Cf, Cs = lpeg.P, lpeg.S, lpeg.C, lpeg.R, lpeg.Cb, lpeg.Cg, lpeg.Carg, lpeg.Ct, lpeg.Cc, lpeg.Cf, lpeg.Cs
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local sort = table.sort
local setmetatableindex = table.setmetatableindex

xml.css            = xml.css or { }
local css          = xml.css

local getid        = lxml.getid

if not number.dimenfactors then
    require("util-dim.lua")
end

local dimenfactors = number.dimenfactors
local bpf          = 1/dimenfactors.bp
local cmf          = 1/dimenfactors.cm
local mmf          = 1/dimenfactors.mm
local inf          = 1/dimenfactors["in"]

local whitespace   = lpegpatterns.whitespace
local skipspace    = whitespace^0

local percentage, exheight, emwidth, pixels

if tex then

    local exheights = fonts.hashes.exheights
    local emwidths  = fonts.hashes.emwidths
    local texget    = tex.get

    percentage = function(s,pcf) return tonumber(s) * (pcf or texget("hsize"))    end
    exheight   = function(s,exf) return tonumber(s) * (exf or exheights[true])    end
    emwidth    = function(s,emf) return tonumber(s) * (emf or emwidths[true])     end
    pixels     = function(s,pxf) return tonumber(s) * (pxf or emwidths[true]/300) end

else

    local function generic(s,unit) return tonumber(s) * unit end

    percentage = generic
    exheight   = generic
    emwidth    = generic
    pixels     = generic

end

local validdimen = Cg(lpegpatterns.number,'a') * (
        Cb('a') * P("pt") / function(s) return tonumber(s) * bpf end
      + Cb('a') * P("cm") / function(s) return tonumber(s) * cmf end
      + Cb('a') * P("mm") / function(s) return tonumber(s) * mmf end
      + Cb('a') * P("in") / function(s) return tonumber(s) * inf end
      + Cb('a') * P("px") * Carg(1) / pixels
      + Cb('a') * P("%")  * Carg(2) / percentage
      + Cb('a') * P("ex") * Carg(3) / exheight
      + Cb('a') * P("em") * Carg(4) / emwidth
      + Cb('a')           * Carg(1) / pixels
    )

local pattern = (validdimen * skipspace)^1

-- todo: default if ""

local function dimension(str,pixel,percent,exheight,emwidth)
    return (lpegmatch(pattern,str,1,pixel,percent,exheight,emwidth))
end

local function padding(str,pixel,percent,exheight,emwidth)
    local top, bottom, left, right = lpegmatch(pattern,str,1,pixel,percent,exheight,emwidth)
    if not bottom then
        bottom, left, right = top, top, top
    elseif not left then
        bottom, left, right = top, bottom, bottom
    elseif not right then
        bottom, left, right = left, bottom, bottom
    end
    return top, bottom, left, right
end

css.dimension = dimension
css.padding   = padding

-- local hsize    = 655360*100
-- local exheight = 65536*4
-- local emwidth  = 65536*10
-- local pixel    = emwidth/100
--
-- print(padding("10px",pixel,hsize,exheight,emwidth))
-- print(padding("10px 20px",pixel,hsize,exheight,emwidth))
-- print(padding("10px 20px 30px",pixel,hsize,exheight,emwidth))
-- print(padding("10px 20px 30px 40px",pixel,hsize,exheight,emwidth))
--
-- print(padding("10%",pixel,hsize,exheight,emwidth))
-- print(padding("10% 20%",pixel,hsize,exheight,emwidth))
-- print(padding("10% 20% 30%",pixel,hsize,exheight,emwidth))
-- print(padding("10% 20% 30% 40%",pixel,hsize,exheight,emwidth))
--
-- print(padding("10",pixel,hsize,exheight,emwidth))
-- print(padding("10 20",pixel,hsize,exheight,emwidth))
-- print(padding("10 20 30",pixel,hsize,exheight,emwidth))
-- print(padding("10 20 30 40",pixel,hsize,exheight,emwidth))
--
-- print(padding("10pt",pixel,hsize,exheight,emwidth))
-- print(padding("10pt 20pt",pixel,hsize,exheight,emwidth))
-- print(padding("10pt 20pt 30pt",pixel,hsize,exheight,emwidth))
-- print(padding("10pt 20pt 30pt 40pt",pixel,hsize,exheight,emwidth))

-- print(padding("0",pixel,hsize,exheight,emwidth))

local context = context

if context then

    local currentfont = font.current
    local texget      = tex.get
    local hashes      = fonts.hashes
    local quads       = hashes.quads
    local xheights    = hashes.xheights

    local function todimension(str)
        local font     = currentfont()
        local exheight = xheights[font]
        local emwidth  = quads[font]
        local hsize    = texget("hsize")/100
        local pixel    = emwidth/100
        return dimension(str,pixel,hsize,exheight,emwidth)
    end

    css.todimension = todimension

    function context.cssdimension(str)
     -- context("%ssp",todimension(str))
        context(todimension(str) .. "sp")
    end

end


do

    local p_digit    = lpegpatterns.digit
    local p_unquoted = Cs(lpegpatterns.unquoted)
    local p_size     = (S("+-")^0 * (p_digit^0 * P(".") * p_digit^1 + p_digit^1 * P(".") + p_digit^1)) / tonumber
                     * C(P("p") * S("txc") + P("e") * S("xm") + S("mc") * P("m") + P("in") + P("%"))

    local pattern = Cf( Ct("") * (
        Cg(
            Cc("style") * (
                C("italic")
              + C("oblique")
              + C("slanted") / "oblique"
            )
          + Cc("variant") * (
                (C("smallcaps") + C("caps")) / "small-caps"
            )
          + Cc("weight") * (
                C("bold")
            )
          + Cc("family") * (
                (C("mono")      + C("type")) / "monospace"  -- just ignore the "space(d)"
              + (C("sansserif") + C("sans")) / "sans-serif" -- match before serif
              +  C("serif")
            )
          + Cc("size") * Ct(p_size)
        )
      + P(1)
    )^0 , rawset)

    function css.fontspecification(str)
        return str and lpegmatch(pattern,lower(str))
    end

    -- These map onto context!

    function css.style(str)
        if str and str ~= "" then
            str = lower(str)
            if str == "italic" then
                return "italic"
            elseif str == "slanted" or str == "oblique" then
                return "slanted"
            end
        end
        return "normal"
    end

    function css.variant(str) -- will change to a feature
        if str and str ~= "" then
            str = lower(str)
            if str == "small-caps" or str == "caps" or str == "smallcaps" then
                return "caps"
            end
        end
        return "normal"
    end

    function css.weight(str)
        if str and str ~= "" then
            str = lower(str)
            if str == "bold" then
                return "bold"
            end
        end
        return "normal"
    end

    function css.family(str)
        if str and str ~= "" then
            str = lower(str)
            if str == "mono" or str == "type" or str == "monospace" then
                return "mono"
            elseif str == "sansserif" or str == "sans" then
                return "sans"
            elseif str == "serif" then
                return "serif"
            else
                -- what if multiple ...
                return lpegmatch(p_unquoted,str) or str
            end
        end
    end

    function css.size(str,factors)
        local size, unit
        if type(str) == "table" then
            size, unit = str[1], str[2]
        elseif str and str ~= "" then
            size, unit = lpegmatch(p_size,lower(str))
        end
        if size and unit then
            if factors then
                return (factors[unit] or 1) * size
            else
                return size, unit
            end
        end
    end

    function css.colorspecification(str)
        if str and str ~= "" then
            local c = attributes.colors.values[tonumber(str)]
            if c then
                return format("rgb(%s%%,%s%%,%s%%)",c[3]*100,c[4]*100,c[5]*100)
            end
        end
    end

end

-- The following might be handy. It hooks into the normal parser as <selector>
-- and should work ok with the rest. It's sometimes even a bit faster but that might
-- change. It's somewhat optimized but not too aggressively.

-- element-1 > element-2 : element-2 with parent element-1

local function s_element_a(list,collected,c,negate,str,dummy,dummy,n)
    local all = str == "*"
    for l=1,#list do
        local ll = list[l]
        local dt = ll.dt
        if dt then
            local ok = all or ll.tg == str
            if negate then
                ok = not ok
            end
            if ok then
                c = c + 1
                collected[c] = ll
            end
            if (not n or n > 1) and dt then
                c = s_element_a(dt,collected,c,negate,str,dummy,dummy,n and n+1 or 1)
            end
        end
    end
    return c
end

-- element-1 + element-2 : element-2 preceded by element-1

local function s_element_b(list,collected,c,negate,str)
    local all = str == "*"
    for l=1,#list do
        local ll = list[l]
        local pp = ll.__p__
        if pp then
            local dd = pp.dt
            if dd then
                local ni = ll.ni
                local d = dd[ni+1]
                local dt = d and d.dt
                if not dt then
                    d = dd[ni+2]
                    dt = d and d.dt
                end
                if dt then
                    local ok = all or d.tg == str
                    if negate then
                        ok = not ok
                    end
                    if ok then
                        c = c + 1
                        collected[c] = d
                    end
                end
            end
        end
    end
    return c
end

-- element-1 ~ element-2 : element-2 preceded by element-1 -- ?

local function s_element_c(list,collected,c,negate,str)
    local all = str == "*"
    for l=1,#list do
        local ll = list[l]
        local pp = ll.__p__
        if pp then
            local dt = pp.dt
            if dt then
                local ni = ll.ni
                for i=ni+1,#dt do
                    local d = dt[i]
                    local dt = d.dt
                    if dt then
                        local ok = all or d.tg == str
                        if negate then
                            ok = not ok
                        end
                        if ok then
                            c = c + 1
                            collected[c] = d
                        end
                    end
                end
            end
        end
    end
    return c
end

-- element
-- element-1   element-2 : element-2 inside element-1

local function s_element_d(list,collected,c,negate,str)
    if str == "*" then
        if not negate then
            for l=1,#list do
                local ll = list[l]
                local dt = ll.dt
                if dt then
                    if not ll.special then
                        c = c + 1
                        collected[c] = ll
                    end
                    c = s_element_d(dt,collected,c,negate,str)
                end
            end
        end
    else
        for l=1,#list do
            local ll = list[l]
            local dt = ll.dt
            if dt then
                if not ll.special then
                    local ok = ll.tg == str
                    if negate then
                        ok = not ok
                    end
                    if ok then
                        c = c + 1
                        collected[c] = ll
                    end
                end
                c = s_element_d(dt,collected,c,negate,str)
            end
        end
    end
    return c
end

-- [attribute]
-- [attribute=value]     equals
-- [attribute~=value]    contains word
-- [attribute^="value"]  starts with
-- [attribute$="value"]  ends with
-- [attribute*="value"]  contains

-- .class    (no need to optimize)
-- #id       (no need to optimize)

local function s_attribute(list,collected,c,negate,str,what,value)
    for l=1,#list do
        local ll = list[l]
        local dt = ll.dt
        if dt then
            local at = ll.at
            if at then
                local v  = at[str]
                local ok = negate
                if v then
                    if not what then
                        ok = not negate
                    elseif what == 1 then
                        if v == value then
                            ok = not negate
                        end
                    elseif what == 2 then
                        -- todo: lpeg
                        if find(v,value) then -- value can be a pattern
                            ok = not negate
                        end
                    elseif what == 3 then
                        -- todo: lpeg
                        if find(v," ",1,true) then
                            for s in gmatch(v,"[^ ]+") do
                                if s == value then
                                    ok = not negate
                                    break
                                end
                            end
                        elseif v == value then
                            ok = not negate
                        end
                    end
                end
                if ok then
                    c = c + 1
                    collected[c] = ll
                end
            end
            c = s_attribute(dt,collected,c,negate,str,what,value)
        end
    end
    return c
end

-- :nth-child(n)
-- :nth-last-child(n)
-- :first-child
-- :last-child

local function filter_down(collected,c,negate,dt,a,b)
    local t = { }
    local n = 0
    for i=1,#dt do
        local d = dt[i]
        if type(d) == "table" then
            n = n + 1
            t[n] = i
        end
    end
    if n == 0 then
        return 0
    end
    local m = a
    while true do
        if m > n then
            break
        end
        if m > 0 then
            t[m] = -t[m] -- sign signals match
        end
        m = m + b
    end
    if negate then
        for i=n,1-1 do
            local ti = t[i]
            if ti > 0 then
                local di = dt[ti]
                c = c + 1
                collected[c] = di
            end
        end
    else
        for i=n,1,-1 do
            local ti = t[i]
            if ti < 0 then
                ti = - ti
                local di = dt[ti]
                c = c + 1
                collected[c] = di
            end
        end
    end
    return c
end

local function filter_up(collected,c,negate,dt,a,b)
    local t = { }
    local n = 0
    for i=1,#dt do
        local d = dt[i]
        if type(d) == "table" then
            n = n + 1
            t[n] = i
        end
    end
    if n == 0 then
        return 0
    end
    if not b then
        b = 0
    end
    local m = n - a
    while true do
        if m < 1 then
            break
        end
        if m < n then
            t[m] = -t[m] -- sign signals match
        end
        m = m - b
    end
    if negate then
        for i=1,n do
            local ti = t[i]
            if ti > 0 then
                local di = dt[ti]
                c = c + 1
                collected[c] = di
            end
        end
    else
        for i=1,n do
            local ti = t[i]
            if ti < 0 then
                ti = - ti
                local di = dt[ti]
                c = c + 1
                collected[c] = di
            end
        end
    end
    return c
end

local function just(collected,c,negate,dt,a,start,stop,step)
    local m = 0
    for i=start,stop,step do
        local d = dt[i]
        if type(d) == "table" then
            m = m + 1
            if negate then
                if a ~= m then
                    c = c + 1
                    collected[c] = d
                end
            else
                if a == m then
                    c = c + 1
                    collected[c] = d
                    break
                end
            end
        end
    end
    return c
end

local function s_nth_child(list,collected,c,negate,a,n,b)
    if n == "n" then
        for l=1,#list do
            local ll = list[l]
            local dt = ll.dt
            if dt then
                c = filter_up(collected,c,negate,dt,a,b)
            end
        end
    else
        for l=1,#list do
            local ll = list[l]
            local dt = ll.dt
            if dt then
                c = just(collected,c,negate,dt,a,1,#dt,1)
            end
        end
    end
    return c
end

local function s_nth_last_child(list,collected,c,negate,a,n,b)
    if n == "n" then
        for l=1,#list do
            local ll = list[l]
            local dt = ll.dt
            if dt then
                c = filter_down(collected,c,negate,dt,a,b)
            end
        end
    else
        for l=1,#list do
            local ll = list[l]
            local dt = ll.dt
            if dt then
                c = just(collected,c,negate,dt,a,#dt,1,-1)
            end
        end
    end
    return c
end

-- :nth-of-type(n)
-- :nth-last-of-type(n)
-- :first-of-type
-- :last-of-type

local function s_nth_of_type(list,collected,c,negate,a,n,b)
    if n == "n" then
        return filter_up(collected,c,negate,list,a,b)
    else
        return just(collected,c,negate,list,a,1,#list,1)
    end
end

local function s_nth_last_of_type(list,collected,c,negate,a,n,b)
    if n == "n" then
        return filter_down(collected,c,negate,list,a,b)
    else
        return just(collected,c,negate,list,a,#list,1,-1)
    end
end

-- :only-of-type

local function s_only_of_type(list,collected,c,negate)
    if negate then
        for i=1,#list do
            c = c + 1
            collected[c] = list[i]
        end
    else
        if #list == 1 then
            c = c + 1
            collected[c] = list[1]
        end
    end
    return c
end

-- :only-child

local function s_only_child(list,collected,c,negate)
    if negate then
        for l=1,#list do
            local ll = list[l]
            local dt = ll.dt
            if dt then
                for i=1,#dt do
                    local di = dt[i]
                    if type(di) == "table" then
                        c = c + 1
                        collected[c] = di
                    end
                end
            end
        end
    else
        for l=1,#list do
            local ll = list[l]
            local dt = ll.dt
            if dt and #dt == 1 then
                local di = dt[1]
                if type(di) == "table" then
                    c = c + 1
                    collected[c] = di
                end
            end
        end
    end
    return c
end

-- :empty

local function s_empty(list,collected,c,negate)
    for l=1,#list do
        local ll = list[l]
        local dt = ll.dt
        if dt then
            local dn = #dt
            local ok = dn == 0
            if not ok and dn == 1 then
                local d = dt[1]
                if type(d) == "string" and is_empty(d) then
                    ok = true
                end
            end
            if negate then
                ok = not ok
            end
            if ok then
                c = c + 1
                collected[c] = ll
            end
        end
    end
    return c
end

-- :root

local function s_root(list,collected,c,negate)
    for l=1,#list do
        local ll = list[l]
        if type(ll) == "table" then
            local r = xml.root(ll)
            if r then
                if r.special and r.tg == "@rt@" then
                    r = r.dt[r.ri]
                end
                c = c + 1
                collected[c] = r
                break
            end
        end
    end
    return c
end

local P, R, S, C, Cs, Ct, Cc, Carg, lpegmatch = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cc, lpeg.Carg, lpeg.match

local p_number           = lpegpatterns.integer / tonumber

local p_key              = C((R("az","AZ","09") + S("_-"))^1)
local p_left             = S("#.[],:()")
local p_right            = S("#.[],:() ")
local p_tag              = C((1-p_left) * (1-p_right)^0)
local p_value            = C((1-P("]"))^0)
local p_unquoted         = (P('"')/"") * C((1-P('"'))^0) * (P('"')/"")
                         + (1-P("]"))^1
local p_element          =          Ct( (
                               P(">") * skipspace * Cc(s_element_a) +
                               P("+") * skipspace * Cc(s_element_b) +
                               P("~") * skipspace * Cc(s_element_c) +
                                                    Cc(s_element_d)
                           ) * p_tag )
local p_attribute        = P("[") * Ct(Cc(s_attribute) * p_key * (
                               P("=" ) * Cc(1) * Cs(           p_unquoted)
                             + P("^=") * Cc(2) * Cs(Cc("^") * (p_unquoted / topattern))
                             + P("$=") * Cc(2) * Cs(           p_unquoted / topattern * Cc("$"))
                             + P("*=") * Cc(2) * Cs(           p_unquoted / topattern)
                             + P("~=") * Cc(3) * Cs(           p_unquoted)
                           )^0 * P("]"))

local p_separator        = skipspace * P(",") * skipspace

local p_formula          = skipspace * P("(")
                         * skipspace
                         * (
                                p_number * skipspace * (C("n") * skipspace * (p_number + Cc(0)))^-1
                              + P("even") * Cc(0)  * Cc("n") * Cc(2)
                              + P("odd")  * Cc(-1) * Cc("n") * Cc(2)
                           )
                         * skipspace
                         * P(")")

local p_step             = P(".") * Ct(Cc(s_attribute) * Cc("class") * Cc(3) * p_tag)
                         + P("#") * Ct(Cc(s_attribute) * Cc("id")    * Cc(1) * p_tag)
                         + p_attribute
                         + p_element
                         + P(":nth-child")        * Ct(Cc(s_nth_child)        * p_formula)
                         + P(":nth-last-child")   * Ct(Cc(s_nth_last_child)   * p_formula)
                         + P(":first-child")      * Ct(Cc(s_nth_child)        * Cc(1))
                         + P(":last-child")       * Ct(Cc(s_nth_last_child)   * Cc(1))
                         + P(":only-child")       * Ct(Cc(s_only_child)       )
                         + P(":nth-of-type")      * Ct(Cc(s_nth_of_type)      * p_formula)
                         + P(":nth-last-of-type") * Ct(Cc(s_nth_last_of_type) * p_formula)
                         + P(":first-of-type")    * Ct(Cc(s_nth_of_type)      * Cc(1))
                         + P(":last-of-type")     * Ct(Cc(s_nth_last_of_type) * Cc(1))
                         + P(":only-of-type")     * Ct(Cc(s_only_of_type)     )
                         + P(":empty")            * Ct(Cc(s_empty)            )
                         + P(":root")             * Ct(Cc(s_root)             )

local p_not              = P(":not") * Cc(true) * skipspace * P("(") * skipspace * p_step * skipspace * P(")")
local p_yes              =             Cc(false)                     * skipspace * p_step

local p_stepper          = Ct((skipspace * (p_not+p_yes))^1)
local p_steps            = Ct((p_stepper * p_separator^0)^1) * skipspace * (P(-1) + function() print("error") end)

local cache = setmetatableindex(function(t,k)
    local v = lpegmatch(p_steps,k) or false
    t[k] = v
    return v
end)

local function selector(root,s)
 -- local steps = lpegmatch(p_steps,s)
    local steps = cache[s]
    if steps then
        local done         = { }
        local collected    = { }
        local nofcollected = 0
        local nofsteps     = #steps
        for i=1,nofsteps do
            local step = steps[i]
            local n    = #step
            if n > 0 then
                local r = root
                local m = 0
                local c = { }
                for i=1,n,2 do
                    local s = step[i+1] -- function + data
                    m = s[1](r,c,0,step[i],s[2],s[3],s[4])
                    if m == 0 then
                        break
                    else
                        r = c
                        c = { }
                    end
                end
                if m > 0 then
                    if nofsteps > 1 then
                        for i=1,m do
                            local ri = r[i]
                            if done[ri] then
                             -- print("duplicate",i)
                         -- elseif ri.special then
                         --     done[ri] = true
                            else
                                nofcollected = nofcollected + 1
                                collected[nofcollected] = ri
                                done[ri] = true
                            end
                        end
                    else
                        return r
                    end
                end
            end
        end
        if nofcollected > 1 then
         -- local n = 0
         -- local function traverse(e)
         --     if done[e] then
         --         n = n + 1
         --         done[e] = n
         --     end
         --     local dt = e.dt
         --     if dt then
         --         for i=1,#dt do
         --             local e = dt[i]
         --             if type(e) == "table" then
         --                 traverse(e)
         --             end
         --         end
         --     end
         -- end
         -- traverse(root[1])
            --
            local n = 0
            local function traverse(dt)
                for i=1,#dt do
                    local e = dt[i]
                    if done[e] then
                        n = n + 1
                        done[e] = n
                        if n == nofcollected then
                            return
                        end
                    end
                    local d = e.dt
                    if d then
                        traverse(d)
                        if n == nofcollected then
                            return
                        end
                    end
                end
            end
            local r = root[1]
            if done[r] then
                n = n + 1
                done[r] = n
            end
            traverse(r.dt)
            --
            sort(collected,function(a,b) return done[a] < done[b] end)
        end
        return collected
    else
        return { }
    end
end

xml.applyselector= selector

-- local t = [[
-- <?xml version="1.0" ?>
--
-- <a>
--     <b class="one">   </b>
--     <b class="two">   </b>
--     <b class="one">   </b>
--     <b class="three"> </b>
--     <b id="first">    </b>
--     <c>               </c>
--     <d>   d e         </d>
--     <e>   d e         </e>
--     <e>   d e e       </e>
--     <d>   d f         </d>
--     <f foo="bar">     </f>
--     <f bar="foo">     </f>
--     <f bar="foo1">     </f>
--     <f bar="foo2">     </f>
--     <f bar="foo3">     </f>
--     <f bar="foo+4">     </f>
--     <g> </g>
--     <?crap ?>
--     <!-- crap -->
--     <g> <gg> <d> </d> </gg> </g>
--     <g> <gg> <f> </f> </gg> </g>
--     <g> <gg> <f class="one"> g gg f </f> </gg> </g>
--     <g> </g>
--     <g> <gg> <f class="two"> g gg f </f> </gg> </g>
--     <g> <gg> <f class="three"> g gg f </f> </gg> </g>
--     <g> <f class="one"> g f </f> </g>
--     <g> <f class="three"> g f </f> </g>
--     <h whatever="four five six"> </h>
-- </a>
-- ]]
--
-- local s = [[ .one ]]
-- local s = [[ .one, .two ]]
-- local s = [[ .one, .two, #first ]]
-- local s = [[ .one, .two, #first, c, e, [foo], [bar=foo] ]]
-- local s = [[ .one, .two, #first, c, e, [foo], [bar=foo], [bar~=foo] [bar^="foo"] ]]
-- local s = [[ [bar^="foo"] ]]
-- local s = [[ g f .one, g f .three ]]
-- local s = [[ g > f .one, g > f .three ]]
-- local s = [[ * ]]
-- local s = [[ d + e ]]
-- local s = [[ d ~ e ]]
-- local s = [[ d ~ e, g f .one, g f .three ]]
-- local s = [[ :not(d) ]]
-- local s = [[ [whatever~="five"] ]]
-- local s = [[ :not([whatever~="five"]) ]]
-- local s = [[ e ]]
-- local s = [[ :not ( e ) ]]
-- local s = [[ a:nth-child(3) ]]
-- local s = [[ a:nth-child(3n+1) ]]
-- local s = [[ a:nth-child(2n+8) ]]
-- local s = [[ g:nth-of-type(3) ]]
-- local s = [[ a:first-child ]]
-- local s = [[ a:last-child ]]
-- local s = [[ e:first-of-type ]]
-- local s = [[gg d:only-of-type ]]
-- local s = [[ a:nth-child(even) ]]
-- local s = [[ a:nth-child(odd) ]]
-- local s = [[ g:empty ]]
-- local s = [[ g:root ]]

-- local c = css.applyselector(xml.convert(t),s) for i=1,#c do print(xml.tostring(c[i])) end

function css.applyselector(x,str)
    -- the wrapping needs checking so this is a placeholder
    return applyselector({ x },str)
end

-- -- Some helpers to map e.g. style attributes:
--
-- -- string based (2.52):
--
-- local match     = string.match
-- local topattern = string.topattern
--
-- function css.stylevalue(root,name)
--     local list = getid(root).at.style
--     if list then
--         local pattern = topattern(name) .. ":%s*([^;]+)"
--         local value   = match(list,pattern)
--         if value then
--             context(value)
--         end
--     end
-- end
--
-- -- string based, cached (2.28 / 2.17 interfaced):
--
-- local match     = string.match
-- local topattern = string.topattern
--
-- local patterns = table.setmetatableindex(function(t,k)
--     local v = topattern(k) .. ":%s*([^;]+)"
--     t[k] = v
--     return v
-- end)
--
-- function css.stylevalue(root,name)
--     local list = getid(root).at.style
--     if list then
--         local value   = match(list,patterns[name])
--         if value then
--             context(value)
--         end
--     end
-- end
--
-- -- lpeg based (4.26):
--
-- the lpeg variant also removes trailing spaces and accepts spaces before a colon

local ctx_sprint   = context.sprint
local ctx_xmlvalue = context.xmlvalue

local colon        = P(":")
local semicolon    = P(";")
local eos          = P(-1)
local somevalue    = (1 - (skipspace * (semicolon + eos)))^1
local someaction   = skipspace * colon * skipspace * (somevalue/ctx_sprint)

-- function css.stylevalue(root,name)
--     local list = getid(root).at.style
--     if list then
--         lpegmatch(P(name * someaction + 1)^0,list)
--     end
-- end

-- -- cache patterns (2.13):

local patterns = setmetatableindex(function(t,k)
    local v = P(k * someaction + 1)^0
    t[k] = v
    return v
end)

function css.stylevalue(root,name)
    local list = getid(root).at.style -- hard coded style
    if list then
        lpegmatch(patterns[name],list)
    end
end

local somevalue  = (1 - whitespace - semicolon - eos)^1
local someaction = skipspace * colon * (skipspace * Carg(1) * C(somevalue)/function(m,s)
    ctx_xmlvalue(m,s,"") -- use one with two args
end)^1

local patterns= setmetatableindex(function(t,k)
    local v = P(k * someaction + 1)^0
    t[k] = v
    return v
end)

function css.mappedstylevalue(root,map,name)
    local list = getid(root).at.style -- hard coded style
    if list then
        lpegmatch(patterns[name],list,1,map)
    end
end

-- -- faster interface (1.02):

interfaces.implement {
    name      = "xmlstylevalue",
    actions   = css.stylevalue,
    arguments = "2 strings",
}

interfaces.implement {
    name      = "xmlmappedstylevalue",
    actions   = css.mappedstylevalue,
    arguments = "3 strings",
}

-- more (for mm)

local containsws    = string.containsws
local classsplitter = lpeg.tsplitat(whitespace^1)

function xml.functions.classes(e,class) -- cache
    if class then
        local at = e.at
        local data = at[class] or at.class
        if data then
            return lpegmatch(classsplitter,data) or { }
        end
    end
    return { }
end

-- function xml.functions.hasclass(e,class,name)
--     if class then
--         local at = e.at
--         local data = at[class] or at.class
--         if data then
--             return data == name or containsws(data,name)
--         end
--     end
--     return false
-- end
--
-- function xml.expressions.hasclass(attribute,name)
--     if attribute then
--         return attribute == name or containsws(attribute,name)
--     end
--     return false
-- end

function xml.functions.hasclass(e,class,name,more,...)
    if class and name then
        local at = e.at
        local data = at[class] or at.class
        if not data or data == "" then
            return false
        end
        if data == name or data == more then
            return true
        end
        if containsws(data,name) then
            return true
        end
        if not more then
            return false
        end
        if containsws(data,more) then
            return true
        end
        for i=1,select("#",...) do
            if containsws(data,select(i,...)) then
                return true
            end
        end
    end
    return false
end

function xml.expressions.hasclass(data,name,more,...)
    if data then
        if not data or data == "" then
            return false
        end
        if data == name or data == more then
            return true
        end
        if containsws(data,name) then
            return true
        end
        if not more then
            return false
        end
        if containsws(data,more) then
            return true
        end
        for i=1,select("#",...) do
            if containsws(data,select(i,...)) then
                return true
            end
        end
    end
    return false
end
