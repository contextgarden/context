if not modules then modules = { } end modules ['typo-pnc'] = {
    version   = 1.001,
    comment   = "companion to typo-pnc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local nodes           = nodes
local fonts           = fonts

local enableaction    = nodes.tasks.enableaction

local nuts            = nodes.nuts
local tonut           = nodes.tonut

local nodecodes       = nodes.nodecodes
local gluecodes       = nodes.gluecodes
local glyph_code      = nodecodes.glyph
local glue_code       = nodecodes.glue
local spaceskip_code  = gluecodes.spaceskip

local new_kern        = nuts.pool.kern
local insert_after    = nuts.insert_after

local nextglyph       = nuts.traversers.glyph

local getchar         = nuts.getchar
local getfont         = nuts.getfont
local getboth         = nuts.getboth
local getnext         = nuts.getnext
local getattr         = nuts.getattr
local getid           = nuts.getid
local getsubtype      = nuts.getsubtype
local getwidth        = nuts.getwidth
local setwidth        = nuts.setwidth

local parameters      = fonts.hashes.parameters
local categories      = characters.categories

local texsetattribute = tex.setattribute
local unsetvalue      = attributes.unsetvalue

local period          = 0x2E
local factor          = 0.5

-- alternative: tex.getlccode and tex.getuccode

typesetters             = typesetters or { }
local typesetters       = typesetters

local periodkerns       = typesetters.periodkerns or { }
typesetters.periodkerns = periodkerns

local report            = logs.reporter("period kerns")
local trace             = false

trackers.register("typesetters.periodkerns",function(v) trace = v end)

periodkerns.mapping     = periodkerns.mapping or { }
periodkerns.factors     = periodkerns.factors or { }
local a_periodkern      = attributes.private("periodkern")

storage.register("typesetters/periodkerns/mapping", periodkerns.mapping, "typesetters.periodkerns.mapping")
storage.register("typesetters/periodkerns/factors", periodkerns.factors, "typesetters.periodkerns.factors")

local mapping = periodkerns.mapping
local factors = periodkerns.factors

function periodkerns.handler(head)
    for current, char, font in nextglyph, head do
        if char == period then
            local a = getattr(current,a_periodkern)
            if a then
                local factor = mapping[a]
                if factor then
                    local prev, next = getboth(current)
                    if prev and next and getid(prev) == glyph_code and getid(next) == glyph_code then
                        local pchar = getchar(prev)
                        local pcode = categories[pchar]
                        if pcode == "lu" or pcode == "ll" then
                            local nchar = getchar(next)
                            local ncode = categories[nchar]
                            if ncode == "lu" or ncode == "ll" then
                                local next2 = getnext(next)
                                if next2 and getid(next2) == glyph_code and getchar(next2) == period then
                                    -- A.B.
                                    local fontspace, inserted
                                    if factor ~= 0 then
                                        fontspace = parameters[getfont(current)].space -- can be sped up
                                        inserted  = factor * fontspace
                                        insert_after(head,current,new_kern(inserted))
                                        if trace then
                                            report("inserting space at %C . [%p] %C .",pchar,inserted,nchar)
                                        end
                                    end
                                    local next3 = getnext(next2)
                                    if next3 and getid(next3) == glue_code and getsubtype(next3) == spaceskip_code then
                                        local width = getwidth(next3)
                                        local space = fontspace or parameters[getfont(current)].space -- can be sped up
                                        if width > space then -- space + extraspace
                                            local next4 = getnext(next3)
                                            if next4 and getid(next4) == glyph_code then
                                                local fchar = getchar(next4)
                                                if categories[fchar] ~= "lu" then
                                                    -- A.B.<glue>X
                                                    if trace then
                                                        if inserted then
                                                            report("reverting space at %C . [%p] %C . [%p->%p] %C",pchar,inserted,nchar,width,space,fchar)
                                                        else
                                                            report("reverting space at %C . %C . [%p->%p] %C",pchar,nchar,width,space,fchar)
                                                        end
                                                    end
                                                    setwidth(next3,space)
                                                else
                                                    if trace then
                                                        if inserted then
                                                            report("keeping space at %C . [%p] %C . [%p] %C",pchar,inserted,nchar,width,fchar)
                                                        else
                                                            report("keeping space at %C . %C . [%p] %C",pchar,nchar,width,fchar)
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return head
end

local enabled = false

function periodkerns.set(factor)
    factor = tonumber(factor) or 0
    if not enabled then
        enableaction("processors","typesetters.periodkerns.handler")
        enabled = true
    end
    local a = factors[factor]
    if not a then
        a = #mapping + 1
        factors[factors], mapping[a] = a, factor
    end
    factor = a
    texsetattribute(a_periodkern,factor)
    return factor
end

-- interface

interfaces.implement {
    name      = "setperiodkerning",
    actions   = periodkerns.set,
    arguments = "string"
}


