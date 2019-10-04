if not modules then modules = { } end modules ['mlib-lmp'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local aux       = mp.aux
local mpnumeric = aux.numeric
local mppair    = aux.pair
local mpquoted  = aux.quoted
local mpdirect  = aux.direct

-- todo: use a stack?

do

    local p = nil
    local n = 0

    local function mf_path_reset()
        p = nil
        n = 0
    end

    if CONTEXTLMTXMODE > 0 then

        local scan       = mp.scan
        local scannumber = scan.number
        local scanpath   = scan.path

        local function mf_path_length()
            p = scanpath()
            n = p and #p or 1
            mpnumeric(n)
        end

        local function mf_path_point()
            local i = scannumber()
            if i > 0 and i <= n then
                local pi = p[i]
                mppair(pi[1],pi[2])
            end
        end

        local function mf_path_left()
            local i = scannumber()
            if i > 0 and i <= n then
                local pi = p[i]
                mppair(pi[5],pi[6])
            end
        end

        local function mf_path_right()
            local i = scannumber()
            if i > 0 and i <= n then
                local pn
                if i == 1 then
                    pn = p[2] or p[1]
                else
                    pn = p[i+1] or p[1]
                end
                mppair(pn[3],pn[4])
            end
        end

        local registerscript = metapost.registerscript

        registerscript("pathreset",    mf_path_reset)
        registerscript("pathlengthof", mf_path_length)
        registerscript("pathpointof",  mf_path_point)
        registerscript("pathleftof",   mf_path_left)
        registerscript("pathrightof",  mf_path_right)

    else

        local get       = mp.get
        local mpgetpath = get.path

        local function mf_path_length(name)
            p = mpgetpath(name)
            n = p and #p or 0
            mpnumeric(n)
        end

        local function mf_path_point(i)
            if i > 0 and i <= n then
                local pi = p[i]
                mppair(pi[1],pi[2])
            end
        end

        local function mf_path_left(i)
            if i > 0 and i <= n then
                local pi = p[i]
                mppair(pi[5],pi[6])
            end
        end

        local function mf_path_right(i)
            if i > 0 and i <= n then
                local pn
                if i == 1 then
                    pn = p[2] or p[1]
                else
                    pn = p[i+1] or p[1]
                end
                mppair(pn[3],pn[4])
            end
        end

        mp.mf_path_length = mf_path_length   mp.pathlength = mf_path_length
        mp.mf_path_point  = mf_path_point    mp.pathpoint  = mf_path_point
        mp.mf_path_left   = mf_path_left     mp.pathleft   = mf_path_left
        mp.mf_path_right  = mf_path_right    mp.pathright  = mf_path_right
        mp.mf_path_reset  = mf_path_reset    mp.pathreset  = mf_path_reset

    end

end

do

    -- if needed we can optimize the sub (cache last split)

    local utflen, utfsub = utf.len, utf.sub

    function mp.utflen(s)
        mpnumeric(utflen(s))
    end

    function mp.utfsub(s,f,t)
        mpquoted(utfsub(s,f,t or f))
    end

end

function mp.lmt_svg_include()
    local filename = metapost.getparameter { "filename" }
    local fontname = metapost.getparameter { "fontname" }
    local metacode = nil
    if fontname and fontname ~= "" then
        local unicode = metapost.getparameter { "unicode" }
        if unicode then
            metacode = metapost.svgglyphtomp(fontname,math.round(unicode))
        end
    elseif filename and filename ~= "" then
        metacode = metapost.svgtomp {
            data = io.loaddata(filename)
        }
    end
    if metacode then
        mpdirect(metacode)
    end
end

if CONTEXTLMTXMODE > 0 then

    local dropins        = fonts.dropins
    local registerglyphs = dropins.registerglyphs
    local registerglyph  = dropins.registerglyph

    function mp.lmt_register_glyph()
        registerglyph(metapost.getparameterset("mpsglyph"))
    end

    function mp.lmt_register_glyphs()
        registerglyphs(metapost.getparameterset("mpsglyphs"))
    end

end
