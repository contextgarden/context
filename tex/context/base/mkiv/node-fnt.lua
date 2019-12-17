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

local trace_characters  = false  trackers.register("nodes.characters", function(v) trace_characters = v end)
local trace_fontrun     = false  trackers.register("nodes.fontrun",    function(v) trace_fontrun    = v end)
local trace_variants    = false  trackers.register("nodes.variants",   function(v) trace_variants   = v end)

-- bad namespace for directives

local force_discrun     = true   directives.register("nodes.discrun",      function(v) force_discrun     = v end)
local force_boundaryrun = true   directives.register("nodes.boundaryrun",  function(v) force_boundaryrun = v end)
local force_basepass    = true   directives.register("nodes.basepass",     function(v) force_basepass    = v end)
local keep_redundant    = false  directives.register("nodes.keepredundant",function(v) keep_redundant    = v end)

local report_fonts      = logs.reporter("fonts","processing")

local fonthashes        = fonts.hashes
local fontdata          = fonthashes.identifiers
local fontvariants      = fonthashes.variants
local fontmodes         = fonthashes.modes

local otf               = fonts.handlers.otf

local starttiming       = statistics.starttiming
local stoptiming        = statistics.stoptiming

local nodecodes         = nodes.nodecodes
local boundarycodes     = nodes.boundarycodes

local handlers          = nodes.handlers

local nuts              = nodes.nuts

local getid             = nuts.getid
local getsubtype        = nuts.getsubtype
local getdisc           = nuts.getdisc
local getnext           = nuts.getnext
local getprev           = nuts.getprev
local getboth           = nuts.getboth
local getdata           = nuts.getdata
local getglyphdata      = nuts.getglyphdata
----- getdisc           = nuts.getdisc

local setchar           = nuts.setchar
local setlink           = nuts.setlink
local setnext           = nuts.setnext
local setprev           = nuts.setprev

local isglyph           = nuts.isglyph -- unchecked
local ischar            = nuts.ischar  -- checked

----- traverse_id       = nuts.traverse_id
----- traverse_char     = nuts.traverse_char
local nextboundary      = nuts.traversers.boundary
local nextdisc          = nuts.traversers.disc
local nextchar          = nuts.traversers.char

local flush_node        = nuts.flush

local disc_code         = nodecodes.disc
local boundary_code     = nodecodes.boundary

local wordboundary_code = boundarycodes.word

local protect_glyphs    = nuts.protect_glyphs
local unprotect_glyphs  = nuts.unprotect_glyphs

local setmetatableindex = table.setmetatableindex

-- some tests with using an array of dynamics[id] and processes[id] demonstrated
-- that there was nothing to gain (unless we also optimize other parts)
--
-- maybe getting rid of the intermediate shared can save some time

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

-- -- -- this will go away
--
-- local disccodes          = nodes.disccodes
-- local explicitdisc_code  = disccodes.explicit
-- local automaticdisc_code = disccodes.automatic
-- local expanders          = nil
--
-- function fonts.setdiscexpansion(v)
--     if v == nil or v == true then
--         expanders = languages and languages.expanders
--     elseif type(v) == "table" then
--         expanders = v
--     else
--         expanders = false
--     end
-- end
--
-- function fonts.getdiscexpansion()
--     return expanders and true or false
-- end
--
-- fonts.setdiscexpansion(true)
--
-- -- -- till here

local function start_trace(head)
    run = run + 1
    report_fonts()
    report_fonts("checking node list, run %s",run)
    report_fonts()
    local n = head
    while n do
        local char, id = isglyph(n)
        if char then
            local font = id
            local attr = getglyphdata(n) or 0
            report_fonts("font %03i, dynamic %03i, glyph %C",font,attr,char)
        elseif id == disc_code then
            report_fonts("[disc] %s",nodes.listtoutf(n,true,false,n))
        elseif id == boundary_code then
            report_fonts("[boundary] %i:%i",getsubtype(n),getdata(n))
        else
            report_fonts("[%s]",nodecodes[id])
        end
        n = getnext(n)
    end
end

local function stop_trace(u,usedfonts,a,attrfonts,b,basefonts,r,redundant,e,expanders)
    report_fonts()
    report_fonts("statics : %s",u > 0 and concat(keys(usedfonts)," ") or "none")
    report_fonts("dynamics: %s",a > 0 and concat(keys(attrfonts)," ") or "none")
    report_fonts("built-in: %s",b > 0 and b or "none")
    report_fonts("removed : %s",r > 0 and r or "none")
 -- if expanders then
 --     report_fonts("expanded: %s",e > 0 and e or "none")
 -- end
    report_fonts()
