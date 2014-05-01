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

local trace_backend       = false  trackers.register("nodes.backend",      function(v) trace_backend      = v end)
local trace_references    = false  trackers.register("nodes.references",   function(v) trace_references   = v end)
local trace_destinations  = false  trackers.register("nodes.destinations", function(v) trace_destinations = v end)

local report_reference    = logs.reporter("backend","references")
local report_destination  = logs.reporter("backend","destinations")
local report_area         = logs.reporter("backend","areas")

local nuts                = nodes.nuts
local nodepool            = nuts.pool

local tonode              = nuts.tonode
local tonut               = nuts.tonut

local getfield            = nuts.getfield
local setfield            = nuts.setfield
local getnext             = nuts.getnext
local getprev             = nuts.getprev
local getid               = nuts.getid
local getlist             = nuts.getlist
local getattr             = nuts.getattr
local setattr             = nuts.setattr
local getsubtype          = nuts.getsubtype

local hpack_list          = nuts.hpack
local list_dimensions     = nuts.dimensions
local traverse            = nuts.traverse
local find_node_tail      = nuts.tail

local nodecodes           = nodes.nodecodes
local skipcodes           = nodes.skipcodes
local whatcodes           = nodes.whatcodes
local listcodes           = nodes.listcodes

local hlist_code          = nodecodes.hlist
local vlist_code          = nodecodes.vlist
local glue_code           = nodecodes.glue
local whatsit_code        = nodecodes.whatsit

local leftskip_code       = skipcodes.leftskip
local rightskip_code      = skipcodes.rightskip
local parfillskip_code    = skipcodes.parfillskip

local localpar_code       = whatcodes.localpar
local dir_code            = whatcodes.dir

local line_code           = listcodes.line

local new_rule            = nodepool.rule
local new_kern            = nodepool.kern

local tosequence          = nodes.tosequence

