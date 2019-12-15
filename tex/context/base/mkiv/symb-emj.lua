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

local nuts            = nodes.nuts
local tonode          = nuts.tonode
local tonut           = nuts.tonut
local remove_node     = nuts.remove
local isglyph         = nuts.isglyph
local getnext         = nuts.getnext

local function removemodifiers(head)
    local head    = tonut(head)
    local current = head
    while current do
        local char, id = isglyph(current)
        if char and char == 0x200D or (char >= 0x1F3FB and char <= 0x1F3FF) then
            head, current = remove_node(head,current,true)
        else
            current = getnext(current)
        end
    end
    return tonode(head)
end

-- fast enough, no need to memoize, maybe use attributes

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


