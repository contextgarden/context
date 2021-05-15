if not modules then modules = { } end modules ['font-phb'] = {
    version   = 1.000, -- 2016.10.10,
    comment   = "companion to font-txt.mkiv",
    original  = "derived from a prototype by Kai Eigner",
    author    = "Hans Hagen", -- so don't blame KE
    copyright = "TAT Zetwerk / PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- The next code is a rewrite of Kai's prototype. Here we forget about components
-- and assume some sane data structures. Clusters are handled on the fly. This is
-- probably one of the places where generic and context code is (to be) different
-- anyway. All errors in the logic below are mine (Hans). The optimizations probably
-- make less sense in luajittex because there the interpreter does some optimization
-- but we may end up with a non-jit version some day.
--
-- For testing I used the commandline tool as this code is not that critital and not
-- used in context for production (maybe for testing). I noticed some issues with
-- r2l shaping of latin but the uniscribe shaper seems better with that but as it's
-- a library we're supposed to treat it as a magic black box and not look into it. In
-- the end all will be sorted out I guess so we don't need to worry about it. Also, I
-- can always improve the code below if really needed.
--
-- We create intermediate tables which might look inefficient. For instance we could
-- just return two tables or an iterator but in the end this is not the bottleneck.
-- In fact, speed is hard to measure anyway, as it depends on the font, complexity
-- of the text, etc. Sometimes the library is faster, sometimes the context Lua one
-- (which is interesting as it does a bit more, i.e. supports additional features,
-- which also makes it even harder to check). When we compare context mkiv runs with
-- mkii runs using pdftex or xetex (which uses harfbuzz) the performance of luatex
-- on (simple) font demos normally is significant less compared with pdftex (8 bit
-- and no unicode) but a bit better than xetex. It looks like the interface that gets
-- implemented here suits that pattern (keep in mind that especially discretionary
-- handling is quite complex and similar to the context mkiv variant).
--
-- The main motivations for supporting this are (1) the fact that Kai spent time on
-- it, and (2) that we can compare the Lua variant with uniscribe, which is kind of
-- a reference. We started a decade ago (2006) with the Lua implementation and had
-- to rely on MSWord for comparison. On the other hand, the command line version is
-- also useable for that. Don't blame the library or its (maybe wrong) use (here)
-- for side effects.
--
-- Currently there are two methods: (1) binary, which is slow and uses the command
-- line shaper and (2) the ffi binding. In the meantime I redid the feed-back-into-
-- the-node-list method. This way tracing is easier, performance better, and there
-- is no need to mess so much with spacing. I have no clue if I lost functionality
-- and as this is not production code issues probably will go unnoticed for a while.
-- We'll see.
--
-- Usage: see m-fonts-plugins.mkiv as that is the interface.
--
-- Remark: It looks like the library sets up some features by default. Passing them
-- somehow doesn't work (yet) so I must miss something here. There is something fishy
-- here with enabling features like init, medi, fina etc because when we turn them on
-- they aren't applied. Also some features are not processed.
--
-- Remark: Because utf32 is fragile I append a couple of zero slots which seems to
-- work out ok. In fact, after some experiment I figured out that utf32 needs a list
-- of 4 byte cardinals. From the fact that Kai used the utf8 method I assumed that
-- there was a utf32 too and indeed that worked but I have no time to look into it
-- more deeply. It seems to work ok though.
--
-- The plugin itself has plugins and we do it the same as with (my)sql support, i.e.
-- we provide methods. The specific methods are implemented in the imp files. We
-- follow that model with other libraries too.
--
-- Somehow the command line version does uniscribe (usp10.dll) but not the library
-- so when I can get motivated I might write a binding for uniscribe. (Problem: I
-- don't look forward to decipher complex (c++) library api's so in the end it might
-- never happen. A quick glance at the usp10 api gives me the impression that the
-- apis don't differ that much, but still.)
--
-- Warning: This is rather old code, cooked up in the second half of 2016. I'm not
-- sure if it will keep working because it's not used in production and therefore
-- doesn't get tested. It was written as part of some comparison tests for Idris,
-- who wanted to compare the ConTeXt handler, uniscribe and hb, for which there are
-- also some special modules (that show results alongside). It has never been tested
-- in regular documents. As it runs independent of the normal font processors there
-- is probably not that much risk of interference but of course one looses all the
-- goodies that have been around for a while (or will show up in the future). The
-- code can probably be optimized a bit.

-- There are three implementation specific files:
--
-- 1  font-phb-imp-binary.lua   : calls the command line version of hb
-- 2  font-phb-imp-library.lua  : uses ffi to interface to hb
-- 3  font-phb-imp-internal.lua : uses a small library to interface to hb
--
-- Variants 1 and 2 should work with mkiv and were used when playing with these
-- things, when writing the articles, and when running some tests for Idris font
-- development. Variant 3 (and maybe 1 also works) is meant for lmtx and has not
-- been used (read: tested) so far. The 1 and 2 variants are kind of old, but 3 is
-- an adaptation of 2 so not hip and modern either.

if not context then
    return
end

local next, tonumber, pcall, rawget = next, tonumber, pcall, rawget

local concat        = table.concat
local sortedhash    = table.sortedhash
local formatters    = string.formatters

local fonts         = fonts
local otf           = fonts.handlers.otf
local texthandler   = otf.texthandler

local fontdata      = fonts.hashes.identifiers

local nuts          = nodes.nuts
local tonode        = nuts.tonode
local tonut         = nuts.tonut

local remove_node   = nuts.remove

local getboth       = nuts.getboth
local getnext       = nuts.getnext
local setnext       = nuts.setnext
local getprev       = nuts.getprev
local setprev       = nuts.setprev
local getid         = nuts.getid
local getchar       = nuts.getchar
local setchar       = nuts.setchar
local setlink       = nuts.setlink
local setoffsets    = nuts.setoffsets
----- getcomponents = nuts.getcomponents
----- setcomponents = nuts.setcomponents
local getwidth      = nuts.getwidth
local setwidth      = nuts.setwidth

local copy_node     = nuts.copy
local find_tail     = nuts.tail

local nodepool      = nuts.pool
local new_kern      = nodepool.fontkern
local new_glyph     = nodepool.glyph

local nodecodes     = nodes.nodecodes
local glyph_code    = nodecodes.glyph
local glue_code     = nodecodes.glue

local skipped = {
    -- we assume that only valid features are set but maybe we need a list
    -- of valid hb features as there can be many context specific ones
    mode     = true,
    features = true,
    language = true,
    script   = true,
}

local seenspaces = {
    [0x0020] = true,
    [0x00A0] = true,
    [0x0009] = true, -- indeed
    [0x000A] = true, -- indeed
    [0x000D] = true, -- indeed
}

-- helpers

local helpers     = { }
local methods     = { }
local initialized = { } -- we don't polute the shared table

local method      = "library"
local shaper      = "native"   -- "uniscribe"
local report      = logs.reporter("font plugin","hb")

utilities.hb = {
    methods = methods,
    helpers = helpers,
    report  = report,
}

do

    local toutf8 = utf.char
    local space  = toutf8(0x20)

    -- we can move this to the internal lib .. just pass a table .. but it is not faster

    function helpers.packtoutf8(text,leading,trailing)
        local size = #text
        for i=1,size do
            text[i] = toutf8(text[i])
        end
        if leading then
            text[0] = space
        end
        if trailing then
            text[size+1] = space
        end
        return concat(text,"",leading and 0 or 1,trailing and (size + 1) or size)
    end

    local toutf32 = utf.toutf32string
    local space   = toutf32(0x20)

    function helpers.packtoutf32(text,leading,trailing)
        local size = #text
        for i=1,size do
            text[i] = toutf32(text[i])
        end
        if leading then
            text[0] = space
        end
        if trailing then
            text[size+1] = space
        end
        return concat(text,"",leading and 0 or 1,trailing and (size + 1) or size)
    end

end

local function initialize(font)

    local tfmdata      = fontdata[font]
    local resources    = tfmdata.resources
    local shared       = tfmdata.shared
    local filename     = resources.filename
    local features     = shared.features
    local descriptions = shared.rawdata.descriptions
    local characters   = tfmdata.characters
    local featureset   = { }
    local copytochar   = shared.copytochar -- indextounicode
    local spacewidth   = nil -- unscaled
    local factor       = tfmdata.parameters.factor
    local marks        = resources.marks or { }

    -- could be shared but why care about a few extra tables

    if not copytochar then
        copytochar = { }
        -- let's make sure that we have an indexed table and not a hash
        local max = 0
        for k, v in next, descriptions do
            if v.index > max then
                max = v.index
            end
        end
        for i=0,max do
            copytochar[i] = i
        end
        -- the normal mapper
        for k, v in next, descriptions do
            copytochar[v.index] = k
        end
        shared.copytochar = copytochar
    end

    -- independent from loop as we have unordered hashes

    if descriptions[0x0020] then
        spacewidth = descriptions[0x0020].width
    elseif descriptions[0x00A0] then
        spacewidth = descriptions[0x00A0].width
    end

    for k, v in sortedhash(features) do
        if #k > 4 then
            -- unknown ones are ignored anyway but we can assume that the current
            -- (and future) extra context features use more verbose names
        elseif skipped[k] then
            -- we don't want to pass language and such so we block a few features
            -- explicitly
        elseif v == "yes" or v == true then
            featureset[#featureset+1] = k .. "=1"     -- cf command line (false)
        elseif v == "no" or v == false then
            featureset[#featureset+1] = k .. "=0"     -- cf command line (true)
        elseif type(v) == "number" then
            featureset[#featureset+1] = k .. "=" .. v -- cf command line (alternate)
        else
            -- unset
        end
    end

    local data = {
        language   = features.language, -- do we need to uppercase and padd to 4 ?
        script     = features.script,   -- do we need to uppercase and padd to 4 ?
        features   = #featureset > 0 and concat(featureset,",") or "", -- hash
        featureset = #featureset > 0 and featureset or nil,
        copytochar = copytochar,
        spacewidth = spacewidth,
        filename   = filename,
        marks      = marks,
        factor     = factor,
        characters = characters, -- the loaded font (we use its metrics which is more accurate)
        method     = features.method or method,
        shaper     = features.shaper or shaper,
    }
    initialized[font] = data
    return data
end

-- In many cases this gives compatible output but especially with respect to spacing and user
-- discretionaries that mix fonts there can be different outcomes. We also have no possibility
-- to tweak and cheat. Of course one can always run a normal node mode pass with specific
-- features first but then one can as well do all in node mode. So .. after a bit of playing
-- around I redid this one from scratch and also added tracing.

local trace_colors  = false  trackers.register("fonts.plugins.hb.colors", function(v) trace_colors  = v end)
local trace_details = false  trackers.register("fonts.plugins.hb.details",function(v) trace_details = v end)
local check_id      = false
----- components    = false -- we have no need for them

local setcolor      = function() end
local resetcolor    = function() end

if context then
    setcolor   = nodes.tracers.colors.set
    resetcolor = nodes.tracers.colors.reset
end

table.setmetatableindex(methods,function(t,k)
    local l = "font-phb-imp-" .. k .. ".lua"
    report("start loading method %a from %a",k,l)
    dofile(resolvers.findfile(l))
    local v = rawget(t,k)
    if v then
        report("loading method %a succeeded",k)
    else
        report("loading method %a failed",k)
        v = function() return { } end
    end
    t[k] = v
    return v
end)

local inandout  do

    local utfbyte = utf.byte
    local utfchar = utf.char
    local utf3208 = utf.utf32_to_utf8_le

    inandout = function(text,result,first,last,copytochar)
        local s = { }
        local t = { }
        local r = { }
        local f = formatters["%05U"]
        for i=1,#text do
            local c = text[i]
         -- t[#t+1] = f(utfbyte(utf3208(c)))
            s[#s+1] = utfchar(c)
            t[#t+1] = f(c)
        end
        for i=first,last do
            r[#r+1] = f(copytochar[result[i][1]])
        end
        return s, t, r
    end

end

local function harfbuzz(head,font,attr,rlmode,start,stop,text,leading,trailing)
    local data = initialized[font]

    if not data then
        data = initialize(font)
    end

    if check_id then
        if getid(start) ~= glyph_code then
            report("error: start is not a glyph")
            return head
        elseif getid(stop) ~= glyph_code then
            report("error: stop is not a glyph")
            return head
        end
    end
    local size   = #text -- original text, without spaces
    local result = methods[data.method](font,data,rlmode,text,leading,trailing)
    local length = result and #result or 0

    if length == 0 then
     -- report("warning: no result")
        return head
    end

    local factor     = data.factor
    local marks      = data.marks
    local spacewidth = data.spacewidth
    local copytochar = data.copytochar
    local characters = data.characters

    -- the text analyzer is only partially clever so we must assume that we get
    -- inconsistent lists

    -- we could check if something has been done (replacement or kern or so) but
    -- then we pass around more information and need to check a lot and spaces
    -- are kind of spoiling that game (we need a different table then) .. more
    -- pain than gain

    -- we could play with 0xFFFE as boundary

    local current  = start
    local prev     = nil
    local glyph    = nil

    local first    = 1
    local last     = length
    local next     = nil -- todo: keep track of them
    local prev     = nil -- todo: keep track of them

    if leading then
        first = first + 1
    end
    if trailing then
        last = last - 1
    end

    local position = first
    local cluster  = 0
    local glyph    = nil
    local index    = 0
    local count    = 1
 -- local runner   = nil
    local saved    = nil

    if trace_details then
        report("start run, original size: %i, result index: %i upto %i",size,first,last)
        local s, t, r = inandout(text,result,first,last,copytochar)
        report("method : %s",data.method)
        report("shaper : %s",data.shaper)
        report("string : %t",s)
        report("text   : % t",t)
        report("result : % t",r)
    end

    -- okay, after some experiments, it became clear that more complex code aimed at
    -- optimization doesn't pay off as complexity also demands more testing

    for i=first,last do
        local r = result[i]
        local unicode = copytochar[r[1]] -- can be private of course
        --
        cluster = r[2] + 1 -- starts at zero
        --
        if position == cluster then
            if i == first then
                index = 1
                if trace_details then
                    report("[%i] position: %i, cluster: %i, index: %i, starting",i,position,cluster,index)
                end
            else
                index = index + 1
                if trace_details then
                    report("[%i] position: %i, cluster: %i, index: %i, next step",i,position,cluster,index)
                end
            end
        elseif position < cluster then
            -- a new cluster
            current  = getnext(current)
            position = position + 1
            size     = size - 1
         -- if runner then
         --     local h, t
         --     if saved then
         --         h = copy_node(runner)
         --         if trace_colors then
         --             resetcolor(h)
         --         end
         --         setchar(h,saved)
         --         t = h
         --         if trace_details then
         --             report("[%i] position: %i, cluster: %i, index: -, initializing components",i,position,cluster)
         --         end
         --     else
         --         h = getcomponents(runner)
         --         t = find_tail(h)
         --     end
         --     for p=position,cluster-1 do
         --         local n
         --         head, current, n = remove_node(head,current)
         --         setlink(t,n)
         --         t = n
         --         if trace_details then
         --             report("[%i] position: %i, cluster: %i, index: -, moving node to components",i,p,cluster)
         --         end
         --         size = size - 1
         --     end
         --     if saved then
         --         setcomponents(runner,h)
         --         saved = false
         --     end
         -- else
                for p=position,cluster-1 do
                    head, current = remove_node(head,current,true)
                    if trace_details then
                        report("[%i] position: %i, cluster: %i, index: -, removing node",i,p,cluster)
                    end
                    size = size - 1
                end
         -- end
            position = cluster
            index    = 1
            glyph    = nil
            if trace_details then
                report("[%i] position: %i, cluster: %i, index: %i, arriving",i,cluster,position,index)
            end
        else -- maybe a space got properties
            if trace_details then
                report("position: %i, cluster: %i, index: %i, quitting due to fatal inconsistency",position,cluster,index)
            end
            return head
        end
        local copied = false
        if glyph then
            if trace_details then
                report("[%i] position: %i, cluster: %i, index: %i, copying glyph, unicode %U",i,position,cluster,index,unicode)
            end
            local g = copy_node(glyph)
            if trace_colors then
                resetcolor(g)
            end
            setlink(current,g,getnext(current))
            current = g
            copied  = true
        else
            if trace_details then
                report("[%i] position: %i, cluster: %i, index: %i, using glyph, unicode %U",i,position,cluster,index,unicode)
            end
            glyph = current
        end
        --
        if not current then
            if trace_details then
                report("quitting due to unexpected end of node list")
            end
            return head
        end
        --
        local id = getid(current)
        if id ~= glyph_code then
            if trace_details then
                report("glyph expected in node list")
            end
            return head
        end
        --
        -- really, we can get a tab (9), lf (10), or cr(13) back in cambria .. don't ask me why
        --
        local prev, next = getboth(current)
        --
        -- assign glyph: first in run
        --
     -- if components and index == 1 then
     --     runner = current
     --     saved  = getchar(current)
     --     if saved ~= unicode then
     --         setchar(current,unicode) -- small optimization
     --         if trace_colors then
     --             count = (count == 8) and 1 or count + 1
     --             setcolor(current,"trace:"..count)
     --         end
     --     end
     -- else
            setchar(current,unicode)
            if trace_colors then
                count = (count == 8) and 1 or count + 1
                setcolor(current,"trace:"..count)
            end
     -- end
        --
        local x_offset  = r[3] -- r.dx
        local y_offset  = r[4] -- r.dy
        local x_advance = r[5] -- r.ax
        ----- y_advance = r[6] -- r.ay
        local left  = 0
        local right = 0
        local dx    = 0
        local dy    = 0
        if trace_details then
            if x_offset ~= 0 or y_offset ~= 0 or x_advance ~= 0 then -- or y_advance ~= 0
                report("[%i] position: %i, cluster: %i, index: %i, old, xoffset: %p, yoffset: %p, xadvance: %p, width: %p",
                    i,position,cluster,index,x_offset*factor,y_offset*factor,x_advance*factor,characters[unicode].width)
            end
        end
        if y_offset ~= 0 then
            dy = y_offset * factor
        end
        if rlmode >= 0 then
            -- l2r marks and rest
            if x_offset ~= 0 then
                dx = x_offset * factor
            end
            local width = characters[unicode].width
            local delta = x_advance * factor
            if delta ~= width then
             -- right = -(delta - width)
                right = delta - width
            end
        elseif marks[unicode] then -- why not just the next loop
            -- r2l marks
            if x_offset ~= 0 then
                dx = -x_offset * factor
            end
        else
            -- r2l rest
            local width = characters[unicode].width
            local delta = (x_advance - x_offset) * factor
            if delta ~= width then
                left = delta - width
            end
            if x_offset ~= 0 then
                right = x_offset * factor
            end
        end
        if copied or dx ~= 0 or dy ~= 0 then
            setoffsets(current,dx,dy)
        end
        if left ~= 0 then
            setlink(prev,new_kern(left),current) -- insertbefore
            if current == head then
                head = prev
            end
        end
        if right ~= 0 then
            local kern = new_kern(right)
            setlink(current,kern,next)
            current = kern
        end
        if trace_details then
            if dy ~= 0 or dx ~= 0 or left ~= 0 or right ~= 0 then
                report("[%i] position: %i, cluster: %i, index: %i, new, xoffset: %p, yoffset: %p, left: %p, right: %p",i,position,cluster,index,dx,dy,left,right)
            end
        end
    end
    --
    if trace_details then
        report("[-] position: %i, cluster: %i, index: -, at end",position,cluster)
    end
    if size > 1 then
        current = getnext(current)
     -- if runner then
     --     local h, t
     --     if saved then
     --         h = copy_node(runner)
     --         if trace_colors then
     --             resetcolor(h)
     --         end
     --         setchar(h,saved)
     --         t = h
     --         if trace_details then
     --             report("[-] position: %i, cluster: -, index: -, initializing components",position)
     --         end
     --     else
     --         h = getcomponents(runner)
     --         t = find_tail(h)
     --     end
     --     for i=1,size-1 do
     --         if trace_details then
     --             report("[-] position: %i + %i, cluster: -, index: -, moving node to components",position,i)
     --         end
     --         local n
     --         head, current, n = remove_node(head,current,true)
     --         setlink(t,n)
     --         t = n
     --     end
     --     if saved then
     --         setcomponents(runner,h)
     --         saved = false
     --     end
     -- else
            for i=1,size-1 do
                if trace_details then
                    report("[-] position: %i + %i, cluster: -, index: -, removing node",position,i)
                end
                head, current = remove_node(head,current,true)
            end
     -- end
    end
    --
    -- We see all kind of interesting spaces come back (like tabs in cambria) so we do a bit of
    -- extra testing here.
    --
    if leading then
        local r = result[1]
        local unicode = copytochar[r[1]]
        if seenspaces[unicode] then
            local x_advance = r[5]
            local delta     = x_advance - spacewidth
            if delta ~= 0 then
                -- nothing to do but jump one slot ahead
                local prev = getprev(start)
                if getid(prev) == glue_code then
                    local dx = delta * factor
                    setwidth(prev,getwidth(prev) + dx)
                    if trace_details then
                        report("compensating leading glue by %p due to codepoint %U",dx,unicode)
                    end
                else
                    report("no valid leading glue node")
                end
            end
        end
    end
    --
    if trailing then
        local r = result[length]
        local unicode = copytochar[r[1]]
        if seenspaces[unicode] then
            local x_advance = r[5]
            local delta     = x_advance - spacewidth
            if delta ~= 0 then
                local next = getnext(stop)
                if getid(next) == glue_code then
                    local dx = delta * factor
                    setwidth(next,getwidth(next) + dx)
                    if trace_details then
                        report("compensating trailing glue by %p due to codepoint %U",dx,unicode)
                    end
                else
                    report("no valid trailing glue node")
                end
            end
        end
    end
    --
    if trace_details then
        report("run done")
    end
    return head
end

otf.registerplugin("harfbuzz",function(head,font,attr,direction)
    return texthandler(head,font,attr,direction,harfbuzz)
end)
