if not modules then modules = { } end modules ['lpdf-ren'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- rendering

local tostring, tonumber, next = tostring, tonumber, next
local concat = table.concat
local formatters = string.formatters
local settings_to_array = utilities.parsers.settings_to_array
local getrandom = utilities.randomizer.get

local backends, lpdf, nodes, node = backends, lpdf, nodes, node

local nodeinjections      = backends.pdf.nodeinjections
local codeinjections      = backends.pdf.codeinjections
local registrations       = backends.pdf.registrations
local viewerlayers        = attributes.viewerlayers

local references          = structures.references

references.executers      = references.executers or { }
local executers           = references.executers

local variables           = interfaces.variables

local v_no                = variables.no
local v_yes               = variables.yes
local v_start             = variables.start
local v_stop              = variables.stop
local v_reset             = variables.reset
local v_auto              = variables.auto
local v_random            = variables.random

local pdfconstant         = lpdf.constant
local pdfdictionary       = lpdf.dictionary
local pdfarray            = lpdf.array
local pdfreference        = lpdf.reference
local pdfflushobject      = lpdf.flushobject
local pdfreserveobject    = lpdf.reserveobject

local addtopageattributes = lpdf.addtopageattributes
local addtopageresources  = lpdf.addtopageresources
local addtocatalog        = lpdf.addtocatalog

local escaped             = lpdf.escaped

local nuts                = nodes.nuts
local copy_node           = nuts.copy

local nodepool            = nuts.pool
local register            = nodepool.register
local pageliteral         = nodepool.pageliteral

local pdf_ocg             = pdfconstant("OCG")
local pdf_ocmd            = pdfconstant("OCMD")
local pdf_off             = pdfconstant("OFF")
local pdf_on              = pdfconstant("ON")
local pdf_view            = pdfconstant("View")
local pdf_design          = pdfconstant("Design")
local pdf_toggle          = pdfconstant("Toggle")
local pdf_setocgstate     = pdfconstant("SetOCGState")

local pdf_print = {
    [v_yes] = pdfdictionary { PrintState = pdf_on  },
    [v_no ] = pdfdictionary { PrintState = pdf_off },
}

local pdf_intent = {
    [v_yes] = pdf_view,
    [v_no]  = pdf_design,
}

local pdf_export = {
    [v_yes] = pdf_on,
    [v_no]  = pdf_off,
}

-- We can have references to layers before they are places, for instance from
-- hide and vide actions. This is why we need to be able to force usage of layers
-- at several moments.

-- management

local pdfln, pdfld = { }, { }
local textlayers, hidelayers, videlayers = pdfarray(), pdfarray(), pdfarray()
local pagelayers, pagelayersreference, cache = nil, nil, { }
local alphabetic = { }

local escapednames   = table.setmetatableindex(function(t,k)
    local v = escaped(k)
    t[k] = v
    return v
end)

local specifications = { }
local initialized    = { }

function codeinjections.defineviewerlayer(specification)
    if viewerlayers.supported and textlayers then
        local tag = specification.tag
        if not specifications[tag] then
            specifications[tag] = specification
        end
    end
end

local function useviewerlayer(name) -- move up so that we can use it as local
    if not environment.initex and not initialized[name] then
        local specification = specifications[name]
        if specification then
            specifications[name] = nil -- or not
            initialized   [name] = true
            if not pagelayers then
                pagelayers = pdfdictionary()
                pagelayersreference = pdfreserveobject()
            end
            local tag = specification.tag
            -- todo: reserve
            local nn = pdfreserveobject()
            local nr = pdfreference(nn)
            local nd = pdfdictionary {
                Type  = pdf_ocg,
                Name  = specification.title or "unknown",
                Usage = {
                    Intent = pdf_intent[specification.editable  or v_yes], -- disable layer hiding by user (useless)
                    Print  = pdf_print [specification.printable or v_yes], -- printable or not
                    Export = pdf_export[specification.export    or v_yes], -- export or not
                },
            }
            cache[#cache+1] = { nn, nd }
            pdfln[tag] = nr -- was n
            local dn = pdfreserveobject()
            local dr = pdfreference(dn)
            local dd = pdfdictionary {
                Type = pdf_ocmd,
                OCGs = pdfarray { nr },
            }
            cache[#cache+1] = { dn, dd }
            pdfld[tag] = dr
            textlayers[#textlayers+1] = nr
            alphabetic[tag] = nr
            if specification.visible == v_start then
                videlayers[#videlayers+1] = nr
            else
                hidelayers[#hidelayers+1] = nr
            end
            pagelayers[escapednames[tag]] = dr -- check
        else
            -- todo: message
        end
    end
end

codeinjections.useviewerlayer = useviewerlayer

local function layerreference(name)
    local r = pdfln[name]
    if r then
        return r
    else
        useviewerlayer(name)
        return pdfln[name]
    end
end

lpdf.layerreference = layerreference -- also triggered when a hide or vide happens

local function flushtextlayers()
    if viewerlayers.supported then
        if pagelayers then
            pdfflushobject(pagelayersreference,pagelayers)
        end
        for i=1,#cache do
            local ci = cache[i]
            pdfflushobject(ci[1],ci[2])
        end
        if textlayers and #textlayers > 0 then -- we can group them if needed, like: layout
            local sortedlayers = { }
            for k, v in table.sortedhash(alphabetic) do
                sortedlayers[#sortedlayers+1] = v -- maybe do a proper numeric sort as well
            end
            local d = pdfdictionary {
                OCGs = textlayers,
                D    = pdfdictionary {
                    Name      = "Document",
                 -- Order     = (viewerlayers.hasorder and textlayers) or nil,
                    Order     = (viewerlayers.hasorder and sortedlayers) or nil,
                    ON        = videlayers,
                    OFF       = hidelayers,
                    BaseState = pdf_on,
                    AS = pdfarray {
                        pdfdictionary {
                            Category = pdfarray { pdfconstant("Print") },
                            Event    = pdfconstant("Print"),
                            OCGs     = (viewerlayers.hasorder and sortedlayers) or nil,
                        }
                    },
                },
            }
            addtocatalog("OCProperties",d)
            textlayers = nil
        end
    end
end

local function flushpagelayers() -- we can share these
    if pagelayers then
        addtopageresources("Properties",pdfreference(pagelayersreference)) -- we could cache this
    end
end

lpdf.registerpagefinalizer    (flushpagelayers,"layers")
lpdf.registerdocumentfinalizer(flushtextlayers,"layers")

local function setlayer(what,arguments)
    -- maybe just a gmatch of even better, earlier in lpeg
    arguments = (type(arguments) == "table" and arguments) or settings_to_array(arguments)
    local state = pdfarray { what }
    for i=1,#arguments do
        local p = layerreference(arguments[i])
        if p then
            state[#state+1] = p
        end
    end
    return pdfdictionary {
        S     = pdf_setocgstate,
        State = state,
    }
end

function executers.hidelayer  (arguments) return setlayer(pdf_off,   arguments) end
function executers.videlayer  (arguments) return setlayer(pdf_on,    arguments) end
function executers.togglelayer(arguments) return setlayer(pdf_toggle,arguments) end

-- injection

local f_bdc = formatters["/OC /%s BDC"]
local s_emc = "EMC"

function codeinjections.startlayer(name) -- used in mp
    if not name then
        name = "unknown"
    end
    useviewerlayer(name)
    return f_bdc(escapednames[name])
end

function codeinjections.stoplayer(name) -- used in mp
    return s_emc
end

local cache = { }
local stop  = nil

function nodeinjections.startlayer(name)
    local c = cache[name]
    if not c then
        useviewerlayer(name)
        c = register(pageliteral(f_bdc(escapednames[name])))
        cache[name] = c
    end
    return copy_node(c)
end

function nodeinjections.stoplayer()
    if not stop then
        stop = register(pageliteral(s_emc))
    end
    return copy_node(stop)
end

-- experimental stacker code (slow, can be optimized): !!!! TEST CODE !!!!

local values     = viewerlayers.values
local startlayer = codeinjections.startlayer
local stoplayer  = codeinjections.stoplayer

function nodeinjections.startstackedlayer(s,t,first,last)
    local r = { }
    for i=first,last do
        r[#r+1] = startlayer(values[t[i]])
    end
    r = concat(r," ")
    return pageliteral(r)
end

function nodeinjections.stopstackedlayer(s,t,first,last)
    local r = { }
    for i=last,first,-1 do
        r[#r+1] = stoplayer()
    end
    r = concat(r," ")
    return pageliteral(r)
end

function nodeinjections.changestackedlayer(s,t1,first1,last1,t2,first2,last2)
    local r = { }
    for i=last1,first1,-1 do
        r[#r+1] = stoplayer()
    end
    for i=first2,last2 do
        r[#r+1] = startlayer(values[t2[i]])
    end
    r = concat(r," ")
    return pageliteral(r)
end

-- transitions

local pagetransitions = {
    {"split","in","vertical"}, {"split","in","horizontal"},
    {"split","out","vertical"}, {"split","out","horizontal"},
    {"blinds","horizontal"}, {"blinds","vertical"},
    {"box","in"}, {"box","out"},
    {"wipe","east"}, {"wipe","west"}, {"wipe","north"}, {"wipe","south"},
    {"dissolve"},
    {"glitter","east"}, {"glitter","south"},
    {"fly","in","east"}, {"fly","in","west"}, {"fly","in","north"}, {"fly","in","south"},
    {"fly","out","east"}, {"fly","out","west"}, {"fly","out","north"}, {"fly","out","south"},
    {"push","east"}, {"push","west"}, {"push","north"}, {"push","south"},
    {"cover","east"}, {"cover","west"}, {"cover","north"}, {"cover","south"},
    {"uncover","east"}, {"uncover","west"}, {"uncover","north"}, {"uncover","south"},
    {"fade"},
}

local mapping = {
    split      = { "S"  , pdfconstant("Split") },
    blinds     = { "S"  , pdfconstant("Blinds") },
    box        = { "S"  , pdfconstant("Box") },
    wipe       = { "S"  , pdfconstant("Wipe") },
    dissolve   = { "S"  , pdfconstant("Dissolve") },
    glitter    = { "S"  , pdfconstant("Glitter") },
    replace    = { "S"  , pdfconstant("R") },
    fly        = { "S"  , pdfconstant("Fly") },
    push       = { "S"  , pdfconstant("Push") },
    cover      = { "S"  , pdfconstant("Cover") },
    uncover    = { "S"  , pdfconstant("Uncover") },
    fade       = { "S"  , pdfconstant("Fade") },
    horizontal = { "Dm" , pdfconstant("H") },
    vertical   = { "Dm" , pdfconstant("V") },
    ["in"]     = { "M"  , pdfconstant("I") },
    out        = { "M"  , pdfconstant("O") },
    east       = { "Di" ,   0 },
    north      = { "Di" ,  90 },
    west       = { "Di" , 180 },
    south      = { "Di" , 270 },
}

local last = 0

-- n: number, "stop", "reset", "random", "a,b,c" delay: number, "none"

function codeinjections.setpagetransition(specification)
    local n, delay = specification.n, specification.delay
    if not n or n == "" then
        return -- let's forget about it
    elseif n == v_auto then
        if last >= #pagetransitions then
            last = 0
        end
        n = last + 1
    elseif n == v_stop then
        return
    elseif n == v_reset then
        last = 0
        return
    elseif n == v_random then
        n = getrandom("transition",1,#pagetransitions)
    else
        n = tonumber(n)
    end
    local t = n and pagetransitions[n] or pagetransitions[1]
    if not t then
        t = settings_to_array(n)
    end
    if t and #t > 0 then
        local d = pdfdictionary()
        for i=1,#t do
            local m = mapping[t[i]]
            d[m[1]] = m[2]
        end
        delay = tonumber(delay)
        if delay and delay > 0 then
            addtopageattributes("Dur",delay)
        end
        addtopageattributes("Trans",d)
    end
end
