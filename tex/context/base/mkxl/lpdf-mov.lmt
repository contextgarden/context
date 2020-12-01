if not modules then modules = { } end modules ['lpdf-mov'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

local lpdf               = lpdf
local context            = context

local nodeinjections     = backends.pdf.nodeinjections
local pdfconstant        = lpdf.constant
local pdfdictionary      = lpdf.dictionary
local pdfarray           = lpdf.array
local pdfborder          = lpdf.border
local write_node         = node.write

function nodeinjections.insertmovie(specification)
    -- managed in figure inclusion: width, height, factor, repeat, controls, preview, label, foundname
    local width  = specification.width
    local height = specification.height
    local factor = specification.factor or number.dimenfactors.bp
    local moviedict = pdfdictionary {
        F      = specification.foundname,
        Aspect = pdfarray { factor * width, factor * height },
        Poster = (specification.preview and true) or false,
    }
    local controldict = pdfdictionary {
        ShowControls = (specification.controls and true) or false,
        Mode         = (specification["repeat"] and pdfconstant("Repeat")) or nil,
    }
    local bs, bc = pdfborder()
    local action = pdfdictionary {
        Subtype = pdfconstant("Movie"),
        Border  = bs,
        C       = bc,
        T       = format("movie %s",specification.label),
        Movie   = moviedict,
        A       = controldict,
    }
    write_node(nodeinjections.annotation(width,height,0,action())) -- test: context(...)
end

function nodeinjections.insertsound(specification)
    -- managed in interaction: repeat, label, foundname
    local soundclip = interactions.soundclips.soundclip(specification.label)
    if soundclip then
        local controldict = pdfdictionary {
            Mode = (specification["repeat"] and pdfconstant("Repeat")) or nil
        }
        local sounddict = pdfdictionary {
            F = soundclip.filename
        }
        local bs, bc = pdfborder()
        local action = pdfdictionary {
            Subtype = pdfconstant("Movie"),
            Border  = bs,
            C       = bc,
            T       = format("sound %s",specification.label),
            Movie   = sounddict,
            A       = controldict,
        }
        write_node(nodeinjections.annotation(0,0,0,action())) -- test: context(...)
    end
end
