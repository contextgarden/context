if not modules then modules = { } end modules ['lpdf-ano'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- when using rotation: \disabledirectives[refences.sharelinks] (maybe flag links)

-- todo: /AA << WC << ... >> >> : WillClose actions etc

-- internal references are indicated by a number (and turned into <autoprefix><number>)
-- we only flush internal destinations that are referred

local next, tostring, tonumber, rawget, type = next, tostring, tonumber, rawget, type
local rep, format, find = string.rep, string.format, string.find
local min = math.min
local lpegmatch = lpeg.match
local formatters = string.formatters
local sortedkeys, concat = table.sortedkeys, table.concat

local backends, lpdf = backends, lpdf

local trace_references        = false  trackers.register("references.references",   function(v) trace_references   = v end)
local trace_destinations      = false  trackers.register("references.destinations", function(v) trace_destinations = v end)
local trace_bookmarks         = false  trackers.register("references.bookmarks",    function(v) trace_bookmarks    = v end)

local log_destinations        = false  directives.register("destinations.log",     function(v) log_destinations = v end)
local untex_urls              = true   directives.register("references.untexurls", function(v) untex_urls       = v end)

local report_references       = logs.reporter("backend","references")
local report_destinations     = logs.reporter("backend","destinations")
local report_bookmarks        = logs.reporter("backend","bookmarks")

local variables               = interfaces.variables
local v_auto                  = variables.auto
local v_page                  = variables.page
local v_name                  = variables.name

local factor                  = number.dimenfactors.bp

local settings_to_array       = utilities.parsers.settings_to_array

local allocate                = utilities.storage.allocate
local setmetatableindex       = table.setmetatableindex

local nodeinjections          = backends.pdf.nodeinjections
local codeinjections          = backends.pdf.codeinjections
local registrations           = backends.pdf.registrations

local javascriptcode          = interactions.javascripts.code

local references              = structures.references
local bookmarks               = structures.bookmarks

local flaginternals           = references.flaginternals
local usedinternals           = references.usedinternals
local usedviews               = references.usedviews

local runners                 = references.runners
local specials                = references.specials
local handlers                = references.handlers
local executers               = references.executers

local nodepool                = nodes.pool

local new_latelua             = nodepool.latelua

local texgetcount             = tex.getcount

local jobpositions            = job.positions
local getpos                  = jobpositions.getpos
local gethpos                 = jobpositions.gethpos
local getvpos                 = jobpositions.getvpos

local pdfdictionary           = lpdf.dictionary
local pdfarray                = lpdf.array
local pdfreference            = lpdf.reference
local pdfunicode              = lpdf.unicode
local pdfconstant             = lpdf.constant
local pdfflushobject          = lpdf.flushobject
local pdfshareobjectreference = lpdf.shareobjectreference
local pdfreserveobject        = lpdf.reserveobject
local pdfpagereference        = lpdf.pagereference
local pdfdelayedobject        = lpdf.delayedobject
local pdfregisterannotation   = lpdf.registerannotation -- forward definition (for the moment)
local pdfnull                 = lpdf.null
local pdfaddtocatalog         = lpdf.addtocatalog
local pdfaddtonames           = lpdf.addtonames
local pdfaddtopageattributes  = lpdf.addtopageattributes
local pdfrectangle            = lpdf.rectangle

-- todo: 3dview

----- pdf_annot               = pdfconstant("Annot")
local pdf_uri                 = pdfconstant("URI")
local pdf_gotor               = pdfconstant("GoToR")
local pdf_goto                = pdfconstant("GoTo")
local pdf_launch              = pdfconstant("Launch")
local pdf_javascript          = pdfconstant("JavaScript")
local pdf_link                = pdfconstant("Link")
local pdf_n                   = pdfconstant("N")
local pdf_t                   = pdfconstant("T")
local pdf_fit                 = pdfconstant("Fit")
local pdf_named               = pdfconstant("Named")

local autoprefix              = "#"
local usedautoprefixes        = { }

local function registerautoprefix(name)
    local internal = autoprefix .. name
    if usedautoprefixes[internal] == nil then
        usedautoprefixes[internal] = false
    end
    return internal
end

local function useautoprefix(name)
    local internal = autoprefix .. name
    usedautoprefixes[internal] = true
    return internal
end

local function checkautoprefixes(destinations)
    for k, v in next, usedautoprefixes do
        if not v then
            if trace_destinations then
                report_destinations("flushing unused autoprefix %a",k)
            end
            destinations[k] = nil
        end
    end
end

local maxslice = 32 -- could be made configureable ... 64 is also ok

local function pdfmakenametree(list,apply)
    if not next(list) then
        return
    end
    local slices   = { }
    local sorted   = sortedkeys(list)
    local size     = #sorted
    local maxslice = maxslice
    if size <= 1.5*maxslice then
        maxslice = size
    end
    for i=1,size,maxslice do
        local amount = min(i+maxslice-1,size)
        local names  = pdfarray { }
        local n      = 0
        for j=i,amount do
            local name   = sorted[j]
            local target = list[name]
            n = n + 1 ; names[n] = tostring(name)
            n = n + 1 ; names[n] = apply and apply(target) or target
        end
        local first = sorted[i]
        local last  = sorted[amount]
        local limits = pdfarray {
            first,
            last,
        }
        local d = pdfdictionary {
            Names  = names,
            Limits = limits,
        }
        slices[#slices+1] = {
            reference = pdfreference(pdfflushobject(d)),
            limits    = limits,
        }
    end
    local function collectkids(slices,first,last)
        local f = slices[first]
        local l = slices[last]
        if f and l then
            local k = pdfarray()
            local n = 0
            local d = pdfdictionary {
                Kids   = k,
                Limits = pdfarray {
                    f.limits[1],
                    l.limits[2],
                },
            }
            for i=first,last do
                n = n + 1 ; k[n] = slices[i].reference
            end
            return d
        end
    end
    if #slices == 1 then
        return slices[1].reference
    else
        while true do
            local size = #slices
            if size > maxslice then
                local temp = { }
                local n    = 0
                for i=1,size,maxslice do
                    local kids = collectkids(slices,i,min(i+maxslice-1,size))
                    if kids then
                        n = n + 1
                        temp[n] = {
                            reference = pdfreference(pdfflushobject(kids)),
                            limits    = kids.Limits,
                        }
                    else
                        -- error
                    end
                end
                slices = temp
            else
                local kids = collectkids(slices,1,size)
                if kids then
                    return pdfreference(pdfflushobject(kids))
                else
                    -- error
                    return
                end
            end
        end
    end
end

lpdf.makenametree = pdfmakenametree

-- Bah, I hate this kind of features .. anyway, as we have delayed resolving we
-- only support a document-wide setup and it has to be set before the first one
-- is used. Also, we default to a non-intrusive gray and the outline is kept
-- thin without dashing lines. This is as far as I'm prepared to go. This way
-- it can also be used as a debug feature.

local pdf_border_style = pdfarray { 0, 0, 0 } -- radius radius linewidth
local pdf_border_color = nil
local set_border       = false

local function pdfborder()
    set_border = true
    return pdf_border_style, pdf_border_color
end

lpdf.border = pdfborder

directives.register("references.border",function(v)
    if v and not set_border then
        if type(v) == "string" then
            local m = attributes.list[attributes.private('color')] or { }
            local c = m and m[v]
            local v = c and attributes.colors.value(c)
            if v then
                local r = v[3]
                local g = v[4]
                local b = v[5]
             -- if r == g and g == b then
             --     pdf_border_color = pdfarray { r }       -- reduced, not not ... bugged viewers
             -- else
                    pdf_border_color = pdfarray { r, g, b } -- always rgb
             -- end
            end
        end
        if not pdf_border_color then
            pdf_border_color = pdfarray { .6, .6, .6 } -- no reduce to { 0.6 } as there are buggy viewers out there
        end
        pdf_border_style = pdfarray { 0, 0, .5 } -- < 0.5 is not show by acrobat (at least not in my version)
    end
end)

-- the used and flag code here is somewhat messy in the sense
-- that it belongs in strc-ref but at the same time depends on
-- the backend so we keep it here

-- the caching is somewhat memory intense on the one hand but
-- it saves many small temporary tables so it might pay off

local pagedestinations = setmetatableindex(function(t,k)
    k = tonumber(k)
    if not k or k <= 0 then
        return pdfnull()
    end
    local v = rawget(t,k)
    if v then
     -- report_references("page number expected, got %s: %a",type(k),k)
        return v
    end
    local v = k > 0 and pdfarray {
        pdfreference(pdfpagereference(k)),
        pdf_fit,
    } or pdfnull()
    t[k] = v
    return v
end)

local pagereferences = setmetatableindex(function(t,k)
    k = tonumber(k)
    if not k or k <= 0 then
        return nil
    end
    local v = rawget(t,k)
    if v then
        return v
    end
    local v = pdfdictionary { -- can be cached
        S = pdf_goto,
        D = pagedestinations[k],
    }
    t[k] = v
    return v
end)

local defaultdestination = pdfarray { 0, pdf_fit }

-- fit is default (see lpdf-nod)

local destinations = { }
local reported     = setmetatableindex("table")

local function pdfregisterdestination(name,reference)
    local d = destinations[name]
    if d then
        if not reported[name][reference] then
            report_destinations("ignoring duplicate destination %a with reference %a",name,reference)
            reported[name][reference] = true
        end
    else
        destinations[name] = reference
    end
end

lpdf.registerdestination = pdfregisterdestination

logs.registerfinalactions(function()
    if log_destinations and next(destinations) then
        local report = logs.startfilelogging("references","used destinations")
        local n = 0
        for destination, pagenumber in table.sortedhash(destinations) do
            report("% 4i : %-5s : %s",pagenumber,usedviews[destination] or defaultview,destination)
            n = n + 1
        end
        logs.stopfilelogging()
        report_destinations("%s destinations saved in log file",n)
    end
end)

local function pdfdestinationspecification()
    if next(destinations) then -- safeguard
        checkautoprefixes(destinations)
        local r = pdfmakenametree(destinations,pdfreference)
        if r then
            pdfaddtonames("Dests",r)
        end
        if not log_destinations then
            destinations = nil
        end
    end
end

lpdf.destinationspecification = pdfdestinationspecification

lpdf.registerdocumentfinalizer(pdfdestinationspecification,"collect destinations")

-- todo

local destinations = { }

local f_xyz   = formatters["<< /D [ %i 0 R /XYZ %.6N %.6N null ] >>"]
local f_fit   = formatters["<< /D [ %i 0 R /Fit ] >>"]
local f_fitb  = formatters["<< /D [ %i 0 R /FitB ] >>"]
local f_fith  = formatters["<< /D [ %i 0 R /FitH %.6N ] >>"]
local f_fitv  = formatters["<< /D [ %i 0 R /FitV %.6N ] >>"]
local f_fitbh = formatters["<< /D [ %i 0 R /FitBH %.6N ] >>"]
local f_fitbv = formatters["<< /D [ %i 0 R /FitBV %.6N ] >>"]
local f_fitr  = formatters["<< /D [ %i 0 R /FitR %.6N %.6N %.6N %.6N ] >>"]

local v_standard  = variables.standard
local v_frame     = variables.frame
local v_width     = variables.width
local v_minwidth  = variables.minwidth
local v_height    = variables.height
local v_minheight = variables.minheight
local v_fit       = variables.fit
local v_tight     = variables.tight

-- nicer is to create dictionaries and set properties but it's a bit overkill

-- The problem with the following settings is that they are guesses: we never know
-- if a box is part of something larger that needs to be in view, or that we are
-- dealing with a vbox or vtop so the used h/d values cannot be trusted in a tight
-- view. Of course some decent additional offset would be nice so maybe i'll add
-- that some day. I never use anything else than 'fit' anyway as I think that the
-- document should fit the device (and vice versa). In fact, with todays swipe
-- and finger zooming this whole view is rather useless and as with any zooming
-- one looses the overview and keeps zooming.

-- todo: scaling

-- local destinationactions = {
--     [v_standard]  = function(r,w,h,d) return f_xyz  (r,gethpos()*factor,(getvpos()+h)*factor) end, -- local left,top with no zoom
--     [v_frame]     = function(r,w,h,d) return f_fitr (r,pdfrectangle(w,h,d)) end,                   -- fit rectangle in window
--     [v_width]     = function(r,w,h,d) return f_fith (r,(getvpos()+h)*factor) end,                  -- top coordinate, fit width of page in window
--     [v_minwidth]  = function(r,w,h,d) return f_fitbh(r,(getvpos()+h)*factor) end,                  -- top coordinate, fit width of content in window
--     [v_height]    = function(r,w,h,d) return f_fitv (r,gethpos()*factor) end,                      -- left coordinate, fit height of page in window
--     [v_minheight] = function(r,w,h,d) return f_fitbv(r,gethpos()*factor) end,                      -- left coordinate, fit height of content in window    [v_fit]       =                          f_fit,                                                 -- fit page in window
--     [v_tight]     =                          f_fitb,                                               -- fit content in window
--     [v_fit]       =                          f_fit,
-- }

local destinationactions = {
    [v_standard]  = function(r,w,h,d,o)        -- local left,top with no zoom
        local tx, ty = getpos()
        return f_xyz(r,tx*factor,(ty+h+2*o)*factor) -- we can assume margins
    end,
    [v_frame]     = function(r,w,h,d,o)        -- fit rectangle in window
        return f_fitr(r,pdfrectangle(w,h,d,o))
    end,
    [v_width]     = function(r,w,h,d,o)        -- top coordinate, fit width of page in window
        return f_fith(r,(getvpos()+h+o)*factor)
    end,
    [v_minwidth]  = function(r,w,h,d,o)        -- top coordinate, fit width of content in window
        return f_fitbh(r,(getvpos()+h+o)*factor)
    end,
    [v_height]    = function(r,w,h,d,o)        -- left coordinate, fit height of page in window
        return f_fitv(r,(gethpos())*factor)
    end,
    [v_minheight] = function(r,w,h,d,o)        -- left coordinate, fit height of content in window
        return f_fitbv(r,(gethpos())*factor)
    end,
    [v_tight]     = f_fitb,                    -- fit content in window
    [v_fit]       = f_fit,                     -- fit content in window
}

local mapping = {
    [v_standard]  = v_standard,  xyz   = v_standard,
    [v_frame]     = v_frame,     fitr  = v_frame,
    [v_width]     = v_width,     fith  = v_width,
    [v_minwidth]  = v_minwidth,  fitbh = v_minwidth,
    [v_height]    = v_height,    fitv  = v_height,
    [v_minheight] = v_minheight, fitbv = v_minheight,
    [v_fit]       = v_fit,       fit   = v_fit,
    [v_tight]     = v_tight,     fitb  = v_tight,
}

local defaultview   = v_fit
local defaultaction = destinationactions[defaultview]
local offset        = 0 -- 65536*5

directives.register("destinations.offset", function(v)
    offset = string.todimen(v) or 0
end)

-- A complication is that we need to use named destinations when we have views so we
-- end up with a mix. A previous versions just output multiple destinations but now
-- that we moved all to here we can be more sparse.

local pagedestinations = setmetatableindex(function(t,k) -- not the same as the one above!
    local v = pdfdelayedobject(f_fit(k))
    t[k] = v
    return v
end)

local function flushdestination(specification)
    local names = specification.names
    local view  = specification.view
    local r     = pdfpagereference(texgetcount("realpageno"))
    if (references.innermethod ~= v_name) and (view == defaultview or not view or view == "") then
        r = pagedestinations[r]
    else
        local action = view and destinationactions[view] or defaultaction
        r = pdfdelayedobject(action(r,specification.width,specification.height,specification.depth,offset))
    end
    for n=1,#names do
        local name = names[n]
        if name then
            pdfregisterdestination(name,r)
        end
    end
end

function nodeinjections.destination(width,height,depth,names,view)
    -- todo check if begin end node / was comment
    view = view and mapping[view] or defaultview
    if trace_destinations then
        report_destinations("width %p, height %p, depth %p, names %|t, view %a",width,height,depth,names,view)
    end
    local method = references.innermethod
    local noview = view == defaultview
    local doview = false
    -- we could save some aut's by using a name when given but it doesn't pay off apart
    -- from making the code messy and tracing hard .. we only save some destinations
    -- which we already share anyway
    if method == v_page then
        for n=1,#names do
            local name = names[n]
            local used = usedviews[name]
            if used and used ~= true then
                -- already done, maybe a warning
            elseif type(name) == "number" then
             -- if noview then
             --     usedviews[name] = view
             --     names[n] = false
             -- else
                    usedviews[name] = view
                    names[n] = false
             -- end
            else
                usedviews[name] = view
            end
        end
    elseif method == v_name then
        for n=1,#names do
            local name = names[n]
            local used = usedviews[name]
            if used and used ~= true then
                -- already done, maybe a warning
            elseif type(name) == "number" then
                local used = usedinternals[name]
                usedviews[name] = view
                names[n] = registerautoprefix(name)
                doview = true
            else
                usedviews[name] = view
                doview = true
            end
        end
    else
        for n=1,#names do
            local name = names[n]
            if usedviews[name] then
                -- already done, maybe a warning
            elseif type(name) == "number" then
                if noview then
                    usedviews[name] = view
                    names[n] = false
                else
                    local used = usedinternals[name]
                    if used and used ~= defaultview then
                        usedviews[name] = view
                        names[n] = registerautoprefix(name)
                        doview = true
                    else
                        names[n] = false
                    end
                end
            else
                usedviews[name] = view
                doview = true
            end
        end
    end
    if doview then
        return new_latelua {
            action = flushdestination,
            width  = width,
            height = height,
            depth  = depth,
            names  = names,
            view   = view,
        }
    end
end

-- we could share dictionaries ... todo

local function pdflinkpage(page)
    return pagereferences[page]
end

local function pdflinkinternal(internal,page)
 -- local method = references.innermethod
    if internal then
        flaginternals[internal] = true -- for bookmarks and so
        local used = usedinternals[internal]
        if used == defaultview or used == true then
            return pagereferences[page]
        else
            if type(internal) ~= "string" then
                internal = useautoprefix(internal)
            end
            return pdfdictionary {
                S = pdf_goto,
                D = internal,
            }
        end
    else
        return pagereferences[page]
    end
end

local function pdflinkname(destination,internal,page)
    local method = references.innermethod
    if method == v_auto then
        local used = defaultview
        if internal then
            flaginternals[internal] = true -- for bookmarks and so
            used = usedinternals[internal] or defaultview
        end
        if used == defaultview then -- or used == true then
            return pagereferences[page]
        else
            return pdfdictionary {
                S = pdf_goto,
                D = destination,
            }
        end
    elseif method == v_name then
     -- flaginternals[internal] = true -- for bookmarks and so
        return pdfdictionary {
            S = pdf_goto,
            D = destination,
        }
    else
        return pagereferences[page]
    end
end

-- annotations

local function pdffilelink(filename,destination,page,actions)
    if not filename or filename == "" or file.basename(filename) == tex.jobname then
        return false
    end
    filename = file.addsuffix(filename,"pdf")
    if (not destination or destination == "") or (references.outermethod == v_page) then
        destination = pdfarray { (page or 1) - 1, pdf_fit }
    end
    return pdfdictionary {
        S         = pdf_gotor, -- can also be pdf_launch
        F         = filename,
        D         = destination or defaultdestination,
        NewWindow = actions.newwindow and true or nil,
    }
end

local untex = references.urls.untex

local function pdfurllink(url,destination,page)
    if not url or url == "" then
        return false
    end
    if untex_urls then
        url = untex(url) -- last minute cleanup of \* and spaces
    end
    if destination and destination ~= "" then
        url = url .. "#" .. destination
    end
    return pdfdictionary {
        S   = pdf_uri,
        URI = url,
    }
end

local function pdflaunch(program,parameters)
    if not program or program == "" then
        return false
    end
    return pdfdictionary {
        S = pdf_launch,
        F = program,
        D = ".",
        P = parameters ~= "" and parameters or nil
    }
end

local function pdfjavascript(name,arguments)
    local script = javascriptcode(name,arguments) -- make into object (hash)
    if script then
        return pdfdictionary {
            S  = pdf_javascript,
            JS = script,
        }
    end
end

local function pdfaction(actions)
    local nofactions = #actions
    if nofactions > 0 then
        local a = actions[1]
        local action = runners[a.kind]
        if action then
            action = action(a,actions)
        end
        if action then
            local first = action
            for i=2,nofactions do
                local a = actions[i]
                local what = runners[a.kind]
                if what then
                    what = what(a,actions)
                end
                if action == what then
                    -- ignore this one, else we get a loop
                elseif what then
                    action.Next = what
                    action = what
                else
                    -- error
                    return nil
                end
            end
            return first, actions.n or #actions
        end
    end
end

lpdf.action = pdfaction

function codeinjections.prerollreference(actions) -- share can become option
    if actions then
        local main, n = pdfaction(actions)
        if main then
            local bs, bc = pdfborder()
            main = pdfdictionary {
                Subtype = pdf_link,
                Border  = bs,
                C       = bc,
                H       = (not actions.highlight and pdf_n) or nil,
                A       = pdfshareobjectreference(main),
                F       = 4, -- print (mandate in pdf/a)
            }
            return main("A"), n
        end
    end
end

-- local function use_normal_annotations()
--
--     local function reference(width,height,depth,prerolled) -- keep this one
--         if prerolled then
--             if trace_references then
--                 report_references("width %p, height %p, depth %p, prerolled %a",width,height,depth,prerolled)
--             end
--             return pdfannotation_node(width,height,depth,prerolled)
--         end
--     end
--
--     local function finishreference()
--     end
--
--     return reference, finishreference
--
-- end

-- eventually we can do this for special refs only

local hashed     = { }
local nofunique  = 0
local nofused    = 0
local nofspecial = 0
local share      = true

local f_annot    = formatters["<< /Type /Annot %s /Rect [ %.6N %.6N %.6N %.6N ] >>"]
local f_quadp    = formatters["<< /Type /Annot %s /QuadPoints [ %s ] /Rect [ %.6N %.6N %.6N %.6N ] >>"]

directives.register("references.sharelinks", function(v)
    share = v
end)

setmetatableindex(hashed,function(t,k)
    local v = pdfdelayedobject(k)
    if share then
        t[k] = v
    end
    nofunique = nofunique + 1
    return v
end)

local function toquadpoints(paths)
    local t, n = { }, 0
    for i=1,#paths do
        local path = paths[i]
        local size = #path
        for j=1,size do
            local p = path[j]
            n = n + 1 ; t[n] = p[1]
            n = n + 1 ; t[n] = p[2]
        end
        local m = size % 4
        if m > 0 then
            local p = path[size]
            for j=size+1,m do
                n = n + 1 ; t[n] = p[1]
                n = n + 1 ; t[n] = p[2]
            end
        end
    end
    return concat(t," ")
end

local function finishreference(specification)
    local prerolled  = specification.prerolled
    local quadpoints = specification.mesh
    local llx, lly,
          urx, ury   = pdfrectangle(specification.width,specification.height,specification.depth)
    local specifier  = nil
    if quadpoints and #quadpoints > 0 then
        specifier = f_quadp(prerolled,toquadpoints(quadpoints),llx,lly,urx,ury)
    else
        specifier = f_annot(prerolled,llx,lly,urx,ury)
    end
    nofused = nofused + 1
    return pdfregisterannotation(hashed[specifier])
end

local function finishannotation(specification)
    local prerolled = specification.prerolled
    local objref    = specification.objref
    if type(prerolled) == "function" then
        prerolled = prerolled()
    end
    local annot = f_annot(prerolled,pdfrectangle(specification.width,specification.height,specification.depth))
    if objref then
        pdfdelayedobject(annot,objref)
    else
        objref = pdfdelayedobject(annot)
    end
    nofspecial = nofspecial + 1
    return pdfregisterannotation(objref)
end

function nodeinjections.reference(width,height,depth,prerolled,mesh)
    if prerolled then
        if trace_references then
            report_references("link: width %p, height %p, depth %p, prerolled %a",width,height,depth,prerolled)
        end
        return new_latelua {
            action    = finishreference,
            width     = width,
            height    = height,
            depth     = depth,
            prerolled = prerolled,
            mesh      = mesh,
        }
    end
end

function nodeinjections.annotation(width,height,depth,prerolled,objref)
    if prerolled then
        if trace_references then
            report_references("special: width %p, height %p, depth %p, prerolled %a",width,height,depth,
                type(prerolled) == "string" and prerolled or "-")
        end
        return new_latelua {
            action    = finishannotation,
            width     = width,
            height    = height,
            depth     = depth,
            prerolled = prerolled,
            objref    = objref or false,
        }
    end
end

-- beware, we register during a latelua sweep so we have to make sure that
-- we finalize after that (also in a latelua for the moment as we have no
-- callback yet)

local annotations = nil

function lpdf.registerannotation(n)
    if annotations then
        annotations[#annotations+1] = pdfreference(n)
    else
        annotations = pdfarray { pdfreference(n) } -- no need to use lpdf.array cum suis
    end
end

pdfregisterannotation = lpdf.registerannotation

function lpdf.annotationspecification()
    if annotations then
        local r = pdfdelayedobject(tostring(annotations)) -- delayed so okay in latelua
        if r then
            pdfaddtopageattributes("Annots",pdfreference(r))
        end
        annotations = nil
    end
end

lpdf.registerpagefinalizer(lpdf.annotationspecification,"finalize annotations")

statistics.register("pdf annotations", function()
    if nofused > 0 or nofspecial > 0 then
        return format("%s links (%s unique), %s special",nofused,nofunique,nofspecial)
    else
        return nil
    end
end)

-- runners and specials

local splitter = lpeg.splitat(",",true)

runners["inner"] = function(var,actions)
    local internal = false
    local name     = nil
    local method   = references.innermethod
    local vi       = var.i
    local page     = var.r
    if vi then
        local vir = vi.references
        if vir then
            -- todo: no need for it when we have a real reference ... although we need
            -- this mess for prefixes anyway
            local reference = vir.reference
            if reference and reference ~= "" then
                reference = lpegmatch(splitter,reference) or reference
                var.inner = reference
                local prefix = var.p
                if prefix and prefix ~= "" then
                    var.prefix = prefix
                    name = prefix .. ":" .. reference
                else
                    name = reference
                end
            end
            internal = vir.internal
            if internal then
                flaginternals[internal] = true
            end
        end
    end
    if name then
        return pdflinkname(name,internal,page)
    elseif internal then
        return pdflinkinternal(internal,page)
    elseif page then
        return pdflinkpage(page)
    else
        -- real bad
    end
end

runners["inner with arguments"] = function(var,actions)
    report_references("todo: inner with arguments")
    return false
end

runners["outer"] = function(var,actions)
    local file, url = references.checkedfileorurl(var.outer,var.outer)
    if file  then
        return pdffilelink(file,var.arguments,nil,actions)
    elseif url then
        return pdfurllink(url,var.arguments,nil,actions)
    end
end

runners["outer with inner"] = function(var,actions)
    return pdffilelink(references.checkedfile(var.outer),var.inner,var.r,actions)
end

runners["special outer with operation"] = function(var,actions)
    local handler = specials[var.special]
    return handler and handler(var,actions)
end

runners["special outer"] = function(var,actions)
    report_references("todo: special outer")
    return false
end

runners["special"] = function(var,actions)
    local handler = specials[var.special]
    return handler and handler(var,actions)
end

runners["outer with inner with arguments"] = function(var,actions)
    report_references("todo: outer with inner with arguments")
    return false
end

runners["outer with special and operation and arguments"] = function(var,actions)
    report_references("todo: outer with special and operation and arguments")
    return false
end

runners["outer with special"] = function(var,actions)
    report_references("todo: outer with special")
    return false
end

runners["outer with special and operation"] = function(var,actions)
    report_references("todo: outer with special and operation")
    return false
end

runners["special operation"]                = runners["special"]
runners["special operation with arguments"] = runners["special"]

local reported = { }

function specials.internal(var,actions) -- better resolve in strc-ref
    local o = var.operation
    local i = o and tonumber(o)
    local v = i and references.internals[i]
    if v then
        flaginternals[i] = true -- also done in pdflinkinternal
        return pdflinkinternal(i,v.references.realpage)
    end
    local v = i or o or "<unset>"
    if not reported[v] then
        report_references("no internal reference %a",v)
        reported[v] = true
    end
end

-- realpage already resolved

specials.i = specials.internal

local pages = references.pages

function specials.page(var,actions)
    local file = var.f
    if file then
        return pdffilelink(references.checkedfile(file),nil,var.operation,actions)
    else
        local p = var.r
        if not p then -- todo: call special from reference code
            p = pages[var.operation]
            if type(p) == "function" then -- double
                p = p()
            else
                p = references.realpageofpage(tonumber(p))
            end
        end
        return pdflinkpage(p or var.operation)
    end
end

function specials.realpage(var,actions)
    local file = var.f
    if file then
        return pdffilelink(references.checkedfile(file),nil,var.operation,actions)
    else
        return pdflinkpage(var.operation)
    end
end

function specials.userpage(var,actions)
    local file = var.f
    if file then
        return pdffilelink(references.checkedfile(file),nil,var.operation,actions)
    else
        local p = var.r
        if not p then -- todo: call special from reference code
            p = var.operation
            if p then -- no function and special check here. only numbers
                p = references.realpageofpage(tonumber(p))
            end
         -- if p then
         --     var.r = p
         -- end
        end
        return pdflinkpage(p or var.operation)
    end
end

function specials.deltapage(var,actions)
    local p = tonumber(var.operation)
    if p then
        p = references.checkedrealpage(p + texgetcount("realpageno"))
        return pdflinkpage(p)
    end
end

-- sections

function specials.section(var,actions)
    -- a bit duplicate
    local sectionname = var.arguments
    local destination = var.operation
    local internal    = structures.sections.internalreference(sectionname,destination)
    if internal then
        var.special   = "internal"
        var.operation = internal
        var.arguments = nil
        return specials.internal(var,actions)
    end
end

-- todo, do this in references namespace ordered instead (this is an experiment)

local splitter = lpeg.splitat(":")

function specials.order(var,actions) -- references.specials !
    local operation = var.operation
    if operation then
        local kind, name, n = lpegmatch(splitter,operation)
        local order = structures.lists.ordered[kind]
        order = order and order[name]
        local v = order[tonumber(n)]
        local r = v and v.references.realpage
        if r then
            var.operation = r -- brrr, but test anyway
            return specials.page(var,actions)
        end
    end
end

function specials.url(var,actions)
    return pdfurllink(references.checkedurl(var.operation),var.arguments,nil,actions)
end

function specials.file(var,actions)
    return pdffilelink(references.checkedfile(var.operation),var.arguments,nil,actions)
end

function specials.fileorurl(var,actions)
    local file, url = references.checkedfileorurl(var.operation,var.operation)
    if file then
        return pdffilelink(file,var.arguments,nil,actions)
    elseif url then
        return pdfurllink(url,var.arguments,nil,actions)
    end
end

function specials.program(var,content)
    local program = references.checkedprogram(var.operation)
    return pdflaunch(program,var.arguments)
end

function specials.javascript(var)
    return pdfjavascript(var.operation,var.arguments)
end

specials.JS = specials.javascript

executers.importform  = pdfdictionary { S = pdf_named, N = pdfconstant("AcroForm:ImportFDF") }
executers.exportform  = pdfdictionary { S = pdf_named, N = pdfconstant("AcroForm:ExportFDF") }
executers.first       = pdfdictionary { S = pdf_named, N = pdfconstant("FirstPage") }
executers.previous    = pdfdictionary { S = pdf_named, N = pdfconstant("PrevPage") }
executers.next        = pdfdictionary { S = pdf_named, N = pdfconstant("NextPage") }
executers.last        = pdfdictionary { S = pdf_named, N = pdfconstant("LastPage") }
executers.backward    = pdfdictionary { S = pdf_named, N = pdfconstant("GoBack") }
executers.forward     = pdfdictionary { S = pdf_named, N = pdfconstant("GoForward") }
executers.print       = pdfdictionary { S = pdf_named, N = pdfconstant("Print") }
executers.exit        = pdfdictionary { S = pdf_named, N = pdfconstant("Quit") }
executers.close       = pdfdictionary { S = pdf_named, N = pdfconstant("Close") }
executers.save        = pdfdictionary { S = pdf_named, N = pdfconstant("Save") }
executers.savenamed   = pdfdictionary { S = pdf_named, N = pdfconstant("SaveAs") }
executers.opennamed   = pdfdictionary { S = pdf_named, N = pdfconstant("Open") }
executers.help        = pdfdictionary { S = pdf_named, N = pdfconstant("HelpUserGuide") }
executers.toggle      = pdfdictionary { S = pdf_named, N = pdfconstant("FullScreen") }
executers.search      = pdfdictionary { S = pdf_named, N = pdfconstant("Find") }
executers.searchagain = pdfdictionary { S = pdf_named, N = pdfconstant("FindAgain") }
executers.gotopage    = pdfdictionary { S = pdf_named, N = pdfconstant("GoToPage") }
executers.query       = pdfdictionary { S = pdf_named, N = pdfconstant("AcroSrch:Query") }
executers.queryagain  = pdfdictionary { S = pdf_named, N = pdfconstant("AcroSrch:NextHit") }
executers.fitwidth    = pdfdictionary { S = pdf_named, N = pdfconstant("FitWidth") }
executers.fitheight   = pdfdictionary { S = pdf_named, N = pdfconstant("FitHeight") }

local function fieldset(arguments)
    -- [\dogetfieldset{#1}]
    return nil
end

function executers.resetform(arguments)
    arguments = (type(arguments) == "table" and arguments) or settings_to_array(arguments)
    return pdfdictionary {
        S     = pdfconstant("ResetForm"),
        Field = fieldset(arguments[1])
    }
end

local formmethod = "post" -- "get" "post"
local formformat = "xml"  -- "xml" "html" "fdf"

-- bit 3 = html bit 6 = xml bit 4 = get

local flags = {
    get = {
        html = 12, fdf = 8, xml = 40,
    },
    post = {
        html = 4, fdf = 0, xml = 32,
    }
}

function executers.submitform(arguments)
    arguments = (type(arguments) == "table" and arguments) or settings_to_array(arguments)
    local flag = flags[formmethod] or flags.post
    flag = (flag and (flag[formformat] or flag.xml)) or 32 -- default: post, xml
    return pdfdictionary {
        S     = pdfconstant("SubmitForm"),
        F     = arguments[1],
        Field = fieldset(arguments[2]),
        Flags = flag,
    -- \PDFsubmitfiller
    }
end

local pdf_hide = pdfconstant("Hide")

function executers.hide(arguments)
    return pdfdictionary {
        S = pdf_hide,
        H = true,
        T = arguments,
    }
end

function executers.show(arguments)
    return pdfdictionary {
        S = pdf_hide,
        H = false,
        T = arguments,
    }
end

local pdf_movie  = pdfconstant("Movie")
local pdf_start  = pdfconstant("Start")
local pdf_stop   = pdfconstant("Stop")
local pdf_resume = pdfconstant("Resume")
local pdf_pause  = pdfconstant("Pause")

local function movie_or_sound(operation,arguments)
    arguments = (type(arguments) == "table" and arguments) or settings_to_array(arguments)
    return pdfdictionary {
        S         = pdf_movie,
        T         = format("movie %s",arguments[1] or "noname"),
        Operation = operation,
    }
end

function executers.startmovie (arguments) return movie_or_sound(pdf_start ,arguments) end
function executers.stopmovie  (arguments) return movie_or_sound(pdf_stop  ,arguments) end
function executers.resumemovie(arguments) return movie_or_sound(pdf_resume,arguments) end
function executers.pausemovie (arguments) return movie_or_sound(pdf_pause ,arguments) end

function executers.startsound (arguments) return movie_or_sound(pdf_start ,arguments) end
function executers.stopsound  (arguments) return movie_or_sound(pdf_stop  ,arguments) end
function executers.resumesound(arguments) return movie_or_sound(pdf_resume,arguments) end
function executers.pausesound (arguments) return movie_or_sound(pdf_pause ,arguments) end

function specials.action(var)
    local operation = var.operation
    if var.operation and operation ~= "" then
        local e = executers[operation]
        if type(e) == "table" then
            return e
        elseif type(e) == "function" then
            return e(var.arguments)
        end
    end
end

local function build(levels,start,parent,method,nested)
    local startlevel = levels[start].level
    local noflevels  = #levels
    local i = start
    local n = 0
    local child, entry, m, prev, first, last, f, l
    while i and i <= noflevels do
        local current = levels[i]
        if current.usedpage == false then
            -- safeguard
            i = i + 1
        else
            local level     = current.level
            local title     = current.title
            local reference = current.reference
            local opened    = current.opened
            local reftype   = type(reference)
            local block     = nil
            local variant   = "unknown"
            if reftype == "table" then
                -- we're okay
                variant  = "list"
                block    = reference.block
                realpage = reference.realpage
            elseif reftype == "string" then
                local resolved = references.identify("",reference)
                realpage = resolved and structures.references.setreferencerealpage(resolved) or 0
                if realpage > 0 then
                    variant   = "realpage"
                    realpage  = realpage
                    reference = structures.pages.collected[realpage]
                    block     = reference and reference.block
                end
            elseif reftype == "number" then
                if reference > 0 then
                    variant   = "realpage"
                    realpage  = reference
                    reference = structures.pages.collected[realpage]
                    block     = reference and reference.block
                end
            else
                -- error
            end
            current.block = block
            if variant == "unknown" then
                -- error, ignore
                i = i + 1
         -- elseif (level < startlevel) or (i > 1 and block ~= levels[i-1].reference.block) then
            elseif (level < startlevel) or (i > 1 and block ~= levels[i-1].block) then
                if nested then -- could be an option but otherwise we quit too soon
                    if entry then
                        pdfflushobject(child,entry)
                    else
                        report_bookmarks("error 1")
                    end
                    return i, n, first, last
                else
                    report_bookmarks("confusing level change at level %a around %a",level,title)
                    startlevel = level
                end
            end
            if level == startlevel then
                if trace_bookmarks then
                    report_bookmarks("%3i %w%s %s",realpage,(level-1)*2,(opened and "+") or "-",title)
                end
                local prev = child
                child = pdfreserveobject()
                if entry then
                    entry.Next = child and pdfreference(child)
                    pdfflushobject(prev,entry)
                end
                local action = nil
                if variant == "list" then
                    action = pdflinkinternal(reference.internal,reference.realpage)
                elseif variant == "realpage" then
                    action = pagereferences[realpage]
                else
                    -- hm, what to do
                end
                entry = pdfdictionary {
                    Title  = pdfunicode(title),
                    Parent = parent,
                    Prev   = prev and pdfreference(prev),
                    A      = action,
                }
             -- entry.Dest = pdflinkinternal(reference.internal,reference.realpage)
                if not first then
                    first, last = child, child
                end
                prev = child
                last = prev
                n = n + 1
                i = i + 1
            elseif i < noflevels and level > startlevel then
                i, m, f, l = build(levels,i,pdfreference(child),method,true)
                if entry then
                    entry.Count = (opened and m) or -m
                    if m > 0 then
                        entry.First = pdfreference(f)
                        entry.Last  = pdfreference(l)
                    end
                else
                    report_bookmarks("error 2")
                end
            else
                -- missing intermediate level but ok
                i, m, f, l = build(levels,i,pdfreference(child),method,true)
                if entry then
                    entry.Count = (opened and m) or -m
                    if m > 0 then
                        entry.First = pdfreference(f)
                        entry.Last  = pdfreference(l)
                    end
                    pdfflushobject(child,entry)
                else
                    report_bookmarks("error 3")
                end
                return i, n, first, last
            end
        end
    end
    pdfflushobject(child,entry)
    return nil, n, first, last
end

function codeinjections.addbookmarks(levels,method)
    if levels and #levels > 0 then
        local parent = pdfreserveobject()
        local _, m, first, last = build(levels,1,pdfreference(parent),method or "internal",false)
        local dict = pdfdictionary {
            Type  = pdfconstant("Outlines"),
            First = pdfreference(first),
            Last  = pdfreference(last),
            Count = m,
        }
        pdfflushobject(parent,dict)
        pdfaddtocatalog("Outlines",lpdf.reference(parent))
    end
end

-- this could also be hooked into the frontend finalizer

lpdf.registerdocumentfinalizer(function() bookmarks.place() end,1,"bookmarks") -- hm, why indirect call
