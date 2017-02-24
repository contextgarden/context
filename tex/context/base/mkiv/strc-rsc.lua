if not modules then modules = { } end modules ['strc-rsc'] = {
    version   = 1.001,
    comment   = "companion to strc-ref.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The scanner is in a separate module so that we can test without too
-- many dependencies.

-- The scanner accepts nested outer, but we don't care too much, maybe
-- some day we will have both but currently the innermost wins.

local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local lpegP, lpegS, lpegCs, lpegCt, lpegCf, lpegCc, lpegC, lpegCg = lpeg.P, lpeg.S, lpeg.Cs, lpeg.Ct, lpeg.Cf, lpeg.Cc, lpeg.C, lpeg.Cg
local find = string.find

local spaces     = lpegP(" ")^0
local lparent    = lpegP("(")
local rparent    = lpegP(")")
local lbrace     = lpegP("{")
local rbrace     = lpegP("}")
local tcolon     = lpegP(":::") -- component or outer
local dcolon     = lpegP("::")  -- outer
local scolon     = lpegP(":")   -- prefix
local backslash  = lpegP("\\")

      lparent    = spaces * lparent * spaces
      rparent    = spaces * rparent * spaces
      lbrace     = spaces * lbrace  * spaces
      rbrace     = spaces * rbrace  * spaces
      tcolon     = spaces * tcolon  * spaces
      dcolon     = spaces * dcolon  * spaces

local endofall   = spaces * lpegP(-1)

----- o_token    = 1 - rparent - rbrace - lparent - lbrace  -- can be made more efficient
----- a_token    = 1 - rbrace
local s_token    = 1 - lparent - lbrace
local i_token    = 1 - lparent - lbrace - endofall
local f_token    = 1 - lparent - lbrace - dcolon
local c_token    = 1 - lparent - lbrace - tcolon

-- experimental

local o_token    = lpegpatterns.nestedparents
                 + (1 - rparent - lbrace)
local a_token    = lpegpatterns.nestedbraces
                 + (1 - rbrace)
local q_token    = lpegpatterns.unsingle
                 + lpegpatterns.undouble

local hastexcode = lpegCg(lpegCc("has_tex")   * lpegCc(true)) -- cannot be made to work
local component  = lpegCg(lpegCc("component") * lpegCs(c_token^1))
local outer      = lpegCg(lpegCc("outer")     * lpegCs(f_token^1))
----- operation  = lpegCg(lpegCc("operation") * lpegCs(o_token^1))
local operation  = lpegCg(lpegCc("operation") * lpegCs(q_token + o_token^1))
local arguments  = lpegCg(lpegCc("arguments") * lpegCs(q_token + a_token^0))
local special    = lpegCg(lpegCc("special")   * lpegCs(s_token^1))
local inner      = lpegCg(lpegCc("inner")     * lpegCs(i_token^1))

      arguments  = (lbrace * arguments * rbrace)^-1
      component  = component * tcolon
      outer      = outer * dcolon
      operation  = outer^-1 * operation -- special case: page(file::1) and file::page(1)
      inner      = inner * arguments
      special    = special * lparent * (operation * arguments)^-1 * rparent

local referencesplitter = spaces
                        * lpegCf (lpegCt("") * (component + outer)^-1 * (special + inner)^-1 * endofall, rawset)

local prefixsplitter    = lpegCs(lpegP((1-scolon)^1 * scolon))
                        * #-scolon
                        * lpegCs(lpegP(1)^1)

local componentsplitter = lpegCs(lpegP((1-scolon)^1))
                        * scolon * #-scolon
                        * lpegCs(lpegP(1)^1)

prefixsplitter = componentsplitter

local function splitreference(str)
    if str and str ~= "" then
        local t = lpegmatch(referencesplitter,str)
        if t then
            local a = t.arguments
            if a and find(a,"\\",1,true) then
                t.has_tex = true
            else
                local o = t.arguments
                if o and find(o,"\\",1,true) then
                    t.has_tex = true
                end
            end
            return t
        end
    end
end

local function splitprefix(str)
    return lpegmatch(prefixsplitter,str)
end

local function splitcomponent(str)
    return lpegmatch(componentsplitter,str)
end

-- register in the right namespace

structures                   = structures or { }
structures.references        = structures.references or { }
local references             = structures.references

references.referencesplitter = referencesplitter
references.splitreference    = splitreference
references.prefixsplitter    = prefixsplitter
references.splitprefix       = splitprefix
references.componentsplitter = componentsplitter
references.splitcomponent    = splitcomponent

-- test code:

-- inspect(splitreference([[component:::inner]]))
-- inspect(splitprefix([[component:::inner]]))
-- inspect(splitprefix([[component:inner]]))

-- inspect(splitreference([[name(foo)]]))
-- inspect(splitreference([[name{foo}]]))
-- inspect(splitreference([[xx::name(foo, bar and me)]]))

-- inspect(splitreference([[ ]]))
-- inspect(splitreference([[ inner ]]))
-- inspect(splitreference([[ special ( operation { argument, argument } ) ]]))
-- inspect(splitreference([[ special ( operation { argument } ) ]]))
-- inspect(splitreference([[ special ( operation { argument, \argument } ) ]]))
-- inspect(splitreference([[ special ( operation { \argument } ) ]]))
-- inspect(splitreference([[ special ( operation ) ]]))
-- inspect(splitreference([[ special ( \operation ) ]]))
-- inspect(splitreference([[ special ( o\peration ) ]]))
-- inspect(splitreference([[ special ( ) ]]))
-- inspect(splitreference([[ inner { argument } ]]))
-- inspect(splitreference([[ inner { \argument } ]]))
-- inspect(splitreference([[ inner { ar\gument } ]]))
-- inspect(splitreference([[inner{a\rgument}]]))
-- inspect(splitreference([[ inner { argument, argument } ]]))
-- inspect(splitreference([[ inner { argument, \argument } ]]))  -- fails: bug in lpeg?
-- inspect(splitreference([[ inner { \argument, \argument } ]]))
-- inspect(splitreference([[ outer :: ]]))
-- inspect(splitreference([[ outer :: inner]]))
-- inspect(splitreference([[ outer :: special (operation { argument,argument } ) ]]))
-- inspect(splitreference([[ outer :: special (operation { } )]]))
-- inspect(splitreference([[ outer :: special ( operation { argument, \argument } ) ]]))
-- inspect(splitreference([[ outer :: special ( operation ) ]]))
-- inspect(splitreference([[ outer :: special ( \operation ) ]]))
-- inspect(splitreference([[ outer :: special ( ) ]]))
-- inspect(splitreference([[ outer :: inner { argument } ]]))
-- inspect(splitreference([[ special ( outer :: operation ) ]]))

-- inspect(splitreference([[inner(foo,bar)]]))

-- inspect(splitreference([[]]))
-- inspect(splitreference([[inner]]))
-- inspect(splitreference([[special(operation{argument,argument})]]))
-- inspect(splitreference([[special(operation)]]))
-- inspect(splitreference([[special(\operation)]]))
-- inspect(splitreference([[special()]]))
-- inspect(splitreference([[inner{argument}]]))
-- inspect(splitreference([[inner{\argument}]]))
-- inspect(splitreference([[outer::]]))
-- inspect(splitreference([[outer::inner]]))
-- inspect(splitreference([[outer::special(operation{argument,argument})]]))
-- inspect(splitreference([[outer::special(operation{argument,\argument})]]))
-- inspect(splitreference([[outer::special(operation)]]))
-- inspect(splitreference([[outer::special(\operation)]]))
-- inspect(splitreference([[outer::special()]]))
-- inspect(splitreference([[outer::inner{argument}]]))
-- inspect(splitreference([[special(outer::operation)]]))

-- inspect(splitreference([[special(operation)]]))
-- inspect(splitreference([[special(operation(whatever))]]))
-- inspect(splitreference([[special(operation{argument,argument{whatever}})]]))
-- inspect(splitreference([[special(operation{argument{whatever}})]]))

-- inspect(splitreference([[special("operation(")]]))
-- inspect(splitreference([[special("operation(whatever")]]))
-- inspect(splitreference([[special(operation{"argument,argument{whatever"})]]))
-- inspect(splitreference([[special(operation{"argument{whatever"})]]))

-- inspect(splitreference([[url(http://a,b.c)]]))
-- inspect(splitcomponent([[url(http://a,b.c)]]))
-- inspect(splitcomponent([[url(http://a.b.c)]]))

