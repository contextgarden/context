if not modules then modules = { } end modules ['node-acc'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local nodes, node = nodes, node

local tasks              = nodes.tasks

local nuts               = nodes.nuts
local tonut              = nodes.tonut
local tonode             = nodes.tonode

local getid              = nuts.getid
local getsubtype         = nuts.getsubtype
local getattr            = nuts.getattr
local getlist            = nuts.getlist
local getchar            = nuts.getchar
local getnext            = nuts.getnext

local setattr            = nuts.setattr
local setlink            = nuts.setlink
local setchar            = nuts.setchar
local setsubtype         = nuts.setsubtype
local getwidth           = nuts.getwidth
local setwidth           = nuts.setwidth

local nextglyph          = nuts.traversers.glyph
local nextnode           = nuts.traversers.node

----- copy_node          = nuts.copy
local insert_after       = nuts.insert_after
local copy_no_components = nuts.copy_no_components

local nodecodes          = nodes.nodecodes
local gluecodes          = nodes.gluecodes

local glue_code          = nodecodes.glue
----- kern_code          = nodecodes.kern
local glyph_code         = nodecodes.glyph
local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist

local userskip_code      = gluecodes.user
local spaceskip_code     = gluecodes.spaceskip
local xspaceskip_code    = gluecodes.xspaceskip

local a_characters       = attributes.private("characters")

local nofreplaced        = 0

-- todo: nbsp etc
-- todo: collapse kerns (not needed, backend does this)
-- todo: maybe cache as we now create many nodes
-- todo: check for subtype related to spacing (13/14 but most seems to be user anyway)

local trace = false   trackers.register("backend.spaces", function(v) trace = v end)
local slot  = nil

local function injectspaces(head)
    local p, p_id
    local n = head
    while n do
        local id = getid(n)
        if id == glue_code then
            if p and getid(p) == glyph_code then
                local s = getsubtype(n)
                if s == spaceskip_code or s == xspaceskip_code then
                    -- unless we don't care about the little bit of overhead
                    -- we can just: local g = copy_node(g)
                    local g = copy_no_components(p)
                    local a = getattr(n,a_characters)
                    setchar(g,slot)
                    setlink(p,g,n)
                    setwidth(n,getwidth(n) - getwidth(g))
                 -- setsubtype(n,userskip_code)
                    if a then
                        setattr(g,a_characters,a)
                    end
                    setattr(n,a_characters,0)
                    nofreplaced = nofreplaced + 1
                end
            end
        elseif id == hlist_code or id == vlist_code then
            injectspaces(getlist(n),slot)
        end
        p_id = id
        p = n
        n = getnext(n)
    end
    return head
end

nodes.handlers.accessibility = function(head)
    if trace then
        if not slot then
            slot = fonts.helpers.privateslot("visualspace")
        end
    else
        slot = 32
    end
    return injectspaces(head,slot)
end

statistics.register("inserted spaces in output",function()
    if nofreplaced > 0 then
        return nofreplaced
    end
end)

-- todo:

-- local a_hyphenated = attributes.private('hyphenated')
--
-- local hyphenated, codes = { }, { }
--
-- local function compact(n)
--     local t = { }
--     for n in nextglyph, n do
--         t[#t+1] = utfchar(getchar(n)) -- check for unicode
--     end
--     return concat(t,"")
-- end
--
-- local function injectspans(head)
--     local done = false
--     for n, id in nextnode, tonuts(head) do
--         if id == disc then
--             local r = getfield(n,"replace")
--             local p = getfield(n,"pre")
--             if r and p then
--                 local str = compact(r)
--                 local hsh = hyphenated[str]
--                 if not hsh then
--                     hsh = #codes + 1
--                     hyphenated[str] = hsh
--                     codes[hsh] = str
--                 end
--                 setattr(n,a_hyphenated,hsh)
--                 done = true
--             end
--         elseif id == hlist_code or id == vlist_code then
--             injectspans(getlist(n))
--         end
--     end
--     return tonodes(head), done
-- end
--
-- nodes.injectspans = injectspans
--
-- tasks.appendaction("processors", "words", "nodes.injectspans")
--
-- local pageliteral = nuts.pool.pageliteral
--
-- local function injectspans(head)
--     local done = false
--     for n, id in nextnode, tonut(head) do
--         if id == disc then
--             local a = getattr(n,a_hyphenated)
--             if a then
--                 local str = codes[a]
--                 local b = pageliteral(format("/Span << /ActualText %s >> BDC", lpdf.tosixteen(str)))
--                 local e = pageliteral("EMC")
--                 insert_before(head,n,b)
--                 insert_after(head,n,e)
--                 done = true
--             end
--         elseif id == hlist_code or id == vlist_code then
--             injectspans(getlist(n))
--         end
--     end
--     return tonodes(head), done
-- end
