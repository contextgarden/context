if not modules then modules = { } end modules ['node-ref'] = {
    version   = 1.001,
    comment   = "companion to node-ref.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- We supported pdf right from the start and in mkii this has resulted in
-- extensive control over the links. Nowadays pdftex provides a lot more
-- control over margins but as mkii supports multiple backends we stuck to
-- our own mechanisms. In mkiv again we implement our own handling. Eventually
-- we will even disable the pdf primitives.

-- helper, will end up in luatex

-- is grouplevel still used?

local concat = table.concat

local attributes, nodes, node = attributes, nodes, node

local allocate            = utilities.storage.allocate, utilities.storage.mark
local mark                = utilities.storage.allocate, utilities.storage.mark

local nodeinjections      = backends.nodeinjections
local codeinjections      = backends.codeinjections

local cleanupreferences   = false
local cleanupdestinations = true

local transparencies      = attributes.transparencies
local colors              = attributes.colors
local references          = structures.references
local tasks               = nodes.tasks

local trace_references    = false  trackers.register("nodes.references",        function(v) trace_references   = v end)
local trace_destinations  = false  trackers.register("nodes.destinations",      function(v) trace_destinations = v end)
local trace_areas         = false  trackers.register("nodes.areas",             function(v) trace_areas        = v end)
local show_references     = false  trackers.register("nodes.references.show",   function(v) show_references    = tonumber(v) or (v and 2.25 or false) end)
local show_destinations   = false  trackers.register("nodes.destinations.show", function(v) show_destinations  = tonumber(v) or (v and 2.00 or false) end)

local report_reference    = logs.reporter("backend","references")
local report_destination  = logs.reporter("backend","destinations")
local report_area         = logs.reporter("backend","areas")

local nuts                = nodes.nuts
local nodepool            = nuts.pool

local tonode              = nuts.tonode
local tonut               = nuts.tonut

local getfield            = nuts.getfield
local setfield            = nuts.setfield
local setlink             = nuts.setlink
local setnext             = nuts.setnext
local setprev             = nuts.setprev
local getnext             = nuts.getnext
local getprev             = nuts.getprev
local getid               = nuts.getid
local getlist             = nuts.getlist
local setlist             = nuts.setlist
local getattr             = nuts.getattr
local setattr             = nuts.setattr
local getsubtype          = nuts.getsubtype

local hpack_list          = nuts.hpack
local vpack_list          = nuts.vpack
local list_dimensions     = nuts.dimensions
local traverse            = nuts.traverse
local find_node_tail      = nuts.tail

local nodecodes           = nodes.nodecodes
local skipcodes           = nodes.skipcodes
local listcodes           = nodes.listcodes

local hlist_code          = nodecodes.hlist
local vlist_code          = nodecodes.vlist
local glue_code           = nodecodes.glue
local glyph_code          = nodecodes.glyph
local rule_code           = nodecodes.rule
local dir_code            = nodecodes.dir
local localpar_code       = nodecodes.localpar

local leftskip_code       = skipcodes.leftskip
local rightskip_code      = skipcodes.rightskip
local parfillskip_code    = skipcodes.parfillskip

local line_code           = listcodes.line

local new_rule            = nodepool.rule
local new_kern            = nodepool.kern

local free_node           = nuts.free

local tosequence          = nodes.tosequence

local implement           = interfaces.implement

-- Normally a (destination) area is a box or a simple stretch if nodes but when it is
-- a paragraph we have a problem: we cannot calculate the height well. This happens
-- with footnotes or content broken across a page.

local function vlist_dimensions(start,stop)
    local temp
    if stop then
        temp = getnext(stop)
        setnext(stop,nil)
    end
    local v = vpack_list(start)
    local w = getfield(v,"width")
    local h = getfield(v,"height")
    local d = getfield(v,"depth")
    setlist(v)
    free_node(v)
    if temp then
        setnext(stop,temp)
    end
    return w, h, d
end

local function hlist_dimensions(start,stop,parent)
    local last = stop and getnext(stop)
    if parent then
        return list_dimensions(getfield(parent,"glue_set"),getfield(parent,"glue_sign"),getfield(parent,"glue_order"),start,last)
    else
        return list_dimensions(start,last)
    end
end

local function dimensions(parent,start,stop) -- in principle we could move some to the caller
    local id = getid(start)
    if start == stop then
        if id == hlist_code or id == vlist_code or id == glyph_code or id == rule_code then -- or image
            if trace_areas then
                report_area("dimensions taken of %a",nodecodes[id])
            end
            -- hm, parent can be zero
            local width  = getfield(start,"width")
            local height = getfield(parent,"height")
            local depth  = getfield(parent,"depth")
            if height == 0 and depth == 0 then
                height = getfield(start,"height")
                depth  = getfield(start,"depth")
            end
            return width, height, depth
        else
            if trace_areas then
                report_area("dimensions calculated of %a",nodecodes[id])
            end
            return hlist_dimensions(start,stop) -- one node only so simple
        end
    end
    local last = stop and getnext(stop)
    if parent then
        -- todo: if no prev and no next and parent
        -- todo: we need a a list_dimensions for a vlist
        if getid(parent) == vlist_code then
            local l = getlist(parent)
            local c = l
            local ok = false
            while c do
                if c == start then
                    ok = true
                end
                if ok and getid(c) == hlist_code then
                    break
                else
                    c = getnext(c)
                end
            end
            if ok and c then
                if trace_areas then
                    report_area("dimensions taken of first line in vlist")
                end
                return getfield(c,"width"), getfield(c,"height"), getfield(c,"depth"), c
            else
                if trace_areas then
                    report_area("dimensions taken of vlist (probably wrong)")
                end
                return hlist_dimensions(start,stop,parent)
            end
        else
            if trace_areas then
                report_area("dimensions taken of range starting with %a using parent",nodecodes[id])
            end
            return hlist_dimensions(start,stop,parent)
        end
    else
        if trace_areas then
            report_area("dimensions taken of range starting with %a",nodecodes[id])
        end
        return hlist_dimensions(start,stop)
    end
end

-- is pardir important at all?

local function inject_range(head,first,last,reference,make,stack,parent,pardir,txtdir)
    local width, height, depth, line = dimensions(parent,first,last)
    if txtdir == "+TRT" or (txtdir == "===" and pardir == "TRT") then -- KH: textdir == "===" test added
        width = - width
    end
    local result, resolved = make(width,height,depth,reference)
    if result and resolved then
        if line then
            -- special case, we only treat the first line in a vlist
            local l = getlist(line)
            if trace_areas then
                report_area("%s: %04i %s %s %s => w=%p, h=%p, d=%p, c=%S","line",
                    reference,pardir or "---",txtdir or "---",
                    tosequence(l,nil,true),width,height,depth,resolved)
            end
            setlist(line,result)
            setlink(result,l)
            return head, last
        else
            if head == first then
                if trace_areas then
                    report_area("%s: %04i %s %s %s => w=%p, h=%p, d=%p, c=%S","head",
                        reference,pardir or "---",txtdir or "---",
                        tosequence(first,last,true),width,height,depth,resolved)
                end
                setlink(result,first)
                return result, last
            else
                if trace_areas then
                    report_area("%s: %04i %s %s %s => w=%p, h=%p, d=%p, c=%S","middle",
                        reference,pardir or "---",txtdir or "---",
                        tosequence(first,last,true),width,height,depth,resolved)
                end
                local prev = getprev(first)
                if prev then
                    setlink(prev,result)
                end
                setlink(result,first)
             -- if first == getnext(head) then
             --     setnext(head,result) -- hm, weird
             -- end
                return head, last
            end
        end
    else
        return head, last
    end
end

local function inject_list(id,current,reference,make,stack,pardir,txtdir)
    local width      = getfield(current,"width")
    local height     = getfield(current,"height")
    local depth      = getfield(current,"depth")
    local correction = 0
    local moveright  = false
    local first      = getlist(current)
    if id == hlist_code then -- box_code line_code
        -- can be either an explicit hbox or a line and there is no way
        -- to recognize this; anyway only if ht/dp (then inline)
        local sr = stack[reference]
        if first then
            if sr and sr[2] then
                local last = find_node_tail(first)
                if getid(last) == glue_code and getsubtype(last) == rightskip_code then
                    local prev = getprev(last)
                    moveright = getid(first) == glue_code and getsubtype(first) == leftskip_code
                    if prev and getid(prev) == glue_code and getsubtype(prev) == parfillskip_code then
                        width = dimensions(current,first,getprev(prev)) -- maybe not current as we already take care of it
                    else
                        if moveright then
                            width = width - getfield(first,"stretch") * getfield(current,"glue_set") * getfield(current,"glue_sign")
                        end
                        width = width - getfield(last,"stretch") * getfield(current,"glue_set") * getfield(current,"glue_sign")
                    end
                end
            else
                -- also weird
            end
        else
            -- ok
        end
        correction = width
    else
        correction = height + depth
        height, depth = depth, height -- ugly hack, needed because pdftex backend does something funny
    end
    if pardir == "TRT" then
        width = - width
    end
    local result, resolved = make(width,height,depth,reference)
    -- todo: only when width is ok
    if result and resolved then
        if trace_areas then
            report_area("%s: %04i %s %s %s: w=%p, h=%p, d=%p, c=%S","box",
                reference,pardir or "---",txtdir or "----","[]",width,height,depth,resolved)
        end
        if not first then
            setlist(current,result)
        elseif moveright then -- brr no prevs done
            -- result after first
            local n = getnext(first)
            setnext(result,n)
            setlink(first,first)
            if n then
                setprev(n,result)
            end
        else
            -- first after result
            setlink(result,first)
            setlist(current,result)
        end
    end
end

-- skip is somewhat messy

local function inject_areas(head,attribute,make,stack,done,skip,parent,pardir,txtdir)  -- main
    if head then
        local current, first, last, firstdir, reference = head, nil, nil, nil, nil
        pardir = pardir or "==="
        txtdir = txtdir or "==="
        while current do
            local id = getid(current)
            if id == hlist_code or id == vlist_code then

                -- see dimensions: this is tricky with split off boxes like inserts
                -- where we can end up with a first and last spanning lines

                local r = getattr(current,attribute)
                -- test \goto{test}[page(2)] test \gotobox{test}[page(2)]
                -- test \goto{\TeX}[page(2)] test \gotobox{\hbox {x} \hbox {x}}[page(2)]
             -- if r and (not skip or r >) skip then -- maybe no > test
             --     inject_list(id,current,r,make,stack,pardir,txtdir)
             -- end
                if r then
                    if not reference then
                        reference, first, last, firstdir = r, current, current, txtdir
                    elseif r == reference then
                        -- same link
                        last = current
                    elseif (done[reference] or 0) == 0 then
                        if not skip or r > skip then -- maybe no > test
                            head, current = inject_range(head,first,last,reference,make,stack,parent,pardir,firstdir)
                            reference, first, last, firstdir = nil, nil, nil, nil
                        end
                    else
                        reference, first, last, firstdir = r, current, current, txtdir
                    end
                    done[r] = (done[r] or 0) + 1
                end
                local list = getlist(current)
                if list then
                    local h, ok
                    h, ok , pardir, txtdir = inject_areas(list,attribute,make,stack,done,r or skip or 0,current,pardir,txtdir)
                    setlist(current,h)
                end
                if r then
                    done[r] = done[r] - 1
                end
            elseif id == dir_code then
                txtdir = getfield(current,"dir")
            elseif id == localpar_code then
                pardir = getfield(current,"dir")
            elseif id == glue_code and getsubtype(current) == leftskip_code then -- any glue at the left?
                --
            else
                local r = getattr(current,attribute)
                if not r then
                    -- just go on, can be kerns
                elseif not reference then
                    reference, first, last, firstdir = r, current, current, txtdir
                elseif r == reference then
                    last = current
                elseif (done[reference] or 0) == 0 then -- or id == glue_code and getsubtype(current) == right_skip_code
                    if not skip or r > skip then -- maybe no > test
                        head, current = inject_range(head,first,last,reference,make,stack,parent,pardir,firstdir)
                        reference, first, last, firstdir = nil, nil, nil, nil
                    end
                else
                    reference, first, last, firstdir = r, current, current, txtdir
                end
            end
            current = getnext(current)
        end
        if reference and (done[reference] or 0) == 0 then
            head = inject_range(head,first,last,reference,make,stack,parent,pardir,firstdir)
        end
    end
    return head, true, pardir, txtdir
end

local function inject_area(head,attribute,make,stack,done,parent,pardir,txtdir) -- singular  !
    if head then
        pardir = pardir or "==="
        txtdir = txtdir or "==="
        local current = head
        while current do
            local id = getid(current)
            if id == hlist_code or id == vlist_code then
                local r = getattr(current,attribute)
                if r and not done[r] then
                    done[r] = true
                    inject_list(id,current,r,make,stack,pardir,txtdir)
                end
                local list = getlist(current)
                if list then
                    setlist(current,(inject_area(list,attribute,make,stack,done,current,pardir,txtdir)))
                end
            elseif id == dir_code then
                txtdir = getfield(current,"dir")
            elseif id == localpar_code then
                pardir = getfield(current,"dir")
            else
                local r = getattr(current,attribute)
                if r and not done[r] then
                    done[r] = true
                    head, current = inject_range(head,current,current,r,make,stack,parent,pardir,txtdir)
                end
            end
            current = getnext(current)
        end
    end
    return head, true
end

-- tracing: todo: use predefined colors

local register_color = colors.register

local a_color        = attributes.private('color')
local a_colormodel   = attributes.private('colormodel')
local a_transparency = attributes.private('transparency')
local u_transparency = nil
local u_colors       = { }
local force_gray     = true

local function addstring(what,str,shift) --todo make a pluggable helper (in font-ctx)
    if str then
        local typesetters = nuts.typesetters
        if typesetters then
            local hashes   = fonts.hashes
            local infofont = fonts.infofont()
            local emwidth  = hashes.emwidths [infofont]
            local exheight = hashes.exheights[infofont]
            if what == "reference" then
                str   = str .. " "
                shift = - (shift or 2.25) * exheight
            else
                str   = str .. " "
                shift = (shift or 2) * exheight
            end
            local text = typesetters.tohpack(str,infofont)
            local rule = new_rule(emwidth/5,4*exheight,3*exheight)
            setfield(text,"shift",shift)
            return hpack_list(nuts.linked(text,rule))
        end
    end
end

local function colorize(width,height,depth,n,reference,what,sr,offset)
    if force_gray then n = 0 end
    u_transparency = u_transparency or transparencies.register(nil,2,.65)
    local ucolor = u_colors[n]
    if not ucolor then
        if n == 1 then
            u_color = register_color(nil,'rgb',.75,0,0)
        elseif n == 2 then
            u_color = register_color(nil,'rgb',0,.75,0)
        elseif n == 3 then
            u_color = register_color(nil,'rgb',0,0,.75)
        else
            n = 0
            u_color = register_color(nil,'gray',.5)
        end
        u_colors[n] = u_color
    end
    if width == 0 then
        -- probably a strut as placeholder
        report_area("%s %s has no %s dimensions, width %p, height %p, depth %p",what,reference,"horizontal",width,height,depth)
        width = 65536
    end
    if height + depth <= 0 then
        report_area("%s %s has no %s dimensions, width %p, height %p, depth %p",what,reference,"vertical",width,height,depth)
        height = 65536/2
        depth  = height
    end
    local rule = new_rule(width,height,depth) -- todo: use tracer rule
    setattr(rule,a_colormodel,1) -- gray color model
    setattr(rule,a_color,u_color)
    setattr(rule,a_transparency,u_transparency)
    if width < 0 then
        local kern = new_kern(width)
        setfield(rule,"width",-width)
        setnext(kern,rule)
        setprev(rule,kern)
        return kern
    else

if sr and sr ~= "" then
    local text = addstring(what,sr,shift)
    if text then
        local kern = new_kern(-getfield(text,"width"))
        setlink(kern,text)
        setlink(text,rule)
        return kern
    end
end

        return rule
    end
end

local function justadd(what,sr,shift)
    if sr and sr ~= "" then
        local text = addstring(what,sr,shift)
        if text then
            local kern = new_kern(-getfield(text,"width"))
            setlink(kern,text)
            setlink(text,rule)
            return kern
        end
    end
end

-- references:

local texsetattribute = tex.setattribute
local texsetcount     = tex.setcount

local stack           = { }
local done            = { }
local attribute       = attributes.private('reference')
local nofreferences   = 0
local topofstack      = 0

nodes.references = {
    attribute = attribute,
    stack     = stack,
    done      = done,
}

-- todo: get rid of n (n is just a number, can be used for tracing, obsolete)

local function setreference(h,d,r)
    topofstack = topofstack + 1
    -- the preroll permits us to determine samepage (but delayed also has some advantages)
    -- so some part of the backend work is already done here
    stack[topofstack] = { r, h, d, codeinjections.prerollreference(r) }
 -- texsetattribute(attribute,topofstack) -- todo -> at tex end
    texsetcount("lastreferenceattribute",topofstack)
end

function references.get(n) -- not public so functionality can change
    local sn = stack[n]
    return sn and sn[1]
end

local function makereference(width,height,depth,reference) -- height and depth are of parent
    local sr = stack[reference]
    if sr then
        if trace_references then
            report_reference("resolving attribute %a",reference)
        end
        local resolved, ht, dp, set, n = sr[1], sr[2], sr[3], sr[4], sr[5]
     -- logs.report("temp","child: ht=%p dp=%p, parent: ht=%p dp=%p",ht,dp,height,depth)
        if ht then
            if height < ht then height = ht end
            if depth  < dp then depth  = dp end
        end
     -- logs.report("temp","used: ht=%p dp=%p",height,depth)
        local annot = nodeinjections.reference(width,height,depth,set)
        if annot then
            annot = tonut(annot) -- todo
            nofreferences = nofreferences + 1
            local result, current, texts
            if show_references then
                local d = sr[1]
                if d then
                    local r = d.reference
                    local p = d.prefix
                    if r then
                        if p then
                            texts = p .. "|" .. r
                        else
                            texts = r
                        end
                    else
                     -- t[#t+1] = d.internal or "?"
                    end
                end
            end
            if trace_references then
                local step = 65536
                result = hpack_list(colorize(width,height-step,depth-step,2,reference,"reference",texts,show_references)) -- step subtracted so that we can see seperate links
                setfield(result,"width",0)
                current = result
            elseif texts then
                texts = justadd("reference",texts,show_references)
                if texts then
                    result = hpack_list(texts)
                    setfield(result,"width",0)
                    current = result
                end
            end
            if current then
                setlink(current,annot)
            else
                result = annot
            end
            references.registerpage(n)
            result = hpack_list(result,0)
            setfield(result,"width",0)
            setfield(result,"height",0)
            setfield(result,"depth",0)
            if cleanupreferences then stack[reference] = nil end
            return result, resolved
        elseif trace_references then
            report_reference("unable to resolve annotation %a",reference)
        end
    elseif trace_references then
        report_reference("unable to resolve attribute %a",reference)
    end
end

-- function nodes.references.handler(head)
--     if topofstack > 0 then
--         return inject_areas(head,attribute,makereference,stack,done)
--     else
--         return head, false
--     end
-- end

function nodes.references.handler(head)
    if topofstack > 0 then
        head = tonut(head)
        local head, done = inject_areas(head,attribute,makereference,stack,done)
        return tonode(head), done
    else
        return head, false
    end
end

-- destinations (we can clean up once set, unless tagging!)

local stack           = { }
local done            = { }
local attribute       = attributes.private('destination')
local nofdestinations = 0
local topofstack      = 0

nodes.destinations = {
    attribute = attribute,
    stack     = stack,
    done      = done,
}

local function setdestination(n,h,d,name,view) -- n = grouplevel, name == table
    topofstack = topofstack + 1
    stack[topofstack] = { n, h, d, name, view }
    return topofstack
end

local function makedestination(width,height,depth,reference)
    local sr = stack[reference]
    if sr then
        if trace_destinations then
            report_destination("resolving attribute %a",reference)
        end
        local resolved, ht, dp, name, view = sr[1], sr[2], sr[3], sr[4], sr[5] -- sr[4] will change to just internal
        if ht then
            if height < ht then height = ht end
            if depth  < dp then depth  = dp end
        end
        local result, current, texts
        if show_destinations then
            if name and #name > 0 then
                local t = { }
                for i=1,#name do
                    local s = name[i]
                    if type(s) == "number" then
                        local d = references.internals[s]
                        if d then
                            d = d.references
                            local r = d.reference
                            local p = d.usedprefix
                            if r then
                                if p then
                                    t[#t+1] = p .. "|" .. r
                                else
                                    t[#t+1] = r
                                end
                            else
                             -- t[#t+1] = d.internal or "?"
                            end
                        end
                    else
                        -- in fact we have a prefix:name here
                    end
                end
                if #t > 0 then
                    texts = concat(t," & ")
                end
            end
        end
        if trace_destinations then
            local step = 0
            if width  == 0 then
                step = 4*65536
                width, height, depth = 5*step, 5*step, 0
            end
            local rule = hpack_list(colorize(width,height,depth,3,reference,"destination",texts,show_destinations))
            setfield(rule,"width",0)
            if not result then
                result, current = rule, rule
            else
                setlink(current,rule)
                current = rule
            end
            width, height = width - step, height - step
        elseif texts then
            texts = justadd("destination",texts,show_destinations)
            if texts then
                result = hpack_list(texts)
                if result then
                    setfield(result,"width",0)
                    current = result
                end
            end
        end
        nofdestinations = nofdestinations + 1
        local annot = nodeinjections.destination(width,height,depth,name,view)
        if annot then
            annot = tonut(annot) -- obsolete soon
            if result then
                setlink(current,annot)
            else
                result  = annot
            end
            current = find_node_tail(annot)
        end
        if result then
            -- some internal error
            result = hpack_list(result,0)
            setfield(result,"width",0)
            setfield(result,"height",0)
            setfield(result,"depth",0)
        end
        if cleanupdestinations then stack[reference] = nil end
        return result, resolved
    elseif trace_destinations then
        report_destination("unable to resolve attribute %a",reference)
    end
end

-- function nodes.destinations.handler(head)
--     if topofstack > 0 then
--         return inject_area(head,attribute,makedestination,stack,done) -- singular
--     else
--         return head, false
--     end
-- end

function nodes.destinations.handler(head)
    if topofstack > 0 then
        head = tonut(head)
        local head, done = inject_areas(head,attribute,makedestination,stack,done)
        return tonode(head), done
    else
        return head, false
    end
end


-- will move

function references.mark(reference,h,d,view)
    return setdestination(tex.currentgrouplevel,h,d,reference,view)
end

function references.inject(prefix,reference,specification) -- todo: use currentreference is possible
-- print(prefix,reference,h,d,highlight,newwindow,layer)
    local set, bug = references.identify(prefix,reference)
    if bug or #set == 0 then
        -- unknown ref, just don't set it and issue an error
    else
        -- check
        set.highlight = specification.highlight
        set.newwindow = specification.newwindow
        set.layer     = specification.layer
        setreference(specification.height,specification.depth,set) -- sets attribute / todo: for set[*].error
    end
end

function references.injectcurrentset(h,d) -- used inside doifelse
    local currentset = references.currentset
    if currentset then
        setreference(h,d,currentset) -- sets attribute / todo: for set[*].error
    end
end

implement {
    name      = "injectreference",
    actions   = references.inject,
    arguments = {
        "string",
        "string",
        {
            { "highlight", "boolean" },
            { "newwindow", "boolean" },
            { "layer" },
            { "height", "dimen" },
            { "depth", "dimen" },
        }
    }
}

implement {
    name      = "injectcurrentreference",
    actions   = references.injectcurrentset,
}

implement {
    name      = "injectcurrentreferencehtdp",
    actions   = references.injectcurrentset,
    arguments = { "dimen", "dimen" },
}

--

local function checkboth(open,close)
    if open and open ~= "" then
        local set, bug = references.identify("",open)
        open = not bug and #set > 0 and set
    end
    if close and close ~= "" then
        local set, bug = references.identify("",close)
        close = not bug and #set > 0 and set
    end
    return open, close
end

-- end temp hack

statistics.register("interactive elements", function()
    if nofreferences > 0 or nofdestinations > 0 then
        return string.format("%s references, %s destinations",nofreferences,nofdestinations)
    else
        return nil
    end
end)

function references.enableinteraction()
    tasks.enableaction("shipouts","nodes.references.handler")
    tasks.enableaction("shipouts","nodes.destinations.handler")
    function references.enableinteraction() end
end

implement {
    name     = "enableinteraction",
    actions  = references.enableinteraction,
    onlyonce = true
}
