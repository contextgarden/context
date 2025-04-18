if not modules then modules = { } end modules ['font-nod'] = {
    version   = 1.001,
    optimize  = true,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utfchar = utf.char
local concat, fastcopy = table.concat, table.fastcopy
local match, rep = string.match, string.rep

fonts = fonts or { }
nodes = nodes or { }

local fonts            = fonts
local nodes            = nodes
local context          = context

local tracers          = nodes.tracers or { }
nodes.tracers          = tracers

local tasks            = nodes.tasks or { }
nodes.tasks            = tasks

local handlers         = nodes.handlers or { }
nodes.handlers         = handlers

local nuts             = nodes.nuts
local tonut            = nuts.tonut
local tonode           = nuts.tonode

local injections       = nodes.injections or { }
nodes.injections       = injections

local step_tracers     = tracers.steppers or { }
tracers.steppers       = step_tracers

local nodecodes        = nodes.nodecodes

local glyph_code       = nodecodes.glyph
local hlist_code       = nodecodes.hlist
local vlist_code       = nodecodes.vlist
local disc_code        = nodecodes.disc
local glue_code        = nodecodes.glue
local kern_code        = nodecodes.kern
local dir_code         = nodecodes.dir
local par_code         = nodecodes.par

local getnext          = nuts.getnext
local getprev          = nuts.getprev
local getid            = nuts.getid
local getfont          = nuts.getfont
local getsubtype       = nuts.getsubtype
local getlist          = nuts.getlist
local getdisc          = nuts.getdisc
local getreplace       = nuts.getreplace
local isglyph          = nuts.isglyph
local getkern          = nuts.getkern
local getdirection     = nuts.getdirection
local getwidth         = nuts.getwidth

local setbox           = nuts.setbox
local setchar          = nuts.setchar
local setsubtype       = nuts.setsubtype

local copy_node_list   = nuts.copylist
local hpacknodelist    = nuts.hpack
local flushnodelist    = nuts.flushlist
local protectglyphs    = nuts.protectglyphs
local startofpar       = nuts.startofpar

local nextnode         = nuts.traversers.node
local nextglyph        = nuts.traversers.glyph

local nodepool         = nuts.pool
local new_glyph        = nodepool.glyph

local formatters       = string.formatters
local formatter        = string.formatter

local hashes           = fonts.hashes

local fontidentifiers  = hashes.identifiers
local fontdescriptions = hashes.descriptions
local fontcharacters   = hashes.characters
local fontproperties   = hashes.properties
local fontparameters   = hashes.parameters

local properties = nodes.properties.data

local function freeze(h,where)
    for n in nextnode, h do -- todo: disc but not traced anyway
        local p = properties[n]
        if p then
            local i = p.injections         if i then p.injections        = fastcopy(i) end
         -- local i = r.preinjections      if i then p.preinjections     = fastcopy(i) end
         -- local i = r.postinjections     if i then p.postinjections    = fastcopy(i) end
         -- local i = r.replaceinjections  if i then p.replaceinjections = fastcopy(i) end
            -- only injections
        end
    end
end

local f_unicode = formatters["%U"]
local f_badcode = formatters["{%i}"]

local stack = { }

function tracers.start(tag)
    stack[#stack+1] = tag
    local tracer = tracers[tag]
    if tracer and tracer.start then
        tracer.start()
    end
end
function tracers.stop()
    local tracer = stack[#stack]
    if tracer and tracer.stop then
        tracer.stop()
    end
    stack[#stack] = nil
end

-- experimental

local collection, collecting, messages = { }, false, { }

function step_tracers.start()
    collecting = true
end

function step_tracers.stop()
    collecting = false
end

function step_tracers.reset()
    for i=1,#collection do
        local c = collection[i]
        if c then
            flushnodelist(c)
        end
    end
    collection, messages = { }, { }
end

function step_tracers.nofsteps()
    return context(#collection)
end

function step_tracers.glyphs(n,i)
    local c = collection[i]
    if c then
        local c = copy_node_list(c)
        local b = hpacknodelist(c) -- multiple arguments
        setbox(n,b)
    end
end

function step_tracers.features()
    local f = collection[1]
    for n, char, font in nextglyph, f do
        local tfmdata  = fontidentifiers[font]
        local features = tfmdata.resources.features
        local result_1 = { }
        local result_2 = { }
        local gpos = features and features.gpos or { }
        local gsub = features and features.gsub or { }
        for feature, value in table.sortedhash(tfmdata.shared.features) do
            if feature == "number" or feature == "features" then
                value = false
            elseif type(value) == "boolean" then
                if value then
                    value = "yes"
                else
                    value = false
                end
            else
                -- use value
            end
            if value then
                if gpos[feature] or gsub[feature] or feature == "language" or feature == "script" then
                    result_1[#result_1+1] = formatters["%s=%s"](feature,value)
                else
                    result_2[#result_2+1] = formatters["%s=%s"](feature,value)
                end
            end
        end
        if #result_1 > 0 then
            context("{\\bf[basic:} %, t{\\bf]} ",result_1)
        else
            context("{\\bf[}no basic features{\\bf]} ")
        end
        if #result_2 > 0 then
            context("{\\bf[extra:} %, t{\\bf]}",result_2)
        else
            context("{\\bf[}no extra features{\\bf]}")
        end
        return
    end
end

function tracers.fontchar(font,char)
    local n = new_glyph(font,char)
    setsubtype(n,256)
    context(tonode(n))
end

function step_tracers.font(command)
    local c = collection[1]
    for n, char, font in nextglyph, c do
        local name = file.basename(fontproperties[font].filename or "unknown")
        local size = fontparameters[font].size or 0
        if command then
            context[command](font,name,size) -- size in sp
        else
            context("[%s: %s @ %p]",font,name,size)
        end
        return
    end
end

local colors = {
    pre     = { "darkred" },
    post    = { "darkgreen" },
    replace = { "darkblue" },
}

function step_tracers.codes(i,command,space)
    local c = collection[i]

    local function showchar(c,f)
        if command then
            local d = fontdescriptions[f]
            local d = d and d[c]
            context[command](f,c,d and d.class or "")
        else
            context("[%s:U+%X]",f,c)
        end
    end

    local function showdisc(d,w,what)
        if w then
            context.startcolor(colors[what])
            context("%s:",what)
            for c, id in nextnode, w do
                if id == glyph_code then
                    local c, f = isglyph(c)
                    showchar(c,f)
                else
                    context("[%s]",nodecodes[id])
                end
            end
            context[space]()
            context.stopcolor()
        end
    end

    while c do
        local char, id = isglyph(c)
print(nuts.tonode(c))
        if char then
            showchar(char,id)
        elseif id == dir_code or (id == par_code and startofpar(c)) then
            context("[%s]",getdirection(c) or "?")
        elseif id == disc_code then
            local pre, post, replace = getdisc(c)
            if pre or post or replace then
                context("[")
                context[space]()
                showdisc(c,pre,"pre")
                showdisc(c,post,"post")
                showdisc(c,replace,"replace")
                context[space]()
                context("]")
            else
                context("[disc]")
            end
        else
            context("[%s]",nodecodes[id])
        end
        c = getnext(c)
    end
end

function step_tracers.messages(i,command,split)
    local list = messages[i] -- or { "no messages" }
    if list then
        for i=1,#list do
            local l = list[i]
            if not command then
                context("(%s)",l)
            elseif split then
                local a, b = match(l,"^(.-)%s*:%s*(.*)$")
                context[command](a or l or "",b or "")
            else
                context[command](l)
            end
        end
    end
end

-- hooks into the node list processor (see otf)

function step_tracers.check(head)
    if collecting then
        step_tracers.reset()
        local n = copy_node_list(head)
        freeze(n,"check")
        injections.keepcounts() -- one-time
        local l = injections.handler(n,"trace")
        if l then -- hm, can be false
            n = l
        end
        protectglyphs(n)
        collection[1] = n
    end
end

function step_tracers.register(head)
    if collecting then
        local nc = #collection+1
        if messages[nc] then
            local n = copy_node_list(head)
            freeze(n,"register")
            injections.keepcounts() -- one-time
            local l = injections.handler(n,"trace")
            if l then -- hm, can be false
                n = l
            end
            protectglyphs(n)
            collection[nc] = n
        end
    end
end

function step_tracers.message(str,...)
    str = formatter(str,...)
    if collecting then
        local n = #collection + 1
        local m = messages[n]
        if not m then m = { } messages[n] = m end
        m[#m+1] = str
    end
    return str -- saves an intermediate var in the caller
end

--

local threshold = 65536 -- 1pt

local function toutf(list,result,nofresult,stopcriterium,nostrip)
    if list then
        for n, id in nextnode, tonut(list) do
            if id == glyph_code then
                local c, f = isglyph(n)
                if c > 0 then
                    local fc = fontcharacters[f]
                    if fc then
                        local fcc = fc[c]
                        if fcc then
                            local u = fcc.unicode
                            if not u then
                                nofresult = nofresult + 1
                                result[nofresult] = utfchar(c)
                            elseif type(u) == "table" then
                                for i=1,#u do
                                    nofresult = nofresult + 1
                                    result[nofresult] = utfchar(u[i])
                                end
                            else
                                nofresult = nofresult + 1
                                result[nofresult] = utfchar(u)
                            end
                        else
                            nofresult = nofresult + 1
                            result[nofresult] = utfchar(c)
                        end
                    else
                        nofresult = nofresult + 1
                        result[nofresult] = f_unicode(c)
                    end
                else
                    nofresult = nofresult + 1
                    result[nofresult] = f_badcode(c)
                end
            elseif id == disc_code then
                local replace = getreplace(n)
                result, nofresult = toutf(replace,result,nofresult,false,true) -- needed?
            elseif id == hlist_code or id == vlist_code then
             -- if nofresult > 0 and result[nofresult] ~= " " then
             --     nofresult = nofresult + 1
             --     result[nofresult] = " "
             -- end
                result, nofresult = toutf(getlist(n),result,nofresult,false,true)
            elseif id == glue_code then
                if nofresult > 0 and result[nofresult] ~= " " and getwidth(n) > threshold then
                    nofresult = nofresult + 1
                    result[nofresult] = " "
                end
            elseif id == kern_code then
                if nofresult > 0 and result[nofresult] ~= " " and getkern(n) > threshold then
                    nofresult = nofresult + 1
                    result[nofresult] = " "
                end
            end
            if n == stopcriterium then
                break
            end
        end
    end
    if not nostrip and nofresult > 0 and result[nofresult] == " " then
        result[nofresult] = nil
        nofresult = nofresult - 1
    end
    return result, nofresult
end

function nodes.toutf(list,stopcriterium)
    local result, nofresult = toutf(list,{},0,stopcriterium)
    return concat(result)
end
