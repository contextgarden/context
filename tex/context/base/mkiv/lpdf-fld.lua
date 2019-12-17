if not modules then modules = { } end modules ['lpdf-fld'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- TURN OFF: preferences -> forms -> highlight -> etc

-- The problem with widgets is that so far each version of acrobat has some
-- rendering problem. I tried to keep up with this but it makes no sense to do so as
-- one cannot rely on the viewer not changing. Especially Btn fields are tricky as
-- their appearences need to be synchronized in the case of children but e.g.
-- acrobat 10 does not retain the state and forces a check symbol. If you make a
-- file in acrobat then it has MK entries that seem to overload the already present
-- appearance streams (they're probably only meant for printing) as it looks like
-- the viewer has some fallback on (auto generated) MK behaviour built in. So ...
-- hard to test. Unfortunately not even the default appearance is generated. This
-- will probably be solved at some point.
--
-- Also, for some reason the viewer does not always show custom appearances when
-- fields are being rolled over or clicked upon, and circles or checks pop up when
-- you don't expect them. I fear that this kind of instability eventually will kill
-- pdf forms. After all, the manual says: "individual annotation handlers may ignore
-- this entry and provide their own appearances" and one might wonder what
-- 'individual' means here, but effectively this renders the whole concept of
-- appearances useless.
--
-- Okay, here is one observation. A pdf file contains objects and one might consider
-- each one to be a static entity when read in. However, acrobat starts rendering
-- and seems to manipulate (appearance streams) of objects in place (this is visible
-- when the file is saved again). And, combined with some other caching and hashing,
-- this might give side effects for shared objects. So, it seems that for some cases
-- one can best be not too clever and not share but duplicate information. Of course
-- this defeats the whole purpose of these objects. Of course I can be wrong.
--
-- A rarther weird side effect of the viewer is that the highlighting of fields
-- obscures values, unless you uses one of the BS variants, and this makes custum
-- appearances rather useless as there is no way to control this apart from changing
-- the viewer preferences. It could of course be a bug but it would be nice if the
-- highlighting was at least transparent. I have no clue why the built in shapes
-- work ok (some xform based appearances are generated) while equally valid other
-- xforms fail. It looks like acrobat appearances come on top (being refered to in
-- the MK) while custom ones are behind the highlight rectangle. One can disable the
-- "Show border hover color for fields" option in the preferences. If you load
-- java-imp-rhh this side effect gets disabled and you get what you expect (it took
-- me a while to figure out this hack).
--
-- When highlighting is enabled, those default symbols flash up, so it looks like we
-- have some inteference between this setting and custom appearances.
--
-- Anyhow, the NeedAppearances is really needed in order to get a rendering for
-- printing especially when highlighting (those colorfull foregrounds) is on.

local tostring, tonumber, next = tostring, tonumber, next
local gmatch, lower, format, formatters = string.gmatch, string.lower, string.format, string.formatters
local lpegmatch = lpeg.match
local bpfactor, todimen = number.dimenfactors.bp, string.todimen
local sortedhash = table.sortedhash
local trace_fields = false  trackers.register("backends.fields", function(v) trace_fields = v end)

local report_fields = logs.reporter("backend","fields")

local backends, lpdf = backends, lpdf

local variables               = interfaces.variables
local context                 = context

local references              = structures.references
local settings_to_array       = utilities.parsers.settings_to_array

local pdfbackend              = backends.pdf

local nodeinjections          = pdfbackend.nodeinjections
local codeinjections          = pdfbackend.codeinjections
local registrations           = pdfbackend.registrations

local registeredsymbol        = codeinjections.registeredsymbol

local pdfstream               = lpdf.stream
local pdfdictionary           = lpdf.dictionary
local pdfarray                = lpdf.array
local pdfreference            = lpdf.reference
local pdfunicode              = lpdf.unicode
local pdfstring               = lpdf.string
local pdfconstant             = lpdf.constant
local pdfflushobject          = lpdf.flushobject
local pdfshareobjectreference = lpdf.shareobjectreference
local pdfshareobject          = lpdf.shareobject
local pdfreserveobject        = lpdf.reserveobject
local pdfpagereference        = lpdf.pagereference
local pdfaction               = lpdf.action
local pdfmajorversion         = lpdf.majorversion

local pdfcolor                = lpdf.color
local pdfcolorvalues          = lpdf.colorvalues
local pdflayerreference       = lpdf.layerreference

local hpack_node              = node.hpack

local submitoutputformat      = 0 --  0=unknown 1=HTML 2=FDF 3=XML   => not yet used, needs to be checked

local pdf_widget              = pdfconstant("Widget")
local pdf_tx                  = pdfconstant("Tx")
local pdf_sig                 = pdfconstant("Sig")
local pdf_ch                  = pdfconstant("Ch")
local pdf_btn                 = pdfconstant("Btn")
local pdf_yes                 = pdfconstant("Yes")
local pdf_off                 = pdfconstant("Off")
local pdf_p                   = pdfconstant("P") -- None Invert Outline Push
local pdf_n                   = pdfconstant("N") -- None Invert Outline Push
--
local pdf_no_rect             = pdfarray { 0, 0, 0, 0 }

local splitter = lpeg.splitat("=>")

local formats = {
    html = 1, fdf = 2, xml = 3,
}

function codeinjections.setformsmethod(name)
    submitoutputformat = formats[lower(name)] or formats.xml
end

local flag = { -- /Ff
    ReadOnly          = 0x00000001, -- 2^ 0
    Required          = 0x00000002, -- 2^ 1
    NoExport          = 0x00000004, -- 2^ 2
    MultiLine         = 0x00001000, -- 2^12
    Password          = 0x00002000, -- 2^13
    NoToggleToOff     = 0x00004000, -- 2^14
    Radio             = 0x00008000, -- 2^15
    PushButton        = 0x00010000, -- 2^16
    PopUp             = 0x00020000, -- 2^17
    Edit              = 0x00040000, -- 2^18
    Sort              = 0x00080000, -- 2^19
    FileSelect        = 0x00100000, -- 2^20
    DoNotSpellCheck   = 0x00400000, -- 2^22
    DoNotScroll       = 0x00800000, -- 2^23
    Comb              = 0x01000000, -- 2^24
    RichText          = 0x02000000, -- 2^25
    RadiosInUnison    = 0x02000000, -- 2^25
    CommitOnSelChange = 0x04000000, -- 2^26
}

local plus = { -- /F
    Invisible         = 0x00000001, -- 2^0
    Hidden            = 0x00000002, -- 2^1
    Printable         = 0x00000004, -- 2^2
    Print             = 0x00000004, -- 2^2
    NoZoom            = 0x00000008, -- 2^3
    NoRotate          = 0x00000010, -- 2^4
    NoView            = 0x00000020, -- 2^5
    ReadOnly          = 0x00000040, -- 2^6
    Locked            = 0x00000080, -- 2^7
    ToggleNoView      = 0x00000100, -- 2^8
    LockedContents    = 0x00000200, -- 2^9
    AutoView          = 0x00000100, -- 2^8
}

-- todo: check what is interfaced

flag.readonly    = flag.ReadOnly
flag.required    = flag.Required
flag.protected   = flag.Password
flag.sorted      = flag.Sort
flag.unavailable = flag.NoExport
flag.nocheck     = flag.DoNotSpellCheck
flag.fixed       = flag.DoNotScroll
flag.file        = flag.FileSelect

plus.hidden      = plus.Hidden
plus.printable   = plus.Printable
plus.auto        = plus.AutoView

lpdf.flags.widgets     = flag
lpdf.flags.annotations = plus

-- some day .. lpeg with function or table

local function fieldflag(specification) -- /Ff
    local o, n = specification.option, 0
    if o and o ~= "" then
        for f in gmatch(o,"[^, ]+") do
            n = n + (flag[f] or 0)
        end
    end
    return n
end

local function fieldplus(specification) -- /F
    local o, n = specification.option, 0
    if o and o ~= "" then
        for p in gmatch(o,"[^, ]+") do
            n = n + (plus[p] or 0)
        end
    end
-- n = n + 4
    return n
end

-- keep:
--
-- local function checked(what)
--     local set, bug = references.identify("",what)
--     if not bug and #set > 0 then
--         local r, n = pdfaction(set)
--         return pdfshareobjectreference(r)
--     end
-- end
--
-- local function fieldactions(specification) -- share actions
--     local d, a = { }, nil
--     a = specification.mousedown
--      or specification.clickin           if a and a ~= "" then d.D  = checked(a) end
--     a = specification.mouseup
--      or specification.clickout          if a and a ~= "" then d.U  = checked(a) end
--     a = specification.regionin          if a and a ~= "" then d.E  = checked(a) end -- Enter
--     a = specification.regionout         if a and a ~= "" then d.X  = checked(a) end -- eXit
--     a = specification.afterkey          if a and a ~= "" then d.K  = checked(a) end
--     a = specification.format            if a and a ~= "" then d.F  = checked(a) end
--     a = specification.validate          if a and a ~= "" then d.V  = checked(a) end
--     a = specification.calculate         if a and a ~= "" then d.C  = checked(a) end
--     a = specification.focusin           if a and a ~= "" then d.Fo = checked(a) end
--     a = specification.focusout          if a and a ~= "" then d.Bl = checked(a) end
--     a = specification.openpage          if a and a ~= "" then d.PO = checked(a) end
--     a = specification.closepage         if a and a ~= "" then d.PC = checked(a) end
--  -- a = specification.visiblepage       if a and a ~= "" then d.PV = checked(a) end
--  -- a = specification.invisiblepage     if a and a ~= "" then d.PI = checked(a) end
--     return next(d) and pdfdictionary(d)
-- end

local mapping = {
    mousedown         = "D",    clickin  = "D",
    mouseup           = "U",    clickout = "U",
    regionin          = "E",
    regionout         = "X",
    afterkey          = "K",
    format            = "F",
    validate          = "V",
    calculate         = "C",
    focusin           = "Fo",
    focusout          = "Bl",
    openpage          = "PO",
    closepage         = "PC",
 -- visiblepage       = "PV",
 -- invisiblepage     = "PI",
}

local function fieldactions(specification) -- share actions
    local d = nil
    for key, target in sortedhash(mapping) do -- sort so that we can compare pdf
        local code = specification[key]
        if code and code ~= "" then
         -- local a = checked(code)
            local set, bug = references.identify("",code)
            if not bug and #set > 0 then
                local a = pdfaction(set) -- r, n
                if a then
                    local r = pdfshareobjectreference(a)
                    if d then
                        d[target] = r
                    else
                        d = pdfdictionary { [target] = r }
                    end
                else
                    report_fields("invalid field action %a, case %s",code,2)
                end
            else
                report_fields("invalid field action %a, case %s",code,1)
            end
        end
    end
 -- if d then
 --     d = pdfshareobjectreference(d) -- not much overlap or maybe only some patterns
 -- end
    return d
end

-- fonts and color

local pdfdocencodingvector, pdfdocencodingcapsule

-- The pdf doc encoding vector is needed in order to trigger propper unicode. Interesting is that when
-- a glyph is not in the vector, it is still visible as it is taken from some other font. Messy.

-- To be checked: only when text/line fields.

local function checkpdfdocencoding()
    report_fields("adding pdfdoc encoding vector")
    local encoding = dofile(resolvers.findfile("lpdf-enc.lua")) -- no checking, fatal if not present
    pdfdocencodingvector = pdfreference(pdfflushobject(encoding))
    local capsule = pdfdictionary {
        PDFDocEncoding = pdfdocencodingvector
    }
    pdfdocencodingcapsule = pdfreference(pdfflushobject(capsule))
    checkpdfdocencoding = function() end
end

local fontnames = {
    rm = {
        tf = "Times-Roman",
        bf = "Times-Bold",
        it = "Times-Italic",
        sl = "Times-Italic",
        bi = "Times-BoldItalic",
        bs = "Times-BoldItalic",
    },
    ss = {
        tf = "Helvetica",
        bf = "Helvetica-Bold",
        it = "Helvetica-Oblique",
        sl = "Helvetica-Oblique",
        bi = "Helvetica-BoldOblique",
        bs = "Helvetica-BoldOblique",
    },
    tt = {
        tf = "Courier",
        bf = "Courier-Bold",
        it = "Courier-Oblique",
        sl = "Courier-Oblique",
        bi = "Courier-BoldOblique",
        bs = "Courier-BoldOblique",
    },
    symbol = {
        dingbats = "ZapfDingbats",
    }
}

local usedfonts = { }

local function fieldsurrounding(specification)
    local fontsize        = specification.fontsize or "12pt"
    local fontstyle       = specification.fontstyle or "rm"
    local fontalternative = specification.fontalternative or "tf"
    local colorvalue      = tonumber(specification.colorvalue)
    local s = fontnames[fontstyle]
    if not s then
        fontstyle, s = "rm", fontnames.rm
    end
    local a = s[fontalternative]
    if not a then
        alternative, a = "tf", s.tf
    end
    local tag = fontstyle .. fontalternative
    fontsize  = todimen(fontsize)
    fontsize  = fontsize and (bpfactor * fontsize) or 12
    fontraise = 0.1 * fontsize -- todo: figure out what the natural one is and compensate for strutdp
    local fontcode  = formatters["%0.4F Tf %0.4F Ts"](fontsize,fontraise)
    -- we could test for colorvalue being 1 (black) and omit it then
    local colorcode = pdfcolor(3,colorvalue) -- we force an rgb color space
    if trace_fields then
        report_fields("using font, style %a, alternative %a, size %p, tag %a, code %a",fontstyle,fontalternative,fontsize,tag,fontcode)
        report_fields("using color, value %a, code %a",colorvalue,colorcode)
    end
    local stream = pdfstream {
        pdfconstant(tag),
        formatters["%s %s"](fontcode,colorcode)
    }
    usedfonts[tag] = a -- the name
    -- move up with "x.y Ts"
    return tostring(stream)
end

-- Can we use any font?

codeinjections.fieldsurrounding = fieldsurrounding

local function registerfonts()
    if next(usedfonts) then
        checkpdfdocencoding() -- already done
        local pdffontlist    = pdfdictionary()
        local pdffonttype    = pdfconstant("Font")
        local pdffontsubtype = pdfconstant("Type1")
        for tag, name in sortedhash(usedfonts) do
            local f = pdfdictionary {
                Type     = pdffonttype,
                Subtype  = pdffontsubtype,
                Name     = pdfconstant(tag),
                BaseFont = pdfconstant(name),
                Encoding = pdfdocencodingvector,
            }
            pdffontlist[tag] = pdfreference(pdfflushobject(f))
        end
        return pdffontlist
    end
end

-- symbols

local function fieldappearances(specification)
    -- todo: caching
    local values  = specification.values
    local default = specification.default -- todo
    if not values then
        -- error
        return
    end
    local v = settings_to_array(values)
    local n, r, d
    if #v == 1 then
        n, r, d = v[1], v[1], v[1]
    elseif #v == 2 then
        n, r, d = v[1], v[1], v[2]
    else
        n, r, d = v[1], v[2], v[3]
    end
    local appearance = pdfdictionary {
        N = registeredsymbol(n),
        R = registeredsymbol(r),
        D = registeredsymbol(d),
    }
    return pdfshareobjectreference(appearance)
--     return pdfreference(pdfflushobject(appearance))
end

-- The rendering part of form support has always been crappy and didn't really
-- improve over time. Did bugs become features? Who knows. Why provide for instance
-- control over appearance and then ignore it when the mouse clicks someplace else.
-- Strangely enough a lot of effort went into JavaScript support while basic
-- appearance control of checkboxes stayed poor. I found this link when googling for
-- conformation after the n^th time looking into this behaviour:
--
-- https://stackoverflow.com/questions/15479855/pdf-appearance-streams-checkbox-not-shown-correctly-after-focus-lost
--
-- ... "In particular check boxes, therefore, whenever not interacting with the user, shall
-- be displayed using their normal captions, not their appearances."
--
-- So: don't use check boxes. In fact, even radio buttons can have these funny "flash some
-- funny symbol" side effect when clocking on them. I tried all combinations if /H and /AP
-- and /AS and ... Because (afaiks) the acrobat interface assumes that one uses dingbats no
-- one really cared about getting custom appeances done well. This erratic behaviour might
-- as well be the reason why no open source viewer ever bothered implementing forms. It's
-- probably also why most forms out there look kind of bad.

local function fieldstates_precheck(specification)
    local values  = specification.values
    local default = specification.default
    if not values or values == "" then
        return
    end
    local yes = settings_to_array(values)[1]
    local yesshown, yesvalue = lpegmatch(splitter,yes)
    if not (yesshown and yesvalue) then
        yesshown = yes
    end
    return default == settings_to_array(yesshown)[1] and pdf_yes or pdf_off
end

local function fieldstates_check(specification)
    -- we don't use Opt here (too messy for radio buttons)
    local values  = specification.values
    local default = specification.default
    if not values or values == "" then
        -- error
        return
    end
    local v = settings_to_array(values)
    local yes, off, yesn, yesr, yesd, offn, offr, offd
    if #v == 1 then
        yes, off = v[1], v[1]
    else
        yes, off = v[1], v[2]
    end
    local yesshown, yesvalue = lpegmatch(splitter,yes)
    if not (yesshown and yesvalue) then
        yesshown = yes, yes
    end
    yes = settings_to_array(yesshown)
    local offshown, offvalue = lpegmatch(splitter,off)
    if not (offshown and offvalue) then
        offshown = off, off
    end
    off = settings_to_array(offshown)
    if #yes == 1 then
        yesn, yesr, yesd = yes[1], yes[1], yes[1]
    elseif #yes == 2 then
        yesn, yesr, yesd = yes[1], yes[1], yes[2]
    else
        yesn, yesr, yesd = yes[1], yes[2], yes[3]
    end
    if #off == 1 then
        offn, offr, offd = off[1], off[1], off[1]
    elseif #off == 2 then
        offn, offr, offd = off[1], off[1], off[2]
    else
        offn, offr, offd = off[1], off[2], off[3]
    end
    if not yesvalue then
        yesvalue = yesdefault or yesn
    end
    if not offvalue then
        offvalue = offn
    end
    if default == yesn then
        default  = pdf_yes
        yesvalue = yesvalue == yesn and "Yes" or "Off"
    else
        default  = pdf_off
        yesvalue = "Off"
    end
    local appearance
 -- if false then
    if true then
        -- needs testing
        appearance = pdfdictionary { -- maybe also cache components
            N = pdfshareobjectreference(pdfdictionary { Yes = registeredsymbol(yesn), Off = registeredsymbol(offn) }),
            R = pdfshareobjectreference(pdfdictionary { Yes = registeredsymbol(yesr), Off = registeredsymbol(offr) }),
            D = pdfshareobjectreference(pdfdictionary { Yes = registeredsymbol(yesd), Off = registeredsymbol(offd) }),
        }
    else
        appearance = pdfdictionary { -- maybe also cache components
            N = pdfdictionary { Yes = registeredsymbol(yesn), Off = registeredsymbol(offn) },
            R = pdfdictionary { Yes = registeredsymbol(yesr), Off = registeredsymbol(offr) },
            D = pdfdictionary { Yes = registeredsymbol(yesd), Off = registeredsymbol(offd) }
        }
    end
    local appearanceref = pdfshareobjectreference(appearance)
 -- local appearanceref = pdfreference(pdfflushobject(appearance))
    return appearanceref, default, yesvalue
end

-- It looks like there is always a (MK related) symbol used and that the appearances
-- are only used as ornaments behind a symbol. So, contrary to what we did when
-- widgets showed up, we now limit ourself to more dumb definitions. Especially when
-- highlighting is enabled weird interferences happen. So, we play safe (some nice
-- code has been removed that worked well till recently).

local function fieldstates_radio(specification,name,parent)
    local values  = values  or specification.values
    local default = default or parent.default -- specification.default
    if not values or values == "" then
        -- error
        return
    end
    local v = settings_to_array(values)
    local yes, off, yesn, yesr, yesd, offn, offr, offd
    if #v == 1 then
        yes, off = v[1], v[1]
    else
        yes, off = v[1], v[2]
    end
    -- yes keys might be the same in the three appearances within a field
    -- but can best be different among fields ... don't ask why
    local yessymbols, yesvalue = lpegmatch(splitter,yes) -- n,r,d=>x
    if not (yessymbols and yesvalue) then
        yessymbols = yes
    end
    if not yesvalue then
        yesvalue = name
    end
    yessymbols = settings_to_array(yessymbols)
    if #yessymbols == 1 then
        yesn = yessymbols[1]
        yesr = yesn
        yesd = yesr
    elseif #yessymbols == 2 then
        yesn = yessymbols[1]
        yesr = yessymbols[2]
        yesd = yesr
    else
        yesn = yessymbols[1]
        yesr = yessymbols[2]
        yesd = yessymbols[3]
    end
    -- we don't care about names, as all will be /Off
    local offsymbols = lpegmatch(splitter,off) or off
    offsymbols = settings_to_array(offsymbols)
    if #offsymbols == 1 then
        offn = offsymbols[1]
        offr = offn
        offd = offr
    elseif #offsymbols == 2 then
        offn = offsymbols[1]
        offr = offsymbols[2]
        offd = offr
    else
        offn = offsymbols[1]
        offr = offsymbols[2]
        offd = offsymbols[3]
    end
    if default == name then
        default = pdfconstant(name)
    else
        default = pdf_off
    end
    --
    local appearance
    if false then -- needs testing
        appearance = pdfdictionary { -- maybe also cache components
            N = pdfshareobjectreference(pdfdictionary { [name] = registeredsymbol(yesn), Off = registeredsymbol(offn) }),
            R = pdfshareobjectreference(pdfdictionary { [name] = registeredsymbol(yesr), Off = registeredsymbol(offr) }),
            D = pdfshareobjectreference(pdfdictionary { [name] = registeredsymbol(yesd), Off = registeredsymbol(offd) }),
        }
    else
        appearance = pdfdictionary { -- maybe also cache components
            N = pdfdictionary { [name] = registeredsymbol(yesn), Off = registeredsymbol(offn) },
            R = pdfdictionary { [name] = registeredsymbol(yesr), Off = registeredsymbol(offr) },
            D = pdfdictionary { [name] = registeredsymbol(yesd), Off = registeredsymbol(offd) }
        }
    end
    local appearanceref = pdfshareobjectreference(appearance) -- pdfreference(pdfflushobject(appearance))
    return appearanceref, default, yesvalue
end

local function fielddefault(field,pdf_yes)
    local default = field.default
    if not default or default == "" then
        local values = settings_to_array(field.values)
        default = values[1]
    end
    if not default or default == "" then
        return pdf_off
    else
        return pdf_yes or pdfconstant(default)
    end
end

local function fieldoptions(specification)
    local values  = specification.values
    local default = specification.default
    if values then
        local v = settings_to_array(values)
        for i=1,#v do
            local vi = v[i]
            local shown, value = lpegmatch(splitter,vi)
            if shown and value then
                v[i] = pdfarray { pdfunicode(value), shown }
            else
                v[i] = pdfunicode(v[i])
            end
        end
        return pdfarray(v)
    end
end

local mapping = {
    -- acrobat compliant (messy, probably some pdfdoc encoding interference here)
    check   = "4", -- 0x34
    circle  = "l", -- 0x6C
    cross   = "8", -- 0x38
    diamond = "u", -- 0x75
    square  = "n", -- 0x6E
    star    = "H", -- 0x48
}

local function todingbat(n)
    if n and n ~= "" then
        return mapping[n] or ""
    end
end

local function fieldrendering(specification)
    local bvalue = tonumber(specification.backgroundcolorvalue)
    local fvalue = tonumber(specification.framecolorvalue)
    local svalue = specification.fontsymbol
    if bvalue or fvalue or (svalue and svalue ~= "") then
        return pdfdictionary {
            BG = bvalue and pdfarray { pdfcolorvalues(3,bvalue) } or nil, -- or zero_bg,
            BC = fvalue and pdfarray { pdfcolorvalues(3,fvalue) } or nil, -- or zero_bc,
            CA = svalue and pdfstring (svalue) or nil,
        }
    end
end

-- layers

local function fieldlayer(specification) -- we can move this in line
    local layer = specification.layer
    return (layer and pdflayerreference(layer)) or nil
end

-- defining

local fields, radios, clones, fieldsets, calculationset = { }, { }, { }, { }, nil

local xfdftemplate = [[
<?xml version='1.0' encoding='UTF-8'?>

<xfdf xmlns='http://ns.adobe.com/xfdf/'>
  <f href='%s.pdf'/>
  <fields>
%s
  </fields>
</xfdf>
]]

function codeinjections.exportformdata(name)
    local result = { }
    for k, v in sortedhash(fields) do
        result[#result+1] = formatters["    <field name='%s'><value>%s</value></field>"](v.name or k,v.default or "")
    end
    local base = file.basename(tex.jobname)
    local xfdf = format(xfdftemplate,base,table.concat(result,"\n"))
    if not name or name == "" then
        name = base
    end
    io.savedata(file.addsuffix(name,"xfdf"),xfdf)
end

function codeinjections.definefieldset(tag,list)
    fieldsets[tag] = list
end

function codeinjections.getfieldset(tag)
    return fieldsets[tag]
end

local function fieldsetlist(tag)
    if tag then
        local ft = fieldsets[tag]
        if ft then
            local a = pdfarray()
            for name in gmatch(list,"[^, ]+") do
                local f = field[name]
                if f and f.pobj then
                    a[#a+1] = pdfreference(f.pobj)
                end
            end
            return a
        end
    end
end

function codeinjections.setfieldcalculationset(tag)
    calculationset = tag
end

interfaces.implement {
    name      = "setfieldcalculationset",
    actions   = codeinjections.setfieldcalculationset,
    arguments = "string",
}

local function predefinesymbols(specification)
    local values = specification.values
    if values then
        local symbols = settings_to_array(values)
        for i=1,#symbols do
            local symbol = symbols[i]
            local a, b = lpegmatch(splitter,symbol)
            codeinjections.presetsymbol(a or symbol)
        end
    end
end

function codeinjections.getdefaultfieldvalue(name)
    local f = fields[name]
    if f then
        local values  = f.values
        local default = f.default
        if not default or default == "" then
            local symbols = settings_to_array(values)
            local symbol = symbols[1]
            if symbol then
                local a, b = lpegmatch(splitter,symbol) -- splits at =>
                default = a or symbol
            end
        end
        return default
    end
end

function codeinjections.definefield(specification)
    local n = specification.name
    local f = fields[n]
    if not f then
        local fieldtype = specification.type
        if not fieldtype then
            if trace_fields then
                report_fields("invalid definition for %a, unknown type",n)
            end
        elseif fieldtype == "radio" then
            local values = specification.values
            if values and values ~= "" then
                values = settings_to_array(values)
                for v=1,#values do
                    radios[values[v]] = { parent = n }
                end
                fields[n] = specification
                if trace_fields then
                    report_fields("defining %a as type %a",n,"radio")
                end
            elseif trace_fields then
                report_fields("invalid definition of radio %a, missing values",n)
            end
        elseif fieldtype == "sub" then
            -- not in main field list !
            local radio = radios[n]
            if radio then
                -- merge specification
                for key, value in next, specification do
                    radio[key] = value
                end
                if trace_fields then
                    local p = radios[n] and radios[n].parent
                    report_fields("defining %a as type sub of radio %a",n,p)
                end
            elseif trace_fields then
                report_fields("invalid definition of radio sub %a, no parent given",n)
            end
            predefinesymbols(specification)
        elseif fieldtype == "text" or fieldtype == "line" then
            fields[n] = specification
            if trace_fields then
                report_fields("defining %a as type %a",n,fieldtype)
            end
            if specification.values ~= "" and specification.default == "" then
                specification.default, specification.values = specification.values, nil
            end
        else
            fields[n] = specification
            if trace_fields then
                report_fields("defining %a as type %a",n,fieldtype)
            end
            predefinesymbols(specification)
        end
    elseif trace_fields then
        report_fields("invalid definition for %a, already defined",n)
    end
end

function codeinjections.clonefield(specification) -- obsolete
    local p = specification.parent
    local c = specification.children
    local v = specification.alternative
    if not p or not c then
        if trace_fields then
            report_fields("invalid clone, children %a, parent %a, alternative %a",c,p,v)
        end
        return
    end
    local x = fields[p] or radios[p]
    if not x then
        if trace_fields then
            report_fields("invalid clone, unknown parent %a",p)
        end
        return
    end
    for n in gmatch(c,"[^, ]+") do
        local f, r, c = fields[n], radios[n], clones[n]
        if f or r or c then
            if trace_fields then
                report_fields("already cloned, child %a, parent %a, alternative %a",n,p,v)
            end
        else
            if trace_fields then
                report_fields("cloning, child %a, parent %a, alternative %a",n,p,v)
            end
            clones[n] = specification
            predefinesymbols(specification)
        end
    end
end

function codeinjections.getfieldcategory(name)
    local f = fields[name] or radios[name] or clones[name]
    if f then
        local g = f.category
        if not g or g == "" then
            local v, p, t = f.alternative, f.parent, f.type
            if v == "clone" or v == "copy" then
                f = fields[p] or radios[p]
                g = f and f.category
            elseif t == "sub" then
                f = fields[p]
                g = f and f.category
            end
        end
        return g
    end
end

--

function codeinjections.validfieldcategory(name)
    return fields[name] or radios[name] or clones[name]
end

function codeinjections.validfieldset(name)
    return fieldsets[tag]
end

function codeinjections.validfield(name)
    return fields[name]
end

--

local alignments = {
    flushleft  = 0, right  = 0,
    center     = 1, middle = 1,
    flushright = 2, left   = 2,
}

local function fieldalignment(specification)
    return alignments[specification.align] or 0
end

local function enhance(specification,option)
    local so = specification.option
    if so and so ~= "" then
        specification.option = so .. "," .. option
    else
        specification.option = option
    end
    return specification
end

-- finish (if we also collect parents we can inline the kids which is
-- more efficient ... but hardly anyone used widgets so ...)

local collected     = pdfarray()
local forceencoding = false

-- todo : check #opt

local function finishfields()
    local sometext = forceencoding
    local somefont = next(usedfonts)
    for name, field in sortedhash(fields) do
        local kids = field.kids
        if kids then
            pdfflushobject(field.kidsnum,kids)
        end
        local opt = field.opt
        if opt then
            pdfflushobject(field.optnum,opt)
        end
        local type = field.type
        if not sometext and (type == "text" or type == "line") then
            sometext = true
        end
    end
    for name, field in sortedhash(radios) do
        local kids = field.kids
        if kids then
            pdfflushobject(field.kidsnum,kids)
        end
        local opt = field.opt
        if opt then
            pdfflushobject(field.optnum,opt)
        end
    end
    if #collected > 0 then
        local acroform = pdfdictionary {
            NeedAppearances = pdfmajorversion() == 1 or nil,
            Fields          = pdfreference(pdfflushobject(collected)),
            CO              = fieldsetlist(calculationset),
        }
        if sometext or somefont then
            checkpdfdocencoding()
            if sometext then
                usedfonts.tttf = fontnames.tt.tf
                acroform.DA = "/tttf 12 Tf 0 g"
            end
            acroform.DR = pdfdictionary {
                Font     = registerfonts(),
                Encoding = pdfdocencodingcapsule,
            }
        end
        -- maybe:
     -- if sometext then
     --     checkpdfdocencoding()
     --     if sometext then
     --         usedfonts.tttf = fontnames.tt.tf
     --         acroform.DA = "/tttf 12 Tf 0 g"
     --     end
     --     acroform.DR = pdfdictionary {
     --         Font     = registerfonts(),
     --         Encoding = pdfdocencodingcapsule,
     --     }
     -- elseif somefont then
     --     acroform.DR = pdfdictionary {
     --         Font     = registerfonts(),
     --     }
     -- end
        lpdf.addtocatalog("AcroForm",pdfreference(pdfflushobject(acroform)))
    end
end

lpdf.registerdocumentfinalizer(finishfields,"form fields")

local methods = { }

function nodeinjections.typesetfield(name,specification)
    local field = fields[name] or radios[name] or clones[name]
    if not field then
        report_fields( "unknown child %a",name)
        -- unknown field
        return
    end
    local alternative, parent = field.alternative, field.parent
    if alternative == "copy" or alternative == "clone" then -- only in clones
        field = fields[parent] or radios[parent]
    end
    local method = methods[field.type]
    if method then
        return method(name,specification,alternative)
    else
        report_fields( "unknown method %a for child %a",field.type,name)
    end
end

local function save_parent(field,specification,d,hasopt)
    local kidsnum = pdfreserveobject()
    d.Kids        = pdfreference(kidsnum)
    field.kidsnum = kidsnum
    field.kids    = pdfarray()
    if hasopt then
        local optnum = pdfreserveobject()
        d.Opt        = pdfreference(optnum)
        field.optnum = optnum
        field.opt    = pdfarray()
    end
    local pnum = pdfflushobject(d)
    field.pobj = pnum
    collected[#collected+1] = pdfreference(pnum)
end

local function save_kid(field,specification,d,optname)
    local kn = pdfreserveobject()
    field.kids[#field.kids+1] = pdfreference(kn)
    if optname then
        local opt = field.opt
        if opt then
            opt[#opt+1] = optname
        end
    end
    local width  = specification.width  or 0
    local height = specification.height or 0
    local depth  = specification.depth  or 0
    local box = hpack_node(nodeinjections.annotation(width,height,depth,d(),kn))
    -- redundant
    box.width  = width
    box.height = height
    box.depth  = depth
    return box
end

local function makelineparent(field,specification)
    local text   = pdfunicode(field.default)
    local length = tonumber(specification.length or 0) or 0
    local d      = pdfdictionary {
        Subtype  = pdf_widget,
        T        = pdfunicode(specification.title),
        F        = fieldplus(specification),
        Ff       = fieldflag(specification),
        OC       = fieldlayer(specification),
        DA       = fieldsurrounding(specification),
        AA       = fieldactions(specification),
        FT       = pdf_tx,
        Q        = fieldalignment(specification),
        MaxLen   = length == 0 and 1000 or length,
        DV       = text,
        V        = text,
    }
    save_parent(field,specification,d)
end

local function makelinechild(name,specification)
    local field  = clones[name]
    local parent = nil
    if field then
        parent = fields[field.parent]
        if not parent.pobj then
            if trace_fields then
                report_fields("forcing parent text %a",parent.name)
            end
            makelineparent(parent,specification)
        end
    else
        parent = fields[name]
        field  = parent
        if not parent.pobj then
            if trace_fields then
                report_fields("using parent text %a",name)
            end
            makelineparent(parent,specification)
        end
    end
    if trace_fields then
        report_fields("using child text %a",name)
    end
    -- we could save a little by not setting some key/value when it's the
    -- same as parent but it would cost more memory to keep track of it
    local d = pdfdictionary {
        Subtype = pdf_widget,
        Parent  = pdfreference(parent.pobj),
        F       = fieldplus(specification),
        OC      = fieldlayer(specification),
        DA      = fieldsurrounding(specification),
        AA      = fieldactions(specification),
        MK      = fieldrendering(specification),
        Q       = fieldalignment(specification),
    }
    return save_kid(parent,specification,d)
end

function methods.line(name,specification)
    return makelinechild(name,specification)
end

function methods.text(name,specification)
    return makelinechild(name,enhance(specification,"MultiLine"))
end

-- copy of line ... probably also needs a /Lock

local function makesignatureparent(field,specification)
    local text   = pdfunicode(field.default)
    local length = tonumber(specification.length or 0) or 0
    local d      = pdfdictionary {
        Subtype  = pdf_widget,
        T        = pdfunicode(specification.title),
        F        = fieldplus(specification),
        Ff       = fieldflag(specification),
        OC       = fieldlayer(specification),
        DA       = fieldsurrounding(specification),
        AA       = fieldactions(specification),
        FT       = pdf_sig,
        Q        = fieldalignment(specification),
        MaxLen   = length == 0 and 1000 or length,
        DV       = text,
        V        = text,
    }
    save_parent(field,specification,d)
end

local function makesignaturechild(name,specification)
    local field  = clones[name]
    local parent = nil
    if field then
        parent = fields[field.parent]
        if not parent.pobj then
            if trace_fields then
                report_fields("forcing parent signature %a",parent.name)
            end
            makesignatureparent(parent,specification)
        end
    else
        parent = fields[name]
        field  = parent
        if not parent.pobj then
            if trace_fields then
                report_fields("using parent text %a",name)
            end
            makesignatureparent(parent,specification)
        end
    end
    if trace_fields then
        report_fields("using child text %a",name)
    end
    -- we could save a little by not setting some key/value when it's the
    -- same as parent but it would cost more memory to keep track of it
    local d = pdfdictionary {
        Subtype = pdf_widget,
        Parent  = pdfreference(parent.pobj),
        F       = fieldplus(specification),
        OC      = fieldlayer(specification),
        DA      = fieldsurrounding(specification),
        AA      = fieldactions(specification),
        MK      = fieldrendering(specification),
        Q       = fieldalignment(specification),
    }
    return save_kid(parent,specification,d)
end

function methods.signature(name,specification)
    return makesignaturechild(name,specification)
end
--

local function makechoiceparent(field,specification)
    local d = pdfdictionary {
        Subtype  = pdf_widget,
        T        = pdfunicode(specification.title),
        F        = fieldplus(specification),
        Ff       = fieldflag(specification),
        OC       = fieldlayer(specification),
        AA       = fieldactions(specification),
        FT       = pdf_ch,
        Opt      = fieldoptions(field), -- todo
    }
    save_parent(field,specification,d)
end

local function makechoicechild(name,specification)
    local field  = clones[name]
    local parent = nil
    if field then
        parent = fields[field.parent]
        if not parent.pobj then
            if trace_fields then
                report_fields("forcing parent choice %a",parent.name)
            end
            makechoiceparent(parent,specification,extras)
        end
    else
        parent = fields[name]
        field  = parent
        if not parent.pobj then
            if trace_fields then
                report_fields("using parent choice %a",name)
            end
            makechoiceparent(parent,specification,extras)
        end
    end
    if trace_fields then
        report_fields("using child choice %a",name)
    end
    local d = pdfdictionary {
        Subtype = pdf_widget,
        Parent  = pdfreference(parent.pobj),
        F       = fieldplus(specification),
        OC      = fieldlayer(specification),
        AA      = fieldactions(specification),
    }
    return save_kid(parent,specification,d) -- do opt here
end

function methods.choice(name,specification)
    return makechoicechild(name,specification)
end

function methods.popup(name,specification)
    return makechoicechild(name,enhance(specification,"PopUp"))
end

function methods.combo(name,specification)
    return makechoicechild(name,enhance(specification,"PopUp,Edit"))
end

local function makecheckparent(field,specification)
    local default = fieldstates_precheck(field)
    local d = pdfdictionary {
        T  = pdfunicode(specification.title), -- todo: when tracing use a string
        F  = fieldplus(specification),
        Ff = fieldflag(specification),
        OC = fieldlayer(specification),
        AA = fieldactions(specification), -- can be shared
        FT = pdf_btn,
        V  = fielddefault(field,default),
    }
    save_parent(field,specification,d,true)
end

local function makecheckchild(name,specification)
    local field  = clones[name]
    local parent = nil
    if field then
        parent = fields[field.parent]
        if not parent.pobj then
            if trace_fields then
                report_fields("forcing parent check %a",parent.name)
            end
            makecheckparent(parent,specification,extras)
        end
    else
        parent = fields[name]
        field  = parent
        if not parent.pobj then
            if trace_fields then
                report_fields("using parent check %a",name)
            end
            makecheckparent(parent,specification,extras)
        end
    end
    if trace_fields then
        report_fields("using child check %a",name)
    end
    local d = pdfdictionary {
        Subtype = pdf_widget,
        Parent  = pdfreference(parent.pobj),
        F       = fieldplus(specification),
        OC      = fieldlayer(specification),
        AA      = fieldactions(specification), -- can be shared
        H       = pdf_n,
    }
    local fontsymbol = specification.fontsymbol
    if fontsymbol and fontsymbol ~= "" then
        specification.fontsymbol = todingbat(fontsymbol)
        specification.fontstyle = "symbol"
        specification.fontalternative = "dingbats"
        d.DA = fieldsurrounding(specification)
        d.MK = fieldrendering(specification)
        return save_kid(parent,specification,d)
    else
        local appearance, default, value = fieldstates_check(field)
        d.AS = default
        d.AP = appearance
        return save_kid(parent,specification,d)
    end
end

function methods.check(name,specification)
    return makecheckchild(name,specification)
end

local function makepushparent(field,specification) -- check if we can share with the previous
    local d = pdfdictionary {
        Subtype = pdf_widget,
        T       = pdfunicode(specification.title),
        F       = fieldplus(specification),
        Ff      = fieldflag(specification),
        OC      = fieldlayer(specification),
        AA      = fieldactions(specification), -- can be shared
        FT      = pdf_btn,
        AP      = fieldappearances(field),
        H       = pdf_p,
    }
    save_parent(field,specification,d)
end

local function makepushchild(name,specification)
    local field, parent = clones[name], nil
    if field then
        parent = fields[field.parent]
        if not parent.pobj then
            if trace_fields then
                report_fields("forcing parent push %a",parent.name)
            end
            makepushparent(parent,specification)
        end
    else
        parent = fields[name]
        field = parent
        if not parent.pobj then
            if trace_fields then
                report_fields("using parent push %a",name)
            end
            makepushparent(parent,specification)
        end
    end
    if trace_fields then
        report_fields("using child push %a",name)
    end
    local fontsymbol = specification.fontsymbol
    local d = pdfdictionary {
        Subtype = pdf_widget,
        Parent  = pdfreference(field.pobj),
        F       = fieldplus(specification),
        OC      = fieldlayer(specification),
        AA      = fieldactions(specification), -- can be shared
        H       = pdf_p,
    }
    if fontsymbol and fontsymbol ~= "" then
        specification.fontsymbol = todingbat(fontsymbol)
        specification.fontstyle = "symbol"
        specification.fontalternative = "dingbats"
        d.DA = fieldsurrounding(specification)
        d.MK = fieldrendering(specification)
    else
        d.AP = fieldappearances(field)
    end
    return save_kid(parent,specification,d)
end

function methods.push(name,specification)
    return makepushchild(name,enhance(specification,"PushButton"))
end

local function makeradioparent(field,specification)
    specification = enhance(specification,"Radio,RadiosInUnison,Print,NoToggleToOff")
    local d = pdfdictionary {
        T  = field.name,
        FT = pdf_btn,
     -- F  = fieldplus(specification),
        Ff = fieldflag(specification),
     -- H  = pdf_n,
        V  = fielddefault(field),
    }
    save_parent(field,specification,d,true)
end

-- local function makeradiochild(name,specification)
--     local field  = clones[name]
--     local parent = nil
--     local pname  = nil
--     if field then
--         pname  = field.parent
--         field  = radios[pname]
--         parent = fields[pname]
--         if not parent.pobj then
--             if trace_fields then
--                 report_fields("forcing parent radio %a",parent.name)
--             end
--             makeradioparent(parent,parent)
--         end
--     else
--         field = radios[name]
--         if not field then
--             report_fields("there is some problem with field %a",name)
--             return nil
--         end
--         pname  = field.parent
--         parent = fields[pname]
--         if not parent.pobj then
--             if trace_fields then
--                 report_fields("using parent radio %a",name)
--             end
--             makeradioparent(parent,parent)
--         end
--     end
--     if trace_fields then
--         report_fields("using child radio %a with values %a and default %a",name,field.values,field.default)
--     end
--     local fontsymbol = specification.fontsymbol
--  -- fontsymbol = "circle"
--     local d = pdfdictionary {
--         Subtype = pdf_widget,
--         Parent  = pdfreference(parent.pobj),
--         F       = fieldplus(specification),
--         OC      = fieldlayer(specification),
--         AA      = fieldactions(specification),
--         H       = pdf_n,
-- -- H       = pdf_p,
-- -- P       = pdfpagereference(true),
--     }
--     if fontsymbol and fontsymbol ~= "" then
--         specification.fontsymbol = todingbat(fontsymbol)
--         specification.fontstyle = "symbol"
--         specification.fontalternative = "dingbats"
--         d.DA = fieldsurrounding(specification)
--         d.MK = fieldrendering(specification)
--         return save_kid(parent,specification,d) -- todo: what if no value
--     else
--         local appearance, default, value = fieldstates_radio(field,name,fields[pname])
--         d.AP = appearance
--         d.AS = default -- /Whatever
--         return save_kid(parent,specification,d,value)
--     end
-- end

local function makeradiochild(name,specification)
    local field, parent = clones[name], nil
    if field then
        field  = radios[field.parent]
        parent = fields[field.parent]
        if not parent.pobj then
            if trace_fields then
                report_fields("forcing parent radio %a",parent.name)
            end
            makeradioparent(parent,parent)
        end
    else
        field = radios[name]
        if not field then
            report_fields("there is some problem with field %a",name)
            return nil
        end
        parent = fields[field.parent]
        if not parent.pobj then
            if trace_fields then
                report_fields("using parent radio %a",name)
            end
            makeradioparent(parent,parent)
        end
    end
    if trace_fields then
        report_fields("using child radio %a with values %a and default %a",name,field.values,field.default)
    end
    local fontsymbol = specification.fontsymbol
 -- fontsymbol = "circle"
    local d = pdfdictionary {
        Subtype = pdf_widget,
        Parent  = pdfreference(parent.pobj),
        F       = fieldplus(specification),
        OC      = fieldlayer(specification),
        AA      = fieldactions(specification),
        H       = pdf_n,
    }
    if fontsymbol and fontsymbol ~= "" then
        specification.fontsymbol = todingbat(fontsymbol)
        specification.fontstyle = "symbol"
        specification.fontalternative = "dingbats"
        d.DA = fieldsurrounding(specification)
        d.MK = fieldrendering(specification)
    end
    local appearance, default, value = fieldstates_radio(field,name,fields[field.parent])
    d.AP = appearance
    d.AS = default -- /Whatever
-- d.MK = pdfdictionary { BC = pdfarray {0}, BG = pdfarray { 1 } }
d.BS = pdfdictionary { S = pdfconstant("I"), W = 1 }
    return save_kid(parent,specification,d,value)
end

function methods.sub(name,specification)
    return makeradiochild(name,enhance(specification,"Radio,RadiosInUnison"))
end
