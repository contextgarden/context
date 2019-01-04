if not modules then modules = { } end modules ['typo-fkr'] = {
    version   = 1.001,
    comment   = "companion to typo-fkr.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local nuts          = nodes.nuts
local getid         = nuts.getid
local getnext       = nuts.getnext
local getattr       = nuts.getattr
local isglyph       = nuts.isglyph

local nodecodes     = nodes.nodecodes
local glyph_code    = nodecodes.glyph

local fontdata      = fonts.hashes.identifiers
local getkernpair   = fonts.handlers.otf.getkern

local insert_before = nuts.insert_before
local new_kern      = nuts.pool.fontkern

local enableaction  = nodes.tasks.enableaction

local a_extrakern   = attributes.private("extrafontkern")

-- 0=none 1=min 2=max 3=mixed

typesetters.fontkerns = { }

function typesetters.fontkerns.handler(head)
    local current   = head
    local lastfont  = nil
    local lastchar  = nil
    local lastdata  = nil
    while current do
        local char, font = isglyph(current)
        if char then
            local a = getattr(current,a_extrakern)
            if a then
                if font ~= lastfont then
                    if a > 0 and lastchar then
                        if not lastdata then
                            lastdata = fontdata[lastfont]
                        end
                        local kern  = nil
                        local data  = fontdata[font]
                        local kern1 = getkernpair(lastdata,lastchar,char)
                        local kern2 = getkernpair(data,lastchar,char)
                        if a == 1 then
                            kern = kern1 > kern2 and kern2 or kern1 -- min
                        elseif a == 2 then
                            kern = kern1 > kern2 and kern1 or kern2 -- max
                        else -- 3
                            kern = (kern1 + kern2)/2                -- mixed
                        end
                        if kern ~= 0 then
                            head, current = insert_before(head,current,new_kern(kern))
                        end
                        lastdata = data
                    else
                        lastdata = nil
                    end
                elseif lastchar then
                    if not lastdata then
                        lastdata = fontdata[lastfont]
                    end
                    local kern = getkernpair(lastdata,lastchar,char)
                    if kern ~= 0 then
                        head, current = insert_before(head,current,new_kern(kern))
                    end
                end
                lastchar = char
                lastfont = font
            elseif lastfont then
                lastfont = nil
                lastchar = nil
                lastdata = nil
            end
        elseif lastfont then
            lastfont = nil
            lastchar = nil
            lastdata = nil
        end
        current = getnext(current)
    end
    return head
end

if context then

    local variables    = interfaces.variables
    local unsetvalue   = attributes.unsetvalue
    local enabled      = false
    local setattribute = tex.setattribute

    local values       = {
        [variables.none ] = 0,
        [variables.min  ] = 1,
        [variables.max  ] = 2,
        [variables.mixed] = 3,
        [variables.reset] = unsetvalue,
    }

    local function setextrafontkerns(str)
        if not enabled then
            enableaction("processors","typesetters.fontkerns.handler")
            enabled = true
        end
        setattribute(a_extrakern,values[str] or unsetvalue)
    end

    interfaces.implement {
        name      = "setextrafontkerns",
        arguments = "string",
        actions   = setextrafontkerns,
    }

end
