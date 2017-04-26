if not modules then modules = { } end modules ['symb-emj'] = {
    version   = 1.001,
    comment   = "companion to symb-emj.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local symbols        = fonts.symbols

-- emoji

-- processors.hpack_filter does it all

local resolvedemoji   = characters.emoji.resolve
local processfeatures = fonts.handlers.otf.featuresprocessor
local injectspacing   = nodes.injections.handler
local protectglyphs   = nodes.handlers.protectglyphs
local tonodes         = nodes.tonodes
local currentfont     = font.current

-- fast enough, no need to memoize

local glyph_code   = nodes.nodecodes.glyph
local remove_node  = nodes.remove
local getid        = nodes.getid
local getnext      = nodes.getnext
local getchar      = nodes.getchar

local function removemodifiers(head)
    local current = head
    while current do
        if getid(current) == glyph_code then
            local char = getchar(current) -- using categories is too much
            if char == 0x200D or (char >= 0x1F3FB and char <= 0x1F3FF) then
                head, current = remove_node(head,current,true)
            else
                current = getnext(current)
            end
        else
            current = getnext(current)
        end
    end
    return head
end

-- attributes

local function checkedemoji(name,id)
    local str = resolvedemoji(name)
    if str then
        if not id then
            id = currentfont()
        end
        local head = tonodes(str,id,nil,nil,true) -- use current attributes
        head = processfeatures(head,id,false)
        if head then
            head = injectspacing(head)
            protectglyphs(head)
            return removemodifiers(head)
        end
    end
end

symbols.emoji = {
    resolved = resolvedemoji,
    checked  = checkedemoji,
}

interfaces.implement {
    name      = "resolvedemoji",
    actions   = { resolvedemoji, context.escaped },
    arguments = "string",
}

interfaces.implement {
    name      = "checkedemoji",
    actions   = { checkedemoji, context },
    arguments = "string",
}


