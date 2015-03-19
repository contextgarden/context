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

local next, tostring, tonumber, rawget = next, tostring, tonumber, rawget
local rep, format, find = string.rep, string.format, string.find
local min = math.min
local lpegmatch = lpeg.match
local formatters = string.formatters

local backends, lpdf = backends, lpdf

local trace_references        = false  trackers.register("references.references",   function(v) trace_references   = v end)
local trace_destinations      = false  trackers.register("references.destinations", function(v) trace_destinations = v end)
local trace_bookmarks         = false  trackers.register("references.bookmarks",    function(v) trace_bookmarks    = v end)

local log_destinations        = false  directives.register("destinations.log",      function(v) log_destinations   = v end)

local report_reference        = logs.reporter("backend","references")
local report_destination      = logs.reporter("backend","destinations")
local report_bookmark         = logs.reporter("backend","bookmarks")

local variables               = interfaces.variables
local v_auto                  = variables.auto
local v_page                  = variables.page

local factor                  = number.dimenfactors.bp

local settings_to_array       = utilities.parsers.settings_to_array

local allocate                = utilities.storage.allocate
local setmetatableindex       = table.setmetatableindex

local nodeinjections          = backends.pdf.nodeinjections
local codeinjections          = backends.pdf.codeinjections
local registrations           = backends.pdf.registrations

local getpos                  = codeinjections.getpos
local gethpos                 = codeinjections.gethpos
local getvpos                 = codeinjections.getvpos

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

----- pdfannotation_node      = nodepool.pdfannotation
----- pdfdestination_node     = nodepool.pdfdestination
----- latelua_node            = nodepool.latelua
local latelua_function_node   = nodepool.lateluafunction -- still node ... todo

local texgetcount             = tex.getcount

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

local pdf_annot               = pdfconstant("Annot")
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

-- Bah, I hate this kind of features .. anyway, as we have delayed resolving we
-- only support a document-wide setup and it has to be set before the first one
-- is used. Also, we default to a non-intrusive gray and the outline is kept
-- thin without dashing lines. This is as far as I'm prepared to go. This way
-- it can also be used as a debug feature.

local pdf_border_style        = pdfarray { 0, 0, 0 } -- radius radius linewidth
local pdf_border_color        = nil
local set_border              = false

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
                local r, g, b = v[3], v[4], v[5]
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

local pagedestinations = allocate()
local pagereferences   = allocate() -- annots are cached themselves

setmetatableindex(pagedestinations, function(t,k)
    k = tonumber(k)
    if not k or k <= 0 then
        return pdfnull()
    end
    local v = rawget(t,k)
    if v then
     -- report_reference("page number expected, got %s: %a",type(k),k)
        return v
    end
    local v = k > 0 and pdfarray {
        pdfreference(pdfpagereference(k)),
        pdf_fit,
    } or pdfnull()
    t[k] = v
    return v
end)

