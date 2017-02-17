if not modules then modules = { } end modules ['toks-ini'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

tokens = tokens or { }

local tokens     = tokens
local token      = token -- the built in one
local tonumber   = tonumber
local tostring   = tostring
local utfchar    = utf.char
local char       = string.char
local printtable = table.print
local concat     = table.concat

if setinspector then

    local istoken = token.is_token
    local simple  = { letter = "letter", other_char = "other" }

    local function astable(t)
        if t and istoken(t) then
            local cmdname = t.cmdname
            local simple  = simple[cmdname]
            if simple then
                return {
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
                    mode       = t.mode,
                    index      = t.index,
                    cmdname    = cmdname,
                }
            end
        end
    end

    tokens.istoken = istoken
    tokens.astable = astable

    setinspector("token",function(v) if istoken(v) then printtable(astable(v),tostring(v)) return true end end)

end

local scan_toks    = token.scan_toks
local scan_string  = token.scan_string
local scan_int     = token.scan_int
local scan_code    = token.scan_code
local scan_dimen   = token.scan_dimen
local scan_glue    = token.scan_glue
local scan_keyword = token.scan_keyword
local scan_token   = token.scan_token
local scan_word    = token.scan_word
local scan_number  = token.scan_number
local scan_csname  = token.scan_csname

local get_next     = token.get_next

if not token.get_macro then
    local scantoks = tex.scantoks
    local gettoks  = tex.gettoks
    function token.get_meaning(name)
        scantoks("t_get_macro",tex.ctxcatcodes,"\\"..name)
        return gettoks("t_get_macro")
    end
    function token.get_macro(name)
        scantoks("t_get_macro",tex.ctxcatcodes,"\\"..name)
        local s = gettoks("t_get_macro")
        return match(s,"^.-%->(.*)$") or s
    end
end

local set_macro    = token.set_macro
local get_macro    = token.get_macro
local get_meaning  = token.get_meaning
local get_cmdname  = token.get_cmdname
local create_token = token.create

function tokens.defined(name)
    return get_cmdname(create_token(name)) ~= "undefined_cs"
end

-- set_macro = function(k,v,g)
--     if g == "global" then
--         context.setgvalue(k,v or '')
--     else
--         context.setvalue(k,v or '')
--     end
-- end

local bits = {
    escape      = 2^ 0,
    begingroup  = 2^ 1,
    endgroup    = 2^ 2,
    mathshift   = 2^ 3,
    alignment   = 2^ 4,
    endofline   = 2^ 5,
    parameter   = 2^ 6,
    superscript = 2^ 7,
    subscript   = 2^ 8,
    ignore      = 2^ 9,
    space       = 2^10, -- 1024
    letter      = 2^11,
    other       = 2^12,
    active      = 2^13,
    comment     = 2^14,
    invalid     = 2^15,
    --
    character   = 2^11 + 2^12,
    whitespace  = 2^13 + 2^10, --    / needs more checking
    --
    open        = 2^10 + 2^1, -- space + begingroup
    close       = 2^10 + 2^2, -- space + endgroup
}

-- for k, v in next, bits do bits[v] = k end

tokens.bits = bits

local space_bits = bits.space

-- words are space or \relax terminated and the trailing space is gobbled; a word
-- can contain any non-space letter/other

local t = { } -- small optimization, a shared variable that is not reset

if scan_word then

    scan_number = function(base)
        local s = scan_word()
        if not s then
            return nil
        elseif base then
            return tonumber(s,base)
        else
            return tonumber(s)
        end
    end

else

    scan_word = function()
        local n = 0
        while true do
            local c = scan_code()
            if c then
                n = n + 1
                t[n] = utfchar(c)
            elseif scan_code(space_bits) then
                if n > 0 then
                    break
                end
            elseif n > 0 then
                break
            else
                return
            end
        end
        return concat(t,"",1,n)
    end

    -- so we gobble the space (like scan_int) (number has to be space or non-char terminated
    -- as we accept 0xabcd and such so there is no clear separator for a keyword

    scan_number = function(base)
        local n = 0
        while true do
            local c = scan_code()
            if c then
                n = n + 1
                t[n] = char(c)
            elseif scan_code(space_bits) then
                if n > 0 then
                    break
                end
            elseif n > 0 then
                break
            else
                return
            end
        end
        local s = concat(t,"",1,n)
        if base then
            return tonumber(s,base)
        else
            return tonumber(s)
        end
    end

end

-- -- the next one cannot handle \iftrue true\else false\fi
--
-- local function scan_boolean()
--     if scan_keyword("true") then
--         return true
--     elseif scan_keyword("false") then
--         return false
--     else
--         return nil
--     end
-- end

local function scan_boolean()
    local kw = scan_word()
    if kw == "true" then
        return true
    elseif kw == "false" then
        return false
    else
        return nil
    end
end

if not scan_csname then

    scan_csname = function()
        local t = get_next()
        local n = t.csname
        return n ~= "" and n or nil
    end

end

tokens.scanners = { -- these expand
    token     = scan_token,
    toks      = scan_toks,
    tokens    = scan_toks,
    dimen     = scan_dimen,
    dimension = scan_dimen,
    glue      = scan_glue,
    skip      = scan_glue,
    integer   = scan_int,
    count     = scan_int,
    string    = scan_string,
    code      = scan_code,
    word      = scan_word,
    number    = scan_number,
    boolean   = scan_boolean,
    keyword   = scan_keyword,
    csname    = scan_csname,
}

tokens.getters = { -- these don't expand
    meaning = get_meaning,
    macro   = get_macro,
    token   = get_next,
    count   = tex.getcount,
    dimen   = tex.getdimen,
    skip    = tex.getglue,
    glue    = tex.getglue,
    skip    = tex.getmuglue,
    glue    = tex.getmuglue,
    box     = tex.getbox,
}

tokens.setters = {
    macro = set_macro,
    count = tex.setcount,
    dimen = tex.setdimen,
    skip  = tex.setglue,
    glue  = tex.setglue,
    skip  = tex.setmuglue,
    glue  = tex.setmuglue,
    box   = tex.setbox,
}

-- static int run_scan_token(lua_State * L)
-- {
--     saved_tex_scanner texstate;
--     save_tex_scanner(texstate);
--     get_x_token();
--     make_new_token(L, cur_cmd, cur_chr, cur_cs);
--     unsave_tex_scanner(texstate);
--     return 1;
-- }
--
-- static int run_get_future(lua_State * L)
-- {
--  /* saved_tex_scanner texstate; */
--  /* save_tex_scanner(texstate); */
--     get_token();
--     make_new_token(L, cur_cmd, cur_chr, cur_cs);
--     back_input();
--  /* unsave_tex_scanner(texstate); */
--     return 1;
-- }
