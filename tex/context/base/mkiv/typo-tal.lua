if not modules then modules = { } end modules ['typo-tal'] = {
    version   = 1.001,
    comment   = "companion to typo-tal.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- I'll make it a bit more efficient and provide named instances too which is needed for
-- nested tables.
--
-- Currently we have two methods: text and number with some downward compatible
-- defaulting.

-- We can speed up by saving the current fontcharacters[font] + lastfont.

local next, type, tonumber = next, type, tonumber
local div = math.div
local utfbyte = utf.byte

local splitmethod          = utilities.parsers.splitmethod

local nodecodes            = nodes.nodecodes
local glyph_code           = nodecodes.glyph
local glue_code            = nodecodes.glue

local fontcharacters       = fonts.hashes.characters
----- unicodes             = fonts.hashes.unicodes
local categories           = characters.categories -- nd

local variables            = interfaces.variables
local v_text               = variables.text
local v_number             = variables.number

local nuts                 = nodes.nuts
local tonut                = nuts.tonut

local getnext              = nuts.getnext
local getprev              = nuts.getprev
local getboth              = nuts.getboth
local getid                = nuts.getid
local getfont              = nuts.getfont
local getchar              = nuts.getchar
local getattr              = nuts.getattr
local isglyph              = nuts.isglyph

local setattr              = nuts.setattr
local setchar              = nuts.setchar

local insert_node_before   = nuts.insert_before
local insert_node_after    = nuts.insert_after
local nextglyph            = nuts.traversers.glyph
local getdimensions        = nuts.dimensions
local first_glyph          = nuts.first_glyph

local setglue              = nuts.setglue

local nodepool             = nuts.pool
local new_kern             = nodepool.kern

local tracers              = nodes.tracers
local setcolor             = tracers.colors.set
local tracedrule           = tracers.pool.nuts.rule

local enableaction         = nodes.tasks.enableaction

local characteralign       = { }
typesetters.characteralign = characteralign

local trace_split          = false  trackers.register("typesetters.characteralign", function(v) trace_split = true end)
local report               = logs.reporter("aligning")

local a_characteralign     = attributes.private("characteralign")
local a_character          = attributes.private("characters")

local enabled              = false

local datasets             = false

local implement            = interfaces.implement

local comma                = 0x002C
local period               = 0x002E
local punctuationspace     = 0x2008

local validseparators = {
    [comma]            = true,
    [period]           = true,
    [punctuationspace] = true,
}

local validsigns = {
    [0x002B] = 0x002B, -- plus
    [0x002D] = 0x2212, -- hyphen
    [0x00B1] = 0x00B1, -- plusminus
    [0x2212] = 0x2212, -- minus
    [0x2213] = 0x2213, -- minusplus
}

-- If needed we can have more modes which then also means a faster simple handler
-- for non numbers.

local function setcharacteralign(column,separator,before,after)
    if not enabled then
        enableaction("processors","typesetters.characteralign.handler")
        enabled = true
    end
    if not datasets then
        datasets = { }
    end
    local dataset = datasets[column] -- we can use a metatable
    if not dataset then
        local method, token
        if separator then
            method, token = splitmethod(separator)
            if method and token then
                separator = utfbyte(token) or comma
            else
                separator = utfbyte(separator) or comma
                method    = validseparators[separator] and v_number or v_text
            end
        else
            separator = comma
            method    = v_number
        end
        local before = tonumber(before) or 0
        local after  = tonumber(after) or 0
        dataset = {
            separator  = separator,
            list       = { },
            maxbefore  = before,
            maxafter   = after,
            predefined = before > 0 or after > 0,
            collected  = false,
            method     = method,
            separators = validseparators,
            signs      = validsigns,
        }
        datasets[column] = dataset
        used = true
    end
    return dataset
end

local function resetcharacteralign()
    datasets = false
end

characteralign.setcharacteralign   = setcharacteralign
characteralign.resetcharacteralign = resetcharacteralign

implement {
    name      = "setcharacteralign",
    actions   = setcharacteralign,
    arguments = { "integer", "string" }
}

implement {
    name      = "setcharacteraligndetail",
    actions   = setcharacteralign,
    arguments = { "integer", "string", "dimension", "dimension" }
}

implement {
    name      = "resetcharacteralign",
    actions   = resetcharacteralign
}

local function traced_kern(w)
    return tracedrule(w,nil,nil,"darkgray")
end

function characteralign.handler(head,where)
    if not datasets then
        return head
    end
 -- local first = first_glyph(head) -- we could do that once
    local first
    for n in nextglyph, head do
        first = n
        break
    end
    if not first then
        return head
    end
    local a = getattr(first,a_characteralign)
    if not a or a == 0 then
        return head
    end
    local column    = div(a,0xFFFF)
    local row       = a % 0xFFFF
    local dataset   = datasets and datasets[column] or setcharacteralign(column)
    local separator = dataset.separator
    local list      = dataset.list
    local b_start   = nil
    local b_stop    = nil
    local a_start   = nil
    local a_stop    = nil
    local c         = nil
    local current   = first
    local sign      = nil
    --
    local validseparators = dataset.separators
    local validsigns      = dataset.signs
    local method          = dataset.method
    -- we can think of constraints
    if method == v_number then

        local function bothdigit(current) -- this could become a helper
            local prev, next = getboth(current)
            if next and prev and getid(next) == glyph_code and getid(prev) == glyph_code then
                local pchar    = getchar(prev)
                local nchar    = getchar(next)
                local pdata    = fontcharacters[getfont(prev)][pchar]
                local ndata    = fontcharacters[getfont(next)][nchar]
                local punicode = pdata and pdata.unicode or pchar -- we ignore tables
                local nunicode = ndata and ndata.unicode or nchar -- we ignore tables
                if punicode and nunicode and categories[punicode] == "nd" and categories[nunicode] == "nd" then
                    return true
                else
                    return false
                end
            end
        end

        while current do
            local char, id = isglyph(current)
            if char then
                local font    = id --- nicer
                local data    = fontcharacters[font][char]
                local unicode = data and data.unicode or char -- ignore tables
                if not unicode then -- type(unicode) ~= "number"
                    -- no unicode so forget about it
                elseif unicode == separator then
                    c = current
                    if trace_split then
                        setcolor(current,"darkred")
                    end
                    dataset.hasseparator = true
                elseif categories[unicode] == "nd" or validseparators[unicode] then
                    if c then
                        if not a_start then
                            a_start = current
                        end
                        a_stop = current
                        if trace_split then
                            setcolor(current,validseparators[unicode] and "darkcyan" or "darkblue")
                        end
                    else
                        if not b_start then
                            if sign then
                                b_start = sign
                                local c, f = isglyph(sign)
                                local new = validsigns[c]
                                if char == new or not fontcharacters[f][new] then
                                    if trace_split then
                                        setcolor(sign,"darkyellow")
                                    end
                                else
                                    setchar(sign,new)
                                    if trace_split then
                                        setcolor(sign,"darkmagenta")
                                    end
                                end
                                sign = nil
                                b_stop = current
                            else
                                b_start = current
                                b_stop = current
                            end
                        else
                            b_stop = current
                        end
                        if trace_split and current ~= sign then
                            setcolor(current,validseparators[unicode] and "darkcyan" or "darkblue")
                        end
                    end
                elseif not b_start then
                    sign = validsigns[unicode] and current
                 -- if trace_split then
                 --     setcolor(current,"darkgreen")
                 -- end
                end
            elseif (b_start or a_start) and id == glue_code then
                -- maybe only in number mode
                -- somewhat inefficient
                if bothdigit(current) then
                    local width = fontcharacters[getfont(b_start or a_start)][separator or period].width
                    setglue(current,width,0,0)
                    setattr(current,a_character,punctuationspace)
                    if a_start then
                        a_stop = current
                    elseif b_start then
                        b_stop = current
                    end
                end
            end
            current = getnext(current)
        end
    else
        while current do
            local char, id = isglyph(current)
            if char then
                local font = id -- nicer
             -- local unicode = unicodes[font][char]
                local unicode = fontcharacters[font][char].unicode or char -- ignore tables
                if not unicode then
                    -- no unicode so forget about it
                elseif unicode == separator then
                    c = current
                    if trace_split then
                        setcolor(current,"darkred")
                    end
                    dataset.hasseparator = true
                else
                    if c then
                        if not a_start then
                            a_start = current
                        end
                        a_stop = current
                        if trace_split then
                            setcolor(current,"darkgreen")
                        end
                    else
                        if not b_start then
                            b_start = current
                        end
                        b_stop = current
                        if trace_split then
                            setcolor(current,"darkblue")
                        end
                    end
                end
            end
            current = getnext(current)
        end
    end
    local predefined = dataset.predefined
    local before, after
    if predefined then
        before = b_start and getdimensions(b_start,getnext(b_stop)) or 0
        after  = a_start and getdimensions(a_start,getnext(a_stop)) or 0
    else
        local entry = list[row]
        if entry then
            before = entry.before or 0
            after  = entry.after  or 0
        else
            before = b_start and getdimensions(b_start,getnext(b_stop)) or 0
            after  = a_start and getdimensions(a_start,getnext(a_stop)) or 0
            list[row] = {
                before = before,
                after  = after,
            }
            return head, true
        end
        if not dataset.collected then
         -- print("[maxbefore] [maxafter]")
            local maxbefore = 0
            local maxafter  = 0
            for k, v in next, list do
                local before = v.before
                local after  = v.after
                if before and before > maxbefore then
                    maxbefore = before
                end
                if after and after > maxafter then
                    maxafter = after
                end
            end
            dataset.maxbefore = maxbefore
            dataset.maxafter  = maxafter
            dataset.collected = true
        end
    end
    local maxbefore = dataset.maxbefore
    local maxafter  = dataset.maxafter
    local new_kern  = trace_split and traced_kern or new_kern
    if b_start then
        if before < maxbefore then
            head = insert_node_before(head,b_start,new_kern(maxbefore-before))
        end
        if not c then
         -- print("[before]")
            if dataset.hasseparator then
                local width = fontcharacters[getfont(b_start)][separator].width
                insert_node_after(head,b_stop,new_kern(maxafter+width))
            end
        elseif a_start then
         -- print("[before] [separator] [after]")
            if after < maxafter then
                insert_node_after(head,a_stop,new_kern(maxafter-after))
            end
        else
         -- print("[before] [separator]")
            if maxafter > 0 then
                insert_node_after(head,c,new_kern(maxafter))
            end
        end
    elseif a_start then
        if c then
         -- print("[separator] [after]")
            if maxbefore > 0 then
                head = insert_node_before(head,c,new_kern(maxbefore))
            end
        else
         -- print("[after]")
            local width = fontcharacters[getfont(b_stop)][separator].width
            head = insert_node_before(head,a_start,new_kern(maxbefore+width))
        end
        if after < maxafter then
            insert_node_after(head,a_stop,new_kern(maxafter-after))
        end
    elseif c then
     -- print("[separator]")
        if maxbefore > 0 then
            head = insert_node_before(head,c,new_kern(maxbefore))
        end
        if maxafter > 0 then
            insert_node_after(head,c,new_kern(maxafter))
        end
    end
    return head
end
