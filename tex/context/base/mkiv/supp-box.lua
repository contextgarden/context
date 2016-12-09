if not modules then modules = { } end modules ['supp-box'] = {
    version   = 1.001,
    comment   = "companion to supp-box.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this is preliminary code, use insert_before etc

local lpegmatch = lpeg.match

local report_hyphenation = logs.reporter("languages","hyphenation")

local tex           = tex
local context       = context
local nodes         = nodes

local implement     = interfaces.implement

local nodecodes     = nodes.nodecodes

local disc_code     = nodecodes.disc
local hlist_code    = nodecodes.hlist
local vlist_code    = nodecodes.vlist
local glue_code     = nodecodes.glue
local glyph_code    = nodecodes.glyph

local nuts          = nodes.nuts
local tonut         = nuts.tonut
local tonode        = nuts.tonode

local getfield      = nuts.getfield
local getnext       = nuts.getnext
local getprev       = nuts.getprev
local getdisc       = nuts.getdisc
local getid         = nuts.getid
local getlist       = nuts.getlist
local getattribute  = nuts.getattribute
local getbox        = nuts.getbox
local takebox       = nuts.takebox

local setfield      = nuts.setfield
local setlink       = nuts.setlink
local setboth       = nuts.setboth
local setnext       = nuts.setnext
local setbox        = nuts.setbox
local setlist       = nuts.setlist

local flush_node    = nuts.flush_node
local flush_list    = nuts.flush_list
local copy_node     = nuts.copy
local copy_list     = nuts.copy_list
local find_tail     = nuts.tail
local traverse_id   = nuts.traverse_id
local link_nodes    = nuts.linked
local dimensions    = nuts.dimensions
local hpack         = nuts.hpack

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
        local id   = getid(current)
        local next = getnext(current)
        local prev = getprev(current)
        if id == disc_code then
            local pre, post, replace = getdisc(current)
            if pre then
                setfield(current,"pre",nil)
            end
            if post then
                setfield(current,"post",nil)
            end
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
                setfield(current,"replace",nil)
            end
            setboth(current)
            local list = link_nodes (
                pre and new_penalty(10000),
                pre,
                current,
                post,
                post and new_penalty(10000)
            )
            local tail = find_tail(list)
            if prev then
                setlink(prev,list)
            end
            if next then
                setlink(tail,next)
            end
         -- flush_node(current)
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
--     for n in traverse_id(disc_code,tonut(head)) do
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
    actions   = function(box)
        report_hyphenation("show: %s",listtoutf(checkedlist(n),false,true))
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
    end
}

implement {
    name      = "hboxtovbox",
    arguments = "integer",
    actions   = function(n)
        local b = getbox(n)
        local factor = texget("baselineskip").width / texget("hsize")
        setfield(b,"depth",0)
        setfield(b,"height",getfield(b,"width") * factor)
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
    local w, h, d = 0, 0, 0
    local l = getlist(getbox(n))
    if l then
        w, h, d = dimensions(l)
    end
    texsetdimen("lastnaturalboxwd",w)
    texsetdimen("lastnaturalboxht",h)
    texsetdimen("lastnaturalboxdp",d)
    return w, h, d
end

interfaces.implement {
    name      = "getnaturaldimensions",
    arguments = "integer",
    actions   = getnaturaldimensions
}

interfaces.implement {
    name      = "naturalwd",
    arguments = "integer",
    actions   = function(n)
        getnaturaldimensions(n)
        context.lastnaturalboxwd(false)
    end
}

interfaces.implement {
    name      = "getnaturalwd",
    arguments = "integer",
    actions   = function(n)
        local w, h, d = 0, 0, 0
        local l = getlist(getbox(n))
        if l then
            w, h, d = dimensions(l)
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

interfaces.implement {
    name      = "setnaturalwd",
    arguments = "integer",
    actions   = setboxtonaturalwd
}

nodes.setboxtonaturalwd = setboxtonaturalwd

local function firstdirinbox(n)
    local b = getbox(n)
    if b then
        local l = getlist(b)
        if l then
            for h in traverse_id(hlist_code,l) do
                return getfield(h,"dir")
            end
        end
    end
end

nodes.firstdirinbox = firstdirinbox

local doifelse = commands.doifelse

interfaces.implement {
    name      = "doifelserighttoleftinbox",
    arguments = "integer",
    actions   = function(n)
        doifelse(firstdirinbox(n) == "TRT")
    end
}

-- new (handy for mp) .. might move to its own module

do

    local flush_list = nodes.flush_list
    local copy_list  = nodes.copy_list
    local takebox    = nodes.takebox
    local texsetbox  = tex.setbox

    local new_hlist  = nodes.pool.hlist

    local boxes  = { }
    nodes.boxes  = boxes
    local cache  = table.setmetatableindex("table")
    local report = logs.reporter("boxes","cache")
    local trace  = false

    trackers.register("nodes.boxes",function(v) trace = v end)

    function boxes.save(category,name,box)
name = tonumber(name) or name
        local b = takebox(box)
        if trace then
            report("category %a, name %a, %s (%s)",category,name,"save",b and "content" or "empty")
        end
        cache[category][name] = b or false
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
        return b or nil
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
        texsetbox(box,b or nil)
    end

    function boxes.dimensions(category,name)
name = tonumber(name) or name
        local b = cache[category][name]
        if b then
            return b.width, b.height, b.depth
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

    interfaces.implement {
        name      = "putboxincache",
        arguments = { "string", "string", "integer" },
        actions   = boxes.save,
    }

    interfaces.implement {
        name      = "getboxfromcache",
        arguments = { "string", "string", "integer" },
        actions   = boxes.restore,
    }

    interfaces.implement {
        name      = "directboxfromcache",
        arguments = { "string", "string" },
        actions   = { boxes.direct, context },
     -- actions   = function(category,name) local b = boxes.direct(category,name) if b then context(b) end end,
    }

    interfaces.implement {
        name      = "directcopyboxfromcache",
        arguments = { "string", "string", true },
        actions   = { boxes.direct, context },
     -- actions   = function(category,name) local b = boxes.direct(category,name,true) if b then context(b) end end,
    }

    interfaces.implement {
        name      = "copyboxfromcache",
        arguments = { "string", "string", "integer", true },
        actions   = boxes.restore,
    }

    interfaces.implement {
        name      = "doifelseboxincache",
        arguments = { "string", "string" },
        actions   = { boxes.found, doifelse },
    }

    interfaces.implement {
        name      = "resetboxesincache",
        arguments = { "string" },
        actions   = boxes.reset,
    }

end