-- local function dimensions(parent,start,stop)
--     stop = stop and getnext(stop)
--     if parent then
--         if stop then
--             return list_dimensions(getfield(parent,"glue_set"),getfield(parent,"glue_sign"),getfield(parent,"glue_order"),start,stop)
--         else
--             return list_dimensions(getfield(parent,"glue_set"),getfield(parent,"glue_sign",getfield(parent,"glue_order"),start)
--         end
--     else
--         if stop then
--             return list_dimensions(start,stop)
--         else
--             return list_dimensions(start)
--         end
--     end
-- end
--
-- -- more compact

local function dimensions(parent,start,stop)
    if parent then
        return list_dimensions(getfield(parent,"glue_set"),getfield(parent,"glue_sign"),getfield(parent,"glue_order"),start,stop and getnext(stop))
    else
        return list_dimensions(start,stop and getnext(stop))
    end
end

-- is pardir important at all?

local function inject_range(head,first,last,reference,make,stack,parent,pardir,txtdir)
    local width, height, depth = dimensions(parent,first,last)
    if txtdir == "+TRT" or (txtdir == "===" and pardir == "TRT") then -- KH: textdir == "===" test added
        width = - width
    end
    local result, resolved = make(width,height,depth,reference)
    if result and resolved then
        if head == first then
            if trace_backend then
                report_area("%s: %04i %s %s %s => w=%p, h=%p, d=%p, c=%S","head",
                    reference,pardir or "---",txtdir or "---",tosequence(first,last,true),width,height,depth,resolved)
            end
            setfield(result,"next",first)
            setfield(first,"prev",result)
            return result, last
        else
            if trace_backend then
                report_area("%s: %04i %s %s %s => w=%p, h=%p, d=%p, c=%S","middle",
                    reference,pardir or "---",txtdir or "---",tosequence(first,last,true),width,height,depth,resolved)
            end
            local prev = getprev(first)
            if prev then
                setfield(prev,"next",result)
                setfield(result,"prev",prev)
            end
            setfield(result,"next",first)
            setfield(first,"prev",result)
--             if first == getnext(head) then
--                 setfield(head,"next",result) -- hm, weird
--             end
            return head, last
        end
    else
        return head, last
    end
end

local function inject_list(id,current,reference,make,stack,pardir,txtdir)
    local width, height, depth, correction = getfield(current,"width"), getfield(current,"height"), getfield(current,"depth"), 0
    local moveright = false
    local first = getlist(current)
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
                        if moveright and getfield(first,"writable") then
                            width = width - getfield(getfield(first,"spec"),"stretch") * getfield(current,"glue_set") * getfield(current,"glue_sign")
                        end
                        if getfield(last,"writable") then
                            width = width - getfield(getfield(last,"spec"),"stretch") * getfield(current,"glue_set") * getfield(current,"glue_sign")
                        end
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
        if trace_backend then
            report_area("%s: %04i %s %s %s: w=%p, h=%p, d=%p, c=%S","box",
                reference,pardir or "---",txtdir or "----","[]",width,height,depth,resolved)
        end
        if not first then
            setfield(current,"list",result)
        elseif moveright then -- brr no prevs done
            -- result after first
            local n = getnext(first)
            setfield(result,"next",n)
            setfield(first,"next",result)
            setfield(result,"prev",first)
            if n then
                setfield(n,"prev",result)
            end
        else
            -- first after result
            setfield(result,"next",first)
            setfield(first,"prev",result)
            setfield(current,"list",result)
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
                    setfield(current,"list",h)
                end
                if r then
                    done[r] = done[r] - 1
                end
            elseif id == whatsit_code then
                local subtype = getsubtype(current)
                if subtype == localpar_code then
                    pardir = getfield(current,"dir")
                elseif subtype == dir_code then
                    txtdir = getfield(current,"dir")
                end
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
                    setfield(current,"list",(inject_area(list,attribute,make,stack,done,current,pardir,txtdir)))
                end
            elseif id == whatsit_code then
                local subtype = getsubtype(current)
                if subtype == localpar_code then
                    pardir = getfield(current,"dir")
                elseif subtype == dir_code then
                    txtdir = getfield(current,"dir")
                end
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

-- tracing

local register_color = colors.register

local a_color        = attributes.private('color')
local a_colormodel   = attributes.private('colormodel')
local a_transparency = attributes.private('transparency')
local u_transparency = nil
local u_colors       = { }
local force_gray     = true

local function colorize(width,height,depth,n,reference,what)
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
        setfield(kern,"next",rule)
        setfield(rule,"prev",kern)
        return kern
    else
        return rule
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
-- step = 0
        local annot = nodeinjections.reference(width,height,depth,set)
        if annot then
annot = tonut(annot)
            nofreferences = nofreferences + 1
            local result, current
            if trace_references then
                local step = 65536
                result = hpack_list(colorize(width,height-step,depth-step,2,reference,"reference")) -- step subtracted so that we can see seperate links
                setfield(result,"width",0)
                current = result
            end
            if current then
                setfield(current,"next",annot)
                setfield(annot,"prev",current)
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
        local resolved, ht, dp, name, view = sr[1], sr[2], sr[3], sr[4], sr[5]
        if ht then
            if height < ht then height = ht end
            if depth  < dp then depth  = dp end
        end
        local result, current
        if trace_destinations then
            local step = 0
            if width  == 0 then
                step = 4*65536
                width, height, depth = 5*step, 5*step, 0
            end
            local rule = hpack_list(colorize(width,height,depth,3,reference,"destination"))
            setfield(rule,"width",0)
            if not result then
                result, current = rule, rule
            else
                setfield(current,"next",rule)
                setfield(rule,"prev",current)
                current = rule
            end
            width, height = width - step, height - step
        end
        nofdestinations = nofdestinations + 1
        local annot = nodeinjections.destination(width,height,depth,name,view)
        if annot then
            annot = tonut(annot) -- obsolete soon
            if result then
                setfield(current,"next",annot)
                setfield(annot,"prev",current)
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

function references.inject(prefix,reference,h,d,highlight,newwindow,layer) -- todo: use currentreference is possible
    local set, bug = references.identify(prefix,reference)
    if bug or #set == 0 then
        -- unknown ref, just don't set it and issue an error
    else
        -- check
        set.highlight, set.newwindow, set.layer = highlight, newwindow, layer
        setreference(h,d,set) -- sets attribute / todo: for set[*].error
    end
end

function references.injectcurrentset(h,d) -- used inside doifelse
    local currentset = references.currentset
    if currentset then
        setreference(h,d,currentset) -- sets attribute / todo: for set[*].error
    end
end

commands.injectreference        = references.inject
commands.injectcurrentreference = references.injectcurrentset

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
end
