if node.count then
    return
end

local type = type

local node     = node
local direct   = node.direct
local todirect = direct.tovaliddirect
local tonode   = direct.tonode

local count  = direct.count
local length = direct.length
local slide  = direct.slide

function node.count(id,first,last)
    return count(id,first and todirect(first), last and todirect(last) or nil)
end

function node.length(first,last)
    return length(first and todirect(first), last and todirect(last) or nil)
end

function node.slide(n)
    if n then
        n = slide(todirect(n))
        if n then
            return tonode(n)
        end
    end
    return nil
end

local hyphenating = direct.hyphenating
local ligaturing  = direct.ligaturing
local kerning     = direct.kerning

-- kind of inconsistent

function node.hyphenating(first,last)
    if first then
        local h, t = hyphenating(todirect(first), last and todirect(last) or nil)
        return h and tonode(h) or nil, t and tonode(t) or nil, true
    else
        return nil, false
    end
end

function node.ligaturing(first,last)
    if first then
        local h, t = ligaturing(todirect(first), last and todirect(last) or nil)
        return h and tonode(h) or nil, t and tonode(t) or nil, true
    else
        return nil, false
    end
end

function node.kerning(first,last)
    if first then
        local h, t = kerning(todirect(first), last and todirect(last) or nil)
        return h and tonode(h) or nil, t and tonode(t) or nil, true
    else
        return nil, false
    end
 end

local protect_glyph    = direct.protect_glyph
local unprotect_glyph  = direct.unprotect_glyph
local protect_glyphs   = direct.protect_glyphs
local unprotect_glyphs = direct.unprotect_glyphs

function node.protect_glyphs(first,last)
    protect_glyphs(todirect(first), last and todirect(last) or nil)
end

function node.unprotect_glyphs(first,last)
    unprotect_glyphs(todirect(first), last and todirect(last) or nil)
end

function node.protect_glyph(first)
    protect_glyph(todirect(first))
end

function node.unprotect_glyph(first)
    unprotect_glyph(todirect(first))
end

local flatten_discretionaries = direct.flatten_discretionaries
local check_discretionaries   = direct.check_discretionaries
local check_discretionary     = direct.check_discretionary

function node.flatten_discretionaries(first)
    local h, count = flatten_discretionaries(todirect(first))
    return tonode(h), count
end

function node.check_discretionaries(n)
    check_discretionaries(todirect(n))
end

function node.check_discretionary(n)
    check_discretionary(todirect(n))
end

local hpack         = direct.hpack
local vpack         = direct.vpack
local list_to_hlist = direct.mlist_to_hlist

function node.hpack(head,...)
    local h, badness = hpack(head and todirect(head) or nil,...)
    return tonode(h), badness
end

function node.vpack(head,...)
    local h, badness = vpack(head and todirect(head) or nil,...)
    return tonode(h), badness
end

function node.mlist_to_hlist(head,...)
    return tonode(mlist_to_hlist(head and todirect(head) or nil,...))
end

local end_of_math    = direct.end_of_math
local find_attribute = direct.find_attribute
local first_glyph    = direct.first_glyph

function node.end_of_math(n)
    if n then
        n = end_of_math(todirect(n))
        if n then
            return tonode(n)
        end
    end
    return nil
end

function node.find_attribute(n,a)
    if n then
        local v, n = find_attribute(todirect(n),a)
        if n then
            return v, tonode(n)
        end
    end
    return nil
end

function node.first_glyph(first,last)
    local n = first_glyph(todirect(first), last and todirect(last) or nil)
    return n and tonode(n) or nil
end

local dimensions      = direct.dimensions
local rangedimensions = direct.rangedimensions
local effective_glue  = direct.effective_glue

function node.dimensions(a,b,c,d,e)
    if type(a) == "userdata" then
        a = todirect(a)
        if type(b) == "userdata" then
            b = todirect(b)
        end
        return dimensions(a,b)
    else
        d = todirect(d)
        if type(e) == "userdata" then
            e = todirect(e)
        end
        return dimensions(a,b,c,d,e)
    end
    return 0, 0, 0
end

function node.rangedimensions(parent,first,last)
    return rangedimenensions(todirect(parent),todirect(first),last and todirect(last))
end

function node.effective_glue(list,parent)
    return effective_glue(list and todirect(list) or nil,parent and todirect(parent) or nil)
end

local uses_font            = direct.uses_font
local has_glyph            = direct.has_glyph
local protrusion_skippable = direct.protrusion_skippable
local prepend_prevdepth    = direct.prepend_prevdepth
local make_extensible      = direct.make_extensible

function node.uses_font(n,f)
    return uses_font(todirect(n),f)
end

function node.has_glyph(n)
    return has_glyph(todirect(n))
end

function node.protrusion_skippable(n)
    return protrusion_skippable(todirect(n))
end

function node.prepend_prevdepth(n)
    local n, d = prepend_prevdepth(todirect(n))
    return tonode(n), d
end

function node.make_extensible(...)
    local n = make_extensible(...)
    return n and tonode(n) or nil
end

local last_node = direct.last_node

function node.last_node()
    local n = last_node()
    return n and tonode(n) or nil
end

local is_zero_glue = direct.is_zero_glue
local getglue      = direct.getglue
local setglue      = direct.setglue

function node.is_zero_glue(n)
    return is_zero_glue(todirect(n))
end

function node.get_glue(n)
    return get_glue(todirect(n))
end

function node.set_glue(n)
    return set_glue(todirect(n))
end

node.family_font = tex.getfontoffamily
