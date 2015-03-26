if not modules then modules = { } end modules ['toks-ini'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

tokens = tokens or { }

local tokens     = tokens
local tostring   = tostring
local utfchar    = utf.char
local char       = string.char
local printtable = table.print
local concat     = table.concat

if newtoken then

    if setinspector then

        local istoken = newtoken.is_token
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
                        cmdname    = cmdname,
                    }
                end
            end
        end

        tokens.istoken = istoken
        tokens.astable = astable

        setinspector(function(v) if istoken(v) then printtable(astable(v),tostring(v)) return true end end)

    end

    local scan_toks    = newtoken.scan_toks
    local scan_string  = newtoken.scan_string
    local scan_int     = newtoken.scan_int
    local scan_code    = newtoken.scan_code
    local scan_dimen   = newtoken.scan_dimen
    local scan_glue    = newtoken.scan_glue
    local scan_keyword = newtoken.scan_keyword
    local scan_token   = newtoken.scan_token
    local scan_word    = newtoken.scan_word
    local scan_number  = newtoken.scan_number

    local get_next     = newtoken.get_next

    local set_macro    = newtoken.set_macro

    set_macro = function(k,v) context.setvalue(k,v or '') end

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

    tokens.scanners = { -- these expand
        token     = scan_token or get_next,
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
    }

    tokens.getters = { -- these don't expand
        token = get_next,
        count = tex.getcount,
        dimen = tex.getdimen,
        box   = tex.getbox,
    }

    tokens.setters = {
        macro = set_macro,
        count = tex.setcount,
        dimen = tex.setdimen,
        box   = tex.setbox,
    }

end

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
