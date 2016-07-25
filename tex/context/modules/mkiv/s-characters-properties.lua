if not modules then modules = { } end modules ['s-characters-properties'] = {
    version   = 1.001,
    comment   = "companion to s-characters-properties.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.characters            = moduledata.characters            or { }
moduledata.characters.properties = moduledata.characters.properties or { }

local catcodenames = { [0] =
    "escape",    "begingroup", "endgroup",  "mathshift",
    "alignment", "endofline",  "parameter", "superscript",
    "subscript", "ignore",     "space",     "letter",
    "other",     "active",     "comment",   "invalid",
}

table.swapped(catcodes,catcodes)

local catcodes   = context.catcodes
local getcatcode = tex.getcatcode
local c_context  = catcodes.context
local c_tex      = catcodes.tex
local c_protect  = catcodes.protect
local c_text     = catcodes.text
local c_verbatim = catcodes.verbatim

local context      = context
local ctx_NC       = context.NC
local ctx_NR       = context.NR
local ctx_MR       = context.MR
local ctx_ML       = context.ML
local ctx_bold     = context.bold
local ctx_verbatim = context.verbatim

function moduledata.characters.properties.showcatcodes(specification)

    local function range(f,l,quit)
        if quit then
            ctx_MR()
        end
        for i=f,l do
            ctx_NC()
            if quit then
                ctx_verbatim("%c .. %c",f,l)
            else
                ctx_verbatim("%c",i)
            end
            ctx_NC() context(catcodenames[getcatcode(c_tex,i)])
            ctx_NC() context(catcodenames[getcatcode(c_context,i)])
            ctx_NC() context(catcodenames[getcatcode(c_protect,i)])
            ctx_NC() context(catcodenames[getcatcode(c_text,i)])
            ctx_NC() context(catcodenames[getcatcode(c_verbatim,i)])
            ctx_NC() ctx_NR()
            if quit then
                ctx_MR()
                break
            end
        end
    end

    context.starttabulate { "|c|c|c|c|c|c|" }
        ctx_ML()
        ctx_NC() ctx_bold("ascii")
        ctx_NC() ctx_bold("context")
        ctx_NC() ctx_bold("tex")
        ctx_NC() ctx_bold("protect")
        ctx_NC() ctx_bold("text")
        ctx_NC() ctx_bold("verbatim")
        ctx_NC() ctx_NR()
        ctx_ML()
        range(32,47)
        range(48,57,true)
        range(58,64)
        range(65,90,true)
        range(91,96)
        range(97,122,true)
        range(123,126)
        ctx_ML()
    context.stoptabulate()

end
