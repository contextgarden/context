if not modules then modules = { } end modules ['node-acc'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local nodes, node = nodes, node

local nodecodes          = nodes.nodecodes
local tasks              = nodes.tasks

local nuts               = nodes.nuts
local tonut              = nodes.tonut
local tonode             = nodes.tonode

local getid              = nuts.getid
local getfield           = nuts.getfield
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

----- traverse_nodes     = nuts.traverse
local traverse_id        = nuts.traverse_id
----- copy_node          = nuts.copy
local insert_after       = nuts.insert_after
local copy_no_components = nuts.copy_no_components

local glue_code          = nodecodes.glue
----- kern_code          = nodecodes.kern
local glyph_code         = nodecodes.glyph
local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist

local a_characters       = attributes.private("characters")

local threshold          = 65536 -- not used
local nofreplaced        = 0

-- todo: nbsp etc
-- todo: collapse kerns (not needed, backend does this)
-- todo: maybe cache as we now create many nodes
-- todo: check for subtype related to spacing (13/14 but most seems to be user anyway)

local function injectspaces(head)
    local p, p_id
    local n = head
    while n do
        local id = getid(n)
        if id == glue_code then
            if p and getid(p) == glyph_code then
                -- unless we don't care about the little bit of overhead
                -- we can just: local g = copy_node(g)
                local g = copy_no_components(p)
                local a = getattr(n,a_characters)
                setchar(g,32)
                setlink(p,g,n)
                setwidth(n,getwidth(n) - getwidth(g))
                if a then
                    setattr(g,a_characters,a)
                end
                setattr(n,a_characters,0)
                nofreplaced = nofreplaced + 1
            end
        elseif id == hlist_code or id == vlist_code then
            injectspaces(getlist(n),attribute)
        end
        p_id = id
        p = n
        n = getnext(n)
    end
    return head, true -- always done anyway
end

nodes.handlers.accessibility = function(head)
    local head, done = injectspaces(tonut(head))
    return tonode(head), done
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
--     for n in traverse_id(glyph_code,n) do
--         t[#t+1] = utfchar(getchar(n)) -- check for unicode
--     end
--     return concat(t,"")
-- end
--
-- local function injectspans(head)
--     local done = false
--     for n in traverse_nodes(tonuts(head)) do
--         local id = getid(n)
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
-- local pdfpageliteral = nuts.pool.pdfpageliteral
--
-- local function injectspans(head)
--     local done = false
--     for n in traverse_nodes(tonut(head)) do
--         local id = getid(n)
--         if id == disc then
--             local a = getattr(n,a_hyphenated)
--             if a then
--                 local str = codes[a]
--                 local b = pdfpageliteral(format("/Span << /ActualText %s >> BDC", lpdf.tosixteen(str)))
--                 local e = pdfpageliteral("EMC")
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
