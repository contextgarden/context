if not modules then modules = { } end modules ['luat-ini'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>We cannot load anything yet. However what we will do us reserve a few tables.
These can be used for runtime user data or third party modules and will not be
cluttered by macro package code.</p>
--ldx]]--

userdata      = userdata      or { } -- for users (e.g. functions etc)
thirddata     = thirddata     or { } -- only for third party modules
moduledata    = moduledata    or { } -- only for development team
documentdata  = documentdata  or { } -- for users (e.g. raw data)
parametersets = parametersets or { } -- for special purposes

table.setmetatableindex(moduledata,"table")
table.setmetatableindex(thirddata, "table")

if not global then
    global  = _G
end

LUATEXVERSION       = status.luatex_version/100
                    + tonumber(status.luatex_revision)/1000

LUATEXENGINE        = status.luatex_engine and string.lower(status.luatex_engine)
                   or (string.find(status.banner,"LuajitTeX",1,true) and "luajittex" or "luatex")

LUATEXFUNCTIONALITY = status.development_id or 6346

LUATEXFORMATID      = status.format_id or 0

JITSUPPORTED        = LUATEXENGINE == "luajittex" or jit

INITEXMODE          = status.ini_version

CONTEXTLMTXMODE     = CONTEXTLMTXMODE or (LUATEXENGINE == "luametatex" and 1) or 0

function os.setlocale()
    -- no need for a message
end
