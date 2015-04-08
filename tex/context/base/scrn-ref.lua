if not modules then modules = { } end modules ['scrn-ref'] = {
    version   = 1.001,
    comment   = "companion to scrn-int.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

interactions            = interactions or { }
interactions.references = interactions.references or { }
local references        = interactions.references

local codeinjections    = backends.codeinjections

local expandcurrent     = structures.references.expandcurrent
local identify          = structures.references.identify

local implement         = interfaces.implement

local function check(what)
    if what and what ~= "" then
        local set, bug = identify("",what)
        return not bug and #set > 0 and set
    end
end

local function setopendocumentaction(open)
    local opendocument = check(open)
    if opendocument then
        codeinjections.registerdocumentopenaction(opendocument)
        expandcurrent()
    end
end

local function setclosedocumentaction(close)
    local closedocument = check(close)
    if closedocument then
        codeinjections.registerdocumentcloseaction(closedocument)
        expandcurrent()
    end
end

local function setopenpageaction(open)
    local openpage = check(open)
    if openpage then
        codeinjections.registerpageopenaction(openpage)
        expandcurrent()
    end
end

local function setclosepageaction(close)
    local closepage = check(close)
    if closepage then
        codeinjections.registerpagecloseaction(closepage)
        expandcurrent()
    end
end

references.setopendocument  = setopendocumentaction
references.setclosedocument = setclosedocumentaction
references.setopenpage      = setopenpageaction
references.setclosepage     = setclosepageaction

implement { name = "setopendocumentaction",  arguments = "string", actions = setopendocumentaction }
implement { name = "setclosedocumentaction", arguments = "string", actions = setclosedocumentaction }
implement { name = "setopenpageaction",      arguments = "string", actions = setopenpageaction }
implement { name = "setclosepageaction",     arguments = "string", actions = setclosepageaction }
