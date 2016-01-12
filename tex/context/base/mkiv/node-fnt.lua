if not modules then modules = { } end modules ['node-fnt'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

if not context then os.exit() end -- generic function in node-dum

local next, type = next, type
local concat, keys = table.concat, table.keys

local nodes, node, fonts = nodes, node, fonts

local trace_characters  = false  trackers  .register("nodes.characters",    function(v) trace_characters = v end)
local trace_fontrun     = false  trackers  .register("nodes.fontrun",       function(v) trace_fontrun    = v end)
local trace_variants    = false  trackers  .register("nodes.variants",      function(v) trace_variants   = v end)

local force_discrun     = true   directives.register("nodes.discrun",       function(v) force_discrun    = v end)
local force_basepass    = true   directives.register("nodes.basepass",      function(v) force_basepass   = v end)

local report_fonts      = logs.reporter("fonts","processing")

local fonthashes        = fonts.hashes
local fontdata          = fonthashes.identifiers
local fontvariants      = fonthashes.variants
local fontmodes         = fonthashes.modes

local otf               = fonts.handlers.otf

local starttiming       = statistics.starttiming
local stoptiming        = statistics.stoptiming

local nodecodes         = nodes.nodecodes
local handlers          = nodes.handlers

local nuts              = nodes.nuts
local tonut             = nuts.tonut
local tonode            = nuts.tonode

local getattr           = nuts.getattr
local getid             = nuts.getid
local getfont           = nuts.getfont
local getsubtype        = nuts.getsubtype
local getchar           = nuts.getchar
local getnext           = nuts.getnext
local getprev           = nuts.getprev
local getfield          = nuts.getfield
----- getdisc           = nuts.getdisc
local setchar           = nuts.setchar
local setlink           = nuts.setlink
local setfield          = nuts.setfield

local traverse_id       = nuts.traverse_id
local traverse_char     = nuts.traverse_char
local delete_node       = nuts.delete
local protect_glyph     = nuts.protect_glyph

local glyph_code        = nodecodes.glyph
local disc_code         = nodecodes.disc

local setmetatableindex = table.setmetatableindex

-- some tests with using an array of dynamics[id] and processes[id] demonstrated
-- that there was nothing to gain (unless we also optimize other parts)
--
-- maybe getting rid of the intermediate shared can save some time

-- potential speedup: check for subtype < 256 so that we can remove that test
-- elsewhere, danger: injected nodes will not be dealt with but that does not
-- happen often; we could consider processing sublists but that might need more
-- checking later on; the current approach also permits variants

local run = 0

local setfontdynamics = { }
local fontprocesses   = { }

-- setmetatableindex(setfontdynamics, function(t,font)
--     local tfmdata = fontdata[font]
--     local shared = tfmdata.shared
--     local v = shared and shared.dynamics and otf.setdynamics or false
--     t[font] = v
--     return v
-- end)

setmetatableindex(setfontdynamics, function(t,font)
    local tfmdata = fontdata[font]
    local shared = tfmdata.shared
    local f = shared and shared.dynamics and otf.setdynamics or false
    if f then
        local v = { }
        t[font] = v
        setmetatableindex(v,function(t,k)
            local v = f(font,k)
            t[k] = v
            return v
        end)
        return v
    else
        t[font] = false
        return false
    end
end)

setmetatableindex(fontprocesses, function(t,font)
    local tfmdata = fontdata[font]
    local shared = tfmdata.shared -- we need to check shared, only when same features
    local processes = shared and shared.processes
    if processes and #processes > 0 then
        t[font] = processes
        return processes
    else
        t[font] = false
        return false
    end
end)

fonts.hashes.setdynamics = setfontdynamics
fonts.hashes.processes   = fontprocesses

-- if we forget about basemode we don't need to test too much here and we can consider running
-- over sub-ranges .. this involves a bit more initializations but who cares .. in that case we
-- also need to use the stop criterium (we already use head too) ... we cannot use traverse
-- then, so i'll test it on some local clone first ... the only pitfall is changed directions
-- inside a run which means that we need to keep track of this which in turn complicates matters
-- in a way i don't like

-- we need to deal with the basemode fonts here and can only run over ranges as we
-- otherwise get luatex craches due to all kind of asserts in the disc/lig builder

local ligaturing = nuts.ligaturing
local kerning    = nuts.kerning

local expanders

function fonts.setdiscexpansion(v)
    if v == nil or v == true then
        expanders = languages and languages.expanders
    elseif type(v) == "table" then
        expanders = v
    else
        expanders = false
    end
end

function fonts.getdiscexpansion()
    return expanders and true or false
end

fonts.setdiscexpansion(true)

function handlers.characters(head)
    -- either next or not, but definitely no already processed list
    starttiming(nodes)

    local usedfonts = { }
    local attrfonts = { }
    local basefonts = { }
    local a, u, b   = 0, 0, 0
    local basefont  = nil
    local prevfont  = nil
    local prevattr  = 0
    local mode      = nil
    local done      = false
    local variants  = nil
    local redundant = nil

    if trace_fontrun then
        run = run + 1
        report_fonts()
        report_fonts("checking node list, run %s",run)
        report_fonts()
        local n = tonut(head)
        while n do
            local id = getid(n)
            if id == glyph_code then
                local font = getfont(n)
                local attr = getattr(n,0) or 0
                report_fonts("font %03i, dynamic %03i, glyph %C",font,attr,getchar(n))
            elseif id == disc_code then
                report_fonts("[disc] %s",nodes.listtoutf(n,true,false,n))
            else
                report_fonts("[%s]",nodecodes[id])
            end
            n = getnext(n)
        end
    end

    local nuthead = tonut(head)

    for n in traverse_char(nuthead) do
        local font = getfont(n)
        local attr = getattr(n,0) or 0 -- zero attribute is reserved for fonts in context
        if font ~= prevfont or attr ~= prevattr then
            prevfont = font
            prevattr = attr
            mode     = fontmodes[font] -- we can also avoid the attr check
            variants = fontvariants[font]
            if mode == "none" then
                -- skip
                protect_glyph(n)
            else
                if basefont then
                    basefont[2] = getprev(n)
                end
                if attr > 0 then
                    local used = attrfonts[font]
                    if not used then
                        used = { }
                        attrfonts[font] = used
                    end
                    if not used[attr] then
                        local fd = setfontdynamics[font]
                        if fd then
                            used[attr] = fd[attr]
                            a = a + 1
                        elseif force_basepass then
                            b = b + 1
                            basefont = { n, nil }
                            basefonts[b] = basefont
                        end
                    end
                else
                    local used = usedfonts[font]
                    if not used then
                        local fp = fontprocesses[font]
                        if fp then
                            usedfonts[font] = fp
                            u = u + 1
                        elseif force_basepass then
                            b = b + 1
                            basefont = { n, nil }
                            basefonts[b] = basefont
                        end
                    end
                end
            end
        end
        if variants then
            local char = getchar(n)
            if char >= 0xFE00 and (char <= 0xFE0F or (char >= 0xE0100 and char <= 0xE01EF)) then
                local hash = variants[char]
                if hash then
                    local p = getprev(n)
                    if p and getid(p) == glyph_code then
                        local char    = getchar(p)
                        local variant = hash[char]
                        if variant then
                            if trace_variants then
                                report_fonts("replacing %C by %C",char,variant)
                            end
                            setchar(p,variant)
                            if not redundant then
                                redundant = { n }
                            else
                                redundant[#redundant+1] = n
                            end
                        end
                    end
                end
            end
        end
    end

    if redundant then
        for i=1,#redundant do
            delete_node(nuthead,n)
        end
    end

    -- could be an optional pass : seldom needed, only for documentation as a discretionary
    -- with pre/post/replace will normally not occur on it's own

    local e = 0

    if force_discrun then

        -- basefont is not supported in disc only runs ... it would mean a lot of
        -- ranges .. we could try to run basemode as a separate processor run but
        -- not for now (we can consider it when the new node code is tested

     -- local prevfont  = nil
     -- local prevattr  = 0

        for d in traverse_id(disc_code,nuthead) do
            -- we could use first_glyph
            local r = getfield(d,"replace") -- good enough
            if r then
                for n in traverse_char(r) do
                    local font = getfont(n)
                    local attr = getattr(n,0) or 0 -- zero attribute is reserved for fonts in context
                    if font ~= prevfont or attr ~= prevattr then
                        if attr > 0 then
                            local used = attrfonts[font]
                            if not used then
                                used = { }
                                attrfonts[font] = used
                            end
                            if not used[attr] then
                                local fd = setfontdynamics[font]
                                if fd then
                                    used[attr] = fd[attr]
                                    a = a + 1
                                end
                            end
                        else
                            local used = usedfonts[font]
                            if not used then
                                local fp = fontprocesses[font]
                                if fp then
                                    usedfonts[font] = fp
                                    u = u + 1
                                end
                            end
                        end
                        prevfont = font
                        prevattr = attr
                    end
                end
                break
            elseif expanders then
                local subtype = getsubtype(d)
                if subtype == discretionary_code then
                    -- already done when replace
                else
                    expanders[subtype](d)
                    e = e + 1
                end
            end
        end

    end

    if trace_fontrun then
        report_fonts()
        report_fonts("statics : %s",u > 0 and concat(keys(usedfonts)," ") or "none")
        report_fonts("dynamics: %s",a > 0 and concat(keys(attrfonts)," ") or "none")
        report_fonts("built-in: %s",b > 0 and b                           or "none")
    if expanders then
        report_fonts("expanded: %s",e > 0 and e                           or "none")
    end
        report_fonts()
    end
    -- in context we always have at least 2 processors
    if u == 0 then
        -- skip
    elseif u == 1 then
        local font, processors = next(usedfonts)
        for i=1,#processors do
            local h, d = processors[i](head,font,0)
            if d then
                head = h or head
                done = true
            end
        end
    else
        for font, processors in next, usedfonts do
            for i=1,#processors do
                local h, d = processors[i](head,font,0)
                if d then
                    head = h or head
                    done = true
                end
            end
        end
    end
    if a == 0 then
        -- skip
    elseif a == 1 then
        local font, dynamics = next(attrfonts)
        for attribute, processors in next, dynamics do -- attr can switch in between
            for i=1,#processors do
                local h, d = processors[i](head,font,attribute)
                if d then
                    head = h or head
                    done = true
                end
            end
        end
    else
        for font, dynamics in next, attrfonts do
            for attribute, processors in next, dynamics do -- attr can switch in between
                for i=1,#processors do
                    local h, d = processors[i](head,font,attribute)
                    if d then
                        head = h or head
                        done = true
                    end
                end
            end
        end
    end
    if b == 0 then
        -- skip
    elseif b == 1 then
        -- only one font
        local range = basefonts[1]
        local start = range[1]
        local stop  = range[2]
        if (start or stop) and (start ~= stop) then
            local front = nuthead == start
            if stop then
                start, stop = ligaturing(start,stop)
                start, stop = kerning(start,stop)
            elseif start then -- safeguard
                start = ligaturing(start)
                start = kerning(start)
            end
            if front then
                head = tonode(start)
            end
        end
    else
        -- multiple fonts
        local front = nuthead == start
        for i=1,b do
            local range = basefonts[i]
            local start = range[1]
            local stop  = range[2]
            if (start or stop) and (start ~= stop) then
                local prev, next
                if stop then
                    next = getnext(stop)
                    start, stop = ligaturing(start,stop)
                    start, stop = kerning(start,stop)
                elseif start then -- safeguard
                    prev  = getprev(start)
                    start = ligaturing(start)
                    start = kerning(start)
                end
                if prev then
                    setlink(prev,start)
                end
                if next then
                    setlink(stop,next)
                end
                if front then
                    nuthead  = start
                    front = nil -- we assume a proper sequence
                end
            end
            if front then
                -- shouldn't happen
                nuthead = start
            end
        end
        if front then
            head = tonode(nuthead)
        end
    end
    stoptiming(nodes)
    if trace_characters then
        nodes.report(head,done)
    end
    return head, true
end

--     local formatters = string.formatters

--     local function make(processors,font,attribute)
--         _G.__temp = processors
--         local t = { }
--         for i=1,#processors do
--             if processors[i] then
--                 t[#t+1] = formatters["local p_%s = _G.__temp[%s]"](i,i)
--             end
--         end
--         t[#t+1] = "return function(head,done)"
--         if #processors == 1 then
--             t[#t+1] = formatters["return p_%s(head,%s,%s)"](1,font,attribute or 0)
--         else
--             for i=1,#processors do
--                 if processors[i] then
--                     t[#t+1] = formatters["local h,d=p_%s(head,%s,%s) if d then head=h or head done=true end"](i,font,attribute or 0)
--                 end
--             end
--             t[#t+1] = "return head, done"
--         end
--         t[#t+1] = "end"
--         t = concat(t,"\n")
--         t = load(t)(processors)
--         _G.__temp = nil
--         return t
--     end

--     setmetatableindex(fontprocesses, function(t,font)
--         local tfmdata = fontdata[font]
--         local shared = tfmdata.shared -- we need to check shared, only when same features
--         local processes = shared and shared.processes
--         if processes and #processes > 0 then
--             processes = make(processes,font,0)
--             t[font] = processes
--             return processes
--         else
--             t[font] = false
--             return false
--         end
--     end)

--     setmetatableindex(setfontdynamics, function(t,font)
--         local tfmdata = fontdata[font]
--         local shared = tfmdata.shared
--         local f = shared and shared.dynamics and otf.setdynamics or false
--         if f then
--             local v = { }
--             t[font] = v
--             setmetatableindex(v,function(t,k)
--                 local v = f(font,k)
--                 v = make(v,font,k)
--                 t[k] = v
--                 return v
--             end)
--             return v
--         else
--             t[font] = false
--             return false
--         end
--     end)
--
--     -- TODO: basepasses!
--
--     function handlers.characters(head)
--         -- either next or not, but definitely no already processed list
--         starttiming(nodes)
--         local usedfonts, attrfonts
--         local a, u, prevfont, prevattr, done = 0, 0, nil, 0, false
--         if trace_fontrun then
--             run = run + 1
--             report_fonts()
--             report_fonts("checking node list, run %s",run)
--             report_fonts()
--             local n = head
--             while n do
--                 local id = n.id
--                 if id == glyph_code then
--                     local font = n.font
--                     local attr = n[0] or 0
--                     report_fonts("font %03i, dynamic %03i, glyph %s",font,attr,utf.char(n.char))
--                 else
--                     report_fonts("[%s]",nodecodes[n.id])
--                 end
--                 n = n.next
--             end
--         end
--         for n in traverse_id(glyph_code,head) do
--          -- if n.subtype<256 then -- all are 1
--             local font = n.font
--             local attr = n[0] or 0 -- zero attribute is reserved for fonts in context
--             if font ~= prevfont or attr ~= prevattr then
--                 if attr > 0 then
--                     if not attrfonts then
--                         attrfonts = {
--                             [font] = {
--                                 [attr] = setfontdynamics[font][attr]
--                             }
--                         }
--                         a = 1
--                     else
--                         local used = attrfonts[font]
--                         if not used then
--                             attrfonts[font] = {
--                                 [attr] = setfontdynamics[font][attr]
--                             }
--                             a = a + 1
--                         elseif not used[attr] then
--                             used[attr] = setfontdynamics[font][attr]
--                             a = a + 1
--                         end
--                     end
--                 else
--                     if not usedfonts then
--                         local fp = fontprocesses[font]
--                         if fp then
--                             usedfonts = {
--                                 [font] = fp
--                             }
--                             u = 1
--                         end
--                     else
--                         local used = usedfonts[font]
--                         if not used then
--                             local fp = fontprocesses[font]
--                             if fp then
--                                 usedfonts[font] = fp
--                                 u = u + 1
--                             end
--                         end
--                     end
--                 end
--                 prevfont = font
--                 prevattr = attr
--                 variants = fontvariants[font]
--             end
--             if variants then
--                 local char = getchar(n)
--                 if char >= 0xFE00 and (char <= 0xFE0F or (char >= 0xE0100 and char <= 0xE01EF)) then
--                     local hash = variants[char]
--                     if hash then
--                         local p = getprev(n)
--                         if p and getid(p) == glyph_code then
--                             local variant = hash[getchar(p)]
--                             if variant then
--                                 setchar(p,variant)
--                                 delete_node(nuthead,n)
--                             end
--                         end
--                     end
--                 end
--             end
--             end
--         -- end
--         end
--         if trace_fontrun then
--             report_fonts()
--             report_fonts("statics : %s",(u > 0 and concat(keys(usedfonts)," ")) or "none")
--             report_fonts("dynamics: %s",(a > 0 and concat(keys(attrfonts)," ")) or "none")
--             report_fonts()
--         end
--         if not usedfonts then
--             -- skip
--         elseif u == 1 then
--             local font, processors = next(usedfonts)
--             head, done = processors(head,done)
--         else
--             for font, processors in next, usedfonts do
--                 head, done = processors(head,done)
--             end
--         end
--         if not attrfonts then
--             -- skip
--         elseif a == 1 then
--             local font, dynamics = next(attrfonts)
--             for attribute, processors in next, dynamics do
--                 head, done = processors(head,done)
--             end
--         else
--             for font, dynamics in next, attrfonts do
--                 for attribute, processors in next, dynamics do
--                     head, done = processors(head,done)
--                 end
--             end
--         end
--         stoptiming(nodes)
--         if trace_characters then
--             nodes.report(head,done)
--         end
--         return head, true
--     end

local d_protect_glyphs   = nuts.protect_glyphs
local d_unprotect_glyphs = nuts.unprotect_glyphs

handlers.protectglyphs   = function(n) return d_protect_glyphs  (tonut(n)) end
handlers.unprotectglyphs = function(n) return d_unprotect_glyphs(tonut(n)) end

-- function handlers.protectglyphs(h)
--     local h = tonut(h)
--     for n in traverse_id(disc_code,h) do
--         local pre, post, replace = getdisc(n)
--         if pre     then d_protect_glyphs(pre)     end
--         if post    then d_protect_glyphs(post)    end
--         if replace then d_protect_glyphs(replace) end
--     end
--     return d_protect_glyphs(h)
-- end
