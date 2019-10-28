if not modules then modules = { } end modules ['strc-tag'] = {
    version   = 1.001,
    comment   = "companion to strc-tag.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is rather experimental code. Tagging happens on the fly and there are two analysers
-- involved: the pdf backend tagger and the exporter. They share data but there are subtle
-- differences. Each tag carries a specification and these can be accessed by attribute (the
-- end of the chain tag) or by so called fullname which is a tagname combined with a number.

local type, next = type, next
local insert, remove, unpack, concat, merge = table.insert, table.remove, table.unpack, table.concat, table.merge
local find, topattern, format = string.find, string.topattern, string.format
local lpegmatch, P, S, C, Cc = lpeg.match, lpeg.P, lpeg.S, lpeg.C, lpeg.Cc
local allocate = utilities.storage.allocate
local settings_to_hash = utilities.parsers.settings_to_hash
local setmetatableindex = table.setmetatableindex

local trace_tags = false  trackers.register("structures.tags", function(v) trace_tags = v end)

local report_tags = logs.reporter("structure","tags")

local attributes      = attributes
local structures      = structures
local implement       = interfaces.implement

local a_tagged        = attributes.private('tagged')

local unsetvalue      = attributes.unsetvalue
local codeinjections  = backends.codeinjections

local texgetattribute = tex.getattribute
local texsetattribute = tex.setattribute

local taglist         = allocate() -- access by attribute
local specifications  = allocate() -- access by fulltag
local labels          = allocate()
local stack           = { }
local chain           = { }
local ids             = { }
local enabled         = false
local tagcontext      = { }
local tagpatterns     = { }
local lasttags        = { }
local stacksize       = 0
local metadata        = nil -- applied to the next element
local documentdata    = { }
local extradata       = false

local tags            = structures.tags
tags.taglist          = taglist -- can best be hidden
tags.labels           = labels
tags.patterns         = tagpatterns
tags.specifications   = specifications

function tags.current()
    if stacksize > 0 then
        return stack[stacksize] -- maybe copy or proxy
    end
end

-- Tags are internally stored as:
--
-- tag>number tag>number tag>number

local p_splitter     = C((1-S(">"))^1) * P(">") * C(P(1)^1)
tagpatterns.splitter = p_splitter

local properties     = allocate { -- todo: more "record = true" to improve formatting

    document              = { pdf = "Div",        nature = "display" },

    division              = { pdf = "Div",        nature = "display" },
    paragraph             = { pdf = "P",          nature = "mixed"   },
    p                     = { pdf = "P",          nature = "mixed"   },
    construct             = { pdf = "Span",       nature = "inline"  },
    highlight             = { pdf = "Span",       nature = "inline"  },

    section               = { pdf = "Sect",       nature = "display" },
    sectioncaption        = { pdf = "Div",        nature = "display", record = true },
    sectiontitle          = { pdf = "H",          nature = "mixed"   },
    sectionnumber         = { pdf = "H",          nature = "mixed"   },
    sectioncontent        = { pdf = "Div",        nature = "display" },

    itemgroup             = { pdf = "L",          nature = "display" },
    item                  = { pdf = "LI",         nature = "display" },
    itemtag               = { pdf = "Lbl",        nature = "mixed"   },
    itemcontent           = { pdf = "LBody",      nature = "mixed"   },
    itemhead              = { pdf = "Div",        nature = "display" },
    itembody              = { pdf = "Div",        nature = "display" },

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
    registerlocation      = { pdf = "Span",       nature = "inline"  },
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
    tableheadcell         = { pdf = "TH",         nature = "mixed"   },
    tablehead             = { pdf = "THEAD",      nature = "display" },
    tablebody             = { pdf = "TBODY",      nature = "display" },
    tablefoot             = { pdf = "TFOOT",      nature = "display" },

    tabulate              = { pdf = "Table",      nature = "display" },
    tabulaterow           = { pdf = "TR",         nature = "display" },
    tabulatecell          = { pdf = "TD",         nature = "mixed"   },
    tabulateheadcell      = { pdf = "TH",         nature = "mixed"   },
    tabulatehead          = { pdf = "THEAD",      nature = "display" },
    tabulatebody          = { pdf = "TBODY",      nature = "display" },
    tabulatefoot          = { pdf = "TFOOT",      nature = "display" },

    list                  = { pdf = "TOC",        nature = "display" },
    listitem              = { pdf = "TOCI",       nature = "display" },
    listtag               = { pdf = "Lbl",        nature = "mixed"   },
    listcontent           = { pdf = "P",          nature = "mixed"   },
    listdata              = { pdf = "P",          nature = "mixed"   },
    listpage              = { pdf = "Reference",  nature = "mixed"   },
    listtext              = { pdf = "Span",       nature = "inline"  },

    delimitedblock        = { pdf = "BlockQuote", nature = "display" },
    delimited             = { pdf = "Quote",      nature = "inline"  },
    delimitedcontent      = { pdf = "Span",       nature = "inline"  },
    delimitedsymbol       = { pdf = "Span",       nature = "inline"  },
    subsentence           = { pdf = "Span",       nature = "inline"  },
    subsentencecontent    = { pdf = "Span",       nature = "inline"  },
    subsentencesymbol     = { pdf = "Span",       nature = "inline"  },

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
    reference             = { pdf = "Span",       nature = "inline"  },

    margintextblock       = { pdf = "Span",       nature = "inline"  },
    margintext            = { pdf = "Span",       nature = "inline"  },
    marginanchor          = { pdf = "Span",       nature = "inline"  },

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

    mstacker              = { pdf = "Span",       nature = "display" }, -- these are only internally used
    mstackertop           = { pdf = "Span",       nature = "display" }, -- these are only internally used
    mstackerbot           = { pdf = "Span",       nature = "display" }, -- these are only internally used
    mstackermid           = { pdf = "Span",       nature = "display" }, -- these are only internally used

    mtable                = { pdf = "Table",      nature = "display" }, -- might change
    mtr                   = { pdf = "TR",         nature = "display" }, -- might change
    mtd                   = { pdf = "TD",         nature = "display" }, -- might change

    ignore                = { pdf = "Span",       nature = "mixed"   }, -- used internally
    private               = { pdf = "Span",       nature = "mixed"   }, -- for users (like LS) when they need it
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

    publications          = { pdf = "Div",        nature = "display" },
    publication           = { pdf = "Div",        nature = "mixed"   },
    pubfld                = { pdf = "Span",       nature = "inline"  },

    block                 = { pdf = "Div",        nature = "display"  },
    userdata              = { pdf = "Div",        nature = "display"  },

}

tags.properties = properties

local patterns = setmetatableindex(function(t,tag)
    local v = topattern("^" .. tag .. ">")
    t[tag] = v
    return v
end)

function tags.locatedtag(tag)
    local attribute = texgetattribute(a_tagged)
    if attribute >= 0 then
        local specification = taglist[attribute]
        if specification then
            local taglist = specification.taglist
            local pattern = patterns[tag]
            for i=#taglist,1,-1 do
                local t = taglist[i]
                if find(t,pattern) then
                    return t
                end
            end
        end
    else
        -- enabled but not auto
    end
    return false -- handy as bogus index
end

function structures.atlocation(str)
    local specification = taglist[texgetattribute(a_tagged)]
    if specification then
        if list then
            local taglist = specification.taglist
            local pattern = patterns[str]
            for i=#list,1,-1 do
                if find(list[i],pattern) then
                    return true
                end
            end
        end
    end
end

function tags.setproperty(tag,key,value)
    local p = properties[tag]
    if p then
        p[key] = value
    else
        properties[tag] = { [key] = value }
    end
end

function tags.setaspect(key,value)
    local tag = chain[stacksize]
    if tag then
        local p = properties[tag]
        if p then
            p[key] = value
        else
            properties[tag] = { [key] = value }
        end
    end
end

function tags.registermetadata(data)
    local d = settings_to_hash(data)
    if #chain > 1 then
        if metadata then
            merge(metadata,d)
        else
            metadata = d
        end
    else
        merge(documentdata,d)
    end
end

function tags.getmetadata()
    return documentdata or { }
end

function tags.registerextradata(name,serializer)
    if type(serializer) == "function" then
        if extradata then
            extradata[name] = serializer
        else
            extradata = { [name] = serializer }
        end
    end
end

function tags.getextradata()
    return extradata
end

function tags.start(tag,specification)
    if not enabled then
        codeinjections.enabletags()
        enabled = true
    end
    --
    labels[tag] = tag -- can go away
    --
    local attribute = #taglist + 1
    local tagindex  = (ids[tag] or 0) + 1
    --
    local completetag = tag .. ">" .. tagindex
    --
    ids[tag]      = tagindex
    lasttags[tag] = tagindex
    stacksize     = stacksize + 1
    --
    chain[stacksize] = completetag
    stack[stacksize] = attribute
    tagcontext[tag]  = completetag
    --
    local tagnesting = { unpack(chain,1,stacksize) } -- a copy so we can add actualtext
    --
    if specification then
        specification.attribute = attribute
        specification.tagindex  = tagindex
        specification.taglist   = tagnesting
        specification.tagname   = tag
        if metadata then
            specification.metadata = metadata
            metadata = nil
        end
        local userdata = specification.userdata
        if userdata ~= "" and type(userdata) == "string"  then
            specification.userdata = settings_to_hash(userdata)
        end
        local detail = specification.detail
        if detail == "" then
            specification.detail = nil
        end
        local parents = specification.parents
        if parents == "" then
            specification.parents = nil
        end
    else
        specification = {
            attribute = attribute,
            tagindex  = tagindex,
            taglist   = tagnesting,
            tagname   = tag,
            metadata  = metadata,
        }
        metadata = nil
    end
    --
    taglist[attribute]          = specification
    specifications[completetag] = specification
    --
    if completetag == "document>1" then
        specification.metadata = documentdata
    end
    --
    texsetattribute(a_tagged,attribute)
    return attribute
end

function tags.restart(attribute)
    stacksize = stacksize + 1
    if type(attribute) == "number" then
        local taglist = taglist[attribute].taglist
        chain[stacksize] = taglist[#taglist]
    else
        chain[stacksize] = attribute -- a string
        attribute = #taglist + 1
        taglist[attribute] = { taglist = { unpack(chain,1,stacksize) } }
    end
    stack[stacksize] = attribute
    texsetattribute(a_tagged,attribute)
    return attribute
end

function tags.stop()
    if stacksize > 0 then
        stacksize = stacksize - 1
    end
    local t = stack[stacksize]
    if not t then
        if trace_tags then
            report_tags("ignoring end tag, previous chain: %s",stacksize > 0 and concat(chain," ",1,stacksize) or "none")
        end
        t = unsetvalue
    end
    texsetattribute(a_tagged,t)
    return t
end

function tags.getid(tag,detail)
    return ids[tag] or "?"
end

function tags.last(tag)
    return lasttags[tag] -- or false
end

function tags.lastinchain(tag)
    if tag and tag ~= "" then
        return tagcontext[tag]
    else
        return chain[stacksize]
    end
end

local strip = C((1-S(">"))^1)

function tags.elementtag()
    local fulltag = chain[stacksize]
    if fulltag then
        return lpegmatch(strip,fulltag)
    end
end

function tags.strip(fulltag)
    return lpegmatch(strip,fulltag)
end

function tags.setuserproperties(tag,list)
    if not list or list == "" then
        tag, list = chain[stacksize], tag
    else
        tag = tagcontext[tag]
    end
    if tag then -- an attribute now
        local l = settings_to_hash(list)
        local s = specifications[tag]
        if s then
            local u = s.userdata
            if u then
                for k, v in next, l do
                    u[k] = v
                end
            else
                s.userdata = l
            end
        else
           -- error
        end
    end
end

function tags.handler(head)  -- we need a dummy
    return head, false
end

statistics.register("structure elements", function()
    if enabled then
        if stacksize > 0 then
            return format("%s element chains identified, open chain: %s ",#taglist,concat(chain," => ",1,stacksize))
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

-- interface

local starttag = tags.start

implement {
    name      = "starttag",
    actions   = starttag,
    arguments = "string",
}

implement {
    name      = "stoptag",
    actions   = tags.stop,
}

implement {
    name      = "starttag_u",
    scope     = "private",
    actions   = function(tag,userdata) starttag(tag,{ userdata = userdata }) end,
    arguments = "2 strings",
}

implement {
    name      = "starttag_d",
    scope     = "private",
    actions   = function(tag,detail) starttag(tag,{ detail = detail }) end,
    arguments = "2 strings",
}

implement {
    name      = "starttag_c",
    scope     = "private",
    actions   = function(tag,detail,parents) starttag(tag,{ detail = detail, parents = parents }) end,
    arguments = "3 strings",
}

implement { name = "settagaspect",     actions = tags.setaspect,   arguments = "2 strings" }
implement { name = "settagproperty",   actions = tags.setproperty, arguments = "3 strings" }
implement { name = "settagproperty_b", actions = tags.setproperty, arguments = { "string", "'backend'", "string" }, scope = "private" }
implement { name = "settagproperty_n", actions = tags.setproperty, arguments = { "string", "'nature'",  "string" }, scope = "private" }

implement { name = "getelementtag",    actions = { tags.elementtag, context } }

implement {
    name      = "setelementuserproperties",
    scope     = "private",
    actions   = tags.setuserproperties,
    arguments = "2 strings",
}

implement {
    name      = "doifelseinelement",
    actions   = { structures.atlocation, commands.testcase },
    arguments = "string",
}

implement {
    name      = "settaggedmetadata",
    actions   = tags.registermetadata,
    arguments = "string",
}
