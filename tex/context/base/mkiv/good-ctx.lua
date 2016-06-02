if not modules then modules = { } end modules ['good-ctx'] = {
    version   = 1.000,
    comment   = "companion to font-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- depends on ctx

local type, next, tonumber = type, next, tonumber
local find, splitup = string.find, string.splitup

local fonts              = fonts
local nodes              = nodes
local attributes         = attributes

----- trace_goodies      = false  trackers.register("fonts.goodies", function(v) trace_goodies = v end)
----- report_goodies     = logs.reporter("fonts","goodies")

local allocate           = utilities.storage.allocate
local setmetatableindex  = table.setmetatableindex

local implement          = interfaces.implement

local registerotffeature = fonts.handlers.otf.features.register
----- registerafmfeature = fonts.handlers.afm.features.register
----- registertfmfeature = fonts.handlers.tfm.features.register

local fontgoodies        = fonts.goodies or { }

local glyph_code         = nodes.nodecodes.glyph

local nuts               = nodes.nuts
local tonut              = nuts.tonut
local getfont            = nuts.getfont
local getchar            = nuts.getchar
local getattr            = nuts.getattr
local traverse_id        = nuts.traverse_id

-- colorschemes

local colorschemes       = fontgoodies.colorschemes or allocate { }
fontgoodies.colorschemes = colorschemes
colorschemes.data        = colorschemes.data or { }

local function setcolorscheme(tfmdata,scheme)
    if type(scheme) == "string" then
        local goodies = tfmdata.goodies
        -- todo : check for already defined in shared
        if goodies then
            local what
            for i=1,#goodies do
                -- last one counts
                local g = goodies[i]
                what = g.colorschemes and g.colorschemes[scheme] or what
            end
            if type(what) == "table" then
                -- this is font bound but we can share them if needed
                -- just as we could hash the conversions (per font)
                local hash       = tfmdata.resources.unicodes
                local reverse    = { }
                local characters = tfmdata.characters
                for i=1,#what do
                    local w = what[i]
                    for j=1,#w do
                        local name = w[j]
                        if name == "*" then
                            -- inefficient but only used for tracing anyway
                            for _, unicode in next, hash do
                                reverse[unicode] = i
                            end
                        elseif type(name) == "number" then
                            reverse[name] = i
                        elseif find(name,":",1,true) then
                            local start, stop = splitup(name,":")
                            start = tonumber(start)
                            stop  = tonumber(stop)
                            if start and stop then
                                -- limited usage: we only deal with non reassigned
                                -- maybe some day I'll also support the ones with a
                                -- tounicode in this range
                                for unicode=start,stop do
                                    if characters[unicode] then
                                        reverse[unicode] = i
                                    end
                                end
                            end
                        else
                            local unicode = hash[name]
                            if unicode then
                                reverse[unicode] = i
                            end
                        end
                    end
                end
                tfmdata.properties.colorscheme = reverse
                return
            end
        end
    end
    tfmdata.properties.colorscheme = false
end

local fontproperties = fonts.hashes.properties

local a_colorscheme  = attributes.private('colorscheme')
local setnodecolor   = nodes.tracers.colors.set

-- function colorschemes.coloring(head)
--     local lastfont, lastscheme
--     local done = false
--     for n in traverse_id(glyph_code,tonut(head)) do
--         local a = getattr(n,a_colorscheme)
--         if a then
--             local f = getfont(n)
--             if f ~= lastfont then
--                 lastscheme = fontproperties[f].colorscheme
--                 lastfont   = f
--             end
--             if lastscheme then
--                 local sc = lastscheme[getchar(n)]
--                 if sc then
--                     done = true
--                     setnodecolor(n,"colorscheme:"..a..":"..sc) -- slow
--                 end
--             end
--         end
--     end
--     return head, done
-- end

-- seldom used, mostly in manuals, so non critical .. anyhow, somewhat faster:

-- function colorschemes.coloring(head)
--     local lastfont   = nil
--     local lastattr   = nil
--     local lastscheme = nil
--     local lastprefix = nil
--     local done       = nil
--     for n in traverse_id(glyph_code,tonut(head)) do
--         local a = getattr(n,a_colorscheme)
--         if a then
--             if a ~= lastattr then
--                 lastattr   = a
--                 lastprefix = "colorscheme:" .. a .. ":"
--             end
--             local f = getfont(n)
--             if f ~= lastfont then
--                 lastfont   = f
--                 lastscheme = fontproperties[f].colorscheme
--             end
--             if lastscheme then
--                 local sc = lastscheme[getchar(n)]
--                 if sc then
--                     setnodecolor(n,lastprefix .. sc) -- slow
--                     done = true
--                 end
--             end
--         end
--     end
--     return head, done
-- end

-- ok, in case we have hundreds of pages colored:

local cache = { } -- this could be a weak table

setmetatableindex(cache,function(t,a)
    local v = { }
    setmetatableindex(v,function(t,c)
        local v = "colorscheme:" .. a .. ":" .. c
        t[c] = v
        return v
    end)
    t[a]= v
    return v
end)

function colorschemes.coloring(head)
    local lastfont   = nil
    local lastattr   = nil
    local lastcache  = nil
    local lastscheme = nil
    local done       = nil
    for n in traverse_id(glyph_code,tonut(head)) do
        local a = getattr(n,a_colorscheme)
        if a then
            local f = getfont(n)
            if f ~= lastfont then
                lastfont   = f
                lastscheme = fontproperties[f].colorscheme
            end
            if a ~= lastattr then
                lastattr  = a
                lastcache = cache[a]
            end
            if lastscheme then
                local sc = lastscheme[getchar(n)]
                if sc then
                    setnodecolor(n,lastcache[sc]) -- we could inline this one
                    done = true
                end
            end
        end
    end
    return head, done
end

function colorschemes.enable()
    nodes.tasks.appendaction("processors","fonts","fonts.goodies.colorschemes.coloring")
    function colorschemes.enable() end
end

registerotffeature {
    name        = "colorscheme",
    description = "goodie color scheme",
    initializers = {
        base = setcolorscheme,
        node = setcolorscheme,
    }
}

-- kern hackery:
--
-- yes  : use goodies table
-- auto : assume features to be set (often ccmp only)

local function setkeepligatures(tfmdata)
    if not tfmdata.properties.keptligatures then
        local goodies = tfmdata.goodies
        if goodies then
            for i=1,#goodies do
                local g = goodies[i]
                local letterspacing = g.letterspacing
                if letterspacing then
                    local keptligatures = letterspacing.keptligatures
                    if keptligatures then
                        local unicodes = tfmdata.resources.unicodes -- so we accept names
                        local hash = { }
                        for k, v in next, keptligatures do
                            local u = unicodes[k]
                            if u then
                                hash[u] = true
                            else
                                -- error: unknown name
                            end
                        end
                        tfmdata.properties.keptligatures = hash
                    end
                end
            end
        end
    end
end

registerotffeature {
    name         = "keepligatures",
    description  = "keep ligatures in letterspacing",
    initializers = {
        base = setkeepligatures,
        node = setkeepligatures,
    }
}

if implement then

    implement {
        name      = "enablefontcolorschemes",
        onlyonce  = true,
        actions   = colorschemes.enable,
        overload  = true, -- for now, permits new font loader
    }

end
