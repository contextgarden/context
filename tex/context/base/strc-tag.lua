if not modules then modules = { } end modules ['strc-tag'] = {
    version   = 1.001,
    comment   = "companion to strc-tag.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is rather experimental code.

local type = type
local insert, remove, unpack, concat = table.insert, table.remove, table.unpack, table.concat
local gsub, find, topattern, format = string.gsub, string.find, string.topattern, string.format
local lpegmatch, P, S, C = lpeg.match, lpeg.P, lpeg.S, lpeg.C
local texattribute = tex.attribute
local allocate = utilities.storage.allocate
local settings_to_hash = utilities.parsers.settings_to_hash

local trace_tags = false  trackers.register("structures.tags", function(v) trace_tags = v end)

local report_tags = logs.reporter("structure","tags")

local attributes, structures = attributes, structures

local a_tagged       = attributes.private('tagged')

local unsetvalue     = attributes.unsetvalue
local codeinjections = backends.codeinjections

local taglist        = allocate()
local properties     = allocate()
local userproperties = allocate()
local labels         = allocate()
local stack          = { }
local chain          = { }
local ids            = { }
local enabled        = false
local tagdata        = { } -- used in export
local tagmetadata    = { } -- used in export
local tagcontext     = { }

local tags           = structures.tags
tags.taglist         = taglist -- can best be hidden
tags.labels          = labels
tags.data            = tagdata
tags.metadata        = tagmetadata
tags.userproperties  = userproperties -- used in backend

local properties     = allocate {

    document              = { pdf = "Div",        nature = "display" },

    division              = { pdf = "Div",        nature = "display" },
    paragraph             = { pdf = "P",          nature = "mixed"   },
    p                     = { pdf = "P",          nature = "mixed"   },
    construct             = { pdf = "Span",       nature = "inline"  },
    highlight             = { pdf = "Span",       nature = "inline"  },

    section               = { pdf = "Sect",       nature = "display" },
    sectiontitle          = { pdf = "H",          nature = "mixed"   },
    sectionnumber         = { pdf = "H",          nature = "mixed"   },
    sectioncontent        = { pdf = "Div",        nature = "display" },

    itemgroup             = { pdf = "L",          nature = "display" },
    item                  = { pdf = "LI",         nature = "display" },
    itemtag               = { pdf = "Lbl",        nature = "mixed"   },
    itemcontent           = { pdf = "LBody",      nature = "mixed"   },

    description           = { pdf = "Div",        nature = "display" },
    descriptiontag        = { pdf = "Div",        nature = "mixed"   },
    descriptioncontent    = { pdf = "Div",        nature = "mixed"   },
    descriptionsymbol     = { pdf = "Span",       nature = "inline"  }, -- note reference

    verbatimblock         = { pdf = "Code",       nature = "display" },
    verbatimlines         = { pdf = "Code",       nature = "display" },
    verbatimline          = { pdf = "Code",       nature = "mixed"   },
    verbatim              = { pdf = "Code",       nature = "inline"  },

    lines                 = { pdf = "Code",       nature = "display" },
    line                  = { pdf = "Code",       nature = "mixed"   },

    synonym               = { pdf = "Span",       nature = "inline"  },
    sorting               = { pdf = "Span",       nature = "inline"  },

    register              = { pdf = "Div",        nature = "display" },
    registersection       = { pdf = "Div",        nature = "display" },
    registertag           = { pdf = "Span",       nature = "mixed"   },
    registerentries       = { pdf = "Div",        nature = "display" },
    registerentry         = { pdf = "Div",        nature = "display" },
    registercontent       = { pdf = "Span",       nature = "mixed"   },
    registersee           = { pdf = "Span",       nature = "mixed"   },
    registerpages         = { pdf = "Span",       nature = "mixed"   },
    registerpage          = { pdf = "Span",       nature = "mixed"   },
    registerseparator     = { pdf = "Span",       nature = "inline"  },
    registerpagerange     = { pdf = "Span",       nature = "mixed"   },

    table                 = { pdf = "Table",      nature = "display" },
    tablerow              = { pdf = "TR",         nature = "display" },
    tablecell             = { pdf = "TD",         nature = "mixed"   },

    tabulate              = { pdf = "Table",      nature = "display" },
    tabulaterow           = { pdf = "TR",         nature = "display" },
    tabulatecell          = { pdf = "TD",         nature = "mixed"   },

    list                  = { pdf = "TOC",        nature = "display" },
    listitem              = { pdf = "TOCI",       nature = "display" },
    listtag               = { pdf = "Lbl",        nature = "mixed"   },
    listcontent           = { pdf = "P",          nature = "mixed"   },
    listdata              = { pdf = "P",          nature = "mixed"   },
    listpage              = { pdf = "Reference",  nature = "mixed"   },

    delimitedblock        = { pdf = "BlockQuote", nature = "display" },
    delimited             = { pdf = "Quote",      nature = "inline"  },
    subsentence           = { pdf = "Span",       nature = "inline"  },

    label                 = { pdf = "Span",       nature = "mixed"   },
    number                = { pdf = "Span",       nature = "mixed"   },

    float                 = { pdf = "Div",        nature = "display" }, -- Figure
    floatcaption          = { pdf = "Caption",    nature = "mixed"   },
    floatlabel            = { pdf = "Span",       nature = "inline"  },
    floatnumber           = { pdf = "Span",       nature = "inline"  },
    floattext             = { pdf = "Span",       nature = "mixed"   },
    floatcontent          = { pdf = "P",          nature = "mixed"   },

    image                 = { pdf = "P",          nature = "mixed"   },
    mpgraphic             = { pdf = "P",          nature = "mixed"   },

    formulaset            = { pdf = "Div",        nature = "display" },
    formula               = { pdf = "Div",        nature = "display" }, -- Formula
    formulacaption        = { pdf = "Span",       nature = "mixed"   },
    formulalabel          = { pdf = "Span",       nature = "mixed"   },
    formulanumber         = { pdf = "Span",       nature = "mixed"   },
    formulacontent        = { pdf = "P",          nature = "display" },
    subformula            = { pdf = "Div",        nature = "display" },

    link                  = { pdf = "Link",       nature = "inline"  },

    margintextblock       = { pdf = "Span",       nature = "inline"  },
    margintext            = { pdf = "Span",       nature = "inline"  },

    math                  = { pdf = "Div",        nature = "inline"  }, -- no display
    mn                    = { pdf = "Span",       nature = "mixed"   },
    mi                    = { pdf = "Span",       nature = "mixed"   },
    mo                    = { pdf = "Span",       nature = "mixed"   },
    ms                    = { pdf = "Span",       nature = "mixed"   },
    mrow                  = { pdf = "Span",       nature = "display" },
    msubsup               = { pdf = "Span",       nature = "display" },
    msub                  = { pdf = "Span",       nature = "display" },
    msup                  = { pdf = "Span",       nature = "display" },
    merror                = { pdf = "Span",       nature = "mixed"   },
    munderover            = { pdf = "Span",       nature = "display" },
    munder                = { pdf = "Span",       nature = "display" },
    mover                 = { pdf = "Span",       nature = "display" },
    mtext                 = { pdf = "Span",       nature = "mixed"   },
    mfrac                 = { pdf = "Span",       nature = "display" },
    mroot                 = { pdf = "Span",       nature = "display" },
    msqrt                 = { pdf = "Span",       nature = "display" },
    mfenced               = { pdf = "Span",       nature = "display" },
    maction               = { pdf = "Span",       nature = "display" },

    mtable                = { pdf = "Table",      nature = "display" }, -- might change
    mtr                   = { pdf = "TR",         nature = "display" }, -- might change
    mtd                   = { pdf = "TD",         nature = "display" }, -- might change

    ignore                = { pdf = "Span",       nature = "mixed"   },
    metadata              = { pdf = "Div",        nature = "display" },
    metavariable          = { pdf = "Span",       nature = "mixed"   },

    mid                   = { pdf = "Span",       nature = "inline"  },
    sub                   = { pdf = "Span",       nature = "inline"  },
    sup                   = { pdf = "Span",       nature = "inline"  },
    subsup                = { pdf = "Span",       nature = "inline"  },

    combination           = { pdf = "Span",       nature = "display" },
    combinationpair       = { pdf = "Span",       nature = "display" },
    combinationcontent    = { pdf = "Span",       nature = "mixed"   },
    combinationcaption    = { pdf = "Span",       nature = "mixed"   },
}

function tags.detailedtag(tag,detail,attribute)
    if not attribute then
        attribute = texattribute[a_tagged]
    end
    if attribute >= 0 then
        local tl = taglist[attribute]
        if tl then
            local pattern
            if detail and detail ~= "" then
                pattern = "^" .. tag .. ":".. detail .. "%-"
            else
                pattern = "^" .. tag .. "%-"
            end
            for i=#tl,1,-1 do
                local tli = tl[i]
                if find(tli,pattern) then
                    return tli
                end
            end
        end
    else
        -- enabled but not auto
    end
    return false -- handy as bogus index
end

tags.properties = properties

local lasttags = { }
local userdata = { }

tags.userdata  = userdata

function tags.setproperty(tag,key,value)
    local p = properties[tag]
    if p then
        p[key] = value
    else
        properties[tag] = { [key] = value }
    end
end

function tags.registerdata(data)
    local fulltag = chain[nstack]
    if fulltag then
        tagdata[fulltag] = data
    end
end

local metadata

function tags.registermetadata(data)
    local d = settings_to_hash(data)
    if metadata then
        table.merge(metadata,d)
    else
        metadata = d
    end
end

local nstack = 0

function tags.start(tag,specification)
    local label, detail, user
    if specification then
        label  = specification.label
        detail = specification.detail
        user   = specification.userdata
    end
    if not enabled then
        codeinjections.enabletags()
        enabled = true
    end
    --
    local fulltag = label ~= "" and label or tag
    labels[tag] = fulltag
    if detail and detail ~= "" then
        fulltag = fulltag .. ":" .. detail
    end
    --
    local t = #taglist + 1
    local n = (ids[fulltag] or 0) + 1
    ids[fulltag] = n
    lasttags[tag] = n
    local completetag = fulltag .. "-" .. n
    nstack = nstack + 1
    chain[nstack] = completetag
    stack[nstack] = t
    --
    tagcontext[tag] = completetag
    --
    -- a copy as we can add key values for alt and actualtext if needed:
    taglist[t] = { unpack(chain,1,nstack) }
    --
    if user and user ~= "" then
        -- maybe we should merge this into taglist or whatever ... anyway there is room to optimize
        -- taglist.userdata = settings_to_hash(user)
        userdata[completetag] = settings_to_hash(user)
    end
    if metadata then
        tagmetadata[completetag] = metadata
        metadata = nil
    end
    texattribute[a_tagged] = t
    return t
end

function tags.restart(completetag)
    local t = #taglist + 1
    nstack = nstack + 1
    chain[nstack] = completetag
    stack[nstack] = t
    taglist[t] = { unpack(chain,1,nstack) }
    texattribute[a_tagged] = t
    return t
end

function tags.stop()
    if nstack > 0 then
        nstack = nstack -1
    end
    local t = stack[nstack]
    if not t then
        if trace_tags then
            report_tags("ignoring end tag, previous chain: %s",nstack > 0 and concat(chain[nstack],"",1,nstack) or "none")
        end
        t = unsetvalue
    end
    texattribute[a_tagged] = t
    return t
end

function tags.getid(tag,detail)
    if detail and detail ~= "" then
        return ids[tag .. ":" .. detail] or "?"
    else
        return ids[tag] or "?"
    end
end

function tags.last(tag)
    return lasttags[tag] -- or false
end

function tags.lastinchain(tag)
    if tag and tag ~= "" then
        return tagcontext[tag]
    else
        return chain[nstack]
    end
end

local strip = C((1-S(":-"))^1)

commands.getelementtag = function()
    local fulltag = chain[nstack]
    if fulltag then
        context(lpegmatch(strip,fulltag))
    end
end

function tags.setuserproperties(tag,list)
    if list then
        tag = tagcontext[tag]
    else
        tag, list = chain[nstack], tag
    end
    if tag then
        local l = settings_to_hash(list)
        local p = userproperties[tag]
        if p then
            for k, v in next, l do
                p[k] = v
            end
        else
           userproperties[tag] = l
        end
    end
end

commands.setelementuserproperties = tags.setuserproperties

function structures.atlocation(str)
    local location = gsub(concat(taglist[texattribute[a_tagged]],"-"),"%-%d+","")
    return find(location,topattern(str)) ~= nil
end

function tags.handler(head)  -- we need a dummy
    return head, false
end

statistics.register("structure elements", function()
    if enabled then
        if nstack > 0 then
            return format("%s element chains identified, open chain: %s ",#taglist,concat(chain," => ",1,nstack))
        else
            return format("%s element chains identified",#taglist)
        end
    end
end)

directives.register("backend.addtags", function(v)
    if not enabled then
        codeinjections.enabletags()
        enabled = true
    end
end)

commands.starttag       = tags.start
commands.stoptag        = tags.stop
commands.settagproperty = tags.setproperty