setmetatableindex(pagereferences,function(t,k)
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

lpdf.pagereferences   = pagereferences   -- table
lpdf.pagedestinations = pagedestinations -- table

local defaultdestination = pdfarray { 0, pdf_fit }

-- fit is default (see lpdf-nod)

local destinations = { } -- to be used soon

local function pdfregisterdestination(name,reference)
    local d = destinations[name]
    if d then
        report_destination("ignoring duplicate destination %a with reference %a",name,reference)
    else
        destinations[name] = reference
    end
end

lpdf.registerdestination = pdfregisterdestination

local maxslice = 32 -- could be made configureable ... 64 is also ok

luatex.registerstopactions(function()
    if log_destinations and next(destinations) then
        local logsnewline      = logs.newline
        local log_destinations = logs.reporter("system","references")
        local log_destination  = logs.reporter("destination")
        logs.pushtarget("logfile")
        logsnewline()
        log_destinations("start used destinations")
        logsnewline()
        local n = 0
        for destination, pagenumber in table.sortedhash(destinations) do
            log_destination("% 4i : %-5s : %s",pagenumber,usedviews[destination] or defaultview,destination)
            n = n + 1
        end
        logsnewline()
        log_destinations("stop used destinations")
        logsnewline()
        logs.poptarget()
        report_destination("%s destinations saved in log file",n)
    end
end)


local function pdfnametree(destinations)
    local slices = { }
    local sorted = table.sortedkeys(destinations)
    local size   = #sorted

    if size <= 1.5*maxslice then
        maxslice = size
    end

    for i=1,size,maxslice do
        local amount = min(i+maxslice-1,size)
        local names  = pdfarray { }
        for j=i,amount do
            local destination = sorted[j]
            local pagenumber  = destinations[destination]
            names[#names+1] = tostring(destination) -- tostring is a safeguard
            names[#names+1] = pdfreference(pagenumber)
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
        local k = pdfarray()
        local d = pdfdictionary {
            Kids   = k,
            Limits = pdfarray {
                slices[first].limits[1],
                slices[last ].limits[2],
            },
        }
        for i=first,last do
            k[#k+1] = slices[i].reference
        end
        return d
    end
    if #slices == 1 then
        return slices[1].reference
    else
        while true do
            if #slices > maxslice then
                local temp = { }
                local size = #slices
                for i=1,size,maxslice do
                    local kids = collectkids(slices,i,min(i+maxslice-1,size))
                    temp[#temp+1] = {
                        reference = pdfreference(pdfflushobject(kids)),
                        limits    = kids.Limits,
                    }
                end
                slices = temp
            else
                return pdfreference(pdfflushobject(collectkids(slices,1,#slices)))
            end
        end
    end
end

local function pdfdestinationspecification()
    if next(destinations) then -- safeguard
        local r = pdfnametree(destinations)
     -- pdfaddtocatalog("Dests",r)
        pdfaddtonames("Dests",r)
        if not log_destinations then
            destinations = nil
        end
    end
end

lpdf.nametree                 = pdfnametree
lpdf.destinationspecification = pdfdestinationspecification

lpdf.registerdocumentfinalizer(pdfdestinationspecification,"collect destinations")

-- todo

local destinations = { }

local f_xyz   = formatters["<< /D [ %i 0 R /XYZ %0.3F %0.3F null ] >>"]
local f_fit   = formatters["<< /D [ %i 0 R /Fit ] >>"]
local f_fitb  = formatters["<< /D [ %i 0 R /FitB ] >>"]
local f_fith  = formatters["<< /D [ %i 0 R /FitH %0.3F ] >>"]
local f_fitv  = formatters["<< /D [ %i 0 R /FitV %0.3F ] >>"]
local f_fitbh = formatters["<< /D [ %i 0 R /FitBH %0.3F ] >>"]
local f_fitbv = formatters["<< /D [ %i 0 R /FitBV %0.3F ] >>"]
local f_fitr  = formatters["<< /D [ %i 0 R /FitR %0.3F %0.3F %0.3F %0.3F ] >>"]

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

local destinationactions = {
 -- [v_standard]  = function(r,w,h,d) return f_xyz  (r,pdfrectangle(w,h,d)) end,                   -- local left,top with zoom (0 in our case)
    [v_standard]  = function(r,w,h,d) return f_xyz  (r,gethpos()*factor,(getvpos()+h)*factor) end, -- local left,top with no zoom
    [v_frame]     = function(r,w,h,d) return f_fitr (r,pdfrectangle(w,h,d)) end,                   -- fit rectangle in window
 -- [v_width]     = function(r,w,h,d) return f_fith (r,gethpos()*factor) end,                      -- top coordinate, fit width of page in window
    [v_width]     = function(r,w,h,d) return f_fith (r,(getvpos()+h)*factor) end,                  -- top coordinate, fit width of page in window
 -- [v_minwidth]  = function(r,w,h,d) return f_fitbh(r,gethpos()*factor) end,                      -- top coordinate, fit width of content in window
    [v_minwidth]  = function(r,w,h,d) return f_fitbh(r,(getvpos()+h)*factor) end,                  -- top coordinate, fit width of content in window
 -- [v_height]    = function(r,w,h,d) return f_fitv (r,(getvpos()+h)*factor) end,                  -- left coordinate, fit height of page in window
    [v_height]    = function(r,w,h,d) return f_fitv (r,gethpos()*factor) end,                      -- left coordinate, fit height of page in window
 -- [v_minheight] = function(r,w,h,d) return f_fitbv(r,(getvpos()+h)*factor) end,                  -- left coordinate, fit height of content in window
    [v_minheight] = function(r,w,h,d) return f_fitbv(r,gethpos()*factor) end,                      -- left coordinate, fit height of content in window    [v_fit]       =                          f_fit,                                                 -- fit page in window
    [v_tight]     =                          f_fitb,                                               -- fit content in window
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

-- A complication is that we need to use named destinations when we have views so we
-- end up with a mix. A previous versions just output multiple destinations but not
-- that we noved all to here we can be more sparse.

local pagedestinations = { }

table.setmetatableindex(pagedestinations,function(t,k)
    local v = pdfdelayedobject(f_fit(k))
    t[k] = v
    return v
end)

local function flushdestination(width,height,depth,names,view)
    local r = pdfpagereference(texgetcount("realpageno"))
    if view == defaultview or not view or view == "" then
        r = pagedestinations[r]
    else
        local action = view and destinationactions[view] or defaultaction
        r = pdfdelayedobject(action(r,width,height,depth))
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
        report_destination("width %p, height %p, depth %p, names %|t, view %a",width,height,depth,names,view)
    end
    local method = references.innermethod
    local noview = view == defaultview
    local doview = false
    -- we could save some aut's by using a name when given but it doesn't pay off apart
    -- from making the code messy and tracing hard .. we only save some destinations
    -- which we already share anyway
    for n=1,#names do
        local name = names[n]
        if usedviews[name] then
            -- already done, maybe a warning
        elseif type(name) == "number" then
            if noview then
                usedviews[name] = view
                names[n] = false
            elseif method == v_page then
                usedviews[name] = view
                names[n] = false
            else
                local used = usedinternals[name]
                if used and used ~= defaultview then
                    usedviews[name] = view
                    names[n] = autoprefix .. name
                    doview = true
                else
                 -- names[n] = autoprefix .. name
                    names[n] = false
                end
            end
        elseif method == v_page then
            usedviews[name] = view
        else
            usedviews[name] = view
            doview = true
        end
    end
    if doview then
        return latelua_function_node(function() flushdestination(width,height,depth,names,view) end)
    end
end

-- we could share dictionaries ... todo

local function somedestination(destination,internal,page) -- no view anyway
    if references.innermethod ~= v_page then
        if type(destination) == "number" then
            if not internal then
                internal = destination
            end
            destination = nil
        end
        if internal then
            flaginternals[internal] = true -- for bookmarks and so
            local used = usedinternals[internal]
            if used == defaultview or used == true then
                return pagereferences[page]
            end
            if type(destination) ~= "string" then
                destination = autoprefix .. internal
            end
            return pdfdictionary {
                S = pdf_goto,
                D = destination,
            }
        end
        if destination then
            -- hopefully this one is flushed
            return pdfdictionary {
                S = pdf_goto,
                D = destination,
            }
        end
    end
    return pagereferences[page]
end

-- annotations

local pdflink = somedestination

local function pdffilelink(filename,destination,page,actions)
    if not filename or filename == "" or file.basename(filename) == tex.jobname then
        return false
    end
    filename = file.addsuffix(filename,"pdf")
    if not destination or destination == "" then
        destination = pdfarray { (page or 0) - 1, pdf_fit }
    end
    return pdfdictionary {
        S = pdf_gotor, -- can also be pdf_launch
        F = filename,
        D = destination or defaultdestination, -- D is mandate
        NewWindow = actions.newwindow and true or nil,
    }
end

local function pdfurllink(url,destination,page)
    if not url or url == "" then
        return false
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
            return first, actions.n
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
--                 report_reference("width %p, height %p, depth %p, prerolled %a",width,height,depth,prerolled)
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

local f_annot = formatters["<< /Type /Annot %s /Rect [ %0.3F %0.3F %0.3F %0.3F ] >>"]

directives.register("refences.sharelinks", function(v) share = v end)

table.setmetatableindex(hashed,function(t,k)
    local v = pdfdelayedobject(k)
    if share then
        t[k] = v
    end
    nofunique = nofunique + 1
    return v
end)

local function finishreference(width,height,depth,prerolled) -- %0.2f looks okay enough (no scaling anyway)
    local annot = hashed[f_annot(prerolled,pdfrectangle(width,height,depth))]
    nofused = nofused + 1
    return pdfregisterannotation(annot)
end

local function finishannotation(width,height,depth,prerolled,r)
    local annot = f_annot(prerolled,pdfrectangle(width,height,depth))
    if r then
        pdfdelayedobject(annot,r)
    else
        r = pdfdelayedobject(annot)
    end
    nofspecial = nofspecial + 1
    return pdfregisterannotation(r)
end

function nodeinjections.reference(width,height,depth,prerolled)
    if prerolled then
        if trace_references then
            report_reference("link: width %p, height %p, depth %p, prerolled %a",width,height,depth,prerolled)
        end
        return latelua_function_node(function() finishreference(width,height,depth,prerolled) end)
    end
end

function nodeinjections.annotation(width,height,depth,prerolled,r)
    if prerolled then
        if trace_references then
            report_reference("special: width %p, height %p, depth %p, prerolled %a",width,height,depth,prerolled)
        end
        return latelua_function_node(function() finishannotation(width,height,depth,prerolled,r or false) end)
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
        pdfaddtopageattributes("Annots",pdfreference(r))
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

runners["inner"] = function(var,actions)
    local internal = false
    local inner    = nil
    if references.innermethod == v_auto then
        local vi = var.i
        if vi then
            local vir = vi.references
            if vir then
                -- todo: no need for it when we have a real reference
                local reference = vir.reference
                if reference and reference ~= "" then
                    var.inner = reference
                    local prefix = var.p
                    if prefix and prefix ~= "" then
                        var.prefix = prefix
                        inner = prefix .. ":" .. reference
                    else
                        inner = reference
                    end
                end
                internal = vir.internal
                if internal then
                    flaginternals[internal] = true
                end
            end
        end
    else
        var.inner = nil
    end
    return pdflink(inner,internal,var.r)
end

runners["inner with arguments"] = function(var,actions)
    report_reference("todo: inner with arguments")
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
    report_reference("todo: special outer")
    return false
end

runners["special"] = function(var,actions)
    local handler = specials[var.special]
    return handler and handler(var,actions)
end

runners["outer with inner with arguments"] = function(var,actions)
    report_reference("todo: outer with inner with arguments")
    return false
end

runners["outer with special and operation and arguments"] = function(var,actions)
    report_reference("todo: outer with special and operation and arguments")
    return false
end

runners["outer with special"] = function(var,actions)
    report_reference("todo: outer with special")
    return false
end

runners["outer with special and operation"] = function(var,actions)
    report_reference("todo: outer with special and operation")
    return false
end

runners["special operation"]                = runners["special"]
runners["special operation with arguments"] = runners["special"]

function specials.internal(var,actions) -- better resolve in strc-ref
    local i = tonumber(var.operation)
    local v = i and references.internals[i]
    if not v then
        -- error
        report_reference("no internal reference %a",i or "<unset>")
    else
        flaginternals[i] = true
        return pdflink(nil,i,v.references.realpage)
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
        return pdflink(nil,nil,p or var.operation)
    end
end

function specials.realpage(var,actions)
    local file = var.f
    if file then
        return pdffilelink(references.checkedfile(file),nil,var.operation,actions)
    else
        return pdflink(nil,nil,var.operation)
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
        return pdflink(nil,nil,p or var.operation)
    end
end

function specials.deltapage(var,actions)
    local p = tonumber(var.operation)
    if p then
        p = references.checkedrealpage(p + texgetcount("realpageno"))
        return pdflink(nil,nil,p)
    end
end

-- sections

-- function specials.section(var,actions)
--     local sectionname = var.operation
--     local destination = var.arguments
--     local internal    = structures.sections.internalreference(sectionname,destination)
--     if internal then
--         var.special   = "internal"
--         var.operation = internal
--         var.arguments = nil
--         specials.internal(var,actions)
--     end
-- end

specials.section = specials.internal -- specials.section just need to have a value as it's checked

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
    local i, n = start, 0
    local child, entry, m, prev, first, last, f, l
    while i and i <= #levels do
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
            local variant   = "unknown"
            if reftype == "table" then
                -- we're okay
                variant  = "list"
            elseif reftype == "string" then
                local resolved = references.identify("",reference)
                local realpage = resolved and structures.references.setreferencerealpage(resolved) or 0
                if realpage > 0 then
                    variant  = "realpage"
                    realpage = realpage
                end
            elseif reftype == "number" then
                if reference > 0 then
                    variant  = "realpage"
                    realpage = reference
                end
            else
                -- error
            end
            if variant == "unknown" then
                -- error, ignore
                i = i + 1
            elseif level <= startlevel then
                if level < startlevel then
                    if nested then -- could be an option but otherwise we quit too soon
                        if entry then
                            pdfflushobject(child,entry)
                        else
                            report_bookmark("error 1")
                        end
                        return i, n, first, last
                    else
                        report_bookmark("confusing level change at level %a around %a",level,title)
                    end
                end
                if trace_bookmarks then
                    report_bookmark("%3i %w%s %s",reference.realpage,(level-1)*2,(opened and "+") or "-",title)
                end
                local prev = child
                child = pdfreserveobject()
                if entry then
                    entry.Next = child and pdfreference(child)
                    pdfflushobject(prev,entry)
                end
                local action = nil
                if variant == "list" then
                    action = somedestination(reference.internal,reference.internal,reference.realpage)
                elseif variant == "realpage" then
                    action = pagereferences[realpage]
                end
                entry = pdfdictionary {
                    Title  = pdfunicode(title),
                    Parent = parent,
                    Prev   = prev and pdfreference(prev),
                    A      = action,
                }
             -- entry.Dest = somedestination(reference.internal,reference.internal,reference.realpage)
                if not first then first, last = child, child end
                prev = child
                last = prev
                n = n + 1
                i = i + 1
            elseif i < #levels and level > startlevel then
                i, m, f, l = build(levels,i,pdfreference(child),method,true)
                if entry then
                    entry.Count = (opened and m) or -m
                    if m > 0 then
                        entry.First = pdfreference(f)
                        entry.Last  = pdfreference(l)
                    end
                else
                    report_bookmark("error 2")
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
                    report_bookmark("error 3")
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
