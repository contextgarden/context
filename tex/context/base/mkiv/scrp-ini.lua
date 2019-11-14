if not modules then modules = { } end modules ['scrp-ini'] = {
    version   = 1.001,
    comment   = "companion to scrp-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- We need to rewrite this a bit ... rather old code ... will be done when japanese
-- is finished.

local tonumber, next = tonumber, next

local trace_analyzing    = false  trackers.register("scripts.analyzing",         function(v) trace_analyzing   = v end)
local trace_injections   = false  trackers.register("scripts.injections",        function(v) trace_injections  = v end)
local trace_splitting    = false  trackers.register("scripts.splitting",         function(v) trace_splitting   = v end)
local trace_splitdetails = false  trackers.register("scripts.splitting.details", function(v) trace_splitdetails = v end)

local report_preprocessing = logs.reporter("scripts","preprocessing")
local report_splitting     = logs.reporter("scripts","splitting")

local utfbyte, utfsplit = utf.byte, utf.split
local gmatch = string.gmatch

local attributes         = attributes
local nodes              = nodes
local context            = context

local texsetattribute    = tex.setattribute

local nodecodes          = nodes.nodecodes
local unsetvalue         = attributes.unsetvalue

local implement          = interfaces.implement

local glyph_code         = nodecodes.glyph
local glue_code          = nodecodes.glue

local emwidths           = fonts.hashes.emwidths
local exheights          = fonts.hashes.exheights

local a_scriptinjection  = attributes.private('scriptinjection')
local a_scriptsplitting  = attributes.private('scriptsplitting')
local a_scriptstatus     = attributes.private('scriptstatus')

local fontdata           = fonts.hashes.identifiers
local allocate           = utilities.storage.allocate
local setnodecolor       = nodes.tracers.colors.set
local setmetatableindex  = table.setmetatableindex

local enableaction       = nodes.tasks.enableaction
local disableaction      = nodes.tasks.disableaction

local nuts               = nodes.nuts

local getnext            = nuts.getnext
local getchar            = nuts.getchar
local getfont            = nuts.getfont
local getid              = nuts.getid
local getglyphdata       = nuts.getglyphdata

local getattr            = nuts.getattr
local setattr            = nuts.setattr

local isglyph            = nuts.isglyph

local insert_node_after  = nuts.insert_after
local insert_node_before = nuts.insert_before

local first_glyph        = nuts.first_glyph

----- traverse_id        = nuts.traverse_id
----- traverse_char      = nuts.traverse_char
local nextglyph          = nuts.traversers.glyph
local nextchar           = nuts.traversers.char

local nodepool           = nuts.pool

local new_glue           = nodepool.glue
local new_rule           = nodepool.rule
local new_penalty        = nodepool.penalty

scripts                  = scripts or { }
local scripts            = scripts

scripts.hash             = scripts.hash or { }
local hash               = scripts.hash

local handlers           = allocate()
scripts.handlers         = handlers

local injectors          = allocate()
scripts.injectors        = handlers

local splitters          = allocate()
scripts.splitters        = splitters

local hash = { -- we could put these presets in char-def.lua
    --
    -- half width opening parenthesis
    --
    [0x0028] = "half_width_open",
    [0x005B] = "half_width_open",
    [0x007B] = "half_width_open",
    [0x2018] = "half_width_open", -- ‘
    [0x201C] = "half_width_open", -- “
    --
    -- full width opening parenthesis
    --
    [0x3008] = "full_width_open", -- 〈   Left book quote
    [0x300A] = "full_width_open", -- 《   Left double book quote
    [0x300C] = "full_width_open", -- 「   left quote
    [0x300E] = "full_width_open", -- 『   left double quote
    [0x3010] = "full_width_open", -- 【   left double book quote
    [0x3014] = "full_width_open", -- 〔   left book quote
    [0x3016] = "full_width_open", --〖   left double book quote
    [0x3018] = "full_width_open", --     left tortoise bracket
    [0x301A] = "full_width_open", --     left square bracket
    [0x301D] = "full_width_open", --     reverse double prime qm
    [0xFF08] = "full_width_open", -- （   left parenthesis
    [0xFF3B] = "full_width_open", -- ［   left square brackets
    [0xFF5B] = "full_width_open", -- ｛   left curve bracket
    --
    -- half width closing parenthesis
    --
    [0x0029] = "half_width_close",
    [0x005D] = "half_width_close",
    [0x007D] = "half_width_close",
    [0x2019] = "half_width_close", -- ’   right quote, right
    [0x201D] = "half_width_close", -- ”   right double quote
    --
    -- full width closing parenthesis
    --
    [0x3009] = "full_width_close", -- 〉   book quote
    [0x300B] = "full_width_close", -- 》   double book quote
    [0x300D] = "full_width_close", -- 」   right quote, right
    [0x300F] = "full_width_close", -- 』   right double quote
    [0x3011] = "full_width_close", -- 】   right double book quote
    [0x3015] = "full_width_close", -- 〕   right book quote
    [0x3017] = "full_width_close", -- 〗  right double book quote
    [0x3019] = "full_width_close", --     right tortoise bracket
    [0x301B] = "full_width_close", --     right square bracket
    [0x301E] = "full_width_close", --     double prime qm
    [0x301F] = "full_width_close", --     low double prime qm
    [0xFF09] = "full_width_close", -- ）   right parenthesis
    [0xFF3D] = "full_width_close", -- ］   right square brackets
    [0xFF5D] = "full_width_close", -- ｝   right curve brackets
    --
    [0xFF62] = "half_width_open", --     left corner bracket
    [0xFF63] = "half_width_close", --     right corner bracket
    --
    -- vertical opening vertical
    --
    -- 0xFE35, 0xFE37, 0xFE39,  0xFE3B,  0xFE3D,  0xFE3F,  0xFE41,  0xFE43,  0xFE47,
    --
    -- vertical closing
    --
    -- 0xFE36, 0xFE38, 0xFE3A,  0xFE3C,  0xFE3E,  0xFE40,  0xFE42,  0xFE44,  0xFE48,
    --
    -- half width opening punctuation
    --
    -- <empty>
    --
    -- full width opening punctuation
    --
    --  0x2236, -- ∶
    --  0xFF0C, -- ，
    --
    -- half width closing punctuation_hw
    --
    [0x0021] = "half_width_close", -- !
    [0x002C] = "half_width_close", -- ,
    [0x002E] = "half_width_close", -- .
    [0x003A] = "half_width_close", -- :
    [0x003B] = "half_width_close", -- ;
    [0x003F] = "half_width_close", -- ?
    [0xFF61] = "half_width_close", -- hw full stop
    --
    -- full width closing punctuation
    --
    [0x3001] = "full_width_close", -- 、
    [0x3002] = "full_width_close", -- 。
    [0xFF0C] = "full_width_close", -- ，
    [0xFF0E] = "full_width_close", --
    --
    -- depends on font
    --
    [0xFF01] = "full_width_close", -- ！
    [0xFF1F] = "full_width_close", -- ？
    --
    [0xFF1A] = "full_width_punct", -- ：
    [0xFF1B] = "full_width_punct", -- ；
    --
    -- non starter
    --
    [0x3005] = "non_starter", [0x3041] = "non_starter", [0x3043] = "non_starter", [0x3045] = "non_starter", [0x3047] = "non_starter",
    [0x3049] = "non_starter", [0x3063] = "non_starter", [0x3083] = "non_starter", [0x3085] = "non_starter", [0x3087] = "non_starter",
    [0x308E] = "non_starter", [0x3095] = "non_starter", [0x3096] = "non_starter", [0x309B] = "non_starter", [0x309C] = "non_starter",
    [0x309D] = "non_starter", [0x309E] = "non_starter", [0x30A0] = "non_starter", [0x30A1] = "non_starter", [0x30A3] = "non_starter",
    [0x30A5] = "non_starter", [0x30A7] = "non_starter", [0x30A9] = "non_starter", [0x30C3] = "non_starter", [0x30E3] = "non_starter",
    [0x30E5] = "non_starter", [0x30E7] = "non_starter", [0x30EE] = "non_starter", [0x30F5] = "non_starter", [0x30F6] = "non_starter",
    [0x30FC] = "non_starter", [0x30FD] = "non_starter", [0x30FE] = "non_starter", [0x31F0] = "non_starter", [0x31F1] = "non_starter",
    [0x30F2] = "non_starter", [0x30F3] = "non_starter", [0x30F4] = "non_starter", [0x31F5] = "non_starter", [0x31F6] = "non_starter",
    [0x30F7] = "non_starter", [0x30F8] = "non_starter", [0x30F9] = "non_starter", [0x31FA] = "non_starter", [0x31FB] = "non_starter",
    [0x30FC] = "non_starter", [0x30FD] = "non_starter", [0x30FE] = "non_starter", [0x31FF] = "non_starter",
    --
    -- hyphenation
    --
    [0x2026] = "hyphen", -- …   ellipsis
    [0x2014] = "hyphen", -- —   hyphen
    --
    [0x1361] = "ethiopic_word",
    [0x1362] = "ethiopic_sentence",
    --
    -- tibetan:
    --
    [0x0F0B] = "breaking_tsheg",
    [0x0F0C] = "nonbreaking_tsheg",

}

local function provide(t,k)
    local v
    if not tonumber(k)                     then v = false
    elseif (k >= 0x03040 and k <= 0x030FF)
        or (k >= 0x031F0 and k <= 0x031FF)
        or (k >= 0x032D0 and k <= 0x032FE)
        or (k >= 0x0FF00 and k <= 0x0FFEF) then v = "katakana"
    elseif (k >= 0x03400 and k <= 0x04DFF)
        or (k >= 0x04E00 and k <= 0x09FFF)
        or (k >= 0x0F900 and k <= 0x0FAFF)
        or (k >= 0x20000 and k <= 0x2A6DF)
        or (k >= 0x2F800 and k <= 0x2FA1F) then v = "chinese"
    elseif (k >= 0x0AC00 and k <= 0x0D7A3) then v = "korean"
    elseif (k >= 0x01100 and k <= 0x0115F) then v = "jamo_initial"
    elseif (k >= 0x01160 and k <= 0x011A7) then v = "jamo_medial"
    elseif (k >= 0x011A8 and k <= 0x011FF) then v = "jamo_final"
    elseif (k >= 0x01200 and k <= 0x0139F) then v = "ethiopic_syllable"
    elseif (k >= 0x00F00 and k <= 0x00FFF) then v = "tibetan"
                                           else v = false
    end
    t[k] = v
    return v
end

setmetatableindex(hash,provide) -- should come from char-def

scripts.hash = hash

local numbertodataset = allocate()
local numbertohandler = allocate()

--~ storage.register("scripts/hash", hash, "scripts.hash")

scripts.numbertodataset = numbertodataset
scripts.numbertohandler = numbertohandler

local defaults = {
    inter_char_shrink_factor          = 0,
    inter_char_shrink_factor          = 0,
    inter_char_stretch_factor         = 0,
    inter_char_half_shrink_factor     = 0,
    inter_char_half_stretch_factor    = 0,
    inter_char_quarter_shrink_factor  = 0,
    inter_char_quarter_stretch_factor = 0,
    inter_char_hangul_penalty         = 0,

    inter_word_stretch_factor         = 0,
}

scripts.defaults = defaults -- so we can add more

function scripts.installmethod(handler)
    local name = handler.name
    handlers[name] = handler
    local attributes = { }
    local datasets = handler.datasets
    if not datasets or not datasets.default then
        report_preprocessing("missing (default) dataset in script %a",name)
        datasets.default = { } -- slower but an error anyway
    end

    for k, v in next, datasets do
        setmetatableindex(v,defaults)
    end
    setmetatable(attributes, {
        __index = function(t,k)
            local v = datasets[k] or datasets.default
            local a = unsetvalue
            if v then
                v.name = name -- for tracing
                a = #numbertodataset + 1
                numbertodataset[a] = v
                numbertohandler[a] = handler
            end
            t[k] = a
            return a
        end
    } )
    handler.attributes = attributes
end

function scripts.installdataset(specification) -- global overload
    local method  = specification.method
    local name    = specification.name
    local dataset = specification.dataset
    if method and name and dataset then
        local parent  = specification.parent or ""
        local handler = handlers[method]
        if handler then
            local datasets = handler.datasets
            if datasets then
                local defaultset = datasets.default
                if defaultset then
                    if parent ~= "" then
                        local p = datasets[parent]
                        if p then
                            defaultset = p
                        else
                            report_preprocessing("dataset, unknown parent %a for method %a",parent,method)
                        end
                    end
                    setmetatable(dataset,defaultset)
                    local existing = datasets[name]
                    if existing then
                        for k, v in next, existing do
                            existing[k] = dataset
                        end
                    else
                        datasets[name] = dataset
                    end
                else
                    report_preprocessing("dataset, no default for method %a",method)
                end
            else
                report_preprocessing("dataset, no datasets for method %a",method)
            end
        else
            report_preprocessing("dataset, no method %a",method)
        end
    else
        report_preprocessing("dataset, invalid specification") -- maybe report table
    end
end

local injectorenabled = false
local splitterenabled = false

function scripts.set(name,method,preset)
    local handler = handlers[method]
    if handler then
        if handler.injector then
            if not injectorenabled then
                enableaction("processors","scripts.injectors.handler")
                injectorenabled = true
            end
            texsetattribute(a_scriptinjection,handler.attributes[preset] or unsetvalue)
        end
        if handler.splitter then
            if not splitterenabled then
                enableaction("processors","scripts.splitters.handler")
                splitterenabled = true
            end
            texsetattribute(a_scriptsplitting,handler.attributes[preset] or unsetvalue)
        end
        if handler.initializer then
            handler.initializer(handler)
            handler.initializer = nil
        end
    else
        texsetattribute(a_scriptinjection,unsetvalue)
        texsetattribute(a_scriptsplitting,unsetvalue)
    end
end

function scripts.reset()
    texsetattribute(a_scriptinjection,unsetvalue)
    texsetattribute(a_scriptsplitting,unsetvalue)
end

-- the following tables will become a proper installer (move to cjk/eth)
--
-- 0=gray 1=red 2=green 3=blue 4=yellow 5=magenta 6=cyan 7=x-yellow 8=x-magenta 9=x-cyan

local scriptcolors = allocate {  -- todo: just named colors
    korean            = "trace:0",
    chinese           = "trace:0",
    katakana          = "trace:0",
    hiragana          = "trace:0",
    full_width_open   = "trace:1",
    full_width_close  = "trace:2",
    half_width_open   = "trace:3",
    half_width_close  = "trace:4",
    full_width_punct  = "trace:5",
    hyphen            = "trace:5",
    non_starter       = "trace:6",
    jamo_initial      = "trace:7",
    jamo_medial       = "trace:8",
    jamo_final        = "trace:9",
    ethiopic_syllable = "trace:1",
    ethiopic_word     = "trace:2",
    ethiopic_sentence = "trace:3",
    breaking_tsheg    = "trace:1",
    nonbreaking_tsheg = "trace:2",
}

scripts.colors = scriptcolors

local numbertocategory = allocate { -- rather bound to cjk ... will be generalized
    "korean",
    "chinese",
    "katakana",
    "hiragana",
    "full_width_open",
    "full_width_close",
    "half_width_open",
    "half_width_close",
    "full_width_punct",
    "hyphen",
    "non_starter",
    "jamo_initial",
    "jamo_medial",
    "jamo_final",
    "ethiopic_syllable",
    "ethiopic_word",
    "ethiopic_sentence",
    "breaking_tsheg",
    "nonbreaking_tsheg",
}

local categorytonumber = allocate(table.swapped(numbertocategory)) -- could be one table

scripts.categorytonumber = categorytonumber
scripts.numbertocategory = numbertocategory

local function colorize(start,stop)
    for n in nextglyph, start do
        local kind = numbertocategory[getattr(n,a_scriptstatus)]
        if kind then
            local ac = scriptcolors[kind]
            if ac then
                setnodecolor(n,ac)
            end
        end
        if n == stop then
            break
        end
    end
end

local function traced_process(head,first,last,process,a)
    if start ~= last then
        local f, l = first, last
        local name = numbertodataset[a]
        name = name and name.name or "?"
        report_preprocessing("before %s: %s",name,nodes.tosequence(f,l))
        process(head,first,last)
        report_preprocessing("after %s: %s", name,nodes.tosequence(f,l))
    end
end

-- eventually we might end up with more extensive parsing
-- todo: pass t[start..stop] == original
--
-- one of the time consuming functions:

-- we can have a fonts.hashes.originals

function scripts.injectors.handler(head)
    local start = first_glyph(head) -- we already have glyphs here (subtype 1)
    if not start then
        return head
    else
        local last_a, normal_process, lastfont, originals, first, last
        local ok = false
        while start do
            local char, id = isglyph(start)
            if char then
                local a = getattr(start,a_scriptinjection)
                if a then
                    if a ~= last_a then
                        if first then
                            if ok then
                                if trace_analyzing then
                                    colorize(first,last)
                                end
                                if trace_injections then
                                    traced_process(head,first,last,normal_process,last_a)
                                else
                                    normal_process(head,first,last)
                                end
                                ok = false
                            end
                            first, last = nil, nil
                        end
                        last_a = a
                        local handler = numbertohandler[a]
                        normal_process = handler.injector
                    end
                    if normal_process then
                        -- id == font
                        if id ~= lastfont then
                            originals = fontdata[id].resources
                            if resources then
                                originals = resources.originals
                            else
                                originals = nil -- can't happen
                            end
                            lastfont = id
                        end
                        if originals and type(originals) == "number" then
                            char = originals[char] or char
                        end
                        local h = hash[char]
                        if h then
                            setattr(start,a_scriptstatus,categorytonumber[h])
                            if not first then
                                first, last = start, start
                            else
                                last = start
                            end
                         -- if cjk == "chinese" or cjk == "korean" then -- we need to prevent too much ( ) processing
                                ok = true
                         -- end
                        elseif first then
                            if ok then
                                if trace_analyzing then
                                    colorize(first,last)
                                end
                                if trace_injections then
                                    traced_process(head,first,last,normal_process,last_a)
                                else
                                    normal_process(head,first,last)
                                end
                                ok = false
                            end
                            first, last = nil, nil
                        end
                    end
                elseif first then
                    if ok then
                        if trace_analyzing then
                            colorize(first,last)
                        end
                        if trace_injections then
                            traced_process(head,first,last,normal_process,last_a)
                        else
                            normal_process(head,first,last)
                        end
                        ok = false
                    end
                    first, last = nil, nil
                end
            elseif id == glue_code then
                if ok then
                    -- continue
                elseif first then
                    -- no chinese or korean
                    first, last = nil, nil
                end
            elseif first then
                if ok then
                    -- some chinese or korean
                    if trace_analyzing then
                        colorize(first,last)
                    end
                    if trace_injections then
                        traced_process(head,first,last,normal_process,last_a)
                    else
                        normal_process(head,first,last)
                    end
                    first, last, ok = nil, nil, false
                elseif first then
                    first, last = nil, nil
                end
            end
            start = getnext(start)
        end
        if ok then
            if trace_analyzing then
                colorize(first,last)
            end
            if trace_injections then
                traced_process(head,first,last,normal_process,last_a)
            else
                normal_process(head,first,last)
            end
        end
        return head
    end
end

-- kind of experimental .. might move to it's own module

-- function scripts.splitters.handler(head)
--     return head
-- end

local function addwords(tree,data)
    if not tree then
        tree = { }
    end
    for word in gmatch(data,"%S+") do
        local root = tree
        local list = utfsplit(word,true)
        for i=1,#list do
            local l = utfbyte(list[i])
            local r = root[l]
            if not r then
                r = { }
                root[l] = r
            end
            if i == #list then
                r.final = word -- true -- could be something else, like word in case of tracing
            else
                root = r
            end
        end
    end
    return tree
end

local loaded = { }

function splitters.load(handler,files)
    local files  = handler.files
    local tree   = handler.tree or { }
    handler.tree = tree
    if not files then
        return
    elseif type(files) == "string" then
        files         = { files }
        handler.files = files
    end
    if trace_splitting then
        report_splitting("loading splitter data for language/script %a",handler.name)
    end
    loaded[handler.name or "unknown"] = (loaded[handler.name or "unknown"] or 0) + 1
    statistics.starttiming(loaded)
    for i=1,#files do
        local filename = files[i]
        local fullname = resolvers.findfile(filename)
        if fullname == "" then
            fullname = resolvers.findfile(filename .. ".gz")
        end
        if fullname ~= "" then
            if trace_splitting then
                report_splitting("loading file %a",fullname)
            end
            local suffix, gzipped = gzip.suffix(fullname)
            if suffix == "lua" then
                local specification = table.load(fullname,gzipped and gzip.load)
                 if specification then
                    local lists = specification.lists
                    if lists then
                        for i=1,#lists do
                            local entry = lists[i]
                            local data = entry.data
                            if data then
                                if entry.compression == "zlib" then
                                    data = zlib.decompress(data)
                                    if entry.length and entry.length ~= #data then
                                        report_splitting("compression error in file %a",fullname)
                                    end
                                end
                                if data then
                                    addwords(tree,data)
                                end
                            end
                        end
                    end
                end
            else
                local data = gzipped and io.loadgzip(fullname) or io.loaddata(fullname)
                if data then
                    addwords(tree,data)
                end
            end
        else
            report_splitting("unknown file %a",filename)
        end
    end
    statistics.stoptiming(loaded)
    return tree
end

statistics.register("loaded split lists", function()
    if next(loaded) then
        return string.format("%s, load time: %s",table.sequenced(loaded),statistics.elapsedtime(loaded))
    end
end)

-- function splitters.addlist(name,filename)
--     local handler = scripts.handlers[name]
--     if handler and filename then
--         local files = handler.files
--         if not files then
--             files = { }
--         elseif type(files) == "string" then
--             files = { files }
--         end
--         handler.files = files
--         if type(filename) == "string" then
--             filename = utilities.parsers.settings_to_array(filename)
--         end
--         if type(filename) == "table" then
--             for i=1,#filename do
--                 files[#files+1] = filenames[i]
--             end
--         end
--     end
-- end
--
-- commands.setscriptsplitterlist = splitters.addlist

local categories = characters.categories or { }

local function hit(root,head)
    local current   = getnext(head)
    local lastrun   = false
    local lastfinal = false
    while current do
        local char = isglyph(current)
        if char then
            local newroot = root[char]
            if newroot then
                local final = newroot.final
                if final then
                    lastrun   = current
                    lastfinal = final
                end
                root = newroot
            elseif categories[char] == "mn" then
                -- continue
            else
                return lastrun, lastfinal
            end
        else
            break
        end
    end
    if lastrun then
        return lastrun, lastfinal
    end
end

local tree, attr, proc

function splitters.handler(head) -- todo: also first_glyph test
    local current = head
    while current do
        if getid(current) == glyph_code then
            local a = getattr(current,a_scriptsplitting)
            if a then
                if a ~= attr then
                    local handler = numbertohandler[a]
                    tree = handler.tree or { }
                    attr = a
                    proc = handler.splitter
                end
                if proc then
                    local root = tree[getchar(current)]
                    if root then
                        -- we don't check for attributes in the hitter (yet)
                        local last, final = hit(root,current)
                        if last then
                            local next = getnext(last)
                            if next then
                                local nextchar = isglyph(next)
                                if not nextchar then
                                    -- we're done
                                elseif tree[nextchar] then
                                    if trace_splitdetails then
                                        if type(final) == "string" then
                                            report_splitting("advance %s processing between <%s> and <%c>","with",final,nextchar)
                                        else
                                            report_splitting("advance %s processing between <%c> and <%c>","with",char,nextchar)
                                        end
                                    end
                                    head, current = proc(handler,head,current,last,1)
                                else
                                    if trace_splitdetails then
                                        -- could be punctuation
                                        if type(final) == "string" then
                                            report_splitting("advance %s processing between <%s> and <%c>","without",final,nextchar)
                                        else
                                            report_splitting("advance %s processing between <%c> and <%c>","without",char,nextchar)
                                        end
                                    end
                                    head, current = proc(handler,head,current,last,2)
                                end
                            end
                        end
                    end
                end
            end
        end
        current = getnext(current)
    end
    return head
end

local function marker(head,current,font,color) -- could become: nodes.tracers.marker
    local ex = exheights[font]
    local em = emwidths [font]
    head, current = insert_node_after(head,current,new_penalty(10000))
    head, current = insert_node_after(head,current,new_glue(-0.05*em))
    head, current = insert_node_after(head,current,new_rule(0.05*em,1.5*ex,0.5*ex))
    setnodecolor(current,color)
    return head, current
end

local last_a, last_f, last_s, last_q

function splitters.insertafter(handler,head,first,last,detail)
    local a = getattr(first,a_scriptsplitting)
    local f = getfont(first)
    if a ~= last_a or f ~= last_f then
        last_s = emwidths[f] * numbertodataset[a].inter_word_stretch_factor
        last_a = a
        last_f = f
    end
    if trace_splitting then
        head, last = marker(head,last,f,detail == 2 and "trace:r" or "trace:g")
    end
    if ignore then
        return head, last
    else
        return insert_node_after(head,last,new_glue(0,last_s))
    end
end

-- word-xx.lua:
--
-- return {
--     comment   = "test",
--     copyright = "not relevant",
--     language  = "en",
--     timestamp = "2013-05-20 14:15:21",
--     version   = "1.00",
--     lists     = {
--         {
--          -- data = "we thrive information in thick worlds because of our marvelous and everyday capacity to select edit single out structure highlight group pair merge harmonize synthesize focus organize condense reduce boil down choose categorize catalog classify list abstract scan look into idealize isolate discriminate distinguish screen pigeonhole pick over sort integrate blend inspect filter lump skip smooth chunk average approximate cluster aggregate outline summarize itemize review dip into flip through browse glance into leaf through skim refine enumerate glean synopsize winnow the wheat from the chaff and separate the sheep from the goats",
--             data = "abstract aggregate and approximate average because blend boil browse capacity catalog categorize chaff choose chunk classify cluster condense dip discriminate distinguish down edit enumerate everyday filter flip focus from glance glean goats group harmonize highlight idealize in information inspect integrate into isolate itemize leaf list look lump marvelous merge of organize our out outline over pair pick pigeonhole reduce refine review scan screen select separate sheep single skim skip smooth sort structure summarize synopsize synthesize the thick thrive through to we wheat winnow worlds",
--         },
--     },
-- }

scripts.installmethod {
    name        = "test",
    splitter    = splitters.insertafter,
    initializer = splitters.load,
    files       = {
     -- "scrp-imp-word-test.lua",
        "word-xx.lua",
    },
    datasets    = {
        default = {
            inter_word_stretch_factor = 0.25, -- of quad
        },
    },
}

-- new plugin:

local registercontext   = fonts.specifiers.registercontext
local mergecontext      = fonts.specifiers.mergecontext

local otfscripts        = characters.otfscripts

local report_scripts    = logs.reporter("scripts","auto feature")
local trace_scripts     = false  trackers.register("scripts.autofeature",function(v) trace_scripts = v end)

local autofontfeature   = scripts.autofontfeature or { }
scripts.autofontfeature = autofontfeature

local cache_yes         = { }
local cache_nop         = { }

setmetatableindex(cache_yes,function(t,k) local v = { } t[k] = v return v end)
setmetatableindex(cache_nop,function(t,k) local v = { } t[k] = v return v end)

-- beware: we need to tag a done (otherwise too many extra instances ... but how
-- often unpack? wait till we have a bitmap
--
-- we can consider merging this in handlers.characters(head) at some point as there
-- already check for the dynamic attribute so it saves a pass, however, then we also
-- need to check for a_scriptinjection there which nils the benefit
--
-- we can consider cheating: set all glyphs in a word as the first one but it's not
-- playing nice

function autofontfeature.handler(head)
    for n, char, font in nextchar, head do
     -- if getattr(n,a_scriptinjection) then
     --     -- already tagged by script feature, maybe some day adapt
     -- else
            local script = otfscripts[char]
            if script then
                local dynamic = getglyphdata(n) or 0
                if dynamic > 0 then
                    local slot = cache_yes[font]
                    local attr = slot[script]
                    if not attr then
                        attr = mergecontext(dynamic,name,2)
                        slot[script] = attr
                        if trace_scripts then
                            report_scripts("script: %s, trigger %C, dynamic: %a, variant: %a",script,char,attr,"extended")
                        end
                    end
                    if attr ~= 0 then
                        n[0] = attr
                        -- maybe set scriptinjection when associated
                    end
                else
                    local slot = cache_nop[font]
                    local attr = slot[script]
                    if not attr then
                        attr = registercontext(font,script,2)
                        slot[script] = attr
                        if trace_scripts then
                            report_scripts("script: %s, trigger %C, dynamic: %s, variant: %a",script,char,attr,"normal")
                        end
                    end
                    if attr ~= 0 then
                        setattr(n,0,attr)
                        -- maybe set scriptinjection when associated
                    end
                end
            end
     -- end
    end
    return head
end

function autofontfeature.enable()
    report_scripts("globally enabled")
    enableaction("processors","scripts.autofontfeature.handler")
end

function autofontfeature.disable()
    report_scripts("globally disabled")
    disableaction("processors","scripts.autofontfeature.handler")
end

implement {
    name      = "enableautofontscript",
    actions   = autofontfeature.enable
}

implement {
    name      = "disableautofontscript",
    actions   = autofontfeature.disable }

implement {
    name      = "setscript",
    actions   = scripts.set,
    arguments = "3 strings",
}

implement {
    name      = "resetscript",
    actions   = scripts.reset
}

-- some common helpers


do

    local parameters = fonts.hashes.parameters

    local space, stretch, shrink, lastfont

    local inter_character_space_factor   = 1
    local inter_character_stretch_factor = 1
    local inter_character_shrink_factor  = 1

    local function space_glue(current)
        local data = numbertodataset[getattr(current,a_scriptinjection)]
        if data then
            inter_character_space_factor   = data.inter_character_space_factor   or 1
            inter_character_stretch_factor = data.inter_character_stretch_factor or 1
            inter_character_shrink_factor  = data.inter_character_shrink_factor  or 1
        end
        local font = getfont(current)
        if lastfont ~= font then
            local pf = parameters[font]
            space    = pf.space
            stretch  = pf.space_stretch
            shrink   = pf.space_shrink
            lastfont = font
        end
        return new_glue(
            inter_character_space_factor   * space,
            inter_character_stretch_factor * stretch,
            inter_character_shrink_factor  * shrink
        )
    end

    scripts.inserters = {

        space_before = function(head,current)
            return insert_node_before(head,current,space_glue(current))
        end,
        space_after = function(head,current)
            return insert_node_after(head,current,space_glue(current))
        end,

        zerowidthspace_before = function(head,current)
            return insert_node_before(head,current,new_glue(0))
        end,
        zerowidthspace_after = function(head,current)
            return insert_node_after(head,current,new_glue(0))
        end,

        nobreakspace_before = function(head,current)
            local g = space_glue(current)
            local p = new_penalty(10000)
            head, current = insert_node_before(head,current,p)
            return insert_node_before(head,current,g)
        end,
        nobreakspace_after = function(head,current)
            local g = space_glue(current)
            local p = new_penalty(10000)
            head, current = insert_node_after(head,current,g)
            return insert_node_after(head,current,p)
        end,

    }

end

-- end of helpers
