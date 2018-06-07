if not modules then modules = { } end modules ['mlib-pps'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local format, gmatch, match, split = string.format, string.gmatch, string.match, string.split
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

----- texgetbox            = tex.getbox
local texsetbox            = tex.setbox
local textakebox           = tex.takebox -- or: nodes.takebox
local copy_list            = node.copy_list
local flush_list           = node.flush_list
local setmetatableindex    = table.setmetatableindex
local sortedhash           = table.sortedhash

local starttiming          = statistics.starttiming
local stoptiming           = statistics.stoptiming

local trace_runs           = false  trackers.register("metapost.runs",     function(v) trace_runs     = v end)
local trace_textexts       = false  trackers.register("metapost.textexts", function(v) trace_textexts = v end)
local trace_scripts        = false  trackers.register("metapost.scripts",  function(v) trace_scripts  = v end)

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

metapost.makempy           = metapost.makempy or { nofconverted = 0 }
local makempy              = metapost.makempy

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

local f_f     = formatters["%F"]
local f_f3    = formatters["%.3F"]

local f_gray  = formatters["%.3F g %.3F G"]
local f_rgb   = formatters["%.3F %.3F %.3F rg %.3F %.3F %.3F RG"]
local f_cmyk  = formatters["%.3F %.3F %.3F %.3F k %.3F %.3F %.3F %.3F K"]
local f_cm    = formatters["q %F %F %F %F %F %F cm"]
local f_shade = formatters["MpSh%s"]

local f_spot  = formatters["/%s cs /%s CS %s SCN %s scn"]

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
                local a, b = 1-ca[1], 1-cb[1]
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

local function startjob(plugmode,kind)
    insert(stack,top)
    top = {
        textexts   = { },                          -- all boxes, optionally with a different color
        texstrings = { },
        texlast    = 0,
        texdata    = setmetatableindex({},preset), -- references to textexts in order or usage
        plugmode   = plugmode,                     -- some day we can then skip all pre/postscripts
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

local settext, gettext

if metapost.use_one_pass then

    settext = function(box,slot,str)
        if top then
         -- if trace_textexts then
         --     report_textexts("getting text %s from box %s",slot,box)
         -- end
            top.textexts[slot] = textakebox(box)
        end
    end

    gettext = function(box,slot)
        if top then
            texsetbox(box,top.textexts[slot])
            top.textexts[slot] = false
         -- if trace_textexts then
         --     report_textexts("putting text %s in box %s",slot,box)
         -- end
        end
    end

else

    settext = function(box,slot,str)
        if top then
         -- if trace_textexts then
         --     report_textexts("getting text %s from box %s",slot,box)
         -- end
            top.textexts[slot] = textakebox(box)
        end
    end

    gettext = function(box,slot)
        if top then
            texsetbox(box,copy_list(top.textexts[slot]))
         -- if trace_textexts then
         --     report_textexts("putting text %s in box %s",slot,box)
         -- end
        end
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
            local r, g, b = cr[1], cr[2], cr[3]
            if r == g and g == b then
                return checked_color_pair(f_gray,r,r)
            else
                return checked_color_pair(f_rgb,r,g,b,r,g,b)
            end
        else
            local c, m, y, k = cr[1], cr[2], cr[3], cr[4]
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
        local r, g, b = cr[1], cr[2], cr[3]
        return checked_color_pair(f_rgb,r,g,b,r,g,b)
    else
        local c, m, y, k = cr[1], cr[2], cr[3], cr[4]
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
            local r, g, b = cr[1], cr[2], cr[3]
            if r == g and g == b then
                return checked_color_pair(f_gray,r,r)
            else
                return checked_color_pair(f_rgb,r,g,b,r,g,b)
            end
        else
            local c, m, y, k = cr[1], cr[2], cr[3], cr[4]
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
        local r, g, b
        if n == 3 then
            r, g, b = cmyktorgb(cr[1],cr[2],cr[3],cr[4])
        else
            r, g, b = cr[1], cr[2], cr[3]
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
            local r, g, b = cr[1], cr[2], cr[3]
            if r == g and g == b then
                return checked_color_pair(f_gray,r,r)
            else
                local c, m, y, k = rgbtocmyk(r,g,b)
                return checked_color_pair(f_cmyk,c,m,y,k,c,m,y,k)
            end
        else
            local c, m, y, k = cr[1], cr[2], cr[3], cr[4]
            if c == m and m == y and y == 0 then
                k = k - 1
                return checked_color_pair(f_gray,k,k)
            else
                return checked_color_pair(f_cmyk,c,m,y,k,c,m,y,k)
            end
        end
    elseif n == 1 then
        local s = cr[1]
        return checked_color_pair(f_gray,s,s)
    else
        local c, m, y, k
        if n == 3 then
            c, m, y, k = rgbtocmyk(cr[1],cr[2],cr[3])
        else
            c, m, y, k = cr[1], cr[2], cr[3], cr[4]
        end
        return checked_color_pair(f_cmyk,c,m,y,k,c,m,y,k)
    end
end

function models.gray(cr)
    local n, s = #cr, 0
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
 -- return models[colors.currentmodel()](cs)
    return models[outercolormodel](cs)
end

local btex      = P("btex")
local etex      = P(" etex")
local vtex      = P("verbatimtex")
local ttex      = P("textext")
local gtex      = P("graphictext")
local multipass = P("forcemultipass")
local spacing   = S(" \n\r\t\v")^0
local dquote    = P('"')

local found, forced = false, false

local function convert(str)
    found = true
    return "rawtextext(\"" .. str .. "\")" -- centered
end
local function ditto(str)
    return "\" & ditto & \""
end
local function register()
    found = true
end
local function force()
    forced = true
end

local texmess = (dquote/ditto + (1 - etex))^0

local function ignore(s)
    report_metapost("ignoring verbatim tex: %s",s)
    return ""
end

-- local parser = P {
--     [1] = Cs((V(2)/register + V(4)/ignore + V(3)/convert + V(5)/force + 1)^0),
--     [2] = ttex + gtex,
--     [3] = btex * spacing * Cs(texmess) * etex,
--     [4] = vtex * spacing * Cs(texmess) * etex,
--     [5] = multipass, -- experimental, only for testing
-- }

-- currently a a one-liner produces less code

-- textext.*(".*") can have "'s but tricky parsing as we can have concatenated strings
-- so this is something for a boring plane or train trip and we might assume proper mp
-- input anyway

local parser = Cs((
    (ttex + gtex)/register
  + (btex * spacing * Cs(texmess) * etex)/convert
  + (vtex * spacing * Cs(texmess) * etex)/ignore
  + 1
)^0)

local checking_enabled = false  directives.register("metapost.checktexts",function(v) checking_enabled = v end)

local function checktexts(str)
    if checking_enabled then
        found, forced = false, false
        return lpegmatch(parser,str), found, forced
    else
        return str
    end
end

metapost.checktexts = checktexts

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

local no_first_run = "boolean mfun_first_run ; mfun_first_run := false ;"
local do_first_run = "boolean mfun_first_run ; mfun_first_run := true ;"
local no_trial_run = "boolean mfun_trial_run ; mfun_trial_run := false ;"
local do_trial_run = "boolean mfun_trial_run ; mfun_trial_run := true ;"
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
    mp.tt_initialize(collected)
end

metapost.intermediate         = metapost.intermediate         or { }
metapost.intermediate.actions = metapost.intermediate.actions or { }

metapost.method = 1 -- 1:dumb 2:clever 3:nothing

if metapost.use_one_pass then

    metapost.method  = 3
    checking_enabled = false

end

-- maybe we can latelua the texts some day

local processmetapost = metapost.process

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
    processmetapost(top.mpx, {
        top.wrappit and do_begin_fig or "",
        no_trial_run,
        top.initializations,
        do_safeguard,
        top.data,
        top.wrappit and do_end_fig or "",
    }, false, nil, false, true, top.askedfig)
end

function metapost.graphic_base_pass(specification) -- name will change (see mlib-ctx.lua)
    local top = startjob(true,"base")
    --
    local mpx             = specification.mpx -- mandate
    local data            = specification.data or ""
    local definitions     = specification.definitions or ""
 -- local extensions      = metapost.getextensions(specification.instance,specification.useextensions)
    local extensions      = specification.extensions or ""
    local inclusions      = specification.inclusions or ""
    local initializations = specification.initializations or ""
    local askedfig        = specification.figure -- no default else no wrapper
    metapost.namespace    = specification.namespace or ""
    --
    local askedfig, wrappit = checkaskedfig(askedfig)
    --
    nofruns      = nofruns + 1
    --
    top.askedfig = askedfig
    top.wrappit  = wrappit
    top.nofruns  = nofruns
    --
    local done_1, done_2, done_3, forced_1, forced_2, forced_3
    if checking_enabled then
        data, done_1, forced_1 = checktexts(data)
        if extensions == "" then
            extensions, done_2, forced_2 = "", false, false
        else
            extensions, done_2, forced_2 = checktexts(extensions)
        end
        if inclusions == "" then
            inclusions, done_3, forced_3 = "", false, false
        else
            inclusions, done_3, forced_3 = checktexts(inclusions)
        end
    end
    top.intermediate     = false
    top.multipass        = false -- no needed here
    top.mpx              = mpx
    top.data             = data
    top.initializations  = initializations
    local method         = metapost.method
    if trace_runs then
        if method == 1 then
            report_metapost("forcing two runs due to library configuration")
        elseif method ~= 2 then
            report_metapost("ignoring extra run due to library configuration")
        elseif not (done_1 or done_2 or done_3) then
            report_metapost("forcing one run only due to analysis")
        elseif done_1 then
            report_metapost("forcing at max two runs due to main code")
        elseif done_2 then
            report_metapost("forcing at max two runs due to extensions")
        else
            report_metapost("forcing at max two runs due to inclusions")
        end
    end
    if method == 1 or (method == 2 and (done_1 or done_2 or done_3)) then
        if trace_runs then
            report_metapost("first run of job %s, asked figure %a",nofruns,askedfig)
        end
     -- first true means: trialrun, second true means: avoid extra run if no multipass
        local flushed = processmetapost(mpx, {
            definitions,
            extensions,
            inclusions,
            wrappit and do_begin_fig or "",
            do_first_run,
            do_trial_run,
            initializations,
            do_safeguard,
            data,
            wrappit and do_end_fig or "",
        }, true, nil, not (forced_1 or forced_2 or forced_3), false, askedfig, true)
        if top.intermediate then
            for _, action in next, metapost.intermediate.actions do
                action()
            end
        end
        if not flushed or not metapost.optimize then
            -- tricky, we can only ask once for objects and therefore
            -- we really need a second run when not optimized
         -- context.MPLIBextrapass(askedfig)
            context(extrapass)
        end
    else
        if trace_runs then
            report_metapost("running job %s, asked figure %a",nofruns,askedfig)
        end
        processmetapost(mpx, {
            definitions,
            extensions,
            inclusions,
            wrappit and do_begin_fig or "",
            do_first_run,
            no_trial_run,
            initializations,
            do_safeguard,
            data,
            wrappit and do_end_fig or "",
        }, false, nil, false, false, askedfig, true)
    end
    context(stopjob)
end

-- we overload metapost.process here

function metapost.process(mpx, data, trialrun, flusher, multipass, isextrapass, askedfig, plugmode) -- overloads
    startjob(plugmode,"process")
    processmetapost(mpx, data, trialrun, flusher, multipass, isextrapass, askedfig)
    stopjob()
end

local start    = [[\starttext]]
local preamble = [[\def\MPLIBgraphictext#1{\startTEXpage[scale=10000]#1\stopTEXpage}]]
local stop     = [[\stoptext]]

local mpyfilename = nil

function makempy.registerfile(filename)
    mpyfilename = filename
end

implement {
    name      = "registermpyfile",
    actions   = makempy.registerfile,
    arguments = "string"
}

local pdftompy = sandbox.registerrunner {
    name     = "mpy:pstoedit",
    program  = "pstoedit",
    template = "-ssp -dt -f mpost %pdffile% %mpyfile%",
    checkers = {
        pdffile = "writable",
        mpyfile = "readable",
    },
    reporter = report_metapost,
}

local textopdf = sandbox.registerrunner {
    name     = "mpy:context",
    program  = "context",
    template = "--once %runmode% %texfile%",
    checkers = {
        runmode = "string",
        texfile = "readable",
    },
    reporter = report_metapost,
}

function makempy.processgraphics(graphics)
    if #graphics == 0 then
        return
    end
    if mpyfilename and exists(mpyfilename) then
        report_metapost("using file: %s",mpyfilename)
        return
    end
    makempy.nofconverted = makempy.nofconverted + 1
    starttiming(makempy)
    local mpofile = tex.jobname .. "-mpgraph"
    local mpyfile = file.replacesuffix(mpofile,"mpy")
    local pdffile = file.replacesuffix(mpofile,"pdf")
    local texfile = file.replacesuffix(mpofile,"tex")
    savedata(texfile, { start, preamble, metapost.tex.get(), concat(graphics,"\n"), stop }, "\n")
    textopdf {
        runmode = tex.interactionmode == 0 and "--batchmode" or "",
        texfile = texfile,
    }
    if exists(pdffile) then
        pdftompy {
            pdffile = pdffile,
            mpyfile = mpyfile,
        }
        if exists(mpyfile) then
            local result, r = { }, 0
            local data = io.loaddata(mpyfile)
            if data and #data > 0 then
                for figure in gmatch(data,"beginfig(.-)endfig") do
                    r = r + 1
                    result[r] = formatters["begingraphictextfig%sendgraphictextfig ;\n"](figure)
                end
                savedata(mpyfile,concat(result,""))
            end
        end
    end
    stoptiming(makempy)
end

-- -- the new plugin handler -- --

local sequencers       = utilities.sequencers
local appendgroup      = sequencers.appendgroup
local appendaction     = sequencers.appendaction

local resetter         = nil
local analyzer         = nil
local processor        = nil

local resetteractions  = sequencers.new { arguments = "t" }
local analyzeractions  = sequencers.new { arguments = "object,prescript" }
local processoractions = sequencers.new { arguments = "object,prescript,before,after" }

appendgroup(resetteractions, "system")
appendgroup(analyzeractions, "system")
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
    if top.plugmode then -- hm, what about other features
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
    if top.plugmode then
        outercolormodel = colors.currentmodel() -- currently overloads the one set at the tex end
        resetter(t)
    end
end

function metapost.analyzeplugins(object) -- each object (first pass)
    if top.plugmode then
        local prescript = object.prescript   -- specifications
        if prescript and #prescript > 0 then
            analyzer(object,splitprescript(prescript) or {})
            return top.multipass
        end
    end
    return false
end

function metapost.processplugins(object) -- each object (second pass)
    if top.plugmode then
        local prescript = object.prescript   -- specifications
        if prescript and #prescript > 0 then
            local before = { }
            local after = { }
            processor(object,splitprescript(prescript) or {},before,after)
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
        local first, second, fourth = op[1], op[2], op[4]
        if fourth then
            local tx, ty = first.x_coord      , first.y_coord
            local sx, sy = second.x_coord - tx, fourth.y_coord - ty
            local rx, ry = second.y_coord - ty, fourth.x_coord - tx
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

local tx_reset, tx_analyze, tx_process  do

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

--     local f_gray_yes = formatters["s=%F,a=%F,t=%F"]
--     local f_gray_nop = formatters["s=%F"]
--     local f_rgb_yes  = formatters["r=%F,g=%F,b=%F,a=%F,t=%F"]
--     local f_rgb_nop  = formatters["r=%F,g=%F,b=%F"]
--     local f_cmyk_yes = formatters["c=%F,m=%F,y=%F,k=%F,a=%F,t=%F"]
--     local f_cmyk_nop = formatters["c=%F,m=%F,y=%F,k=%F"]

    local f_gray_yes = formatters["s=%n,a=%n,t=%n"]
    local f_gray_nop = formatters["s=%n"]
    local f_rgb_yes  = formatters["r=%n,g=%n,b=%n,a=%n,t=%n"]
    local f_rgb_nop  = formatters["r=%n,g=%n,b=%n"]
    local f_cmyk_yes = formatters["c=%n,m=%n,y=%n,k=%n,a=%n,t=%n"]
    local f_cmyk_nop = formatters["c=%n,m=%n,y=%n,k=%n"]

    if metapost.use_one_pass then

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
                    ctx_MPLIBsetCtext(mp_target,f_rgb_nop(mp_c[1],mp_c[2],mp_c[3],mp_a,mp_t),mp_text)
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

        function mp.SomeText(index,str)
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
        end

        function mp.SomeFormattedText(index,fmt,...)
            local t = { }
            for i=1,select("#",...) do
                local ti = select(i,...)
                if type(ti) ~= "table" then
                    t[#t+1] = ti
                end
            end
            local f = lpegmatch(cleaner,fmt)
            local s = formatters[f](unpack(t)) or ""
            mp.SomeText(index,s)
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
            local data  = top.texdata[metapost.properties.number]
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
                local mp_text = top.texstrings[mp_index]
                local hash = fmt(mp_text,mp_a or "-",mp_t or "-",mp_c or "-")
                local box  = data.texhash[hash]
                mp_index  = index
                mp_target = top.texlast - 1
                top.texlast = mp_target
                if box then
                    box = copy_list(box)
                else
                    tex.runtoks("mptexttoks")
                    box = textakebox("mptextbox")
                    data.texhash[hash] = box
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

    else

        local ctx_MPLIBsetNtext = context.MPLIBsetNtext
        local ctx_MPLIBsetCtext = context.MPLIBsetCtext
        local ctx_MPLIBsettext  = context.MPLIBsettext

        tx_reset = function()
            if top then
                top.texhash = { }
                top.texlast = 0
            end
        end

        -- we reuse content when possible
        -- we always create at least one instance (for dimensions)
        -- we make sure we don't do that when we use one (else counter issues with e.g. \definelabel)

        tx_analyze = function(object,prescript)
            local data = top.texdata[metapost.properties.number]
            local tx_stage = prescript.tx_stage
            if tx_stage == "trial" then
                local tx_trial = data.textrial + 1
                data.textrial = tx_trial
                local tx_number = tonumber(prescript.tx_number)
                local s = object.postscript or ""
                local c = object.color -- only simple ones, no transparency
                if #c == 0 then
                    local txc = prescript.tx_color
                    if txc then
                        c = lpegmatch(pat,txc)
                    end
                end
                if prescript.tx_type == "format" then
                    s = applyformat(s)
                end
                local a = tonumber(prescript.tr_alternative)
                local t = tonumber(prescript.tr_transparency)
                local h = fmt(tx_number,a or "-",t or "-",c or "-")
                local n = data.texhash[h] -- todo: hashed variant with s (nicer for similar labels)
                if n then
                    data.texslots[tx_trial] = n
                    if trace_textexts then
                        report_textexts("stage %a, usage %a, number %a, %s %a, hash %a, text %a",tx_stage,tx_trial,tx_number,"old",n,h,s)
                    end
                elseif prescript.tx_global == "yes" and data.texorder[tx_number] then
                    -- we already have one flush and don't want it redone .. this needs checking
                    if trace_textexts then
                        report_textexts("stage %a, usage %a, number %a, %s %a, hash %a, text %a",tx_stage,tx_trial,tx_number,"ignored",tx_last,h,s)
                    end
                else
                    local tx_last = top.texlast + 1
                    top.texlast = tx_last
                 -- report_textexts("tex string: %s",s)
                    if not c then
                        ctx_MPLIBsetNtext(tx_last,s)
                    elseif #c == 1 then
                        if a and t then
                            ctx_MPLIBsetCtext(tx_last,f_gray_yes(c[1],a,t),s)
                        else
                            ctx_MPLIBsetCtext(tx_last,f_gray_nop(c[1]),s)
                        end
                    elseif #c == 3 then
                        if a and t then
                            ctx_MPLIBsetCtext(tx_last,f_rgb_nop(c[1],c[2],c[3],a,t),s)
                        else
                            ctx_MPLIBsetCtext(tx_last,f_rgb_nop(c[1],c[2],c[3]),s)
                        end
                    elseif #c == 4 then
                        if a and t then
                            ctx_MPLIBsetCtext(tx_last,f_cmyk_yes(c[1],c[2],c[3],c[4],a,t),s)
                        else
                            ctx_MPLIBsetCtext(tx_last,f_cmyk_nop(c[1],c[2],c[3],c[4]),s)
                        end
                    else
                        ctx_MPLIBsetNtext(tx_last,s)
                    end
                    top.multipass = true
                    data.texhash [h]         = tx_last
                 -- data.texhash [tx_number] = tx_last
                    data.texslots[tx_trial]  = tx_last
                    data.texorder[tx_number] = tx_last
                    if trace_textexts then
                        report_textexts("stage %a, usage %a, number %a, %s %a, hash %a, text %a",tx_stage,tx_trial,tx_number,"new",tx_last,h,s)
                    end
                end
            elseif tx_stage == "extra" then
                local tx_trial = data.textrial + 1
                data.textrial = tx_trial
                local tx_number = tonumber(prescript.tx_number)
                if not data.texorder[tx_number] then
                    local s = object.postscript or ""
                    local tx_last = top.texlast + 1
                    top.texlast = tx_last
                    ctx_MPLIBsettext(tx_last,s)
                    top.multipass = true
                    data.texslots[tx_trial] = tx_last
                    data.texorder[tx_number] = tx_last
                    if trace_textexts then
                        report_textexts("stage %a, usage %a, number %a, extra %a, text %a",tx_stage,tx_trial,tx_number,tx_last,s)
                    end
                end
            end
        end

        tx_process = function(object,prescript,before,after)
            local data = top.texdata[metapost.properties.number]
            local tx_number = tonumber(prescript.tx_number)
            if tx_number then
                local tx_stage = prescript.tx_stage
                if tx_stage == "final" then
                    local tx_final = data.texfinal + 1
                    data.texfinal = tx_final
                    local n = data.texslots[tx_final]
                    if trace_textexts then
                        report_textexts("stage %a, usage %a, number %a, use %a",tx_stage,tx_final,tx_number,n)
                    end
                    local sx, rx, ry, sy, tx, ty = cm(object) -- needs to be frozen outside the function
                    local box = top.textexts[n]
                    if box then
                        before[#before+1] = function()
                         -- flush always happens, we can have a special flush function injected before
                            context.MPLIBgettextscaledcm(n,
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
                            report_textexts("unknown %s",tx_number)
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


local gt_reset, gt_analyze, gt_process do

    local graphics = { }

    if metapost.use_one_pass then

        local mp_index = 0
        local mp_str   = ""

        function metapost.intermediate.actions.makempy()
        end

        function mp.GraphicText(index,str)
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


    else

        function metapost.intermediate.actions.makempy()
            if #graphics > 0 then
                makempy.processgraphics(graphics)
                graphics = { } -- ? could be gt_reset
            end
        end

        local function gt_analyze(object,prescript)
            local gt_stage = prescript.gt_stage
            local gt_index = tonumber(prescript.gt_index)
            if gt_stage == "trial" and not graphics[gt_index] then
                graphics[gt_index] = formatters["\\MPLIBgraphictext{%s}"](object.postscript or "")
                top.intermediate   = true
                top.multipass      = true
            end
        end

     -- local function gt_process(object,prescript,before,after)
     --     local gt_stage = prescript.gt_stage
     --     if gt_stage == "final" then
     --     end
     -- end

    end

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
        before[#before+1] = f_cm(cm(object))
        before[#before+1] = function()
            figures.bitmapimage {
                xresolution = tonumber(bm_xresolution),
                yresolution = tonumber(prescript.bm_yresolution),
                width       = 1/basepoints,
                height      = 1/basepoints,
                data        = object.postscript
            }
        end
        before[#before+1] = "Q"
        object.path = false
        object.color = false
        object.grouped = true
    end
end

-- positions

local function ps_process(object,prescript,before,after)
    local ps_label = prescript.ps_label
    if ps_label then
        local op = object.path
        local first, third  = op[1], op[3]
        local x, y = first.x_coord, first.y_coord
        local w, h = third.x_coord - x, third.y_coord - y
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

local function fg_process(object,prescript,before,after)
    local fg_name = prescript.fg_name
    if fg_name then
        before[#before+1] = f_cm(cm(object)) -- beware: does not use the cm stack
        before[#before+1] = function()
            context.MPLIBfigure(fg_name,prescript.fg_mask or "")
        end
        before[#before+1] = "Q"
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

local function tr_process(object,prescript,before,after)
    -- before can be shortcut to t
    local tr_alternative = prescript.tr_alternative
    if tr_alternative then
        tr_alternative = tonumber(tr_alternative)
        local tr_transparency = tonumber(prescript.tr_transparency)
        before[#before+1] = formatters["/Tr%s gs"](registertransparency(nil,tr_alternative,tr_transparency,true))
        after[#after+1] = "/Tr0 gs" -- outertransparency
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
                local sp_value = prescript.sp_value or "s:1"
                local sp_temp  = formatters["mp:%s"](sp_value)
                local s = split(sp_value,":")
                local r = remappers[#s]
                defineprocesscolor(sp_temp,r and r(unpack(s)) or "s=0",true,true)
                definespotcolor(sp_name,sp_temp,"p=1",true)
                sp_type = "named"
            elseif sp_type == "multitone" then -- (fractions of a multitone) don't work well in mupdf
                local sp_value = prescript.sp_value or "s:1"
                local sp_spec  = { }
                local sp_list  = split(sp_value," ")
                for i=1,#sp_list do
                    local v = sp_list[i]
                    local t = formatters["mp:%s"](v)
                    local s = split(v,":")
                    local r = remappers[#s]
                    defineprocesscolor(t,r and r(unpack(s)) or "s=0",true,true)
                    local tt = formatters["ms:%s"](v)
                    definespotcolor(tt,t,"p=1",true)
                    sp_spec[#sp_spec+1] = formatters["%s=1"](t)
                end
                sp_spec = concat(sp_spec,",")
                definemultitonecolor(sp_name,sp_spec,"","",true)
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
                        before[#before+1] = formatters["/Tr%s gs"](registertransparency(nil,v[1],v[2],true))
                        after[#after+1] = "/Tr0 gs" -- outertransparency
                    end
                end
                local c = c_list[sp_name] -- string or attribute
                local v = c and colorvalue(c)
                if v then
                    -- all=1 gray=2 rgb=3 cmyk=4
                    local colorspace = v[1]
                    local f = cs[1]
                    if colorspace == 2 then
                        local s = f*v[2]
                        c_b, c_a = checked_color_pair(f_gray,s,s)
                    elseif colorspace == 3 then
                        local r, g, b = f*v[3], f*v[4], f*v[5]
                        c_b, c_a = checked_color_pair(f_rgb,r,g,b,r,g,b)
                    elseif colorspace == 4 or colorspace == 1 then
                        local c, m, y, k = f*v[6], f*v[7], f*v[8], f*v[9]
                        c_b, c_a = checked_color_pair(f_cmyk,c,m,y,k,c,m,y,k)
                    elseif colorspace == 5 then
                        -- not all viewers show the fractions ok
                        local name  = v[10]
                        local value = split(v[13],",")
                        if f ~= 1 then
                            for i=1,#value do
                                value[i] = f * (tonumber(value[i]) or 1)
                            end
                        end
                        value = concat(value," ")
                        c_b, c_a = checked_color_pair(f_spot,name,name,value,value)
                    else
                        local s = f*v[2]
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
        local p1, p2, p3, p4 = path[1], path[2], path[3], path[4]
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

local ot_reset, ot_analyze, ot_process do

    local outlinetexts = { } -- also in top data

    local function ot_reset()
        outlinetexts = { }
    end

    if metapost.use_one_pass then

        local mp_index = 0
        local mp_kind  = ""
        local mp_str   = ""

        function mp.OutlineText(index,str,kind)
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

    else

        local function ot_analyze(object,prescript)
            local ot_stage = prescript.ot_stage
            local ot_index = tonumber(prescript.ot_index)
            if ot_index and ot_stage == "trial" and not outlinetexts[ot_index] then
                local ot_kind = prescript.ot_kind or ""
                top.intermediate  = true
                top.multipass     = true
                context.MPLIBoutlinetext(ot_index,ot_kind,object.postscript)
            end
        end

    end

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

    function mp.get_outline_text(index) -- maybe we need a more private namespace
        mp.print(outlinetexts[index] or "draw origin;")
    end

end

-- definitions

appendaction(resetteractions, "system",ot_reset)
appendaction(resetteractions, "system",cl_reset)
appendaction(resetteractions, "system",tx_reset)

appendaction(processoractions,"system",ot_process)
appendaction(processoractions,"system",gr_process)

appendaction(analyzeractions, "system",ot_analyze)
appendaction(analyzeractions, "system",tx_analyze)
appendaction(analyzeractions, "system",gt_analyze)

appendaction(processoractions,"system",sh_process)
--          (processoractions,"system",gt_process)
appendaction(processoractions,"system",bm_process)
appendaction(processoractions,"system",tx_process)
appendaction(processoractions,"system",bx_process)
appendaction(processoractions,"system",ps_process)
appendaction(processoractions,"system",fg_process)
appendaction(processoractions,"system",tr_process) -- last, as color can be reset

appendaction(processoractions,"system",la_process)

function metapost.installplugin(reset,analyze,process)
    if reset then
        appendaction(resetteractions,"system",reset)
    end
    if analyze then
        appendaction(analyzeractions,"system",analyze)
    end
    if process then
        appendaction(processoractions,"system",process)
    end
    resetter  = resetteractions .runner
    analyzer  = analyzeractions .runner
    processor = processoractions.runner
end

-- we're nice and set them already

resetter  = resetteractions .runner
analyzer  = analyzeractions .runner
processor = processoractions.runner
