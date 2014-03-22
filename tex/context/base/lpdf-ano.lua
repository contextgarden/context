if not modules then modules = { } end modules ['lpdf-ano'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- when using rotation: \disabledirectives[refences.sharelinks] (maybe flag links)

-- todo: /AA << WC << ... >> >> : WillClose actions etc

-- internal references are indicated by a number (and turned into aut:<number>)
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

local report_reference        = logs.reporter("backend","references")
local report_destination      = logs.reporter("backend","destinations")
local report_bookmark         = logs.reporter("backend","bookmarks")

local variables               = interfaces.variables
local constants               = interfaces.constants

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

local pdf_border              = pdfarray { 0, 0, 0 }

-- the used and flag code here is somewhat messy in the sense
-- that it belongs in strc-ref but at the same time depends on
-- the backend so we keep it here

-- the caching is somewhat memory intense on the one hand but
-- it saves many small temporary tables so it might pay off

local destinationviews = { } -- prevent messages

local pagedestinations = allocate()
local pagereferences   = allocate() -- annots are cached themselves

setmetatableindex(pagedestinations, function(t,k)
    k = tonumber(k)
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
            names[#names+1] = destination
            names[#names+1] = pdfreference(destinations[destination])
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
--         pdfaddtocatalog("Dests",r)
        pdfaddtonames("Dests",r)
        destinations = nil
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
local f_fitr  = formatters["<< /D [ %i 0 R /FitR [%0.3F %0.3F %0.3F %0.3F ] ] >>"]

-- nicer is to create dictionaries and set properties but overkill
--
-- local d_xyz   = pdfdictionary {
--     D  = pdfarray {
--         pdfreference(0),
--         pdfconstant("XYZ"),
--         0,
--         0,
--         pdfnull(),
--     }
-- }
--
-- local function xyz(r,width,height,depth)   -- same
--     local llx, lly = pdfrectangle(width,height,depth)
--     d_xyz.D[1][1] = r
--     d_xyz.D[3] = llx
--     d_xyz.D[4] = lly
--     return d_xyz()
-- end

local destinationactions = {
    xyz = function(r,width,height,depth)
        local llx, lly = pdfrectangle(width,height,depth)
        return f_xyz(r,llx,lly)
    end,
    fitr = function(r,width,height,depth)
        return f_fitr(r,pdfrectangle(width,height,depth))
    end,
    fith  = function(r) return f_fith (r,getvpos*factor) end,
    fitbh = function(r) return f_fitbh(r,getvpos*factor) end,
    fitv  = function(r) return f_fitv (r,gethpos*factor) end,
    fitbv = function(r) return f_fitbv(r,gethpos*factor) end,
    fit   = f_fit,
    fitb  = f_fitb,
}

local mapping = {
    xyz   = "xyz",   [variables.standard]  = "xyz",
    fitr  = "fitr",  [variables.frame]     = "fitr",
    fith  = "fith",  [variables.width]     = "fith",
    fitbh = "fitbh", [variables.minwidth]  = "fitbh",
    fitv  = "fitv",  [variables.height]    = "fitv",
    fitbv = "fitbv", [variables.minheight] = "fitbv",
    fit   = "fit",   [variables.fit]       = "fit",
    fitb  = "fitb",
}

local defaultaction = destinationactions.fit

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
    if view == "fit" then
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
    if view then
        view = mapping[view] or "fit"
    else
        view = "fit"
    end
    if trace_destinations then
        report_destination("width %p, height %p, depth %p, names %|t, view %a",width,height,depth,names,view)
    end
    local noview = view ~= "fit"
    local doview = false
    for n=1,#names do
        local name = names[n]
        if not destinationviews[name] then
            destinationviews[name] = not noview
            if type(name) == "number" then
                local u = usedinternals[name]
                if u then
                    if not noview then
                        flaginternals[name] = view
                    end
                    if references.innermethod ~= "auto" or u ~= true then
                        names[n] = "aut:" .. name
                        doview = true
                    else
                        names[n] = false
                    end
                else
                    names[n] = false
                end
            else
                doview = true
            end
        end
    end
    if doview then
        return latelua_function_node(function() flushdestination(width,height,depth,names,view) end)
    end
end

local function somedestination(destination,page)
    if type(destination) == "number" then
        flaginternals[destination] = true
        if references.innermethod == "auto" and usedinternals[destination] == true then
            return pagereferences[page]
        else
            return pdfdictionary { -- can be cached
                S = pdf_goto,
                D = "aut:" .. destination,
            }
        end
    else
        if references.innermethod == "auto" and destinationviews[destination] == true then
            return pagereferences[page] -- we use a simple one but the destination is there
        else
            return pdfdictionary { -- can be cached
                S = pdf_goto,
                D = destination,
            }
        end
    end
end

-- annotations

local function pdflink(url,filename,destination,page,actions)
    if filename and filename ~= "" then
        if file.basename(filename) == tex.jobname then
            return false
        else
            filename = file.addsuffix(filename,"pdf")
        end
    end
    if url and url ~= "" then
        if filename and filename ~= "" then
            if destination and destination ~= "" then
                url = file.join(url,filename).."#"..destination
            else
                url = file.join(url,filename)
            end
        end
        return pdfdictionary {
            S = pdf_uri,
            URI = url,
        }
    elseif filename and filename ~= "" then
        -- no page ?
        if destination == "" then
            destination = nil
        end
        if not destination and page then
            destination = pdfarray { page - 1, pdf_fit }
        end
        return pdfdictionary {
            S = pdf_gotor, -- can also be pdf_launch
            F = filename,
            D = destination or defaultdestination, -- D is mandate
            NewWindow = (actions.newwindow and true) or nil,
        }
    elseif destination and destination ~= "" then
        return somedestination(destination,page)
    end
    return pagereferences[page] -- we use a simple one but the destination is there
end

local function pdflaunch(program,parameters)
    if program and program ~= "" then
        local d = pdfdictionary {
            S = pdf_launch,
            F = program,
            D = ".",
        }
        if parameters and parameters ~= "" then
            d.P = parameters
        end
        return d
    end
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

lpdf.link       = pdflink
lpdf.launch     = pdflaunch
lpdf.javascript = pdfjavascript

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
                if what then
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
             main = pdfdictionary {
                Subtype = pdf_link,
                Border  = pdf_border,
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

local f_annot = formatters["<< /Type /Annot %s /Rect [%0.3F %0.3F %0.3F %0.3F] >>"]

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
    local method = references.innermethod
    if method == "names" or method == "auto" then
        local vi = var.i
        if vi then
            local vir = vi.references
            if vir then
                -- todo: no need for it when we have a real reference
                local reference = vir.reference
                if reference and reference ~= "" then
                    var.inner = reference
                else
                    internal = vir.internal
                    if internal then
                        var.inner = internal
                        flaginternals[internal] = true
                    end
                end
            end
        end
    else
        var.inner = nil
    end
    local prefix = var.p
    local inner = var.inner
    if not internal and inner and prefix and prefix ~= "" then
        -- no prefix with e.g. components
        inner = prefix .. ":" .. inner
    end
    return pdflink(nil,nil,inner,var.r,actions)
end

runners["inner with arguments"] = function(var,actions)
    report_reference("todo: inner with arguments")
    return false
end

runners["outer"] = function(var,actions)
    local file, url = references.checkedfileorurl(var.outer,var.outer)
    return pdflink(url,file,var.arguments,nil,actions)
end

runners["outer with inner"] = function(var,actions)
    local file = references.checkedfile(var.outer) -- was var.f but fails ... why
    return pdflink(nil,file,var.inner,var.r,actions)
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
        report_reference("no internal reference %a",i)
    else
        flaginternals[i] = true
        local method = references.innermethod
        if method == "names" then
            -- named
            return pdflink(nil,nil,i,v.references.realpage,actions)
        elseif method == "auto" then
            -- named
            if usedinternals[i] == true then
                return pdflink(nil,nil,nil,v.references.realpage,actions)
            else
                return pdflink(nil,nil,i,v.references.realpage,actions)
            end
        else
            -- page
            return pdflink(nil,nil,nil,v.references.realpage,actions)
        end
    end
end

-- realpage already resolved

specials.i = specials.internal

local pages = references.pages

function specials.page(var,actions)
    local file = var.f
    if file then
        file = references.checkedfile(file)
        return pdflink(nil,file,nil,var.operation,actions)
    else
        local p = var.r
        if not p then -- todo: call special from reference code
            p = pages[var.operation]
            if type(p) == "function" then -- double
                p = p()
            else
                p = references.realpageofpage(tonumber(p))
            end
         -- if p then
         --     var.r = p
         -- end
        end
        return pdflink(nil,nil,nil,p or var.operation,actions)
    end
end

function specials.realpage(var,actions)
    local file = var.f
    if file then
        file = references.checkedfile(file)
        return pdflink(nil,file,nil,var.operation,actions)
    else
        return pdflink(nil,nil,nil,var.operation,actions)
    end
end

function specials.userpage(var,actions)
    local file = var.f
    if file then
        file = references.checkedfile(file)
        return pdflink(nil,file,nil,var.operation,actions)
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
        return pdflink(nil,nil,nil,p or var.operation,actions)
    end
end

function specials.deltapage(var,actions)
    local p = tonumber(var.operation)
    if p then
        p = references.checkedrealpage(p + texgetcount("realpageno"))
        return pdflink(nil,nil,nil,p,actions)
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
    local url = references.checkedurl(var.operation)
    return pdflink(url,nil,var.arguments,nil,actions)
end

function specials.file(var,actions)
    local file = references.checkedfile(var.operation)
    return pdflink(nil,file,var.arguments,nil,actions)
end

function specials.fileorurl(var,actions)
    local file, url = references.checkedfileorurl(var.operation,var.operation)
    return pdflink(url,file,var.arguments,nil,actions)
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

local function build(levels,start,parent,method)
    local startlevel = levels[start][1]
    local i, n = start, 0
    local child, entry, m, prev, first, last, f, l
    while i and i <= #levels do
        local li = levels[i]
        local level, title, reference, open = li[1], li[2], li[3], li[4]
        if level < startlevel then
            pdfflushobject(child,entry)
            return i, n, first, last
        elseif level == startlevel then
            if trace_bookmarks then
                report_bookmark("%3i %w%s %s",reference.realpage,(level-1)*2,(open and "+") or "-",title)
            end
            local prev = child
            child = pdfreserveobject()
            if entry then
                entry.Next = child and pdfreference(child)
                pdfflushobject(prev,entry)
            end
            entry = pdfdictionary {
                Title  = pdfunicode(title),
                Parent = parent,
                Prev   = prev and pdfreference(prev),
            }
            entry.Dest = somedestination(reference.internal,reference.realpage)
            if not first then first, last = child, child end
            prev = child
            last = prev
            n = n + 1
            i = i + 1
        elseif i < #levels and level > startlevel then
            i, m, f, l = build(levels,i,pdfreference(child),method)
            entry.Count = (open and m) or -m
            if m > 0 then
                entry.First, entry.Last = pdfreference(f), pdfreference(l)
            end
        else
            -- missing intermediate level but ok
            i, m, f, l = build(levels,i,pdfreference(child),method)
            entry.Count = (open and m) or -m
            if m > 0 then
                entry.First, entry.Last = pdfreference(f), pdfreference(l)
            end
            pdfflushobject(child,entry)
            return i, n, first, last
        end
    end
    pdfflushobject(child,entry)
    return nil, n, first, last
end

function codeinjections.addbookmarks(levels,method)
    if #levels > 0 then
        structures.bookmarks.flatten(levels) -- dirty trick for lack of structure
        local parent = pdfreserveobject()
        local _, m, first, last = build(levels,1,pdfreference(parent),method or "internal")
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
