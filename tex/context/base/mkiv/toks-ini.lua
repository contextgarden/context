if not modules then modules = { } end modules ['toks-ini'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

tokens = tokens or { }

local tokens     = tokens
local token      = token -- the built in one
local next       = next
local tonumber   = tonumber
local tostring   = tostring
local utfchar    = utf.char
local char       = string.char
local printtable = table.print
local concat     = table.concat
local format     = string.format

local commands  = token.commands()
tokens.commands = utilities.storage.allocate(table.swapped(commands,commands))
tokens.values   = { }

local scantoks        = token.scan_toks
local scanstring      = token.scan_string
local scanargument    = token.scan_argument
local scandelimited   = token.scan_delimited
local scantokenlist   = token.scan_tokenlist or scanstring
local scaninteger     = token.scan_integer or token.scan_int
local scancardinal    = token.scan_cardinal
local scancode        = token.scan_code
local scantokencode   = token.scan_token_code
local scandimen       = token.scan_dimen
local scanglue        = token.scan_glue
local scanskip        = token.scan_skip
local scankeyword     = token.scan_keyword
local scankeywordcs   = token.scan_keyword_cs or scankeyword
local scantoken       = token.scan_token
local scanbox         = token.scan_box
local scanword        = token.scan_word
local scanletters     = token.scan_letters or scanword -- lmtx
local scankey         = token.scan_key
local scanvalue       = token.scan_value
local scanchar        = token.scan_char
local scannumber      = token.scan_number -- not defined
local scancsname      = token.scan_csname
local scanreal        = token.scan_real
local scanfloat       = token.scan_float
local scanluanumber   = token.scan_luanumber   or scanfloat    -- only lmtx
local scanluainteger  = token.scan_luainteger  or scaninteger  -- only lmtx
local scanluacardinal = token.scan_luacardinal or scancardinal -- only lmtx

local setmacro        = token.set_macro
local setchar         = token.set_char
local setlua          = token.set_lua

local createtoken     = token.create
local newtoken        = token.new
local isdefined       = token.is_defined
local istoken         = token.is_token

tokens.new            = newtoken
tokens.create         = createtoken
tokens.istoken        = istoken
tokens.isdefined      = isdefined
tokens.defined        = isdefined

local bits = {
    escape      = 0x00000001, -- 2^00
    begingroup  = 0x00000002, -- 2^01
    endgroup    = 0x00000004, -- 2^02
    mathshift   = 0x00000008, -- 2^03
    alignment   = 0x00000010, -- 2^04
    endofline   = 0x00000020, -- 2^05
    parameter   = 0x00000040, -- 2^06
    superscript = 0x00000080, -- 2^07
    subscript   = 0x00000100, -- 2^08
    ignore      = 0x00000200, -- 2^09
    space       = 0x00000400, -- 2^10 -- 1024
    letter      = 0x00000800, -- 2^11
    other       = 0x00001000, -- 2^12
    active      = 0x00002000, -- 2^13
    comment     = 0x00004000, -- 2^14
    invalid     = 0x00008000, -- 2^15
    --
    character   = 0x00001800, -- 2^11 + 2^12
    whitespace  = 0x00002400, -- 2^13 + 2^10 --    / needs more checking
    --
    open        = 0x00000402, -- 2^10 + 2^01 -- space + begingroup
    close       = 0x00000404, -- 2^10 + 2^02 -- space + endgroup
}

-- for k, v in next, bits do bits[v] = k end

tokens.bits = bits

-- words are space or \relax terminated and the trailing space is gobbled; a word
-- can contain any non-space letter/other (see archive for implementation in lua)

if not scannumber then

    scannumber = function(base)
        local s = scanword()
        if not s then
            return nil
        elseif base then
            return tonumber(s,base)
        else
            return tonumber(s)
        end
    end

end

local function scanboolean()
    local kw = scanword()
    if kw == "true" then
        return true
    elseif kw == "false" then
        return false
    else
        return nil
    end
end

local function scanverbatim()
    return scanargument(false)
end

if not scanbox then

    local scanlist = token.scan_list
    local putnext  = token.put_next

    scanbox = function(s)
        if s == "hbox" or s == "vbox" or s == "vtop" then
            putnext(createtoken(s))
        end
        return scanlist()
    end

    token.scanbox = scanbox

end

tokens.scanners = { -- these expand
    token          = scantoken,
    toks           = scantoks,
    tokens         = scantoks,
    box            = scanbox,
    hbox           = function() return scanbox("hbox") end,
    vbox           = function() return scanbox("vbox") end,
    vtop           = function() return scanbox("vtop") end,
    dimen          = scandimen,
    dimension      = scandimen,
    glue           = scanglue,
    gluevalues     = function() return scanglue(false,false,true) end,
    gluespec       = scanskip,
    integer        = scaninteger,
    cardinal       = scancardinal,
    real           = scanreal,
    float          = scanfloat,
    luanumber      = scanluanumber,
    luainteger     = scanluainteger,
    luacardinal    = scanluacardinal,
    count          = scaninteger,
    string         = scanstring,
    argument       = scanargument,
    delimited      = scandelimited,
    tokenlist      = scantokenlist,
    verbatim       = scanverbatim, -- detokenize
    code           = scancode,
    tokencode      = scantokencode,
    word           = scanword,
    letters        = scanletters,
    key            = scankey,
    value          = scanvalue,
    char           = scanchar,
    number         = scannumber,
    boolean        = scanboolean,
    keyword        = scankeyword,
    keywordcs      = scankeywordcs,
    csname         = scancsname,

    next           = token.scan_next,
    nextexpanded   = token.scan_next_expanded,

    peek           = token.peek_next,
    peekexpanded   = token.peek_next_expanded,
    peekchar       = token.peek_next_char,

    skip           = token.skip_next,
    skipexpanded   = token.skip_next_expanded,

    cmdchr         = token.scan_cmdchr,
    cmdchrexpanded = token.scan_cmdchr_expanded,

    ischar         = token.is_next_char,
}

tokens.getters = { -- these don't expand
    meaning = token.get_meaning,
    macro   = token.get_macro,
    token   = token.scan_next or token.get_next, -- not here, use scanners.next or token
    cstoken = token.get_cstoken,
    count   = tex.getcount,
    dimen   = tex.getdimen,
    skip    = tex.getglue,
    glue    = tex.getglue,
    skip    = tex.getmuglue,
    glue    = tex.getmuglue,
    box     = tex.getbox,
}

tokens.setters = {
    macro = setmacro,
    char  = setchar,
    lua   = setlua,
    count = tex.setcount,
    dimen = tex.setdimen,
    skip  = tex.setglue,
    glue  = tex.setglue,
    skip  = tex.setmuglue,
    glue  = tex.setmuglue,
    box   = tex.setbox,
}

tokens.accessors = {
    command    = token.get_command,
    cmd        = token.get_command,
    cmdname    = token.get_cmdname,
    name       = token.get_cmdname,
    csname     = token.get_csname,
    index      = token.get_index,
    active     = token.get_active,
    frozen     = token.get_frozen,
    protected  = token.get_protected,
    expandable = token.get_protected,
    user       = token.get_user,
    cmdchrcs   = token.get_cmdchrcs,
    active     = token.get_active,
    range      = token.get_range,
}

if setinspector then

    local simple = { letter = "letter", other_char = "other" }

    local astable = function(t)
        if t and istoken(t) then
            local cmdname = t.cmdname
            local simple  = simple[cmdname]
            if simple then
                return {
                    id         = t.id,
                    category   = simple,
                    character  = utfchar(t.mode) or nil,
                }
            else
                return {
                    command    = t.command,
                    id         = t.id,
                    tok        = t.tok,
                    csname     = t.csname,
                    active     = t.active,
                    expandable = t.expandable,
                    protected  = t.protected,
                    frozen     = t.frozen,
                    mode       = t.mode,
                    index      = t.index,
                    user       = t.user,
                    cmdname    = cmdname,
                }
            end
        end
    end

    tokens.astable = astable

    setinspector("token",function(v) local t = astable(v) if t then printtable(t,tostring(v)) return true end end)

end

tokens.cache = table.setmetatableindex(function(t,k)
    if not isdefined(k) then
        setmacro(k,"","global")
    end
    local v = createtoken(k)
    t[k] = v
    return v
end)

if LUATEXVERSION < 114 then

    local d = tokens.defined
    local c = tokens.create

    function tokens.defined(s,b)
        if b then
            return d(s)
        else
            return c(s).cmd_name == "undefined_cmd"
        end
    end

end
