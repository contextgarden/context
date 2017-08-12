if not modules then modules = { } end modules['s-math-ligatures'] = {
    version   = 1.001,
    comment   = "companion to s-math-ligatures.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.math           = moduledata.math           or { }
moduledata.math.ligatures = moduledata.math.ligatures or { }

local context = context

local utfchar = utf.char
local uformat = string.formatters["%U"]

function moduledata.math.ligatures.showlist(specification)
 -- specification = interfaces.checkedspecification(specification)

    local function setlist(unicode,list,start,v,how)
        if list[start] ~= 0x20 then
            local t, u = { }, { }
            for i=start,#list do
                local li = list[i]
                t[#t+1] = utfchar(li)
                u[#u+1] = uformat(li)
            end
            context.NC() context(how)
            context.NC() context("%U",unicode)
            context.NC() context("%c",unicode)
            context.NC() context("% t",u)
            context.NC() context("%t",t)
            context.NC() context("%t",t)
            context.NC()
            context.nohyphens()
            context.veryraggedright()
            local n = v.mathname
            if n then
                context.tex(n)
            else
                local c = v.mathspec
                if c then
                    for i=1,#c do
                        local n = c[i].name
                        if n then
                            context.tex(n)
                            context.quad()
                        end
                    end
                end
            end
            context.NC()
            context.NR()
        end
    end

    context.starttabulate { "|T|T|m|T|T|m|pl|" }
    for unicode, v in table.sortedhash(characters.data) do
        local vs = v.specials
        if vs and #vs > 2 then
            local kind = vs[1]
            if (v.mathclass or v.mathspec) and (kind == "char" or kind == "compat") then
                setlist(unicode,vs,2,v,"sp")
            end
        end
        local ml = v.mathlist
        if ml then
            setlist(unicode,ml,1,v,"ml")
        end
    end
    context.stoptabulate()
end
