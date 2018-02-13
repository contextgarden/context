if not modules then modules = { } end modules ['lang-dis'] = {
    version   = 1.001,
    comment   = "companion to lang-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat = table.concat

local tex                = tex
local nodes              = nodes

local tasks              = nodes.tasks
local nuts               = nodes.nuts

local enableaction       = tasks.enableaction
local setaction          = tasks.setaction

local tonode             = nuts.tonode
local tonut              = nuts.tonut

local setfield           = nuts.setfield
local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getid              = nuts.getid
local getfont            = nuts.getfont
local getattr            = nuts.getattr
local getsubtype         = nuts.getsubtype
local setsubtype         = nuts.setsubtype
local getchar            = nuts.getchar
local setchar            = nuts.setchar
local getdisc            = nuts.getdisc
local setdisc            = nuts.setdisc
local getlang            = nuts.setlang
local getboth            = nuts.getboth
local setlist            = nuts.setlist
local setlink            = nuts.setlink
local isglyph            = nuts.isglyph

local copy_node          = nuts.copy
local remove_node        = nuts.remove
local traverse_id        = nuts.traverse_id
local flush_list         = nuts.flush_list
local flush_node         = nuts.flush_node

local new_disc           = nuts.pool.disc

local nodecodes          = nodes.nodecodes
local disccodes          = nodes.disccodes

local disc_code          = nodecodes.disc
local glyph_code         = nodecodes.glyph

local discretionary_code = disccodes.discretionary
local explicit_code      = disccodes.explicit
local automatic_code     = disccodes.automatic
local regular_code       = disccodes.regular

local a_visualize        = attributes.private("visualizediscretionary")
local setattribute       = tex.setattribute

local getlanguagedata    = languages.getdata
local prehyphenchar      = lang.prehyphenchar
local posthyphenchar     = lang.posthyphenchar

local check_regular      = true

local setlistcolor = nodes.tracers.colors.setlist

function languages.visualizediscretionaries(head)
    for d in traverse_id(disc_code,tonut(head)) do
        if getattr(d,a_visualize) then
            local pre, post, replace = getdisc(d)
            if pre then
                setlistcolor(pre,"darkred")
            end
            if post then
                setlistcolor(post,"darkgreen")
            end
            if replace then
                setlistcolor(replace,"darkblue")
            end
        end
    end
end

local enabled = false

function languages.showdiscretionaries(v)
    if v == false then
        setattribute(a_visualize,unsetvalue)
    else -- also nil
        if not enabled then
            enableaction("processors","languages.visualizediscretionaries")
            enabled = true
        end
        setattribute(a_visualize,1)
    end
end

interfaces.implement {
    name    = "showdiscretionaries",
    actions = languages.showdiscretionaries
}

do

    local toutf   = nodes.listtoutf
    local utfchar = utf.char
    local f_disc  = string.formatters["{%s}{%s}{%s}"]
    local replace = lpeg.replacer( {
        [utfchar(0x200C)] = "|",
        [utfchar(0x200D)] = "|",
    }, nil, true)

    local function convert(list)
        return list and replace(toutf(list)) or ""
    end

    function languages.serializediscretionary(d) -- will move to tracer
        local pre, post, replace = getdisc(d)
        return f_disc(convert(pre),convert(post),convert(replace))
    end

end

-- --

local wiped = 0

local flatten_discretionaries = node.flatten_discretionaries -- todo in nodes

if flatten_discretionaries then

    -- This is not that much faster than the lua variant simply because there is
    -- seldom a replace list but it fits in the picture. See luatex-todo.w for the
    -- code.

    function languages.flatten(head)
        local h, n = flatten_discretionaries(head)
        wiped = wiped + n
        return h, n > 0
    end

else

    local function wipe(head,delayed)
        local p, n = getboth(delayed)
        local _, _, h, _, _, t = getdisc(delayed,true)
        if p or n then
            if h then
                setlink(p,h)
                setlink(t,n)
                setfield(delayed,"replace")
            else
                setlink(p,n)
            end
        end
        if head == delayed then
            head = h
        end
        wiped = wiped + 1
        flush_node(delayed)
        return head
    end

    function languages.flatten(head)
        local nuthead = tonut(head)
        local delayed = nil
        for d in traverse_id(disc_code,nuthead) do
            if delayed then
                nuthead = wipe(nuthead,delayed)
            end
            delayed = d
        end
        if delayed then
            return tonode(wipe(nuthead,delayed)), true
        else
            return head, false
        end
    end

end

function languages.nofflattened()
    return wiped -- handy for testing
end

-- experiment

local flatten = languages.flatten
local getlist = nodes.getlist

nodes.handlers.flattenline = flatten

function nodes.handlers.flatten(head,where)
    if head and (where == "box" or where == "adjusted_hbox") then
        return flatten(head)
    end
    return true
end

directives.register("hyphenator.flatten",function(v)
    setaction("processors","nodes.handlers.flatten",v)
    setaction("contributers","nodes.handlers.flattenline",v)
end)

-- moved here:

function languages.explicithyphen(template)
    local pre, post
    local disc = new_disc()
    if template then
        local langdata = getlanguagedata(getlang(template))
        local instance = langdata and langdata.instance
        if instance then
            local prechr  = prehyphenchar(instance)
            local postchr = posthyphenchar(instance)
            if prechr >= 0 then
                pre = copy_node(template)
                setchar(pre,prechr)
            end
            if postchr >= 0 then
                post = copy_node(template)
                setchar(post,postchr)
            end
        end
    end
    setdisc(disc,pre,post,nil,explicit_code,tex.exhyphenpenalty)
    return disc
end
