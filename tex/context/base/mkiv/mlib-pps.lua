if not modules then modules = { } end modules ['mlib-pps'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local format, gmatch, match, split, gsub = string.format, string.gmatch, string.match, string.split, string.gsub
local tonumber, type, unpack, next, select = tonumber, type, unpack, next, select
local round, sqrt, min, max = math.round, math.sqrt, math.min, math.max
local insert, remove, concat = table.insert, table.remove, table.concat
local Cs, Cf, C, Cg, Ct, P, S, V, Carg = lpeg.Cs, lpeg.Cf, lpeg.C, lpeg.Cg, lpeg.Ct, lpeg.P, lpeg.S, lpeg.V, lpeg.Carg
local lpegmatch, tsplitat, tsplitter = lpeg.match, lpeg.tsplitat, lpeg.tsplitter
local formatters = string.formatters
local exists, savedata = io.exists, io.savedata

local mplib                = mplib
local metapost             = metapost
local lpdf                 = lpdf
local context              = context

local implement            = interfaces.implement
local setmacro             = interfaces.setmacro

local texsetbox            = tex.setbox
local textakebox           = tex.takebox -- or: nodes.takebox
local copy_list            = node.copy_list
local flush_list           = node.flush_list
local setmetatableindex    = table.setmetatableindex
local sortedhash           = table.sortedhash

local new_hlist            = nodes.pool.hlist

local starttiming          = statistics.starttiming
local stoptiming           = statistics.stoptiming

local trace_runs           = false  trackers.register("metapost.runs",     function(v) trace_runs     = v end)
local trace_textexts       = false  trackers.register("metapost.textexts", function(v) trace_textexts = v end)
local trace_scripts        = false  trackers.register("metapost.scripts",  function(v) trace_scripts  = v end)
local trace_btexetex       = false  trackers.register("metapost.btexetex", function(v) trace_btexetex = v end)

local report_metapost      = logs.reporter("metapost")
local report_textexts      = logs.reporter("metapost","textexts")
local report_scripts       = logs.reporter("metapost","scripts")

local colors               = attributes.colors
local defineprocesscolor   = colors.defineprocesscolor
local definespotcolor      = colors.definespotcolor
local definemultitonecolor = colors.definemultitonecolor
local colorvalue           = colors.value

local transparencies       = attributes.transparencies
local registertransparency = transparencies.register
local transparencyvalue    = transparencies.value

local rgbtocmyk            = colors.rgbtocmyk  -- or function() return 0,0,0,1 end
local cmyktorgb            = colors.cmyktorgb  -- or function() return 0,0,0   end
local rgbtogray            = colors.rgbtogray  -- or function() return 0       end
local cmyktogray           = colors.cmyktogray -- or function() return 0       end

local nooutercolor         = "0 g 0 G"
local nooutertransparency  = "/Tr0 gs" -- only when set
local outercolormode       = 0
local outercolormodel      = 1
local outercolor           = nooutercolor
local outertransparency    = nooutertransparency
local innercolor           = nooutercolor
local innertransparency    = nooutertransparency

local pdfcolor             = lpdf.color
local pdftransparency      = lpdf.transparency

function metapost.setoutercolor(mode,colormodel,colorattribute,transparencyattribute)
    -- has always to be called before conversion
    -- todo: transparency (not in the mood now)
    outercolormode  = mode
    outercolormodel = colormodel
    if mode == 1 or mode == 3 then
        -- inherit from outer (registered color)
        outercolor        = pdfcolor(colormodel,colorattribute)    or nooutercolor
        outertransparency = pdftransparency(transparencyattribute) or nooutertransparency
    elseif mode == 2 then
        -- stand alone (see m-punk.tex)
        outercolor        = ""
        outertransparency = ""
    else -- 0
        outercolor        = nooutercolor
        outertransparency = nooutertransparency
    end
    innercolor        = outercolor
    innertransparency = outertransparency -- not yet used
end

-- todo: get this from the lpdf module

local f_f     = formatters["%.6N"]
local f_f3    = formatters["%.3N"]
local f_gray  = formatters["%.3N g %.3N G"]
local f_rgb   = formatters["%.3N %.3N %.3N rg %.3N %.3N %.3N RG"]
local f_cmyk  = formatters["%.3N %.3N %.3N %.3N k %.3N %.3N %.3N %.3N K"]
local f_cm_b  = formatters["q %.6N %.6N %.6N %.6N %.6N %.6N cm"]
local f_scn   = formatters["%.3N"]

local f_shade = formatters["MpSh%s"]
local f_spot  = formatters["/%s cs /%s CS %s SCN %s scn"]
local s_cm_e  = "Q"

local function checked_color_pair(color,...)
    if not color then
        return innercolor, outercolor
    end
    if outercolormode == 3 then
        innercolor = color(...)
        return innercolor, innercolor
    else
        return color(...), outercolor
    end
end

function metapost.colorinitializer()
    innercolor = outercolor
    innertransparency = outertransparency
    return outercolor, outertransparency
end

--~

local specificationsplitter = tsplitat(" ")
local colorsplitter         = tsplitter(":",tonumber) -- no need for :
local domainsplitter        = tsplitter(" ",tonumber)
local centersplitter        = domainsplitter
local coordinatesplitter    = domainsplitter

-- thanks to taco's reading of the postscript manual:
--
-- x' = sx * x + ry * y + tx
-- y' = rx * x + sy * y + ty

local nofshades = 0 -- todo: hash resources, start at 1000 in order not to clash with older

local function normalize(ca,cb)
    if #cb == 1 then
        if #ca == 4 then
            cb[1], cb[2], cb[3], cb[4] = 0, 0, 0, 1-cb[1]
        else
            cb[1], cb[2], cb[3] = cb[1], cb[1], cb[1]
        end
    elseif #cb == 3 then
        if #ca == 4 then
            cb[1], cb[2], cb[3], cb[4] = rgbtocmyk(cb[1],cb[2],cb[3])
        else
            cb[1], cb[2], cb[3] = cmyktorgb(cb[1],cb[2],cb[3],cb[4])
        end
    end
end


local commasplitter = tsplitat(",")

local function checkandconvertspot(n_a,f_a,c_a,v_a,n_b,f_b,c_b,v_b)
    -- must be the same but we don't check
    local name = f_shade(nofshades)
    local ca = lpegmatch(commasplitter,v_a)
    local cb = lpegmatch(commasplitter,v_b)
    if #ca == 0 or #cb == 0 then
        return { 0 }, { 1 }, "DeviceGray", name
    else
        for i=1,#ca do ca[i] = tonumber(ca[i]) or 0 end
        for i=1,#cb do cb[i] = tonumber(cb[i]) or 1 end
    --~ spotcolorconverter(n_a,f_a,c_a,v_a) -- not really needed
        return ca, cb, n_a or n_b, name
    end
end

local function checkandconvert(ca,cb,model)
    local name = f_shade(nofshades)
    if not ca or not cb or type(ca) == "string" then
        return { 0 }, { 1 }, "DeviceGray", name
    else
        if #ca > #cb then
            normalize(ca,cb)
        elseif #ca < #cb then
            normalize(cb,ca)
        end
        if not model then
            model = colors.currentnamedmodel()
        end
        if model == "all" then
            model= (#ca == 4 and "cmyk") or (#ca == 3 and "rgb") or "gray"
        end
        if model == "rgb" then
            if #ca == 4 then
                ca = { cmyktorgb(ca[1],ca[2],ca[3],ca[4]) }
                cb = { cmyktorgb(cb[1],cb[2],cb[3],cb[4]) }
            elseif #ca == 1 then
                local a = 1 - ca[1]
                local b = 1 - cb[1]
                ca = { a, a, a }
                cb = { b, b, b }
            end
            return ca, cb, "DeviceRGB", name, model
        elseif model == "cmyk" then
            if #ca == 3 then
                ca = { rgbtocmyk(ca[1],ca[2],ca[3]) }
                cb = { rgbtocmyk(cb[1],cb[2],cb[3]) }
            elseif #ca == 1 then
                ca = { 0, 0, 0, ca[1] }
                cb = { 0, 0, 0, ca[1] }
            end
            return ca, cb, "DeviceCMYK", name, model
        else
            if #ca == 4 then
                ca = { cmyktogray(ca[1],ca[2],ca[3],ca[4]) }
                cb = { cmyktogray(cb[1],cb[2],cb[3],cb[4]) }
            elseif #ca == 3 then
                ca = { rgbtogray(ca[1],ca[2],ca[3]) }
                cb = { rgbtogray(cb[1],cb[2],cb[3]) }
            end
            -- backend specific (will be renamed)
            return ca, cb, "DeviceGray", name, model
        end
    end
end

-- We keep textexts in a shared list (as it's easier that way and we also had that in
-- the beginning). Each graphic gets its own (1 based) subtable so that we can also
-- handle multiple conversions in one go which is needed when we process mp files
-- directly.

local stack   = { } -- quick hack, we will pass topofstack around
local top     = nil
local nofruns = 0 -- askedfig: "all", "first", number

local function preset(t,k)
    -- references to textexts by mp index
    local v = {
        textrial = 0,
        texfinal = 0,
        texslots = { },
        texorder = { },
        texhash  = { },
    }
    t[k] = v
    return v
end

local function startjob(plugmode,kind,mpx)
    insert(stack,top)
    top = {
        textexts   = { },                          -- all boxes, optionally with a different color
        texstrings = { },
        mapstrings = { },
        mapindices = { },
        mapmoves   = { },
        texlast    = 0,
        texdata    = setmetatableindex({},preset), -- references to textexts in order or usage
        plugmode   = plugmode,                     -- some day we can then skip all pre/postscripts
        extradata  = mpx and metapost.getextradata(mpx),
    }
    if trace_runs then
        report_metapost("starting %s run at level %i in %s mode",
            kind,#stack+1,plugmode and "plug" or "normal")
    end
    return top
end

local function stopjob()
    if top then
        for slot, content in next, top.textexts do
            if content then
                flush_list(content)
                if trace_textexts then
                    report_textexts("freeing text %s",slot)
                end
            end
        end
        if trace_runs then
            report_metapost("stopping run at level %i",#stack+1)
        end
        top = remove(stack)
        return top
    end
end

function metapost.getjobdata()
    return top
end

-- end of new

local settext = function(box,slot,str)
    if top then
     -- if trace_textexts then
     --     report_textexts("getting text %s from box %s",slot,box)
     -- end
        top.textexts[slot] = textakebox(box)
    end
end

local gettext = function(box,slot)
    if top then
        texsetbox(box,top.textexts[slot])
        top.textexts[slot] = false
     -- if trace_textexts then
     --     report_textexts("putting text %s in box %s",slot,box)
     -- end
    end
end

metapost.settext = settext
metapost.gettext = gettext

implement { name = "mpsettext", actions = settext, arguments = { "integer", "integer" } } -- box slot
implement { name = "mpgettext", actions = gettext, arguments = { "integer", "integer" } } -- box slot

-- rather generic pdf, so use this elsewhere too it no longer pays
-- off to distinguish between outline and fill (we now have both
-- too, e.g. in arrows)

metapost.reducetogray = true

local models = { }

function models.all(cr)
    local n = #cr
    if n == 0 then
        return checked_color_pair()
    elseif metapost.reducetogray then
        if n == 1 then
            local s = cr[1]
            return checked_color_pair(f_gray,s,s)
        elseif n == 3 then
            local r = cr[1]
            local g = cr[2]
            local b = cr[3]
            if r == g and g == b then
                return checked_color_pair(f_gray,r,r)
            else
                return checked_color_pair(f_rgb,r,g,b,r,g,b)
            end
        else
            local c = cr[1]
            local m = cr[2]
            local y = cr[3]
            local k = cr[4]
            if c == m and m == y and y == 0 then
                k = 1 - k
                return checked_color_pair(f_gray,k,k)
            else
                return checked_color_pair(f_cmyk,c,m,y,k,c,m,y,k)
            end
        end
    elseif n == 1 then
        local s = cr[1]
        return checked_color_pair(f_gray,s,s)
    elseif n == 3 then
        local r = cr[1]
        local g = cr[2]
        local b = cr[3]
        return checked_color_pair(f_rgb,r,g,b,r,g,b)
    else
        local c = cr[1]
        local m = cr[2]
        local y = cr[3]
        local k = cr[4]
        return checked_color_pair(f_cmyk,c,m,y,k,c,m,y,k)
    end
end

function models.rgb(cr)
    local n = #cr
    if n == 0 then
        return checked_color_pair()
    elseif metapost.reducetogray then
        if n == 1 then
            local s = cr[1]
            checked_color_pair(f_gray,s,s)
        elseif n == 3 then
            local r = cr[1]
            local g = cr[2]
            local b = cr[3]
            if r == g and g == b then
                return checked_color_pair(f_gray,r,r)
            else
                return checked_color_pair(f_rgb,r,g,b,r,g,b)
            end
        else
            local c = cr[1]
            local m = cr[2]
            local y = cr[3]
            local k = cr[4]
            if c == m and m == y and y == 0 then
                k = 1 - k
                return checked_color_pair(f_gray,k,k)
            else
                local r, g, b = cmyktorgb(c,m,y,k)
                return checked_color_pair(f_rgb,r,g,b,r,g,b)
            end
        end
    elseif n == 1 then
        local s = cr[1]
        return checked_color_pair(f_gray,s,s)
    else
        local r = cr[1]
        local g = cr[2]
        local b = cr[3]
        local r, g, b
        if n == 3 then
            r, g, b = cmyktorgb(r,g,b,cr[4])
        end
        return checked_color_pair(f_rgb,r,g,b,r,g,b)
    end
end

function models.cmyk(cr)
    local n = #cr
    if n == 0 then
        return checked_color_pair()
    elseif metapost.reducetogray then
        if n == 1 then
            local s = cr[1]
            return checked_color_pair(f_gray,s,s)
        elseif n == 3 then
            local r = cr[1]
            local g = cr[2]
            local b = cr[3]
            if r == g and g == b then
                return checked_color_pair(f_gray,r,r)
            else
                local c, m, y, k = rgbtocmyk(r,g,b)
                return checked_color_pair(f_cmyk,c,m,y,k,c,m,y,k)
            end
        else
            local c = cr[1]
            local m = cr[2]
            local y = cr[3]
            local k = cr[4]
            if c == m and m == y and y == 0 then
                k = 1 - k
                return checked_color_pair(f_gray,k,k)
            else
                return checked_color_pair(f_cmyk,c,m,y,k,c,m,y,k)
            end
        end
    elseif n == 1 then
        local s = cr[1]
        return checked_color_pair(f_gray,s,s)
    else
        local c = cr[1]
        local m = cr[2]
        local y = cr[3]
        local k = cr[4]
        if n == 3 then
            if c == m and m == y then
                k, c, m, y = 1 - c, 0, 0, 0
            else
                c, m, y, k = rgbtocmyk(c,m,y)
            end
        end
        return checked_color_pair(f_cmyk,c,m,y,k,c,m,y,k)
    end
end

function models.gray(cr)
    local n = #cr
    local s = 0
    if n == 0 then
        return checked_color_pair()
    elseif n == 4 then
        s = cmyktogray(cr[1],cr[2],cr[3],cr[4])
    elseif n == 3 then
        s = rgbtogray(cr[1],cr[2],cr[3])
    else
        s = cr[1]
    end
    return checked_color_pair(f_gray,s,s)
end

models[1] = models.all
models[2] = models.gray
models[3] = models.rgb
models[4] = models.cmyk

setmetatableindex(models, function(t,k)
    local v = models.gray
    t[k] = v
    return v
end)

local function colorconverter(cs)
    return models[outercolormodel](cs)
end

local factor = 65536*(7227/7200)

implement {
    name       = "mpsetsxsy",
    arguments  = { "dimen", "dimen", "dimen" },
    actions    = function(wd,ht,dp)
        local hd = ht + dp
        setmacro("sx",wd ~= 0 and factor/wd or 0)
        setmacro("sy",hd ~= 0 and factor/hd or 0)
    end
}

local function sxsy(wd,ht,dp) -- helper for text
    local hd = ht + dp
    return (wd ~= 0 and factor/wd) or 0, (hd ~= 0 and factor/hd) or 0
end

metapost.sxsy = sxsy

-- for stock mp we need to declare the booleans first

local do_begin_fig = "; beginfig(1) ; "
local do_end_fig   = "; endfig ;"
local do_safeguard = ";"

function metapost.preparetextextsdata()
    local textexts  = top.textexts
    local collected = { }
    for k, data in sortedhash(top.texdata) do -- sort is nicer in trace
        local texorder = data.texorder
        for n=1,#texorder do
            local box = textexts[texorder[n]]
            if box then
                collected[n] = box
            else
                break
            end
        end
    end
    mp.mf_tt_initialize(collected)
end

local runmetapost = metapost.run

local function checkaskedfig(askedfig) -- return askedfig, wrappit
    if not askedfig then
        return "direct", true
    elseif askedfig == "all" then
        return "all", false
    elseif askedfig == "direct" then
        return "all", true
    else
        askedfig = tonumber(askedfig)
        if askedfig then
            return askedfig, false
        else
            return "direct", true
        end
    end
end

local function extrapass()
    if trace_runs then
        report_metapost("second run of job %s, asked figure %a",top.nofruns,top.askedfig)
    end
    metapost.preparetextextsdata()
    runmetapost {
        mpx         = top.mpx,
        askedfig    = top.askedfig,
        incontext   = true,
        data        = {
            top.wrappit and do_begin_fig or "",
            no_trial_run,
            top.initializations,
            do_safeguard,
            top.data,
            top.wrappit and do_end_fig or "",
        },
    }
end

-- This one is called from the \TEX\ end so the specification is different
-- from the specification to metapost,run cum suis! The definitions and
-- extension used to be handled here but are now delegated to the format
-- initializers because we need to accumulate them for nested instances (a
-- side effect of going single pass).

function metapost.graphic_base_pass(specification)
    local mpx             = specification.mpx -- mandate
    local top             = startjob(true,"base",mpx)
    local data            = specification.data or ""
    local inclusions      = specification.inclusions or ""
    local initializations = specification.initializations or ""
    local askedfig,
          wrappit         = checkaskedfig(specification.figure)
    nofruns               = nofruns + 1
    top.askedfig          = askedfig
    top.wrappit           = wrappit
    top.nofruns           = nofruns
    metapost.namespace    = specification.namespace or ""
    top.mpx               = mpx
    top.data              = data
    top.initializations   = initializations
    if trace_runs then
        report_metapost("running job %s, asked figure %a",nofruns,askedfig)
    end
    runmetapost {
        mpx         = mpx,
        askedfig    = askedfig,
        incontext   = true,
        data        = {
            inclusions,
            wrappit and do_begin_fig or "",
            initializations,
            do_safeguard,
            data,
            wrappit and do_end_fig or "",
        },
    }
    context(stopjob)
end

local function oldschool(mpx, data, trial_run, flusher, was_multi_pass, is_extra_pass, askedfig, incontext)
    metapost.process {
        mpx        = mpx,
        flusher    = flusher,
        askedfig   = askedfig,
        useplugins = incontext,
        incontext  = incontext,
        data       = data,
    }
end

function metapost.process(specification,...)
    if type(specification) ~= "table" then
        oldschool(specification,...)
    else
        startjob(specification.incontext or specification.useplugins,"process",false)
        runmetapost(specification)
        stopjob()
    end
end

-- -- the new plugin handler -- --

local sequencers       = utilities.sequencers
local appendgroup      = sequencers.appendgroup
local appendaction     = sequencers.appendaction

local resetteractions  = sequencers.new { arguments = "t" }
local processoractions = sequencers.new { arguments = "object,prescript,before,after" }

appendgroup(resetteractions, "system")
appendgroup(processoractions,"system")

-- later entries come first

local scriptsplitter = Ct ( Ct (
    C((1-S("= "))^1) * S("= ")^1 * C((1-S("\n\r"))^0) * S("\n\r")^0
)^0 )

local function splitprescript(script)
    local hash = lpegmatch(scriptsplitter,script)
    for i=#hash,1,-1 do
        local h = hash[i]
        if h == "reset" then
            for k, v in next, hash do
                if type(k) ~= "number" then
                    hash[k] = nil
                end
            end
        else
            hash[h[1]] = h[2]
        end
    end
    if trace_scripts then
        report_scripts(table.serialize(hash,"prescript"))
    end
    return hash
end

metapost.splitprescript = splitprescript

-- -- not used:
--
-- local function splitpostscript(script)
--     local hash = lpegmatch(scriptsplitter,script)
--     for i=1,#hash do
--         local h = hash[i]
--         hash[h[1]] = h[2]
--     end
--     if trace_scripts then
--         report_scripts(table.serialize(hash,"postscript"))
--     end
--     return hash
-- end

function metapost.pluginactions(what,t,flushfigure) -- before/after object, depending on what
    if top and top.plugmode then -- hm, what about other features
        for i=1,#what do
            local wi = what[i]
            if type(wi) == "function" then
                -- assume injection
                flushfigure(t) -- to be checked: too many 0 g 0 G
                t = { }
                wi()
            else
                t[#t+1] = wi
            end
        end
        return t
    end
end

function metapost.resetplugins(t) -- intialize plugins, before figure
    if top and top.plugmode then
        outercolormodel = colors.currentmodel() -- currently overloads the one set at the tex end
        resetteractions.runner(t)
    end
end

function metapost.processplugins(object) -- each object (second pass)
    if top and top.plugmode then
        local prescript = object.prescript   -- specifications
        if prescript and #prescript > 0 then
            local before = { }
            local after = { }
            processoractions.runner(object,splitprescript(prescript) or { },before,after)
            return #before > 0 and before, #after > 0 and after
        else
            local c = object.color
            if c and #c > 0 then
                local b, a = colorconverter(c)
                return { b }, { a }
            end
        end
    end
end

-- helpers

local basepoints = number.dimenfactors["bp"]

local function cm(object)
    local op = object.path
    if op then
        local first  = op[1]
        local second = op[2]
        local fourth = op[4]
        if fourth then
            local tx = first.x_coord
            local ty = first.y_coord
            local sx = second.x_coord - tx
            local sy = fourth.y_coord - ty
            local rx = second.y_coord - ty
            local ry = fourth.x_coord - tx
            if sx == 0 then sx = 0.00001 end
            if sy == 0 then sy = 0.00001 end
            return sx, rx, ry, sy, tx, ty
        end
    end
    return 1, 0, 0, 1, 0, 0 -- weird case
end

metapost.cm = cm

-- color

local function cl_reset(t)
    t[#t+1] = metapost.colorinitializer() -- only color
end

-- text

local tx_reset, tx_process  do

    local eol      = S("\n\r")^1
    local cleaner  = Cs((P("@@")/"@" + P("@")/"%%" + P(1))^0)
    local splitter = Ct(
        ( (
            P("s:") * C((1-eol)^1)
          + P("n:") *  ((1-eol)^1/tonumber)
          + P("b:") *  ((1-eol)^1/toboolean)
        ) * eol^0 )^0)

    local function applyformat(s)
        local t = lpegmatch(splitter,s)
        if #t == 1 then
            return s
        else
            local f = lpegmatch(cleaner,t[1])
            return formatters[f](unpack(t,2))
        end
    end

    local fmt = formatters["%s %s %s % t"]
    ----- pat = tsplitat(":")
    local pat = lpeg.tsplitter(":",tonumber) -- so that %F can do its work

    local f_gray_yes = formatters["s=%.3N,a=%i,t=%.3N"]
    local f_gray_nop = formatters["s=%.3N"]
    local f_rgb_yes  = formatters["r=%.3N,g=%.3N,b=%.3N,a=%.3N,t=%.3N"]
    local f_rgb_nop  = formatters["r=%.3N,g=%.3N,b=%.3N"]
    local f_cmyk_yes = formatters["c=%.3N,m=%.3N,y=%.3N,k=%.3N,a=%.3N,t=%.3N"]
    local f_cmyk_nop = formatters["c=%.3N,m=%.3N,y=%.3N,k=%.3N"]

    local ctx_MPLIBsetNtext = context.MPLIBsetNtextX
    local ctx_MPLIBsetCtext = context.MPLIBsetCtextX
    local ctx_MPLIBsettext  = context.MPLIBsettextX

    local bp = number.dimenfactors.bp

    local mp_index  = 0
    local mp_target = 0
    local mp_c      = nil
    local mp_a      = nil
    local mp_t      = nil

    local function processtext()
        local mp_text = top.texstrings[mp_index]
        if not mp_text then
            report_textexts("missing text for index %a",mp_index)
        elseif not mp_c then
            ctx_MPLIBsetNtext(mp_target,mp_text)
        elseif #mp_c == 1 then
            if mp_a and mp_t then
                ctx_MPLIBsetCtext(mp_target,f_gray_yes(mp_c[1],mp_a,mp_t),mp_text)
            else
                ctx_MPLIBsetCtext(mp_target,f_gray_nop(mp_c[1]),mp_text)
            end
        elseif #mp_c == 3 then
            if mp_a and mp_t then
                ctx_MPLIBsetCtext(mp_target,f_rgb_yes(mp_c[1],mp_c[2],mp_c[3],mp_a,mp_t),mp_text)
            else
                ctx_MPLIBsetCtext(mp_target,f_rgb_nop(mp_c[1],mp_c[2],mp_c[3]),mp_text)
            end
        elseif #mp_c == 4 then
            if mp_a and mp_t then
                ctx_MPLIBsetCtext(mp_target,f_cmyk_yes(mp_c[1],mp_c[2],mp_c[3],mp_c[4],mp_a,mp_t),mp_text)
            else
                ctx_MPLIBsetCtext(mp_target,f_cmyk_nop(mp_c[1],mp_c[2],mp_c[3],mp_c[4]),mp_text)
            end
        else
            -- can't happen
            ctx_MPLIBsetNtext(mp_target,mp_text)
        end
    end

    local madetext = nil

    function mp.mf_some_text(index,str)
        mp_target = index
        mp_index  = index
        mp_c      = nil
        mp_a      = nil
        mp_t      = nil
        top.texstrings[mp_index] = str
        tex.runtoks("mptexttoks")
        local box = textakebox("mptextbox")
        top.textexts[mp_target] = box
        mp.triplet(bp*box.width,bp*box.height,bp*box.depth)
        madetext = nil
    end

    function mp.mf_made_text(index)
        mp.mf_some_text(index,madetext)
    end

    -- a label can be anything, also something mp doesn't like in strings
    -- so we return an index instead

    function metapost.processing()
        return top and true or false
    end

    function metapost.remaptext(replacement)
        if top then
            local mapstrings = top.mapstrings
            local mapindices = top.mapindices
            local label      = replacement.label
            local index      = 0
            if label then
                local found = mapstrings[label]
                if found then
                    setmetatableindex(found,replacement)
                    index = found.index
                else
                    index = #mapindices + 1
                    replacement.index = index
                    mapindices[index] = replacement
                    mapstrings[label] = replacement
                end
            end
            return index
        else
            return 0
        end
    end

    function metapost.remappedtext(what)
        return top and (top.mapstrings[what] or top.mapindices[tonumber(what)])
    end

    function mp.mf_map_move(index)
        mp.triplet(top.mapmoves[index])
    end

    function mp.mf_map_text(index,str)
        local map = top.mapindices[tonumber(str)]
        if type(map) == "table" then
            local text     = map.text
            local overload = map.overload
            local offset   = 0
            local width    = 0
            local where    = nil
            --
            mp_index = index
            -- the image text
            if overload then
                top.texstrings[mp_index] = map.template or map.label or "error"
                tex.runtoks("mptexttoks")
                local box = textakebox("mptextbox") or new_hlist()
                width = bp * box.width
                where = overload.where
            end
            -- the real text
            top.texstrings[mp_index] = overload and overload.text or text or "error"
            tex.runtoks("mptexttoks")
            local box = textakebox("mptextbox") or new_hlist()
            local twd = bp * box.width
            local tht = bp * box.height
            local tdp = bp * box.depth
            -- the check
            if where then
                local scale = 1 --  / (map.scale or 1)
                if where == "l" or where == "left" then
                    offset = scale * (twd - width)
                elseif where == "m" or where == "middle" then
                    offset = scale * (twd - width) / 2
                end
            end
            -- the result
            top.textexts[mp_index] = box
            top.mapmoves[mp_index] = { offset, map.dx or 0, map.dy or 0 }
            --
            mp.triplet(twd,tht,tdp)
            madetext = nil
            return
        else
            map = type(map) == "string" and map or str
            return mp.mf_some_text(index,context.escape(map) or map)
        end
    end

    -- This is a bit messy. In regular metapost it's a kind of immediate replacement
    -- so embedded btex ... etex is not really working as one would expect. We now have
    -- a mix: it's immediate when we are at the outer level (rawmadetext) and indirect
    -- (with the danger of stuff that doesn't work well in strings) when we are for
    -- instance in a macro definition (rawtextext (pass back string)) ... of course one
    -- should use textext so this is just a catch. When not in lmtx it's never immediate.

    local reported  = false
    local awayswrap = CONTEXTLMTXMODE <= 1

    function metapost.maketext(s,mode)
        if not reported then
            reported = true
            report_metapost("use 'textext(.....)' instead of 'btex ..... etex'")
        end
        if mode and mode == 1 then
            if trace_btexetex then
                report_metapost("ignoring verbatimtex: [[%s]]",s)
            end
        elseif alwayswrap then
            if trace_btexetex then
                report_metapost("rewrapping btex ... etex [[%s]]",s)
            end
            return 'rawtextext("' .. gsub(s,'"','"&ditto&"') .. '")' -- nullpicture
        elseif metapost.currentmpxstatus() ~= 0 then
            if trace_btexetex then
                report_metapost("rewrapping btex ... etex at the outer level [[%s]]",s)
            end
            return 'rawtextext("' .. gsub(s,'"','"&ditto&"') .. '")' -- nullpicture
        else
            if trace_btexetex then
                report_metapost("handling btex ... etex: [[%s]]",s)
            end
         -- madetext = utilities.strings.collapse(s)
            madetext = s
            return "rawmadetext" -- is assuming immediate processing
        end
    end

    function mp.mf_formatted_text(index,fmt,...)
        local t = { }
        for i=1,select("#",...) do
            local ti = select(i,...)
            if type(ti) ~= "table" then
                t[#t+1] = ti
            end
        end
        local f = lpegmatch(cleaner,fmt)
        local s = formatters[f](unpack(t)) or ""
        mp.mf_some_text(index,s)
    end

    interfaces.implement {
        name    = "mptexttoks",
        actions = processtext,
    }

    tx_reset = function()
        if top then
            top.texhash = { }
            top.texlast = 0
        end
    end

    tx_process = function(object,prescript,before,after)
        local data  = top.texdata[metapost.properties.number] -- the current figure number, messy
        local index = tonumber(prescript.tx_index)
        if index then
            if trace_textexts then
                report_textexts("using index %a",index)
            end
            --
            mp_c = object.color
            if #mp_c == 0 then
                local txc = prescript.tx_color
                if txc then
                    mp_c = lpegmatch(pat,txc)
                end
            end
            mp_a = tonumber(prescript.tr_alternative)
            mp_t = tonumber(prescript.tr_transparency)
            --
            mp_index  = index
            mp_target = top.texlast - 1
            top.texlast = mp_target
            --
            local mp_text = top.texstrings[mp_index]
            local mp_hash = prescript.tx_cache
            local box
            if mp_hash == "no" then
                tex.runtoks("mptexttoks")
                box = textakebox("mptextbox")
            else
                local cache = data.texhash
                if mp_hash then
                    mp_hash = tonumber(mp_hash)
                end
                if mp_hash then
                    local extradata = top.extradata
                    if extradata then
                        cache = extradata.globalcache
                        if not cache then
                            cache = { }
                            extradata.globalcache = cache
                        end
                        if trace_runs then
                            if cache[mp_hash] then
                                report_textexts("reusing global entry %i",mp_hash)
                            else
                                report_textexts("storing global entry %i",mp_hash)
                            end
                        end
                    else
                        mp_hash = nil
                    end
                end
                if not mp_hash then
                    mp_hash = fmt(mp_text,mp_a or "-",mp_t or "-",mp_c or "-")
                end
                box = cache[mp_hash]
                if box then
                    box = copy_list(box)
                else
                    tex.runtoks("mptexttoks")
                    box = textakebox("mptextbox")
                    cache[mp_hash] = box
                end
            end
            top.textexts[mp_target] = box
            --
            if box then
                -- we need to freeze the variables outside the function
                local sx, rx, ry, sy, tx, ty = cm(object)
                local target = mp_target
                before[#before+1] = function()
                    context.MPLIBgettextscaledcm(target,
                        f_f(sx), -- bah ... %s no longer checks
                        f_f(rx), -- bah ... %s no longer checks
                        f_f(ry), -- bah ... %s no longer checks
                        f_f(sy), -- bah ... %s no longer checks
                        f_f(tx), -- bah ... %s no longer checks
                        f_f(ty), -- bah ... %s no longer checks
                        sxsy(box.width,box.height,box.depth))
                end
            else
                before[#before+1] = function()
                    report_textexts("unknown %s",index)
                end
            end
            if not trace_textexts then
                object.path = false -- else: keep it
            end
            object.color   = false
            object.grouped = true
            object.istext  = true
        end
    end

end

-- we could probably redo normal textexts in the next way but as it's rather optimized
-- we keep away from that (at least for now)

local function bx_process(object,prescript,before,after)
    local bx_category = prescript.bx_category
    local bx_name     = prescript.bx_name
    if bx_category and bx_name then
        if trace_textexts then
            report_textexts("category %a, name %a",bx_category,bx_name)
        end
        local sx, rx, ry, sy, tx, ty = cm(object) -- needs to be frozen outside the function
        local wd, ht, dp = nodes.boxes.dimensions(bx_category,bx_name)
        before[#before+1] = function()
            context.MPLIBgetboxscaledcm(bx_category,bx_name,
                f_f(sx), -- bah ... %s no longer checks
                f_f(rx), -- bah ... %s no longer checks
                f_f(ry), -- bah ... %s no longer checks
                f_f(sy), -- bah ... %s no longer checks
                f_f(tx), -- bah ... %s no longer checks
                f_f(ty), -- bah ... %s no longer checks
                sxsy(wd,ht,dp))
        end
        if not trace_textexts then
            object.path = false -- else: keep it
        end
        object.color   = false
        object.grouped = true
        object.istext  = true
    end
end

-- graphics (we use the given index because pictures can be reused)


local gt_reset, gt_process do

    local graphics = { }


    local mp_index = 0
    local mp_str   = ""

    function mp.mf_graphic_text(index,str)
        if not graphics[index] then
            mp_index = index
            mp_str   = str
            tex.runtoks("mpgraphictexttoks")
        end
    end

    interfaces.implement {
        name    = "mpgraphictexttoks",
        actions = function()
            context.MPLIBgraphictext(mp_index,mp_str)
        end,
    }

end

-- shades

local function sh_process(object,prescript,before,after)
    local sh_type = prescript.sh_type
    if sh_type then
        nofshades = nofshades + 1
        local domain    = lpegmatch(domainsplitter,prescript.sh_domain   or "0 1")
        local centera   = lpegmatch(centersplitter,prescript.sh_center_a or "0 0")
        local centerb   = lpegmatch(centersplitter,prescript.sh_center_b or "0 0")
        local transform = toboolean(prescript.sh_transform or "yes",true)
        -- compensation for scaling
        local sx = 1
        local sy = 1
        local sr = 1
        local dx = 0
        local dy = 0
        if transform then
            local first = lpegmatch(coordinatesplitter,prescript.sh_first or "0 0")
            local setx  = lpegmatch(coordinatesplitter,prescript.sh_set_x or "0 0")
            local sety  = lpegmatch(coordinatesplitter,prescript.sh_set_y or "0 0")

            local x = setx[1] -- point that has different x
            local y = sety[1] -- point that has different y

            if x == 0 or y == 0 then
                -- forget about it
            else
                local path   = object.path
                local path1x = path[1].x_coord
                local path1y = path[1].y_coord
                local path2x = path[x].x_coord
                local path2y = path[y].y_coord

                local dxa = path2x - path1x
                local dya = path2y - path1y
                local dxb = setx[2] - first[1]
                local dyb = sety[2] - first[2]

                if dxa == 0 or dya == 0 or dxb == 0 or dyb == 0 then
                    -- forget about it
                else
                    sx = dxa / dxb ; if sx < 0 then sx = - sx end -- yes or no
                    sy = dya / dyb ; if sy < 0 then sy = - sy end -- yes or no

                    sr = sqrt(sx^2 + sy^2)

                    dx = path1x - sx*first[1]
                    dy = path1y - sy*first[2]
                end
            end
        end

        local steps      = tonumber(prescript.sh_step) or 1
        local sh_color_a = prescript.sh_color_a_1 or prescript.sh_color_a or "1"
        local sh_color_b = prescript.sh_color_b_1 or prescript.sh_color_b or "1" -- sh_color_b_<sh_steps>
        local ca, cb, colorspace, name, model, separation, fractions
        if prescript.sh_color == "into" and prescript.sp_name then
            -- some spotcolor
            local value_a, components_a, fractions_a, name_a
            local value_b, components_b, fractions_b, name_b
            for i=1,#prescript do
                -- { "sh_color_a", "1" },
                -- { "sh_color", "into" },
                -- { "sh_radius_b", "0" },
                -- { "sh_radius_a", "141.73225" },
                -- { "sh_center_b", "425.19676 141.73225" },
                -- { "sh_center_a", "425.19676 0" },
                -- { "sh_factor", "1" },
                local tag = prescript[i][1]
                if not name_a and tag == "sh_color_a" then
                    value_a      = prescript[i-5][2]
                    components_a = prescript[i-4][2]
                    fractions_a  = prescript[i-3][2]
                    name_a       = prescript[i-2][2]
                elseif not name_b and tag == "sh_color_b" then
                    value_b      = prescript[i-5][2]
                    components_b = prescript[i-4][2]
                    fractions_b  = prescript[i-3][2]
                    name_b       = prescript[i-2][2]
                end
                if name_a and name_b then
                    break
                end
            end
            ca, cb, separation, name = checkandconvertspot(
                name_a,fractions_a,components_a,value_a,
                name_b,fractions_b,components_b,value_b
            )
        else
            local colora = lpegmatch(colorsplitter,sh_color_a)
            local colorb = lpegmatch(colorsplitter,sh_color_b)
            ca, cb, colorspace, name, model = checkandconvert(colora,colorb)
            -- test:
            if steps > 1 then
                ca = { ca }
                cb = { cb }
                fractions = { tonumber(prescript[formatters["sh_fraction_%i"](1)]) or 0 }
                for i=2,steps do
                    local colora = lpegmatch(colorsplitter,prescript[formatters["sh_color_a_%i"](i)])
                    local colorb = lpegmatch(colorsplitter,prescript[formatters["sh_color_b_%i"](i)])
                    ca[i], cb[i] = checkandconvert(colora,colorb,model)
                    fractions[i] = tonumber(prescript[formatters["sh_fraction_%i"](i)]) or (i/steps)
                end
            end
        end
        if not ca or not cb then
            ca, cb, colorspace, name = checkandconvert()
            steps = 1
        end
        if sh_type == "linear" then
            local coordinates = { dx + sx*centera[1], dy + sy*centera[2], dx + sx*centerb[1], dy + sy*centerb[2] }
            lpdf.linearshade(name,domain,ca,cb,1,colorspace,coordinates,separation,steps>1 and steps,fractions) -- backend specific (will be renamed)
        elseif sh_type == "circular" then
            local factor  = tonumber(prescript.sh_factor) or 1
            local radiusa = factor * tonumber(prescript.sh_radius_a)
            local radiusb = factor * tonumber(prescript.sh_radius_b)
            local coordinates = { dx + sx*centera[1], dy + sy*centera[2], sr*radiusa, dx + sx*centerb[1], dy + sy*centerb[2], sr*radiusb }
            lpdf.circularshade(name,domain,ca,cb,1,colorspace,coordinates,separation,steps>1 and steps,fractions) -- backend specific (will be renamed)
        else
            -- fatal error
        end
        before[#before+1] = "q /Pattern cs"
        after [#after+1]  = formatters["W n /%s sh Q"](name)
        -- false, not nil, else mt triggered
        object.colored = false -- hm, not object.color ?
        object.type    = false
        object.grouped = true
    end
end

-- bitmaps

local function bm_process(object,prescript,before,after)
    local bm_xresolution = prescript.bm_xresolution
    if bm_xresolution then
        before[#before+1] = f_cm_b(cm(object))
        before[#before+1] = function()
            figures.bitmapimage {
                xresolution = tonumber(bm_xresolution),
                yresolution = tonumber(prescript.bm_yresolution),
                width       = 1/basepoints,
                height      = 1/basepoints,
                data        = object.postscript
            }
        end
        before[#before+1] = s_cm_e
        object.path = false
        object.color = false
        object.grouped = true
    end
end

-- positions

local function ps_process(object,prescript,before,after)
    local ps_label = prescript.ps_label
    if ps_label then
        local op     = object.path
        local first  = op[1]
        local third  = op[3]
        local x      = first.x_coord
        local y      = first.y_coord
        local w      = third.x_coord - x
        local h      = third.y_coord - y
        local properties = metapost.properties
        x = x - properties.llx
        y = properties.ury - y
        before[#before+1] = function()
            context.MPLIBpositionwhd(ps_label,x,y,w,h)
        end
        object.path = false
    end
end

-- figures

-- local sx, rx, ry, sy, tx, ty = cm(object)
-- sxsy(box.width,box.height,box.depth))

function mp.mf_external_figure(filename)
    local f = figures.getinfo(filename)
    local w = 0
    local h = 0
    if f then
        local u = f.used
        if u and u.fullname then
            w = u.width or 0
            h = u.height or 0
        end
    else
        report_metapost("external figure %a not found",filename)
    end
    mp.triplet(w/65536,h/65536,0)
end

local function fg_process(object,prescript,before,after)
    local fg_name = prescript.fg_name
    if fg_name then
        before[#before+1] = f_cm_b(cm(object)) -- beware: does not use the cm stack
        before[#before+1] = function()
            context.MPLIBfigure(fg_name,prescript.fg_mask or "")
        end
        before[#before+1] = s_cm_e
        object.path = false
        object.grouped = true
    end
end

-- color and transparency

local value = Cs ( (
    (Carg(1) * C((1-P(","))^1)) / function(a,b) return f_f3(a * tonumber(b)) end
  + P(","))^1
)

-- should be codeinjections

local t_list = attributes.list[attributes.private('transparency')]
local c_list = attributes.list[attributes.private('color')]

local remappers = {
    [1] = formatters["s=%s"],
    [3] = formatters["r=%s,g=%s,b=%s"],
    [4] = formatters["c=%s,m=%s,y=%s,k=%s"],
}

local processlast = 0
local processhash = setmetatableindex(function(t,k)
    processlast = processlast + 1
    local v = formatters["mp_%s"](processlast)
    defineprocesscolor(v,k,true,true)
    t[k] = v
    return v
end)

local function checked_transparency(alternative,transparency,before,after)
    alternative  = tonumber(alternative)  or 1
    transparency = tonumber(transparency) or 0
    before[#before+1] = formatters["/Tr%s gs"](registertransparency(nil,alternative,transparency,true))
    after [#after +1] = "/Tr0 gs" -- outertransparency
end

local function tr_process(object,prescript,before,after)
    -- before can be shortcut to t
    local tr_alternative = prescript.tr_alternative
    if tr_alternative then
        checked_transparency(tr_alternative,prescript.tr_transparency,before,after)
    end
    local cs = object.color
    if cs and #cs > 0 then
        local c_b, c_a
        local sp_type = prescript.sp_type
        if not sp_type then
            c_b, c_a = colorconverter(cs)
        else
            local sp_name = prescript.sp_name or "black"
            if sp_type == "spot" then
                local sp_value      = prescript.sp_value or "1"
                local components    = split(sp_value,":")
                local specification = remappers[#components]
                if specification then
                    specification = specification(unpack(components))
                else
                    specification = "s=0"
                end
                local sp_spec = processhash[specification]
                definespotcolor(sp_name,sp_spec,"p=1",true)
                sp_type = "named"
            elseif sp_type == "multitone" then -- (fractions of a multitone) don't work well in mupdf
                local sp_value = prescript.sp_value or "1"
                local sp_specs = { }
                local sp_list  = split(sp_value," ")
                for i=1,#sp_list do
                    local sp_value      = sp_list[i]
                    local components    = split(sp_value,":")
                    local specification = remappers[#components]
                    if specification then
                        specification = specification(unpack(components))
                    else
                        specification = "s=0"
                    end
                    local sp_spec = processhash[specification]
                    sp_specs[i] = formatters["%s=1"](sp_spec)
                end
                sp_specs = concat(sp_specs,",")
                definemultitonecolor(sp_name,sp_specs,"","")
                sp_type = "named"
            end
            if sp_type == "named" then
                -- we might move this to another namespace .. also, named can be a spotcolor
                -- so we need to check for that too ... also we need to resolve indirect
                -- colors so we might need the second pass for this (draw dots with \MPcolor)
                if not tr_alternative then
                    -- todo: sp_name is not yet registered at this time
                    local t = t_list[sp_name] -- string or attribute
                    local v = t and transparencyvalue(t)
                    if v then
                        checked_transparency(v[1],v[2],before,after)
                    end
                end
                local c = c_list[sp_name] -- string or attribute
                local v = c and colorvalue(c)
                if v then
                    -- all=1 gray=2 rgb=3 cmyk=4
                    local colorspace = v[1]
                    local factor     = cs[1]
                    if colorspace == 2 then
                        local s = factor * v[2]
                        c_b, c_a = checked_color_pair(f_gray,s,s)
                    elseif colorspace == 3 then
                        local r = factor * v[3]
                        local g = factor * v[4]
                        local b = factor * v[5]
                        c_b, c_a = checked_color_pair(f_rgb,r,g,b,r,g,b)
                    elseif colorspace == 4 or colorspace == 1 then
                        local c = factor * v[6]
                        local m = factor * v[7]
                        local y = factor * v[8]
                        local k = factor * v[9]
                        c_b, c_a = checked_color_pair(f_cmyk,c,m,y,k,c,m,y,k)
                    elseif colorspace == 5 then
                        -- not all viewers show the fractions ok
                        local name  = v[10]
                        local value = split(v[13],",")
                        if factor ~= 1 then
                            for i=1,#value do
                                value[i] = f_scn(factor * (tonumber(value[i]) or 1))
                            end
                        end
                        value = concat(value," ")
                        c_b, c_a = checked_color_pair(f_spot,name,name,value,value)
                    else
                        local s = factor *v[2]
                        c_b, c_a = checked_color_pair(f_gray,s,s)
                    end
                end
            end
        end
        if c_a and c_b then
            before[#before+1] = c_b
            after [#after +1] = c_a
        end
    end
end

-- layers (nasty: we need to keep the 'grouping' right

local function la_process(object,prescript,before,after)
    local la_name = prescript.la_name
    if la_name then
        before[#before+1] = backends.codeinjections.startlayer(la_name)
        insert(after,1,backends.codeinjections.stoplayer())
    end
end

-- groups

local function gr_process(object,prescript,before,after)
    local gr_state = prescript.gr_state
    if not gr_state then
       return
    elseif gr_state == "start" then
        local gr_type = utilities.parsers.settings_to_set(prescript.gr_type)
        local path = object.path
        local p1 = path[1]
        local p2 = path[2]
        local p3 = path[3]
        local p4 = path[4]
        local llx = min(p1.x_coord,p2.x_coord,p3.x_coord,p4.x_coord)
        local lly = min(p1.y_coord,p2.y_coord,p3.y_coord,p4.y_coord)
        local urx = max(p1.x_coord,p2.x_coord,p3.x_coord,p4.x_coord)
        local ury = max(p1.y_coord,p2.y_coord,p3.y_coord,p4.y_coord)
        before[#before+1] = function()
            context.MPLIBstartgroup(
                gr_type.isolated and 1 or 0,
                gr_type.knockout and 1 or 0,
                llx, lly, urx, ury
            )
        end
    elseif gr_state == "stop" then
        after[#after+1] = function()
            context.MPLIBstopgroup()
        end
    end
    object.path    = false
    object.color   = false
    object.grouped = true
end

-- outlines

local ot_reset, ot_process do

    local outlinetexts = { } -- also in top data

    ot_reset = function ()
        outlinetexts = { }
    end

    local mp_index = 0
    local mp_kind  = ""
    local mp_str   = ""

    function mp.mf_outline_text(index,str,kind)
        if not outlinetexts[index] then
            mp_index = index
            mp_kind  = kind
            mp_str   = str
            tex.runtoks("mpoutlinetoks")
        end
    end

    interfaces.implement {
        name    = "mpoutlinetoks",
        actions = function()
            context.MPLIBoutlinetext(mp_index,mp_kind,mp_str)
        end,
    }

    implement {
        name      = "MPLIBconvertoutlinetext",
        arguments = { "integer", "string", "integer" },
        actions   = function(index,kind,box)
            local boxtomp = fonts.metapost.boxtomp
            if boxtomp then
                outlinetexts[index] = boxtomp(box,kind)
            else
                outlinetexts[index] = ""
            end
        end
    }

    function mp.mf_get_outline_text(index) -- maybe we need a more private namespace
        mp.print(outlinetexts[index] or "draw origin;")
    end

end

-- mf_object=<string>

local p1      = P("mf_object=")
local p2      = lpeg.patterns.eol * p1
local pattern = (1-p2)^0 * p2 + p1

function metapost.isobject(str)
    return pattern and str ~= "" and lpegmatch(p,str) and true or false
end

local function installplugin(specification)
    local reset   = specification.reset
    local process = specification.process
    local object  = specification.object
    if reset then
        appendaction(resetteractions,"system",reset)
    end
    if process then
        appendaction(processoractions,"system",process)
    end
end

metapost.installplugin = installplugin

-- definitions

installplugin { name = "outline",      reset = ot_reset, process = ot_process }
installplugin { name = "color",        reset = cl_reset, process = cl_process }
installplugin { name = "text",         reset = tx_reset, process = tx_process }
installplugin { name = "group",        reset = gr_reset, process = gr_process }
installplugin { name = "graphictext",  reset = gt_reset, process = gt_process }
installplugin { name = "shade",        reset = sh_reset, process = sh_process }
installplugin { name = "bitmap",       reset = bm_reset, process = bm_process }
installplugin { name = "box",          reset = bx_reset, process = bx_process }
installplugin { name = "position",     reset = ps_reset, process = ps_process }
installplugin { name = "figure",       reset = fg_reset, process = fg_process }
installplugin { name = "layer",        reset = la_reset, process = la_process }
installplugin { name = "transparency", reset = tr_reset, process = tr_process }