end


do

    local usedfonts
    local attrfonts
    local basefonts  -- could be reused
    local basefont
    local prevfont
    local prevattr
    local variants
    local redundant  -- could be reused
    local firstnone
    local lastfont
    local lastproc
    local lastnone

    local a, u, b, r, e

    local function protectnone()
        protect_glyphs(firstnone,lastnone)
        firstnone = nil
    end

    local function setnone(n)
        if firstnone then
            protectnone()
        end
        if basefont then
            basefont[2] = getprev(n)
            basefont = false
        end
        if not firstnone then
            firstnone = n
        end
        lastnone = n
    end

    local function setbase(n)
        if firstnone then
            protectnone()
        end
        if force_basepass then
            if basefont then
                basefont[2] = getprev(n)
            end
            b = b + 1
            basefont = { n, false }
            basefonts[b] = basefont
        end
    end

    local function setnode(n,font,attr) -- we could use prevfont and prevattr when we set then first
        if firstnone then
            protectnone()
        end
        if basefont then
            basefont[2] = getprev(n)
            basefont = false
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
                end
            end
        else
            local used = usedfonts[font]
            if not used then
                lastfont = font
                lastproc = fontprocesses[font]
                if lastproc then
                    usedfonts[font] = lastproc
                    u = u + 1
                end
            end
        end
    end

    function handlers.characters(head,groupcode,size,packtype,direction)
        -- either next or not, but definitely no already processed list
        starttiming(nodes)

        usedfonts = { }
        attrfonts = { }
        basefonts = { }
        basefont  = nil
        prevfont  = nil
        prevattr  = 0
        variants  = nil
        redundant = nil
        firstnone = nil
        lastfont  = nil
        lastproc  = nil
        lastnone  = nil

        a, u, b, r, e = 0, 0, 0, 0, 0

        if trace_fontrun then
            start_trace(head)
        end

        -- There is no gain in checking for a single glyph and then having a fast path. On the
        -- metafun manual (with some 2500 single char lists) the difference is just noise.

        for n, char, font in nextchar, head do
         -- local attr = (none and prevattr) or getglyphdata(n) or 0 -- zero attribute is reserved for fonts in context
            local attr = getglyphdata(n) or 0 -- zero attribute is reserved for fonts in context
            if font ~= prevfont or attr ~= prevattr then
                prevfont = font
                prevattr = attr
                variants = fontvariants[font]
                local fontmode = fontmodes[font]
                if fontmode == "none" then
                    setnone(n)
                elseif fontmode == "base" then
                    setbase(n)
                else
                    setnode(n,font,attr)
                end
            elseif firstnone then
                lastnone = n
            end
            if variants then
                if (char >= 0xFE00 and char <= 0xFE0F) or (char >= 0xE0100 and char <= 0xE01EF) then
                    local hash = variants[char]
                    if hash then
                        local p = getprev(n)
                        if p then
                            local char    = ischar(p) -- checked
                            local variant = hash[char]
                            if variant then
                                if trace_variants then
                                    report_fonts("replacing %C by %C",char,variant)
                                end
                                setchar(p,variant)
                                if redundant then
                                    r = r + 1
                                    redundant[r] = n
                                else
                                    r = 1
                                    redundant = { n }
                                end
                            end
                        end
                    elseif keep_redundant then
                        -- go on, can be used for tracing
                    elseif redundant then
                        r = r + 1
                        redundant[r] = n
                    else
                        r = 1
                        redundant = { n }
                    end
                end
            end
        end

        if firstnone then
            protectnone()
        end

        if force_boundaryrun then

            -- we can inject wordboundaries and then let the hyphenator do its work
            -- but we need to get rid of those nodes in order to build ligatures
            -- and kern (a rather context thing)

            for b, subtype in nextboundary, head do
                if subtype == wordboundary_code then
                    if redundant then
                        r = r + 1
                        redundant[r] = b
                    else
                        r = 1
                        redundant = { b }
                    end
                end
            end

        end

        if redundant then
            for i=1,r do
                local r = redundant[i]
                local p, n = getboth(r)
                if r == head then
                    head = n
                    setprev(n)
                else
                    setlink(p,n)
                end
                if b > 0 then
                    for i=1,b do
                        local bi = basefonts[i]
                        local b1 = bi[1]
                        local b2 = bi[2]
                        if b1 == b2 then
                            if b1 == r then
                                bi[1] = false
                                bi[2] = false
                            end
                        elseif b1 == r then
                            bi[1] = n
                        elseif b2 == r then
                            bi[2] = p
                        end
                    end
                end
                flush_node(r)
            end
        end

        if force_discrun then

            -- basefont is not supported in disc only runs ... it would mean a lot of
            -- ranges .. we could try to run basemode as a separate processor run but
            -- not for now (we can consider it when the new node code is tested
            for d in nextdisc, head do
                -- we could use first_glyph, only doing replace is good enough because
                -- pre and post are normally used for hyphens and these come from fonts
                -- that part of the hyphenated word
                local _, _, r = getdisc(d)
                if r then
                    local prevfont = nil
                    local prevattr = nil
                    local none     = false
                    firstnone = nil
                    basefont  = nil
                    for n, char, font in nextchar, r do
                        local attr = getglyphdata(n) or 0 -- zero attribute is reserved for fonts in context
                        if font ~= prevfont or attr ~= prevattr then
                            prevfont = font
                            prevattr = attr
                            local fontmode = fontmodes[font]
                            if fontmode == "none" then
                                setnone(n)
                            elseif fontmode == "base" then
                                -- so the replace gets an extra treatment ... so be it
                                setbase(n)
                            else
                                setnode(n,font,attr)
                            end
                        elseif firstnone then
                         -- lastnone = n
                            lastnone = nil
                        end
                        -- we assume one font for now (and if there are more and we get into issues then
                        -- we can always remove the break)
                        break
                    end
                    if firstnone then
                        protectnone()
                    end
             -- elseif expanders then
             --     local subtype = getsubtype(d)
             --     if subtype == automaticdisc_code or subtype == explicitdisc_code then
             --         expanders[subtype](d)
             --         e = e + 1
             --     end
                end
            end

        end

        if trace_fontrun then
            stop_trace(u,usedfonts,a,attrfonts,b,basefonts,r,redundant,e,expanders)
        end

        -- in context we always have at least 2 processors
        if u == 0 then
            -- skip
        elseif u == 1 then
            local attr = a > 0 and 0 or false -- 0 is the savest way
            for i=1,#lastproc do
                head = lastproc[i](head,lastfont,attr,direction)
            end
        else
         -- local attr = a == 0 and false or 0 -- 0 is the savest way
            local attr = a > 0 and 0 or false -- 0 is the savest way
            for font, processors in next, usedfonts do -- unordered
                for i=1,#processors do
                    head = processors[i](head,font,attr,direction,u)
                end
            end
        end
        if a == 0 then
            -- skip
        elseif a == 1 then
            local font, dynamics = next(attrfonts)
            for attribute, processors in next, dynamics do -- unordered, attr can switch in between
                for i=1,#processors do
                    head = processors[i](head,font,attribute,direction)
                end
            end
        else
            for font, dynamics in next, attrfonts do
                for attribute, processors in next, dynamics do -- unordered, attr can switch in between
                    for i=1,#processors do
                        head = processors[i](head,font,attribute,direction,a)
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
                local front = head == start
                if stop then
                    start = ligaturing(start,stop)
                    start = kerning(start,stop)
                elseif start then -- safeguard
                    start = ligaturing(start)
                    start = kerning(start)
                end
                if front and head ~= start then
                    head = start
                end
            end
        else
            -- multiple fonts
            for i=1,b do
                local range = basefonts[i]
                local start = range[1]
                local stop  = range[2]
                if start then -- and start ~= stop but that seldom happens
                    local front = head == start
                    local prev  = getprev(start)
                    local next  = getnext(stop)
                    if stop then
                        start, stop = ligaturing(start,stop)
                        start, stop = kerning(start,stop)
                    else
                        start = ligaturing(start)
                        start = kerning(start)
                    end
                    -- is done automatically
                    if prev then
                        setlink(prev,start)
                    end
                    if next then
                        setlink(stop,next)
                    end
                    -- till here
                    if front and head ~= start then
                        head = start
                    end
                end
            end
        end

        stoptiming(nodes)

        if trace_characters then
            nodes.report(head)
        end

        return head
    end

end

handlers.protectglyphs   = protect_glyphs
handlers.unprotectglyphs = unprotect_glyphs
