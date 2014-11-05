if not modules then modules = { } end modules ['spac-chr'] = {
    version   = 1.001,
    comment   = "companion to spac-chr.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local byte, lower = string.byte, string.lower

-- beware: attribute copying is bugged ... there will be a proper luatex helper
-- for this

-- to be redone: characters will become tagged spaces instead as then we keep track of
-- spaceskip etc

-- todo: only setattr when export / use properties

local next = next

local trace_characters = false  trackers.register("typesetters.characters", function(v) trace_characters = v end)

local report_characters = logs.reporter("typesetting","characters")

local nodes, node = nodes, node

local nuts               = nodes.nuts

local tonode             = nuts.tonode
local tonut              = nuts.tonut

local getfield           = nuts.getfield
local setfield           = nuts.setfield
local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getid              = nuts.getid
local getattr            = nuts.getattr
local setattr            = nuts.setattr
local getfont            = nuts.getfont
local getchar            = nuts.getchar

local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after
local remove_node        = nuts.remove
local copy_node_list     = nuts.copy_list
local traverse_id        = nuts.traverse_id

local tasks              = nodes.tasks

local nodepool           = nuts.pool
local new_penalty        = nodepool.penalty
local new_glue           = nodepool.glue

local nodecodes          = nodes.nodecodes
local skipcodes          = nodes.skipcodes
local glyph_code         = nodecodes.glyph
local glue_code          = nodecodes.glue

local space_skip_code    = skipcodes["spaceskip"]

local chardata           = characters.data
local is_punctuation     = characters.is_punctuation

local typesetters        = typesetters

local unicodeblocks      = characters.blocks

local characters         = typesetters.characters or { } -- can be predefined
typesetters.characters   = characters

local fonthashes         = fonts.hashes
local fontparameters     = fonthashes.parameters
local fontcharacters     = fonthashes.characters
local fontquads          = fonthashes.quads

local setmetatableindex  = table.setmetatableindex

local a_character        = attributes.private("characters")
local a_alignstate       = attributes.private("alignstate")

local c_zero   = byte('0')
local c_period = byte('.')

local function inject_quad_space(unicode,head,current,fraction)
    local attr = getfield(current,"attr")
    if fraction ~= 0 then
        fraction = fraction * fontquads[getfont(current)]
    end
    local glue = new_glue(fraction)
    setfield(glue,"attr",attr)
    setfield(current,"attr",nil)
    setattr(glue,a_character,unicode)
    head, current = insert_node_after(head,current,glue)
    return head, current
end

local function inject_char_space(unicode,head,current,parent)
    local attr = getfield(current,"attr")
    local font = getfont(current)
    local char = fontcharacters[font][parent]
    local glue = new_glue(char and char.width or fontparameters[font].space)
    setfield(glue,"attr",attr)
    setfield(current,"attr",nil)
    setattr(glue,a_character,unicode)
    head, current = insert_node_after(head,current,glue)
    return head, current
end

local function inject_nobreak_space(unicode,head,current,space,spacestretch,spaceshrink)
    local attr = getfield(current,"attr")
    local glue = new_glue(space,spacestretch,spaceshrink)
    local penalty = new_penalty(10000)
    setfield(glue,"attr",attr)
    setfield(current,"attr",nil)
    setattr(glue,a_character,unicode)
    head, current = insert_node_after(head,current,penalty)
    head, current = insert_node_after(head,current,glue)
    return head, current
end

local function nbsp(head,current)
    local para = fontparameters[getfont(current)]
    if getattr(current,a_alignstate) == 1 then -- flushright
        head, current = inject_nobreak_space(0x00A0,head,current,para.space,0,0)
        setfield(current,"subtype",space_skip_code)
    else
        head, current = inject_nobreak_space(0x00A0,head,current,para.space,para.spacestretch,para.spaceshrink)
    end
    return head, current
end

-- assumes nuts or nodes, depending on callers .. so no tonuts here

function characters.replacenbsp(head,original)
    local head, current = nbsp(head,original)
    head = remove_node(head,original,true)
    return head, current
end

function characters.replacenbspaces(head)
    for current in traverse_id(glyph_code,head) do
        if getchar(current) == 0x00A0 then
            local h = nbsp(head,current)
            if h then
                head = remove_node(h,current,true)
            end
        end
    end
    return head
end

-- This initialization might move someplace else if we need more of it. The problem is that
-- this module depends on fonts so we have an order problem.

local nbsphash = { } setmetatableindex(nbsphash,function(t,k)
    for i=unicodeblocks.devanagari.first,unicodeblocks.devanagari.last do nbsphash[i] = true end
    for i=unicodeblocks.kannada   .first,unicodeblocks.kannada   .last do nbsphash[i] = true end
    setmetatableindex(nbsphash,nil)
    return nbsphash[k]
end)

local methods = {

    -- The next one uses an attribute assigned to the character but still we
    -- don't have the 'local' value.

    [0x001F] = function(head,current)
        local next = getnext(current)
        if next and getid(next) == glyph_code then
            local char = getchar(next)
            head, current = remove_node(head,current,true)
            if not is_punctuation[char] then
                local p = fontparameters[getfont(next)]
                head, current = insert_node_before(head,current,new_glue(p.space,p.space_stretch,p.space_shrink))
            end
        end
    end,

    [0x00A0] = function(head,current) -- nbsp
        local next = getnext(current)
        if next and getid(next) == glyph_code then
            local char = getchar(next)
            if char == 0x200C or char == 0x200D then -- nzwj zwj
                next = getnext(next)
				if next and nbsphash[getchar(next)] then
                    return false
                end
            elseif nbsphash[char] then
                return false
            end
        end
        local prev = getprev(current)
        if prev and getid(prev) == glyph_code and nbsphash[getchar(prev)] then
            return false
        end
        return nbsp(head,current)
    end,

    [0x2000] = function(head,current) -- enquad
        return inject_quad_space(0x2000,head,current,1/2)
    end,

    [0x2001] = function(head,current) -- emquad
        return inject_quad_space(0x2001,head,current,1)
    end,

    [0x2002] = function(head,current) -- enspace
        return inject_quad_space(0x2002,head,current,1/2)
    end,

    [0x2003] = function(head,current) -- emspace
        return inject_quad_space(0x2003,head,current,1)
    end,

    [0x2004] = function(head,current) -- threeperemspace
        return inject_quad_space(0x2004,head,current,1/3)
    end,

    [0x2005] = function(head,current) -- fourperemspace
        return inject_quad_space(0x2005,head,current,1/4)
    end,

    [0x2006] = function(head,current) -- sixperemspace
        return inject_quad_space(0x2006,head,current,1/6)
    end,

    [0x2007] = function(head,current) -- figurespace
        return inject_char_space(0x2007,head,current,c_zero)
    end,

    [0x2008] = function(head,current) -- punctuationspace
        return inject_char_space(0x2008,head,current,c_period)
    end,

    [0x2009] = function(head,current) -- breakablethinspace
        return inject_quad_space(0x2009,head,current,1/8) -- same as next
    end,

    [0x200A] = function(head,current) -- hairspace
        return inject_quad_space(0x200A,head,current,1/8) -- same as previous (todo)
    end,

    [0x200B] = function(head,current) -- zerowidthspace
        return inject_quad_space(0x200B,head,current,0)
    end,

    [0x202F] = function(head,current) -- narrownobreakspace
        return inject_nobreak_space(0x202F,head,current,fontquads[getfont(current)]/8)
    end,

    [0x205F] = function(head,current) -- math thinspace
        return inject_nobreak_space(0x205F,head,current,fontparameters[getfont(current)].space/8)
    end,

 -- [0xFEFF] = function(head,current) -- zerowidthnobreakspace
 --     return head, current
 -- end,

}

function characters.handler(head) -- todo: use traverse_id
    head = tonut(head)
    local current = head
    local done = false
    while current do
        local id = getid(current)
        if id == glyph_code then
            local next = getnext(current)
            local char = getchar(current)
            local method = methods[char]
            if method then
                if trace_characters then
                    report_characters("replacing character %C, description %a",char,lower(chardata[char].description))
                end
                local h = method(head,current)
                if h then
                    head = remove_node(h,current,true)
                end
                done = true
            end
            current = next
        else
            current = getnext(current)
        end
    end
    return tonode(head), done
end
