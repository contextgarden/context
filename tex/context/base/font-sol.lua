if not modules then modules = { } end modules ['font-sol'] = { -- this was: node-spl
    version   = 1.001,
    comment   = "companion to font-sol.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This module is dedicated to the oriental tex project and for
-- the moment is too experimental to be publicly supported.
--
-- We could cache solutions: say that we store the featureset and
-- all 'words' -> replacement ... so we create a large solution
-- database (per font)
--
-- This module can be optimized by using a dedicated dynamics handler
-- but I'll only do that when the rest of the code is stable.
--
-- Todo: bind setups to paragraph.

local gmatch, concat, format, remove = string.gmatch, table.concat, string.format, table.remove
local next, tostring, tonumber = next, tostring, tonumber
local insert, remove = table.insert, table.remove
local utfchar = utf.char
local random = math.random

local utilities, logs, statistics, fonts, trackers = utilities, logs, statistics, fonts, trackers
local interfaces, commands, attributes = interfaces, commands, attributes
local nodes, node, tex = nodes, node, tex

local trace_split        = false  trackers.register("builders.paragraphs.solutions.splitters.splitter",  function(v) trace_split    = v end)
local trace_optimize     = false  trackers.register("builders.paragraphs.solutions.splitters.optimizer", function(v) trace_optimize = v end)
local trace_colors       = false  trackers.register("builders.paragraphs.solutions.splitters.colors",    function(v) trace_colors   = v end)
local trace_goodies      = false  trackers.register("fonts.goodies",                                     function(v) trace_goodies  = v end)

local report_solutions   = logs.reporter("fonts","solutions")
local report_splitters   = logs.reporter("fonts","splitters")
local report_optimizers  = logs.reporter("fonts","optimizers")

local variables          = interfaces.variables

local v_normal           = variables.normal
local v_reverse          = variables.reverse
local v_preroll          = variables.preroll
local v_random           = variables.random
local v_split            = variables.split

local implement          = interfaces.implement

local settings_to_array  = utilities.parsers.settings_to_array
local settings_to_hash   = utilities.parsers.settings_to_hash

local tasks              = nodes.tasks

local nuts               = nodes.nuts
local tonut              = nuts.tonut
local tonode             = nuts.tonode

local getfield           = nuts.getfield
local setfield           = nuts.setfield
local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getid              = nuts.getid
local getattr            = nuts.getattr
local setattr            = nuts.setattr
local getfont            = nuts.getfont
local getsubtype         = nuts.getsubtype
local getchar            = nuts.getchar
local getlist            = nuts.getlist

local find_node_tail     = nuts.tail
local free_node          = nuts.free
local free_nodelist      = nuts.flush_list
local copy_nodelist      = nuts.copy_list
local traverse_nodes     = nuts.traverse
local traverse_ids       = nuts.traverse_id
local hpack_nodes        = nuts.hpack
local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after
local protect_glyphs     = nuts.protect_glyphs

local repack_hlist       = nuts.repackhlist

local nodes_to_utf       = nodes.listtoutf

----- protect_glyphs     = nodes.handlers.protectglyphs

local setnodecolor       = nodes.tracers.colors.set

local nodecodes          = nodes.nodecodes
local whatsitcodes       = nodes.whatsitcodes
local kerncodes          = nodes.kerncodes

local glyph_code         = nodecodes.glyph
local disc_code          = nodecodes.disc
local kern_code          = nodecodes.kern
local hlist_code         = nodecodes.hlist
local dir_code           = nodecodes.dir or whatsitcodes.dir
local localpar_code      = nodecodes.localpar or whatsitcodes.localpar

local whatsit_code       = nodecodes.whatsit

local fontkern_code      = kerncodes.fontkern

local userdefined_code   = whatsitcodes.userdefined

local nodepool           = nuts.pool
local usernodeids        = nodepool.userids

local new_textdir        = nodepool.textdir
local new_usernumber     = nodepool.usernumber
local new_glue           = nodepool.glue
local new_leftskip       = nodepool.leftskip

local starttiming        = statistics.starttiming
local stoptiming         = statistics.stoptiming
----- process_characters = nodes.handlers.characters
local inject_kerns       = nodes.injections.handler

local fonthashes         = fonts.hashes
local fontdata           = fonthashes.identifiers
local setfontdynamics    = fonthashes.setdynamics
local fontprocesses      = fonthashes.processes

local texsetattribute    = tex.setattribute
local unsetvalue         = attributes.unsetvalue

local parbuilders        = builders.paragraphs
parbuilders.solutions    = parbuilders.solutions or { }
local parsolutions       = parbuilders.solutions
parsolutions.splitters   = parsolutions.splitters or { }
local splitters          = parsolutions.splitters

local solutions          = { } -- attribute sets
local registered         = { } -- backmapping
splitters.registered     = registered

local a_split            = attributes.private('splitter')

local preroll            = true
local criterium          = 0
local randomseed         = nil
local optimize           = nil -- set later
local variant            = v_normal
local splitwords         = true

local cache              = { }
local variants           = { }
local max_less           = 0
local max_more           = 0

local stack              = { }

local dummy              = {
    attribute  = unsetvalue,
    randomseed = 0,
    criterium  = 0,
    preroll    = false,
    optimize   = nil,
    splitwords = false,
    variant    = v_normal,
}

local function checksettings(r,settings)
    local s = r.settings
    local method = settings_to_hash(settings.method or "")
    local optimize, preroll, splitwords
    for k, v in next, method do
        if k == v_preroll then
            preroll = true
        elseif k == v_split then
            splitwords = true
        elseif variants[k] then
            variant = k
            optimize = variants[k] -- last one wins
        end
    end
    r.randomseed = tonumber(settings.randomseed) or s.randomseed or r.randomseed or 0
    r.criterium  = tonumber(settings.criterium ) or s.criterium  or r.criterium  or 0
    r.preroll    = preroll or false
    r.splitwords = splitwords or false
    r.optimize   = optimize or s.optimize or r.optimize or variants[v_normal]
end

local function pushsplitter(name,settings)
    local r = name and registered[name]
    if r then
        if settings then
            checksettings(r,settings)
        end
    else
        r = dummy
    end
    insert(stack,r)
    -- brr
    randomseed = r.randomseed or 0
    criterium  = r.criterium  or 0
    preroll    = r.preroll    or false
    optimize   = r.optimize   or nil
    splitwords = r.splitwords or nil
    --
    texsetattribute(a_split,r.attribute)
    return #stack
end

local function popsplitter()
    remove(stack)
    local n = #stack
    local r = stack[n] or dummy
    --
    randomseed = r.randomseed or 0
    criterium  = r.criterium  or 0
    preroll    = r.preroll    or false
    optimize   = r.optimize   or nil
    --
    texsetattribute(a_split,r.attribute)
    return n
end

local contextsetups = fonts.specifiers.contextsetups

local function convert(featuresets,name,list)
    if list then
        local numbers = { }
        local nofnumbers = 0
        for i=1,#list do
            local feature = list[i]
            local fs = featuresets[feature]
            local fn = fs and fs.number
            if not fn then
                -- fall back on global features
                fs = contextsetups[feature]
                fn = fs and fs.number
            end
            if fn then
                nofnumbers = nofnumbers + 1
                numbers[nofnumbers] = fn
                if trace_goodies or trace_optimize then
                    report_solutions("solution %a of %a uses feature %a with number %s",i,name,feature,fn)
                end
            else
                report_solutions("solution %a of %a has an invalid feature reference %a",i,name,feature)
            end
        end
        return nofnumbers > 0 and numbers
    end
end

local function initialize(goodies)
    local solutions = goodies.solutions
    if solutions then
        local featuresets = goodies.featuresets
        local goodiesname = goodies.name
        if trace_goodies or trace_optimize then
            report_solutions("checking solutions in %a",goodiesname)
        end
        for name, set in next, solutions do
            set.less = convert(featuresets,name,set.less)
            set.more = convert(featuresets,name,set.more)
        end
    end
end

fonts.goodies.register("solutions",initialize)

function splitters.define(name,settings)
    local goodies  = settings.goodies
    local solution = settings.solution
    local less     = settings.less
    local more     = settings.more
    local less_set, more_set
    local l = less and settings_to_array(less)
    local m = more and settings_to_array(more)
    if goodies then
        goodies = fonts.goodies.load(goodies) -- also in tfmdata
        if goodies then
            local featuresets = goodies.featuresets
            local solution = solution and goodies.solutions[solution]
            if l and #l > 0 then
                less_set = convert(featuresets,name,less) -- take from settings
            else
                less_set = solution and solution.less -- take from goodies
            end
            if m and #m > 0 then
                more_set = convert(featuresets,name,more) -- take from settings
            else
                more_set = solution and solution.more -- take from goodies
            end
        end
    else
        if l then
            local n = #less_set
            for i=1,#l do
                local ss = contextsetups[l[i]]
                if ss then
                    n = n + 1
                    less_set[n] = ss.number
                end
            end
        end
        if m then
            local n = #more_set
            for i=1,#m do
                local ss = contextsetups[m[i]]
                if ss then
                    n = n + 1
                    more_set[n] = ss.number
                end
            end
        end
    end
    if trace_optimize then
        report_solutions("defining solutions %a, less %a, more %a",name,concat(less_set or {}," "),concat(more_set or {}," "))
    end
    local nofsolutions = #solutions + 1
    local t = {
        solution  = solution,
        less      = less_set or { },
        more      = more_set or { },
        settings  = settings, -- for tracing
        attribute = nofsolutions,
    }
    solutions[nofsolutions] = t
    registered[name] = t
    return nofsolutions
end

local nofwords, noftries, nofadapted, nofkept, nofparagraphs = 0, 0, 0, 0, 0

local splitter_one = usernodeids["splitters.one"]
local splitter_two = usernodeids["splitters.two"]

local a_word       = attributes.private('word')
local a_fontkern   = attributes.private('fontkern')

local encapsulate  = false

directives.register("builders.paragraphs.solutions.splitters.encapsulate", function(v)
    encapsulate = v
end)

function splitters.split(head)
    -- quite fast
    head = tonut(head)
    local current, done, rlmode, start, stop, attribute = head, false, false, nil, nil, 0
    cache, max_less, max_more = { }, 0, 0
    local function flush() -- we can move this
        local font = getfont(start)
        local last = getnext(stop)
        local list = last and copy_nodelist(start,last) or copy_nodelist(start)
        local n = #cache + 1
        if encapsulate then
            local user_one = new_usernumber(splitter_one,n)
            local user_two = new_usernumber(splitter_two,n)
            head, start = insert_node_before(head,start,user_one)
            insert_node_after(head,stop,user_two)
        else
            local current = start
            while true do
                setattr(current,a_word,n)
                if current == stop then
                    break
                else
                    current = getnext(current)
                end
            end
        end
        if rlmode == "TRT" or rlmode == "+TRT" then
            local dirnode = new_textdir("+TRT")
            setfield(list,"prev",dirnode)
            setfield(dirnode,"next",list)
            list = dirnode
        end
        local c = {
            original  = list,
            attribute = attribute,
            direction = rlmode,
            font      = font
        }
        if trace_split then
            report_splitters("cached %4i: font %a, attribute %a, direction %a, word %a",
                n, font, attribute, nodes_to_utf(list,true), rlmode and "r2l" or "l2r")
        end
        cache[n] = c
        local solution = solutions[attribute]
        local l, m = #solution.less, #solution.more
        if l > max_less then max_less = l end
        if m > max_more then max_more = m end
        start, stop, done = nil, nil, true
    end
    while current do -- also nextid
        local next = getnext(current)
        local id = getid(current)
        if id == glyph_code then
            if getsubtype(current) < 256 then
                local a = getattr(current,a_split)
                if not a then
                    start, stop = nil, nil
                elseif not start then
                    start, stop, attribute = current, current, a
                elseif a ~= attribute then
                    start, stop = nil, nil
                else
                    stop = current
                end
            end
        elseif id == disc_code then
            if splitwords then
                if start then
                    flush()
                end
            elseif start and next and getid(next) == glyph_code and getsubtype(next) < 256 then
                -- beware: we can cross future lines
                stop = next
            else
                start, stop = nil, nil
            end
        elseif id == dir_code or id == localpar_code then
            if start then
                flush()
            end
            rlmode = getfield(current,"dir")
        elseif id == whatsit_code then
            if start then
                flush()
            end
            local subtype = getsubtype(current)
            if subtype == dir_code or subtype == localpar_code then
                rlmode = getfield(current,"dir")
            end
        else
            if start then
                flush()
            end
        end
        current = next
    end
    if start then
        flush()
    end
    nofparagraphs = nofparagraphs + 1
    nofwords = nofwords + #cache
    return tonode(head), done
end

local function collect_words(list) -- can be made faster for attributes
    local words, w, word = { }, 0, nil
    if encapsulate then
        for current in traverse_ids(whatsit_code,list) do
            if getsubtype(current) == userdefined_code then -- hm
                local user_id = getfield(current,"user_id")
                if user_id == splitter_one then
                    word = { getfield(current,"value"), current, current }
                    w = w + 1
                    words[w] = word
                elseif user_id == splitter_two then
                    if word then
                        word[3] = current
                    else
                        -- something is wrong
                    end
                end
            end
        end
    else
        local current, first, last, index = list, nil, nil, nil
        while current do
            -- todo: disc and kern
            local id = getid(current)
            if id == glyph_code or id == disc_code then
                local a = getattr(current,a_word)
                if a then
                    if a == index then
                        -- same word
                        last = current
                    elseif index then
                        w = w + 1
                        words[w] = { index, first, last }
                        first = current
                        last  = current
                        index = a
                    elseif first then
                        last  = current
                        index = a
                    else
                        first = current
                        last  = current
                        index = a
                    end
                elseif index then
                    if first then
                        w = w + 1
                        words[w] = { index, first, last }
                    end
                    index = nil
                    first = nil
                elseif trace_split then
                    if id == disc_code then
                        report_splitters("skipped: disc node")
                    else
                        report_splitters("skipped: %C",current.char)
                    end
                end
            elseif id == kern_code and (getsubtype(current) == fontkern_code or getattr(current,a_fontkern)) then
                if first then
                    last = current
                else
                    first = current
                    last = current
                end
            elseif index then
                w = w + 1
                words[w] = { index, first, last }
                index = nil
                first = nil
                if id == disc_code then
                    if trace_split then
                        report_splitters("skipped: disc node")
                    end
                end
            end
            current = getnext(current)
        end
        if index then
            w = w + 1
            words[w] = { index, first, last }
        end
        if trace_split then
            for i=1,#words do
                local w = words[i]
                local n, f, l = w[1], w[2], w[3]
                local c = cache[n]
                if c then
                    report_splitters("found %4i: word %a, cached %a",n,nodes_to_utf(f,true,true,l),nodes_to_utf(c.original,true))
                else
                    report_splitters("found %4i: word %a, not in cache",n,nodes_to_utf(f,true,true,l))
                end
            end
        end
    end
    return words, list  -- check for empty (elsewhere)
end

-- we could avoid a hpack but hpack is not that slow

local function doit(word,list,best,width,badness,line,set,listdir)
    local changed = 0
    local n = word[1]
    local found = cache[n]
    if found then
        local h, t
        if encapsulate then
            h = getnext(word[2]) -- head of current word
            t = getprev(word[3]) -- tail of current word
        else
            h = word[2]
            t = word[3]
        end
        if splitwords then
            -- there are no lines crossed in a word
        else
            local ok = false
            local c = h
            while c do
                if c == t then
                    ok = true
                    break
                else
                    c = getnext(c)
                end
            end
            if not ok then
                report_solutions("skipping hyphenated word (for now)")
                -- todo: mark in words as skipped, saves a bit runtime
                return false, changed
            end
        end
        local original, attribute, direction = found.original, found.attribute, found.direction
        local solution = solutions[attribute]
        local features = solution and solution[set]
        if features then
            local featurenumber = features[best] -- not ok probably
            if featurenumber then
                noftries = noftries + 1
                local first = copy_nodelist(original)
                if not trace_colors then
                    for n in traverse_nodes(first) do -- maybe fast force so no attr needed
                        setattr(n,0,featurenumber) -- this forces dynamics
                    end
                elseif set == "less" then
                    for n in traverse_nodes(first) do
                        setnodecolor(n,"font:isol") -- yellow
                        setattr(n,0,featurenumber)
                    end
                else
                    for n in traverse_nodes(first) do
                        setnodecolor(n,"font:medi") -- green
                        setattr(n,0,featurenumber)
                    end
                end
first = tonode(first)
                local font = found.font
                local setdynamics = setfontdynamics[font]
                if setdynamics then
                    local processes = setdynamics[featurenumber]
                    for i=1,#processes do -- often more than 1
                        first = processes[i](first,font,featurenumber)
                    end
                else
                    report_solutions("fatal error, no dynamics for font %a",font)
                end
                first = inject_kerns(first)
first = tonut(first)
                if getid(first) == whatsit_code then
                    local temp = first
                    first = getnext(first)
                    free_node(temp)
                end
                local last = find_node_tail(first)
                -- replace [u]h->t by [u]first->last
                local prev = getprev(h)
                local next = getnext(t)
                setfield(prev,"next",first)
                setfield(first,"prev",prev)
                if next then
                    setfield(last,"next",next)
                    setfield(next,"prev",last)
                end
                -- check new pack
                local temp, b = repack_hlist(list,width,'exactly',listdir)
                if b > badness then
                    if trace_optimize then
                        report_optimizers("line %a, badness before %a, after %a, criterium %a, verdict %a",line,badness,b,criterium,"quit")
                    end
                    -- remove last insert
                    setfield(prev,"next",h)
                    setfield(h,"prev",prev)
                    if next then
                        setfield(t,"next",next)
                        setfield(next,"prev",t)
                    else
                        setfield(t,"next",nil)
                    end
                    setfield(last,"next",nil)
                    free_nodelist(first)
                else
                    if trace_optimize then
                        report_optimizers("line %a, badness before: %a, after %a, criterium %a, verdict %a",line,badness,b,criterium,"continue")
                    end
                    -- free old h->t
                    setfield(t,"next",nil)
                    free_nodelist(h) -- somhow fails
                    if not encapsulate then
                        word[2] = first
                        word[3] = last
                    end
                    changed, badness = changed + 1, b
                end
                if b <= criterium then
                    return true, changed
                end
            end
        end
    end
    return false, changed
end

-- We repeat some code but adding yet another layer of indirectness is not
-- making things better.

variants[v_normal] = function(words,list,best,width,badness,line,set,listdir)
    local changed = 0
    for i=1,#words do
        local done, c = doit(words[i],list,best,width,badness,line,set,listdir)
        changed = changed + c
        if done then
            break
        end
    end
    if changed > 0 then
        nofadapted = nofadapted + 1
        -- todo: get rid of pack when ok because we already have packed and we only need the last b
        local list, b = repack_hlist(list,width,'exactly',listdir)
        return list, true, changed, b -- badness
    else
        nofkept = nofkept + 1
        return list, false, 0, badness
    end
end

variants[v_reverse] = function(words,list,best,width,badness,line,set,listdir)
    local changed = 0
    for i=#words,1,-1 do
        local done, c = doit(words[i],list,best,width,badness,line,set,listdir)
        changed = changed + c
        if done then
            break
        end
    end
    if changed > 0 then
        nofadapted = nofadapted + 1
        -- todo: get rid of pack when ok because we already have packed and we only need the last b
        local list, b = repack_hlist(list,width,'exactly',listdir)
        return list, true, changed, b -- badness
    else
        nofkept = nofkept + 1
        return list, false, 0, badness
    end
end

variants[v_random] = function(words,list,best,width,badness,line,set,listdir)
    local changed = 0
    while #words > 0 do
        local done, c = doit(remove(words,random(1,#words)),list,best,width,badness,line,set,listdir)
        changed = changed + c
        if done then
            break
        end
    end
    if changed > 0 then
        nofadapted = nofadapted + 1
        -- todo: get rid of pack when ok because we already have packed and we only need the last b
        local list, b = repack_hlist(list,width,'exactly',listdir)
        return list, true, changed, b -- badness
    else
        nofkept = nofkept + 1
        return list, false, 0, badness
    end
end

local function show_quality(current,what,line)
    local set    = getfield(current,"glue_set")
    local sign   = getfield(current,"glue_sign")
    local order  = getfield(current,"glue_order")
    local amount = set * ((sign == 2 and -1) or 1)
    report_optimizers("line %a, category %a, amount %a, set %a, sign %a, how %a, order %a",line,what,amount,set,sign,how,order)
end

function splitters.optimize(head)
    if not optimize then
        report_optimizers("no optimizer set")
        return
    end
    local nc = #cache
    if nc == 0 then
        return
    end
    starttiming(splitters)
    local listdir = nil -- todo ! ! !
    if randomseed then
        math.setrandomseedi(randomseed)
        randomseed = nil
    end
    local line         = 0
    local tex_hbadness = tex.hbadness
    local tex_hfuzz    = tex.hfuzz
    tex.hbadness       = 10000
    tex.hfuzz          = number.maxdimen
    if trace_optimize then
        report_optimizers("preroll %a, variant %a, criterium %a, cache size %a",preroll,variant,criterium,nc)
    end
    for current in traverse_ids(hlist_code,tonut(head)) do
        line = line + 1
        local sign  = getfield(current,"glue_sign")
        local dir   = getfield(current,"dir")
        local width = getfield(current,"width")
        local list  = getlist(current)
        if not encapsulate and getid(list) == glyph_code then
            -- nasty .. we always assume a prev being there .. future luatex will always have a leftskip set
            -- is this assignment ok ? .. needs checking
            list = insert_node_before(list,list,new_leftskip(0)) -- new_glue(0)
            setfield(current,"list",list)
        end
        local temp, badness = repack_hlist(list,width,'exactly',dir) -- it would be nice if the badness was stored in the node
        if badness > 0 then
            if sign == 0 then
                if trace_optimize then
                    report_optimizers("line %a, badness %a, outcome %a, verdict %a",line,badness,"okay","okay")
                end
            else
                local set, max
                if sign == 1 then
                    if trace_optimize then
                        report_optimizers("line %a, badness %a, outcome %a, verdict %a",line,badness,"underfull","trying more")
                    end
                    set, max = "more", max_more
                else
                    if trace_optimize then
                        report_optimizers("line %a, badness %a, outcome %a, verdict %a",line,badness,"overfull","trying less")
                    end
                    set, max = "less", max_less
                end
                -- we can keep the best variants
                local lastbest, lastbadness = nil, badness
                if preroll then
                    local bb, base
                    for i=1,max do
                        if base then
                            free_nodelist(base)
                        end
                        base = copy_nodelist(list)
                        local words = collect_words(base) -- beware: words is adapted
                        for j=i,max do
                            local temp, done, changes, b = optimize(words,base,j,width,badness,line,set,dir)
                            base = temp
                            if trace_optimize then
                                report_optimizers("line %a, alternative %a.%a, changes %a, badness %a",line,i,j,changes,b)
                            end
                            bb = b
                            if b <= criterium then
                                break
                            end
                         -- if done then
                         --     break
                         -- end
                        end
                        if bb and bb > criterium then -- needs checking
                            if not lastbest then
                                lastbest, lastbadness = i, bb
                            elseif bb > lastbadness then
                                lastbest, lastbadness = i, bb
                            end
                        else
                            break
                        end
                    end
                    free_nodelist(base)
                end
                local words = collect_words(list)
                for best=lastbest or 1,max do
                    local temp, done, changes, b = optimize(words,list,best,width,badness,line,set,dir)
                    setfield(current,"list",temp)
                    if trace_optimize then
                        report_optimizers("line %a, alternative %a, changes %a, badness %a",line,best,changes,b)
                    end
                    if done then
                        if b <= criterium then -- was == 0
                            protect_glyphs(list)
                            break
                        end
                    end
                end
            end
        else
            if trace_optimize then
                report_optimizers("line %a, verdict %a",line,"not bad enough")
            end
        end
        -- we pack inside the outer hpack and that way keep the original wd/ht/dp as bonus
        local list = hpack_nodes(getlist(current),width,'exactly',listdir)
        setfield(current,"list",list)
    end
    for i=1,nc do
        local ci = cache[i]
        free_nodelist(ci.original)
    end
    cache = { }
    tex.hbadness = tex_hbadness
    tex.hfuzz    = tex_hfuzz
    stoptiming(splitters)
end

statistics.register("optimizer statistics", function()
    if nofwords > 0 then
        local elapsed = statistics.elapsedtime(splitters)
        local average = noftries/elapsed
        return format("%s words identified in %s paragraphs, %s words retried, %s lines tried, %0.3f seconds used, %s adapted, %0.1f lines per second",
            nofwords,nofparagraphs,noftries,nofadapted+nofkept,elapsed,nofadapted,average)
    end
end)

-- we could use a stack

local enableaction  = tasks.enableaction
local disableaction = tasks.disableaction

local function enable()
    enableaction("processors", "builders.paragraphs.solutions.splitters.split")
    enableaction("finalizers", "builders.paragraphs.solutions.splitters.optimize")
end

local function disable()
    disableaction("processors", "builders.paragraphs.solutions.splitters.split")
    disableaction("finalizers", "builders.paragraphs.solutions.splitters.optimize")
end

function splitters.start(name,settings)
    if pushsplitter(name,settings) == 1 then
        enable()
    end
end

function splitters.stop()
    if popsplitter() == 0 then
        disable()
    end
end

function splitters.set(name,settings)
    if #stack > 0 then
        stack = { }
    else
        enable()
    end
    pushsplitter(name,settings) -- sets attribute etc
end

function splitters.reset()
    if #stack > 0 then
        stack = { }
        popsplitter() -- resets attribute etc
        disable()
    end
end

-- interface

implement {
    name      = "definefontsolution",
    actions   = splitters.define,
    arguments = {
        "string",
        {
            { "goodies" },
            { "solution" },
            { "less" },
            { "more" },
        }
    }
}

implement {
    name      = "startfontsolution",
    actions   = splitters.start,
    arguments = {
        "string",
        {
            { "method" },
            { "criterium" },
            { "randomseed" },
        }
    }
}

implement {
    name      = "stopfontsolution",
    actions   = splitters.stop
}

implement {
    name      = "setfontsolution",
    actions   = splitters.set,
    arguments = {
        "string",
        {
            { "method" },
            { "criterium" },
            { "randomseed" },
        }
    }
}

implement {
    name      = "resetfontsolution",
    actions   = splitters.reset
}
