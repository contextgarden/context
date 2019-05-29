if not modules then modules = { } end modules ['node-scn'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local floor = math.floor

local attributes         = attributes
local nodes              = nodes

local nuts               = nodes.nuts

local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getid              = nuts.getid
local getattr            = nuts.getattr
local getsubtype         = nuts.getsubtype
local getlist            = nuts.getlist
local setlist            = nuts.setlist

local end_of_math        = nuts.end_of_math

local nodecodes          = nodes.nodecodes
local leadercodes        = nodes.leadercodes
local gluecodes          = nodes.gluecodes
local kerncodes          = nodes.kerncodes

local glyph_code         = nodecodes.glyph
local disc_code          = nodecodes.disc
local rule_code          = nodecodes.rule
local boundary_code      = nodecodes.boundary
local dir_code           = nodecodes.dir
local math_code          = nodecodes.math
local glue_code          = nodecodes.glue
local penalty_code       = nodecodes.penalty
local kern_code          = nodecodes.kern
local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist

local userskip_code      = gluecodes.userskip
local spaceskip_code     = gluecodes.spaceskip
local xspaceskip_code    = gluecodes.xspaceskip

local leaders_code       = leadercodes.leaders

local fontkern_code      = kerncodes.fontkern

local variables          = interfaces.variables

local privateattributes  = attributes.private

local a_runningtext      = privateattributes('runningtext')

local v_yes              = variables.yes
local v_all              = variables.all

local function striprange(first,last) -- todo: dir
    if first and last then -- just to be sure
        if first == last then
            return first, last
        end
        while first and first ~= last do
            local id = getid(first)
            if id == glyph_code or id == disc_code or id == dir_code or id == boundary_code then -- or id == rule_code
                break
            else
                first = getnext(first)
            end
        end
        if not first then
            return nil, nil
        elseif first == last then
            return first, last
        end
        while last and last ~= first do
            local id = getid(last)
            if id == glyph_code or id == disc_code or id == dir_code or id == boundary_code  then -- or id == rule_code
                break
            else
                local prev = getprev(last) -- luatex < 0.70 has italic correction kern not prev'd
                if prev then
                    last = prev
                else
                    break
                end
            end
        end
        if not last then
            return nil, nil
        end
    end
    return first, last
end

nuts.striprange = striprange

-- todo: order and maybe other dimensions

-- we can use this one elsewhere too
--
-- todo: functions: word, sentence
--
-- glyph rule unset whatsit glue margin_kern kern math disc

-- we assume {glyphruns} and no funny extra kerning, ok, maybe we need
-- a dummy character as start and end; anyway we only collect glyphs
--
-- this one needs to take layers into account (i.e. we need a list of
-- critical attributes)

-- omkeren class en level -> scheelt functie call in analyze

-- todo: switching inside math

-- handlers

local function processwords(attribute,data,flush,head,parent,skip) -- we have hlistdir and local dir
    local n = head
    if n then
        local f, l, a, d, i, class
        local continue, leaders, done, strip, level = false, false, false, true, -1
        while n do
            local id = getid(n)
            if id == glyph_code or id == rule_code or (id == hlist_code and getattr(n,a_runningtext)) then
                local aa = getattr(n,attribute)
                if aa and aa ~= skip then
                    if aa == a then
                        if not f then -- ?
                            f = n
                        end
                        l = n
                    else
                        -- possible extensions: when in same class then keep spanning
                        local newlevel, newclass = floor(aa/1000), aa%1000 -- will be configurable
                     -- strip = not continue or level == 1 -- 0
                        if f then
                            if class == newclass then -- and newlevel > level then
                                head, done = flush(head,f,l,d,level,parent,false), true
                            else
                                head, done = flush(head,f,l,d,level,parent,strip), true
                            end
                        end
                        f, l, a = n, n, aa
                        level, class = newlevel, newclass
                        d = data[class]
                        if d then
                            local c = d.continue
                            leaders = c == v_all
                            continue = leaders or c == v_yes
                        else
                            continue = true
                        end
                    end
                else
                    if f then
                        head, done = flush(head,f,l,d,level,parent,strip), true
                    end
                    f, l, a = nil, nil, nil
                end
                if id == hlist_code then
                    local list = getlist(n)
                    if list then
                        setlist(n,(processwords(attribute,data,flush,list,n,aa))) -- watch ()
                    end
                end
            elseif id == disc_code or id == boundary_code then
                if f then
                    l = n
                end
            elseif id == kern_code and getsubtype(n) == fontkern_code then
                if f then
                    l = n
                end
            elseif id == math_code then
                -- otherwise not consistent: a $b$ c vs a $b+c$ d etc
                -- we need a special (optional) go over math variant
                if f then
                    head, done = flush(head,f,l,d,level,parent,strip), true
                    f, l, a = nil, nil, nil
                end
            elseif id == hlist_code or id == vlist_code then
                if f then
                    head, done = flush(head,f,l,d,level,parent,strip), true
                    f, l, a = nil, nil, nil
                end
                local list = getlist(n)
                if list then
                    setlist(n,(processwords(attribute,data,flush,list,n,skip))) -- watch ()
                end
            elseif id == dir_code then -- only changes in dir, we assume proper boundaries
                if f then
                    l = n
                end
            elseif f then
                if continue then
                    if id == penalty_code then
                        l = n
                 -- elseif id == kern_code then
                 --     l = n
                    elseif id == glue_code then
                        -- catch \underbar{a} \underbar{a} (subtype test is needed)
                        local subtype = getsubtype(n)
                        if getattr(n,attribute) and (subtype == userskip_code or subtype == spaceskip_code or subtype == xspaceskip_code or (leaders and subtype >= leaders_code)) then
                            l = n
                        else
                            head, done = flush(head,f,l,d,level,parent,strip), true
                            f, l, a = nil, nil, nil
                        end
                    end
                else
                    head, done = flush(head,f,l,d,level,parent,strip), true
                    f, l, a = nil, nil, nil
                end
            end
            n = getnext(n)
        end
        if f then
            head, done = flush(head,f,l,d,level,parent,strip), true
        end
        return head, true -- todo: done
    else
        return head, false
    end
end

nuts.processwords = function(attribute,data,flush,head,parent) -- we have hlistdir and local dir
    return processwords(attribute,data,flush,head,parent)
end

-- works on lines !
-- todo: stack because skip can change when nested

local function processranges(attribute,flush,head,parent,depth,skip)
    local n = head
    if n then
        local f, l, a
        local done = false
        while n do
            local id = getid(n)
            if id == glyph_code or id == rule_code then
                local aa = getattr(n,attribute)
--                 if aa and (not skip or aa ~= skip) then
                if aa then
                    if aa == a then
                        if not f then
                            f = n
                        end
                        l = n
                    else
                        if f then
                            head, done = flush(head,f,l,a,parent,depth), true
                        end
                        f, l, a = n, n, aa
                    end
                else
                    if f then
                        head, done = flush(head,f,l,a,parent,depth), true
                    end
                    f, l, a = nil, nil, nil
                end
            elseif id == disc_code or id == boundary_code then
                if f then
                    l = n
                else
                    -- weird
                end
            elseif id == kern_code and getsubtype(n) == fontkern_code then
                if f then
                    l = n
                end
         -- elseif id == penalty_code then
            elseif id == glue_code then
                -- todo: leaders
            elseif id == hlist_code or id == vlist_code then
                local aa = getattr(n,attribute)
--                 if aa and (not skip or aa ~= skip) then
                if aa then
                    if aa == a then
                        if not f then
                            f = n
                        end
                        l = n
                    else
                        if f then
                            head, done = flush(head,f,l,a,parent,depth), true
                        end
                        f, l, a = n, n, aa
                    end
                else
                    if f then
                        head, done = flush(head,f,l,a,parent,depth), true
                    end
                    f, l, a = nil, nil, nil
                end
                local list = getlist(n)
                if list then
                    setlist(n,(processranges(attribute,flush,list,n,depth+1,aa)))
                end
            end
            n = getnext(n)
        end
        if f then
            head, done = flush(head,f,l,a,parent,depth), true
        end
        return head, done
    else
        return head, false
    end
end

nuts.processranges = function(attribute,flush,head,parent) -- we have hlistdir and local dir
    return processranges(attribute,flush,head,parent,0)
end
