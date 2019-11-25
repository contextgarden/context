if not modules then modules = { } end modules ['typo-dha'] = {
    version   = 1.001,
    comment   = "companion to typo-dir.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Some analysis by Idris:
--
-- 1. Assuming the reading- vs word-order distinction (bidi-char types) is governing;
-- 2. Assuming that 'ARAB' represents an actual arabic string in raw input order, not word-order;
-- 3. Assuming that 'BARA' represent the correct RL word order;
--
-- Then we have, with input: LATIN ARAB
--
-- \textdir TLT LATIN ARAB => LATIN BARA
-- \textdir TRT LATIN ARAB => LATIN BARA
-- \textdir TRT LRO LATIN ARAB => LATIN ARAB
-- \textdir TLT LRO LATIN ARAB => LATIN ARAB
-- \textdir TLT RLO LATIN ARAB => NITAL ARAB
-- \textdir TRT RLO LATIN ARAB => NITAL ARAB

-- elseif d == "es"  then -- European Number Separator
-- elseif d == "et"  then -- European Number Terminator
-- elseif d == "cs"  then -- Common Number Separator
-- elseif d == "nsm" then -- Non-Spacing Mark
-- elseif d == "bn"  then -- Boundary Neutral
-- elseif d == "b"   then -- Paragraph Separator
-- elseif d == "s"   then -- Segment Separator
-- elseif d == "ws"  then -- Whitespace
-- elseif d == "on"  then -- Other Neutrals

-- todo  : use new dir functions
-- todo  : make faster
-- todo  : move dir info into nodes
-- todo  : swappable tables and floats i.e. start-end overloads (probably loop in builders)

-- I removed the original tracing code and now use the colorful one. If I ever want to change
-- something I will just inject prints for tracing.

local nodes, node = nodes, node

local trace_directions   = false  trackers.register("typesetters.directions", function(v) trace_directions = v end)

local report_directions  = logs.reporter("typesetting","text directions")

local nuts               = nodes.nuts

local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getchar            = nuts.getchar
local getid              = nuts.getid
local getsubtype         = nuts.getsubtype
local getlist            = nuts.getlist
local getattr            = nuts.getattr
local getprop            = nuts.getprop
local getdirection       = nuts.getdirection
local isglyph            = nuts.isglyph -- or ischar

local setprop            = nuts.setprop
local setchar            = nuts.setchar

local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after
local remove_node        = nuts.remove
local end_of_math        = nuts.end_of_math
local start_of_par       = nuts.start_of_par

local nodepool           = nuts.pool

local nodecodes          = nodes.nodecodes
local gluecodes          = nodes.gluecodes

local glyph_code         = nodecodes.glyph
local math_code          = nodecodes.math
local kern_code          = nodecodes.kern
local glue_code          = nodecodes.glue
local dir_code           = nodecodes.dir
local localpar_code      = nodecodes.localpar

local dirvalues          = nodes.dirvalues
local lefttoright_code   = dirvalues.lefttoright
local righttoleft_code   = dirvalues.righttoleft

local parfillskip_code   = gluecodes.parfillskip

local new_direction      = nodepool.direction

local insert             = table.insert

local fonthashes         = fonts.hashes
local fontchar           = fonthashes.characters

local chardirections     = characters.directions
local charmirrors        = characters.mirrors
local charclasses        = characters.textclasses

local directions         = typesetters.directions
local setcolor           = directions.setcolor
local getglobal          = directions.getglobal

local a_state            = attributes.private('state')
local a_directions       = attributes.private('directions')

local strip              = false

local s_isol             = fonts.analyzers.states.isol

local function stopdir(finish) -- we could use finish directly
    local n = new_direction(finish == righttoleft_code and righttoleft_code or lefttoright_code,true)
    setprop(n,"direction",true)
    return n
end

local function startdir(finish) -- we could use finish directly
    local n = new_direction(finish == righttoleft_code and righttoleft_code or lefttoright_code)
    setprop(n,"direction",true)
    return n
end

local function nextisright(current)
    current = getnext(current)
    local character, id = isglyph(current)
    if character then
        local direction = chardirections[character]
        return direction == "r" or direction == "al" or direction == "an"
    end
end

local function previsright(current)
    current = getprev(current)
    local character, id = isglyph(current)
    if character then
        local direction = chardirections[character]
        return direction == "r" or direction == "al" or direction == "an"
    end
end

local function process(start)

    local head     = start
    local current  = head
    local autodir  = 0
    local embedded = 0
    local override = 0
    local pardir   = 0
    local textdir  = 0
    local done     = false
    local stack    = { }
    local top      = 0
    local obsolete = { }
    local rlo      = false
    local lro      = false
    local prevattr = false
    local fences   = { }

    while current do
        -- no isglyph here as we test for skips first
        local id   = getid(current)
        local next = getnext(current)
        if id == math_code then
            current = getnext(end_of_math(next))
        elseif getprop(current,"direction") then
            -- this handles unhbox etc
            current = next
        else
            local attr = getattr(current,a_directions)
            if attr and attr > 0 then
                if attr ~= prevattr then
                    if not getglobal(a) then
                        lro = false
                        rlo = false
                    end
                    prevattr = attr
                end
            end
            if id == glyph_code then
                if attr and attr > 0 then
                    local character, font = isglyph(current)
                    if character == 0 then
                        -- skip signals
                        setprop(current,"direction",true)
                    else
                        local direction = chardirections[character]
                        local reversed  = false
                        if rlo or override > 0 then
                            if direction == "l" then
                                direction = "r"
                                reversed  = true
                            end
                        elseif lro or override < 0 then
                            if direction == "r" or direction == "al" then
                                setprop(current,a_state,s_isol) -- hm
                                direction = "l"
                                reversed  = true
                            end
                        end
                        if direction == "on" then
                            local mirror = charmirrors[character]
                            if mirror and fontchar[font][mirror] then
                                local class = charclasses[character]
                                if class == "open" then
                                    if nextisright(current) then
                                        setchar(current,mirror)
                                        setprop(current,"direction","r")
                                    elseif autodir < 0 then
                                        setchar(current,mirror)
                                        setprop(current,"direction","r")
                                    else
                                        mirror = false
                                        setprop(current,"direction","l")
                                    end
                                    local fencedir = autodir == 0 and textdir or autodir
                                    fences[#fences+1] = fencedir
                                elseif class == "close" and #fences > 0 then
                                    local fencedir = fences[#fences]
                                    fences[#fences] = nil
                                    if fencedir < 0 then
                                        setchar(current,mirror)
                                        setprop(current,"direction","r")
                                    else
                                        setprop(current,"direction","l")
                                        mirror = false
                                    end
                                elseif autodir < 0 then
                                    setchar(current,mirror)
                                    setprop(current,"direction","r")
                                else
                                    setprop(current,"direction","l")
                                    mirror = false
                                end
                            else
                                setprop(current,"direction",true)
                            end
                            if trace_directions then
                                setcolor(current,direction,false,mirror)
                            end
                        elseif direction == "l" then
                            if trace_directions then
                                setcolor(current,"l",reversed)
                            end
                            setprop(current,"direction","l")
                        elseif direction == "r" then
                            if trace_directions then
                                setcolor(current,"r",reversed)
                            end
                            setprop(current,"direction","r")
                        elseif direction == "en" then -- european number
                            if trace_directions then
                                setcolor(current,"l")
                            end
                            setprop(current,"direction","l")
                        elseif direction == "al" then -- arabic letter
                            if trace_directions then
                                setcolor(current,"r")
                            end
                            setprop(current,"direction","r")
                        elseif direction == "an" then -- arabic number
                            -- needs a better scanner as it can be a float
                            if trace_directions then
                                setcolor(current,"l") -- was r
                            end
                            setprop(current,"direction","n") -- was r
                        elseif direction == "lro" then -- Left-to-Right Override -> right becomes left
                            top        = top + 1
                            stack[top] = { override, embedded }
                            override   = -1
                            obsolete[#obsolete+1] = current
                        elseif direction == "rlo" then -- Right-to-Left Override -> left becomes right
                            top        = top + 1
                            stack[top] = { override, embedded }
                            override   = 1
                            obsolete[#obsolete+1] = current
                        elseif direction == "lre" then -- Left-to-Right Embedding -> TLT
                            top        = top + 1
                            stack[top] = { override, embedded }
                            embedded   = 1
                            obsolete[#obsolete+1] = current
                        elseif direction == "rle" then -- Right-to-Left Embedding -> TRT
                            top        = top + 1
                            stack[top] = { override, embedded }
                            embedded   = -1
                            obsolete[#obsolete+1] = current
                        elseif direction == "pdf" then -- Pop Directional Format
                            if top > 0 then
                                local s  = stack[top]
                                override = s[1]
                                embedded = s[2]
                                top      = top - 1
                            else
                                override = 0
                                embedded = 0
                            end
                            obsolete[#obsolete+1] = current
                        elseif trace_directions then
                            setcolor(current)
                            setprop(current,"direction",true)
                        else
                            setprop(current,"direction",true)
                        end
                    end
                else
                    setprop(current,"direction",true)
                end
            elseif id == glue_code then
                if getsubtype(current) == parfillskip_code then
                    setprop(current,"direction",'!')
                else
                    setprop(current,"direction",'g')
                end
            elseif id == kern_code then
                setprop(current,"direction",'k')
            elseif id == dir_code then
                local direction, pop = getdirection(current)
                if direction == righttoleft_code then
                    if not pop then
                        autodir = -1
                    elseif embedded and embedded~= 0 then
                        autodir = embedded
                    else
                        autodir = 0
                    end
                elseif direction == lefttoright_code then
                    if not pop then
                        autodir = 1
                    elseif embedded and embedded~= 0 then
                        autodir = embedded
                    else
                        autodir = 0
                    end
                end
                textdir = autodir
                setprop(current,"direction",true)
            elseif id == localpar_code and start_of_par(current) then
                local direction = getdirection(current)
                if direction == righttoleft_code then
                    autodir = -1
                elseif direction == lefttoright_code then
                    autodir = 1
                end
                pardir  = autodir
                textdir = pardir
                setprop(current,"direction",true)
            else
                setprop(current,"direction",true)
            end
            current = next
        end
    end

    -- todo: track if really needed
    -- todo: maybe we need to set the property (as it can be a copied list)

    if done and strip then
        local n = #obsolete
        if n > 0 then
            for i=1,n do
                remove_node(head,obsolete[i],true)
            end
            if trace_directions then
                report_directions("%s character nodes removed",n)
            end
        end
    end

    local state    = false
    local last     = false
    local collapse = true
    current        = head

    -- todo: textdir
    -- todo: inject before parfillskip

    while current do
        local id = getid(current)
        if id == math_code then
            -- todo: this might be tricky nesting
            current = getnext(end_of_math(getnext(current)))
        else
            local cp = getprop(current,"direction")
            if cp == "n" then
                local swap = state == "r"
                if swap then
                    head = insert_node_before(head,current,startdir("TLT"))
                end
                setprop(current,"direction",true)
                while true do
                    local n = getnext(current)
                    if n and getprop(n,"direction") == "n" then
                        current = n
                        setprop(current,"direction",true)
                    else
                        break
                    end
                end
                if swap then
                    head, current = insert_node_after(head,current,stopdir("TLT"))
                end
            elseif cp == "l" then
                if state ~= "l" then
                    if state == "r" then
                        head = insert_node_before(head,last or current,stopdir("TRT"))
                    end
                    head  = insert_node_before(head,current,startdir("TLT"))
                    state = "l"
                    done  = true
                end
                last  = false
            elseif cp == "r" then
                if state ~= "r" then
                    if state == "l" then
                        head = insert_node_before(head,last or current,stopdir("TLT"))
                    end
                    head  = insert_node_before(head,current,startdir("TRT"))
                    state = "r"
                    done  = true
                end
                last = false
            elseif collapse then
                if cp == "k" or cp == "g" then
                    last = last or current
                else
                    last = false
                end
            else
                if state == "r" then
                    head = insert_node_before(head,current,stopdir("TRT"))
                elseif state == "l" then
                    head = insert_node_before(head,current,stopdir("TLT"))
                end
                state = false
                last  = false
            end
            setprop(current,"direction",true)
        end
        local next = getnext(current)
        if next then
            current = next
        else
            local sd = (state == "r" and stopdir("TRT")) or (state == "l" and stopdir("TLT"))
            if sd then
                if id == glue_code and getsubtype(current) == parfillskip_code then
                    head = insert_node_before(head,current,sd)
                else
                    head = insert_node_after(head,current,sd)
                end
            end
            break
        end
    end

    return head

end

directions.installhandler(interfaces.variables.default,process)
