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

local splitstring   = string.split

local nodecodes     = nodes.nodecodes

local disc_code     = nodecodes.disc
local hlist_code    = nodecodes.hlist
local vlist_code    = nodecodes.vlist
local glue_code     = nodecodes.glue
local kern_code     = nodecodes.kern
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

local setfield      = nuts.setfield
local setlink       = nuts.setlink
local setboth       = nuts.setboth
local setnext       = nuts.setnext
local setbox        = nuts.setbox

local free_node     = nuts.free
local flush_list    = nuts.flush_list
local copy_node     = nuts.copy
local copy_list     = nuts.copy_list
local find_tail     = nuts.tail
local traverse_id   = nuts.traverse_id
local link_nodes    = nuts.linked
local dimensions    = nuts.dimensions

local listtoutf     = nodes.listtoutf

local nodepool      = nuts.pool
local new_penalty   = nodepool.penalty
local new_hlist     = nodepool.hlist
local new_glue      = nodepool.glue
local new_rule      = nodepool.rule
local new_kern      = nodepool.kern

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
         -- setfield(current,"replace",new_rule(65536)) -- new_kern(65536*2))
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
         -- free_node(current)
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
                        setfield(tail,"list",nil)
                        tail = find_tail(list)
                    else
                        tail = prev
                    end
                    free_node(temp)
                end
                -- done
                setnext(tail)
                setfield(current,"list",nil)
            end
            current = next
        end
        local result = new_hlist()
        setfield(result,"list",head)
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
