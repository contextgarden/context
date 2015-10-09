if not modules then modules = { } end modules ['font-off'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lower             = string.lower
local round             = math.round
local setmetatableindex = table.setmetatableindex

local fontloader        = fontloader
local font_to_table     = fontloader.to_table
local open_font         = fontloader.open
local get_font_info     = fontloader.info
local close_font        = fontloader.close
local font_fields       = fontloader.fields

-- table={
--  ["familyname"]="TeXGyrePagella",
--  ["fontname"]="TeXGyrePagella-Regular",
--  ["fullname"]="TeXGyrePagella-Regular",
--  ["italicangle"]=0,
--  ["names"]={
--   {
--    ["lang"]="English (US)",
--    ["names"]={
--     ["copyright"]="Copyright 2006, 2009 for TeX Gyre extensions by B. Jackowski and J.M. Nowacki (on behalf of TeX users groups). This work is released under the GUST Font License --  see http://tug.org/fonts/licenses/GUST-FONT-LICENSE.txt for details.",
--     ["family"]="TeXGyrePagella",
--     ["fullname"]="TeXGyrePagella-Regular",
--     ["postscriptname"]="TeXGyrePagella-Regular",
--     ["preffamilyname"]="TeX Gyre Pagella",
--     ["subfamily"]="Regular",
--     ["trademark"]="Please refer to the Copyright section for the font trademark attribution notices.",
--     ["uniqueid"]="2.004;UKWN;TeXGyrePagella-Regular",
--     ["version"]="Version 2.004;PS 2.004;hotconv 1.0.49;makeotf.lib2.0.14853",
--    },
--   },
--  },
--  ["pfminfo"]={
--   ["avgwidth"]=528,
--   ["codepages"]={ 536871315, 0 },
--   ["firstchar"]=32,
--   ["fstype"]=12,
--   ["hhead_ascent"]=1098,
--   ["hhead_descent"]=-283,
--   ["hheadascent_add"]=0,
--   ["hheaddescent_add"]=0,
--   ["hheadset"]=1,
--   ["lastchar"]=64260,
--   ["linegap"]=0,
--   ["os2_breakchar"]=32,
--   ["os2_capheight"]=692,
--   ["os2_defaultchar"]=0,
--   ["os2_family_class"]=0,
--   ["os2_strikeypos"]=269,
--   ["os2_strikeysize"]=50,
--   ["os2_subxoff"]=0,
--   ["os2_subxsize"]=650,
--   ["os2_subyoff"]=75,
--   ["os2_subysize"]=600,
--   ["os2_supxoff"]=0,
--   ["os2_supxsize"]=650,
--   ["os2_supyoff"]=350,
--   ["os2_supysize"]=600,
--   ["os2_typoascent"]=726,
--   ["os2_typodescent"]=-274,
--   ["os2_typolinegap"]=200,
--   ["os2_vendor"]="UKWN",
--   ["os2_winascent"]=1098,
--   ["os2_windescent"]=283,
--   ["os2_xheight"]=449,
--   ["panose"]={
--    ["armstyle"]="Any",
--    ["contrast"]="Any",
--    ["familytype"]="Any",
--    ["letterform"]="Any",
--    ["midline"]="Any",
--    ["proportion"]="Any",
--    ["serifstyle"]="Any",
--    ["strokevariation"]="Any",
--    ["weight"]="Book",
--    ["xheight"]="Any",
--   },
--   ["panose_set"]=1,
--   ["pfmfamily"]=81,
--   ["pfmset"]=1,
--   ["subsuper_set"]=1,
--   ["typoascent_add"]=0,
--   ["typodescent_add"]=0,
--   ["unicoderanges"]={ 536871047, 0, 0, 0 },
--   ["vheadset"]=0,
--   ["vlinegap"]=0,
--   ["weight"]=400,
--   ["width"]=5,
--   ["winascent_add"]=0,
--   ["windescent_add"]=0,
--  },
--  ["units_per_em"]=1000,
--  ["version"]="2.004;PS 2.004;hotconv 1.0.49;makeotf.lib2.0.14853",
--  ["weight"]="Book",
-- }

-- We had this as temporary solution because we needed a bit more info but in the
-- meantime it got an interesting side effect: currently luatex delays loading of e.g.
-- glyphs so here we first load and then discard which is a waste. In the past it did
-- free memory because a full load was done. One of these things that goes unnoticed.
--
-- local function get_full_info(...) -- check with taco what we get / could get
--     local ff = open_font(...)
--     if ff then
--         local d = ff -- and font_to_table(ff)
--         d.glyphs, d.subfonts, d.gpos, d.gsub, d.lookups = nil, nil, nil, nil, nil
--         close_font(ff)
--         return d
--     else
--         return nil, "error in loading font"
--     end
-- end

-- Phillip suggested this faster variant but it's still a hack as fontloader.info should
-- return these keys/values (and maybe some more) but at least we close the loader which
-- might save some memory in the end.

-- local function get_full_info(name)
--     local ff = open_font(name)
--     if ff then
--         local fields = table.tohash(font_fields(ff),true) -- isn't that one stable
--         local d   = {
--             names       = fields.names               and ff.names,
--             familyname  = fields.familyname          and ff.familyname,
--             fullname    = fields.fullname            and ff.fullname,
--             fontname    = fields.fontname            and ff.fontname,
--             weight      = fields.weight              and ff.weight,
--             italicangle = fields.italicangle         and ff.italicangle,
--             units       = fields.units_per_em        and ff.units_per_em,
--             designsize  = fields.design_size         and ff.design_size,
--             minsize     = fields.design_range_bottom and ff.design_range_bottom,
--             maxsize     = fields.design_range_top    and ff.design_range_top,
--             italicangle = fields.italicangle         and ff.italicangle,
--             pfmweight   = pfminfo and pfminfo.weight or 400,
--             pfmwidth    = pfminfo and pfminfo.width  or 5,
--         }
--      -- setmetatableindex(d,function(t,k)
--      --     report_names("warning, trying to access field %a in font table of %a",k,name)
--      -- end)
--         close_font(ff)
--         return d
--     else
--         return nil, "error in loading font"
--     end
-- end

-- more efficient:

local fields = nil

local function check_names(names)
    if names then
        for i=1,#names do
            local name = names[i]
            if lower(name.lang) == "english (us)" then -- lower added
                return name.names
            end
        end
    end
end

local function get_full_info(name)
    local ff = open_font(name)
    if ff then
        -- unfortunately luatex aborts when a field is not available but we just make
        -- sure that we only access a few known ones
        local pfminfo = ff.pfminfo or { }
        local names   = check_names(ff.names) or { }
        local weight  = names.weight or ff.weight
        local width   = names.width -- no: ff.width
        local d   = {
            familyname  = names.preffamilyname or names.family or ff.familyname,
            fullname    = names.fullname or ff.fullname,
            fontname    = ff.fontname,
            subfamily   = names.subfamily,
            modifiers   = names.prefmodifiers,
            weight      = weight and lower(weight),
            width       = width and lower(width),
            italicangle = round(1000*(tonumber(ff.italicangle) or 0))/1000 or 0,
            units       = ff.units_per_em,
            designsize  = ff.design_size,
            minsize     = ff.design_range_bottom,
            maxsize     = ff.design_range_top,
            pfmweight   = pfminfo.weight or 400,
            pfmwidth    = pfminfo.width  or 5,
            monospaced  = pfminfo.panose and pfminfo.panose.proportion == "Monospaced",
        }
        close_font(ff)
        return d
    else
        return nil, "error in loading font"
    end
end

-- As we have lazy loading anyway, this one still is full and with less code than
-- the previous one. But this depends on the garbage collector to kick in and in the
-- current version that somehow happens not that often (on my machine I end up with
-- some 3 GB extra before that happens).

-- local function get_full_info(...)
--     local ff = open_font(...)
--     if ff then
--         local d = { } -- ff is userdata so [1] or # fails on it
--         setmetatableindex(d,ff)
--         return d -- garbage collection will do the close_font(ff)
--     else
--         return nil, "error in loading font"
--     end
-- end

fonts          = fonts or { }
local handlers = fonts.handlers or { }
fonts.handlers = handlers
local otf      = handlers.otf or { }
handlers.otf   = otf
local readers  = otf.readers or { }
otf.readers    = readers

fontloader.fullinfo = get_full_info
readers.getinfo     = readers.getinfo or get_full_info
