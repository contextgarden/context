if not modules then modules = { } end modules ['scrn-fld'] = {
    version   = 1.001,
    comment   = "companion to scrn-fld.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- we should move some code from lpdf-fld to here

local context       = context
local ctx_doifelse  = commands.doifelse
local implement     = interfaces.implement

local variables     = interfaces.variables
local v_yes         = variables.yes

local report        = logs.reporter("widgets")

local texsetbox     = tex.setbox

local fields        = { }
interactions.fields = fields

local codeinjections = backends.codeinjections
local nodeinjections = backends.nodeinjections

local function define(specification)
    codeinjections.definefield(specification)
end

local function defineset(name,set)
    codeinjections.definefield(name,set)
end

local function clone(specification)
    codeinjections.clonefield(specification)
end

local function insert(name,specification)
    return nodeinjections.typesetfield(name,specification)
end

fields.define    = define
fields.defineset = defineset
fields.clone     = clone
fields.insert    = insert

-- codeinjections are not yet defined

implement {
    name      = "definefield",
    actions   = define,
    arguments = {
        {
            { "name" },
            { "alternative" },
            { "type" },
            { "category" },
            { "values" },
            { "default" },
        }
    }
}

implement {
    name      = "definefieldset",
    actions   = defineset,
    arguments = "2 strings",
}

implement {
    name      = "clonefield",
    actions   = clone,
    arguments = {
        {
            { "children" },
            { "alternative" },
            { "parent" },
            { "category" },
            { "values" },
            { "default" },
        }
    }
}

implement {
    name     = "insertfield",
    actions  = function(name,specification)
        local b = insert(name,specification)
        if b then
            texsetbox("b_scrn_field_body",b)
        else
            report("unknown field %a",name)
        end
    end,
    arguments = {
        "string",
        {
            { "title" },
            { "width", "dimen" },
            { "height", "dimen" },
            { "depth", "dimen" },
            { "align" },
            { "length" },
            { "fontstyle" },
            { "fontalternative" },
            { "fontsize" },
            { "fontsymbol" },
            { "colorvalue", "integer" },
            { "color" },
            { "backgroundcolorvalue", "integer" },
            { "backgroundcolor" },
            { "framecolorvalue", "integer" },
            { "framecolor" },
            { "layer" },
            { "option" },
            { "align" },
            { "clickin" },
            { "clickout" },
            { "regionin" },
            { "regionout" },
            { "afterkey" },
            { "format" },
            { "validate" },
            { "calculate" },
            { "focusin" },
            { "focusout" },
            { "openpage" },
            { "closepage" },
        }
    }
}

-- (for the monent) only tex interface

implement {
    name      = "getfieldcategory",
    arguments = "string",
    actions   = function(name)
        local g = codeinjections.getfieldcategory(name)
        if g then
            context(g)
        end
    end
}

implement {
    name      = "getdefaultfieldvalue",
    arguments = "string",
    actions   = function(name)
        local d = codeinjections.getdefaultfieldvalue(name)
        if d then
            context(d)
        end
    end
}

implement {
    name      = "exportformdata",
    arguments = "string",
    actions   = function(export)
        if export == v_yes then
            codeinjections.exportformdata()
        end
    end
}

implement {
    name      = "setformsmethod",
    arguments = "string",
    actions   = function(method)
        codeinjections.setformsmethod(method)
    end
}

implement {
    name      = "doifelsefieldcategory",
    arguments = "string",
    actions   = function(name)
        ctx_doifelse(codeinjections.validfieldcategory(name))
    end
}

implement {
    name      = "doiffieldsetelse",
    arguments = "string",
    actions   = function(name)
        ctx_doifelse(codeinjections.validfieldset(name))
    end
}
