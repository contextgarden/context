if not modules then modules = { } end modules ['supp-box'] = {
    version   = 1.001,
    comment   = "companion to supp-box.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this is preliminary code, use insert_before etc

local report_hyphenation = logs.reporter("languages","hyphenation")

local tonumber, next, type = tonumber, next, type

local lpegmatch     = lpeg.match

local tex           = tex
local context       = context
local nodes         = nodes

local implement     = interfaces.implement

local nodecodes     = nodes.nodecodes

local disc_code     = nodecodes.disc
local hlist_code    = nodecodes.hlist
local vlist_code    = nodecodes.vlist
local glue_code     = nodecodes.glue
local penalty_code  = nodecodes.penalty
local glyph_code    = nodecodes.glyph

local nuts          = nodes.nuts
local tonut         = nuts.tonut
local tonode        = nuts.tonode

----- getfield      = nuts.getfield
local getnext       = nuts.getnext
local getprev       = nuts.getprev
local getboth       = nuts.getboth
local getdisc       = nuts.getdisc
local getid         = nuts.getid
local getlist       = nuts.getlist
local getattribute  = nuts.getattribute
local getbox        = nuts.getbox
local getdirection  = nuts.getdirection
local getwidth      = nuts.getwidth
local takebox       = nuts.takebox

----- setfield      = nuts.setfield
local setlink       = nuts.setlink
local setboth       = nuts.setboth
local setnext       = nuts.setnext
local setprev       = nuts.setprev
local setbox        = nuts.setbox
local setlist       = nuts.setlist
local setdisc       = nuts.setdisc
local setwidth      = nuts.setwidth
local setheight     = nuts.setheight
local setdepth      = nuts.setdepth
local setshift      = nuts.setshift
local setsplit      = nuts.setsplit
local setattrlist   = nuts.setattrlist

local flush_node    = nuts.flush_node
local flush_list    = nuts.flush_list
local copy_node     = nuts.copy
local copy_list     = nuts.copy_list
local find_tail     = nuts.tail
local getdimensions = nuts.dimensions
local hpack         = nuts.hpack
local vpack         = nuts.vpack
local traverse_id   = nuts.traverse_id
local free          = nuts.free
local findtail      = nuts.tail

local nextdisc      = nuts.traversers.disc
local nextdir       = nuts.traversers.dir
local nexthlist     = nuts.traversers.hlist

local listtoutf     = nodes.listtoutf

local nodepool      = nuts.pool
local new_penalty   = nodepool.penalty
local new_hlist     = nodepool.hlist
local new_glue      = nodepool.glue

local setlistcolor  = nodes.tracers.colors.setlist

local texget        = tex.get
local texgetbox     = tex.getbox
local texsetdimen   = tex.setdimen

local function hyphenatedlist(head,usecolor)
    local current = head and tonut(head)
    while current do
        local id = getid(current)
        local prev, next = getboth(current)
        if id == disc_code then
            local pre, post, replace = getdisc(current)
            if not usecolor then
                -- nothing fancy done
            elseif pre and post then
                setlistcolor(pre,"darkmagenta")
                setlistcolor(post,"darkcyan")
            elseif pre then
                setlistcolor(pre,"darkyellow")
            elseif post then
                setlistcolor(post,"darkyellow")
            end
            if replace then
                flush_list(replace)
            end
            setdisc(current)
            if pre then
                setlink(prev,new_penalty(10000),pre)
                setlink(find_tail(pre),current)
            end
            if post then
                setlink(current,new_penalty(10000),post)
                setlink(find_tail(post),next)
            end
        elseif id == vlist_code or id == hlist_code then
            hyphenatedlist(getlist(current))
        end
        current = next
    end
end

implement {
    name      = "hyphenatedlist",
    arguments = { "integer", "boolean" },
    actions   = function(n,color)
        local b = texgetbox(n)
        if b then
            hyphenatedlist(b.list,color)
        end
    end
}

-- local function hyphenatedhack(head,pre)
--     pre = tonut(pre)
--     for n in nextdisc, tonut(head) do
--         local hyphen = getfield(n,"pre")
--         if hyphen then
--             flush_list(hyphen)
--         end
--         setfield(n,"pre",copy_list(pre))
--     end
-- end
--
-- commands.hyphenatedhack = hyphenatedhack

local function checkedlist(list)
    if type(list) == "number" then
        return getlist(getbox(tonut(list)))
    else
        return tonut(list)
    end
end

implement {
    name      = "showhyphenatedinlist",
    arguments = "integer",
    actions   = function(n)
        -- we just hyphenate (as we pass a hpack) .. a bit too much casting but ...
        local l = languages.hyphenators.handler(tonode(checkedlist(n)))
        report_hyphenation("show: %s",listtoutf(l,false,true))
    end
}

local function applytochars(current,doaction,noaction,nested)
    while current do
        local id = getid(current)
        if nested and (id == hlist_code or id == vlist_code) then
            context.beginhbox()
            applytochars(getlist(current),doaction,noaction,nested)
            context.endhbox()
        elseif id ~= glyph_code then
            noaction(tonode(copy_node(current)))
        else
            doaction(tonode(copy_node(current)))
        end
        current = getnext(current)
    end
end

local function applytowords(current,doaction,noaction,nested)
    local start
    while current do
        local id = getid(current)
        if id == glue_code then
            if start then
                doaction(tonode(copy_list(start,current)))
                start = nil
            end
            noaction(tonode(copy_node(current)))
        elseif nested and (id == hlist_code or id == vlist_code) then
            context.beginhbox()
            applytowords(getlist(current),doaction,noaction,nested)
            context.egroup()
        elseif not start then
            start = current
        end
        current = getnext(current)
    end
    if start then
        doaction(tonode(copy_list(start)))
    end
end

local methods = {
    char       = applytochars,
    characters = applytochars,
    word       = applytowords,
    words      = applytowords,
}

implement {
    name      = "applytobox",
    arguments = {
        {
            { "box", "integer" },
            { "command" },
            { "method" },
            { "nested", "boolean" },
        }
    },
    actions   = function(specification)
        local list   = checkedlist(specification.box)
        local action = methods[specification.method or "char"]
        if list and action then
            action(list,context[specification.command or "ruledhbox"],context,specification.nested)
        end
     end
}

local split_char = lpeg.Ct(lpeg.C(1)^0)
local split_word = lpeg.tsplitat(lpeg.patterns.space)
local split_line = lpeg.tsplitat(lpeg.patterns.eol)

local function processsplit(specification)
    local str     = specification.data    or ""
    local command = specification.command or "ruledhbox"
    local method  = specification.method  or "word"
    local spaced  = specification.spaced
    if method == "char" or method == "character" then
        local words = lpegmatch(split_char,str)
        for i=1,#words do
            local word = words[i]
            if word == " " then
                if spaced then
                    context.space()
                end
            elseif command then
                context[command](word)
            else
                context(word)
            end
        end
    elseif method == "word" then
        local words = lpegmatch(split_word,str)
        for i=1,#words do
            local word = words[i]
            if spaced and i > 1 then
                context.space()
            end
            if command then
                context[command](word)
            else
                context(word)
            end
        end
    elseif method == "line" then
        local words = lpegmatch(split_line,str)
        for i=1,#words do
            local word = words[i]
            if spaced and i > 1 then
                context.par()
            end
            if command then
                context[command](word)
            else
                context(word)
            end
        end
    else
        context(str)
    end
end

implement {
    name      = "processsplit",
    actions   = processsplit,
    arguments = {
        {
            { "data" },
            { "command" },
            { "method" },
            { "spaced", "boolean" },
        }
    }
}

local a_vboxtohboxseparator = attributes.private("vboxtohboxseparator")

implement {
    name      = "vboxlisttohbox",
    arguments = { "integer", "integer", "dimen" },
    actions   = function(original,target,inbetween)
        local current = getlist(getbox(original))
        local head = nil
        local tail = nil
        while current do
            local id   = getid(current)
            local next = getnext(current)
            if id == hlist_code then
                local list = getlist(current)
                if head then
                    if inbetween > 0 then
                        local n = new_glue(0,0,inbetween)
                        setlink(tail,n)
                        tail = n
                    end
                    setlink(tail,list)
                else
                    head = list
                end
                tail = find_tail(list)
                -- remove last separator
                if getid(tail) == hlist_code and getattribute(tail,a_vboxtohboxseparator) == 1 then
                    local temp = tail
                    local prev = getprev(tail)
                    if next then
                        local list = getlist(tail)
                        setlink(prev,list)
                        setlist(tail)
                        tail = find_tail(list)
                    else
                        tail = prev
                    end
                    flush_node(temp)
                end
                -- done
                setnext(tail)
                setlist(current)
            end
            current = next
        end
        local result = new_hlist()
        setlist(result,head)
        setbox(target,result)
     -- setbox(target,new_hlist(head))
    end
}

implement {
    name      = "hboxtovbox",
    arguments = "integer",
    actions   = function(n)
        local b = getbox(n)
        local factor = texget("baselineskip",false) / texget("hsize")
        setdepth(b,0)
        setheight(b,getwidth(b) * factor)
    end
}

implement {
    name      = "boxtostring",
    arguments = "integer",
    actions   = function(n)
        context.puretext(nodes.toutf(texgetbox(n).list)) -- helper is defined later
    end
}

local function getnaturaldimensions(n)
    local w = 0
    local h = 0
    local d = 0
    local l = getlist(getbox(n))
    if l then
        w, h, d = getdimensions(l)
    end
    texsetdimen("lastnaturalboxwd",w)
    texsetdimen("lastnaturalboxht",h)
    texsetdimen("lastnaturalboxdp",d)
    return w, h, d
end

implement {
    name      = "getnaturaldimensions",
    arguments = "integer",
    actions   = getnaturaldimensions
}

implement {
    name      = "naturalwd",
    arguments = "integer",
    actions   = function(n)
        getnaturaldimensions(n)
        context.lastnaturalboxwd(false)
    end
}

implement {
    name      = "getnaturalwd",
    arguments = "integer",
    actions   = function(n)
        local w = 0
        local h = 0
        local d = 0
        local l = getlist(getbox(n))
        if l then
            w, h, d = getdimensions(l)
        end
        context("\\dimexpr%i\\scaledpoint\\relax",w)
    end
}

local function setboxtonaturalwd(n)
    local old = takebox(n)
    local new = hpack(getlist(old))
    setlist(old,nil)
    flush_node(old)
    setbox(n,new)
end

implement {
    name      = "setnaturalwd",
    arguments = "integer",
    actions   = setboxtonaturalwd
}

nodes.setboxtonaturalwd = setboxtonaturalwd

local doifelse = commands.doifelse

do

    local dirvalues        = nodes.dirvalues
    local lefttoright_code = dirvalues.lefttoright
    local righttoleft_code = dirvalues.righttoleft

    local function firstdirinbox(n)
        local b = getbox(n)
        if b then
            local l = getlist(b)
            if l then
                for d in nextdir, l do
                    return getdirection(d)
                end
                for h in nexthlist, l do
                    return getdirection(h)
                end
            end
        end
        return lefttoright_code
    end

    nodes.firstdirinbox = firstdirinbox

    implement {
        name      = "doifelserighttoleftinbox",
        arguments = "integer",
        actions   = function(n)
            doifelse(firstdirinbox(n) == righttoleft_code)
        end
    }

end

-- new (handy for mp) .. might move to its own module

do

    local nuts       = nodes.nuts
    local tonode     = nuts.tonode
    local takebox    = nuts.takebox
    local flush_list = nuts.flush_list
    local copy_list  = nuts.copy_list
    local getwhd     = nuts.getwhd
    local setbox     = nuts.setbox
    local new_hlist  = nuts.pool.hlist

    local boxes      = { }
    nodes.boxes      = boxes
    local cache      = table.setmetatableindex("table")
    local report     = logs.reporter("boxes","cache")
    local trace      = false

    trackers.register("nodes.boxes",function(v) trace = v end)

    function boxes.save(category,name,b)
        name = tonumber(name) or name
        local b = takebox(b)
        if trace then
            report("category %a, name %a, %s (%s)",category,name,"save",b and "content" or "empty")
        end
        cache[category][name] = b or false
    end

    function boxes.savenode(category,name,n)
        name = tonumber(name) or name
        if trace then
            report("category %a, name %a, %s (%s)",category,name,"save",n and "content" or "empty")
        end
        cache[category][name] = tonut(n) or false
    end

    function boxes.found(category,name)
        name = tonumber(name) or name
        return cache[category][name] and true or false
    end

    function boxes.direct(category,name,copy)
        name = tonumber(name) or name
        local c = cache[category]
        local b = c[name]
        if not b then
            -- do nothing, maybe trace
        elseif copy then
            b = copy_list(b)
        else
            c[name] = false
        end
        if trace then
            report("category %a, name %a, %s (%s)",category,name,"direct",b and "content" or "empty")
        end
        if b then
            return tonode(b)
        end
    end

    function boxes.restore(category,name,box,copy)
        name = tonumber(name) or name
        local c = cache[category]
        local b = takebox(box)
        if b then
            flush_list(b)
        end
        local b = c[name]
        if not b then
            -- do nothing, maybe trace
        elseif copy then
            b = copy_list(b)
        else
            c[name] = false
        end
        if trace then
            report("category %a, name %a, %s (%s)",category,name,"restore",b and "content" or "empty")
        end
        setbox(box,b or nil)
    end

    function boxes.dimensions(category,name)
        name = tonumber(name) or name
        local b = cache[category][name]
        if b then
            return getwhd(b)
        else
            return 0, 0, 0
        end
    end

    function boxes.reset(category,name)
        name = tonumber(name) or name
        local c = cache[category]
        if name and name ~= "" then
            local b = c[name]
            if b then
                flush_list(b)
                c[name] = false
            end
            if trace then
                report("category %a, name %a, reset",category,name)
            end
        else
            for k, b in next, c do
                if b then
                    flush_list(b)
                end
            end
            cache[category] = { }
            if trace then
                report("category %a, reset",category)
            end
        end
    end

    implement {
        name      = "putboxincache",
        arguments = { "string", "string", "integer" },
        actions   = boxes.save,
    }

    implement {
        name      = "getboxfromcache",
        arguments = { "string", "string", "integer" },
        actions   = boxes.restore,
    }

    implement {
        name      = "directboxfromcache",
        arguments = "2 strings",
        actions   = { boxes.direct, context },
     -- actions   = function(category,name) local b = boxes.direct(category,name) if b then context(b) end end,
    }

    implement {
        name      = "directcopyboxfromcache",
        arguments = { "string", "string", true },
        actions   = { boxes.direct, context },
     -- actions   = function(category,name) local b = boxes.direct(category,name,true) if b then context(b) end end,
    }

    implement {
        name      = "copyboxfromcache",
        arguments = { "string", "string", "integer", true },
        actions   = boxes.restore,
    }

    implement {
        name      = "doifelseboxincache",
        arguments = "2 strings",
        actions   = { boxes.found, doifelse },
    }

    implement {
        name      = "resetboxesincache",
        arguments = "string",
        actions   = boxes.reset,
    }

end

implement {
    name    = "lastlinewidth",
    actions = function()
        local head = tex.lists.page_head
        -- list dimensions returns 3 value but we take the first
        context(head and getdimensions(getlist(find_tail(tonut(tex.lists.page_head)))) or 0)
    end
}

implement {
    name      = "shiftbox",
    arguments = { "integer", "dimension" },
    actions   = function(n,d)
        setshift(getbox(n),d)
    end,
}

implement { name = "vpackbox", arguments = "integer", actions = function(n) setbox(n,(vpack(takebox(n)))) end }
implement { name = "hpackbox", arguments = "integer", actions = function(n) setbox(n,(hpack(takebox(n)))) end }

implement { name = "vpackedbox", arguments = "integer", actions = function(n) context(vpack(takebox(n))) end }
implement { name = "hpackedbox", arguments = "integer", actions = function(n) context(hpack(takebox(n))) end }

implement {
    name      = "scangivendimensions",
    public    = true,
    protected = true,
    arguments = {
        {
            { "width",  "dimension" },
            { "height", "dimension" },
            { "depth",  "dimension" },
        },
    },
    actions   = function(t)
        texsetdimen("givenwidth", t.width  or 0)
        texsetdimen("givenheight",t.height or 0)
        texsetdimen("givendepth", t.depth  or 0)
    end,
}

local function stripglue(list)
    local done  = false
    local first = list
    while first do
        local id = getid(first)
        if id == glue_code or id == penalty_code then
            first = getnext(first)
        else
            break
        end
    end
    if first and first ~= list then
        -- we have discardables
        setsplit(getprev(first),first)
        flush_list(list)
        list = first
        done = true
    end
    if list then
        local tail = findtail(list)
        local last = tail
        while last do
            local id = getid(last)
            if id == glue_code or id == penalty_code then
                last = getprev(last)
            else
                break
            end
        end
        if last ~= tail then
            -- we have discardables
            flush_list(getnext(last))
            setnext(last)
            done = true
        end
    end
    return list, done
end

local function limitate(t) -- don't pack the result !
    local text = t.text
    if text then
        text = tonut(text)
    else
        return
    end
    local sentinel = t.sentinel
    if sentinel then
        sentinel = tonut(sentinel)
        local s = getlist(sentinel)
        setlist(sentinel)
        free(sentinel)
        sentinel = s
    else
        return tonode(text)
    end
    local width = getwidth(text)
    local list  = getlist(text)
    local done  = false
    if t.strip then
        list, done = stripglue(list)
        if not list then
            setlist(text)
            setwidth(text,0)
            return text
        elseif done then
            width = getdimensions(list)
            setlist(text,list)
        end
    end
    local left  = t.left or 0
    local right = t.right or 0
    if left + right < width then
        local last     = nil
        local first    = nil
        local maxleft  = left
        local maxright = right
        local swidth   = getwidth(sentinel)
        if maxright > 0 then
            maxleft  = maxleft  - swidth/2
            maxright = maxright - swidth/2
        else
            maxleft  = maxleft  - swidth
        end
        for n in traverse_id(glue_code,list) do
            local width = getdimensions(list,n)
            if width > maxleft then
                if not last then
                    last = n
                end
                break
            else
                last = n
            end
        end
        if last and maxright > 0 then
            for n in traverse_id(glue_code,last) do
                local width = getdimensions(n)
                if width < maxright then
                    first = n
                    break
                else
                    first = n
                end
            end
        end
        if last then
            local rest = getnext(last)
            if rest then
                local tail = findtail(sentinel)
                if first and getid(first) == glue_code and getid(tail) == glue_code then
                    setwidth(first,0)
                end
                if last and getid(last) == glue_code and getid(sentinel) == glue_code then
                    setwidth(last,0)
                end
                if first and first ~= last then
                    local prev = getprev(first)
                    if prev then
                        setnext(prev)
                    end
                    setlink(tail,first)
                end
                setlink(last,sentinel)
                setprev(rest)
                flush_list(rest)
            end
        end
    end
    setlist(text)
    free(text)
    return tonode(list)
end

implement {
    name      = "limitated",
    public    = true,
    protected = true,
    arguments = {
        {
            { "left",     "dimension" },
            { "right",    "dimension" },
            { "text",     "hbox" },
            { "sentinel", "hbox" },
            { "strip",    "boolean" },
        }
    },
    actions   = function(t)
        context.dontleavehmode()
        context(limitate(t))
    end,
}
