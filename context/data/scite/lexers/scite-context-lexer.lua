local info = {
    version   = 1.324,
    comment   = "basics for scintilla lpeg lexer for context/metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
    comment   = "contains copyrighted code from mitchell.att.foicica.com",

}

-- todo: move all code here
-- todo: explore adapted dll ... properties + init
-- todo: play with hotspot and other properties

-- wish: replace errorlist lexer (per language!)
-- wish: access to all scite properties

-- The fold and lex functions are copied and patched from original code by Mitchell (see
-- lexer.lua). All errors are mine. The ability to use lpeg is a real nice adition and a
-- brilliant move. The code is a byproduct of the (mainly Lua based) textadept (still a
-- rapidly moving target) that unfortunately misses a realtime output pane. On the other
-- hand, SciTE is somewhat crippled by the fact that we cannot pop in our own (language
-- dependent) lexer into the output pane (somehow the errorlist lexer is hard coded into
-- the editor). Hopefully that will change some day.
--
-- Starting with SciTE version 3.20 there is an issue with coloring. As we still lack
-- a connection with scite itself (properties as well as printing to the log pane) we
-- cannot trace this (on windows). As far as I can see, there are no fundamental
-- changes in lexer.lua or LexLPeg.cxx so it must be in scintilla itself. So for the
-- moment I stick to 3.10. Indicators are: no lexing of 'next' and 'goto <label>' in the
-- Lua lexer and no brace highlighting either. Interesting is that it does work ok in
-- the cld lexer (so the Lua code is okay). Also the fact that char-def.lua lexes fast
-- is a signal that the lexer quits somewhere halfway.
--
-- After checking 3.24 and adapting to the new lexer tables things are okay again. So,
-- this version assumes 3.24 or higher. In 3.24 we have a different token result, i.e. no
-- longer a { tag, pattern } but just two return values. I didn't check other changes but
-- will do that when I run into issues. I had optimized these small tables by hashing which
-- was more efficient but this is no longer needed.
--
-- In 3.3.1 another major change took place: some helper constants (maybe they're no
-- longer constants) and functions were moved into the lexer modules namespace but the
-- functions are assigned to the Lua module afterward so we cannot alias them beforehand.
-- We're probably getting close to a stable interface now.
--
-- I've considered making a whole copy and patch the other functions too as we need
-- an extra nesting model. However, I don't want to maintain too much. An unfortunate
-- change in 3.03 is that no longer a script can be specified. This means that instead
-- of loading the extensions via the properties file, we now need to load them in our
-- own lexers, unless of course we replace lexer.lua completely (which adds another
-- installation issue).
--
-- Another change has been that _LEXERHOME is no longer available. It looks like more and
-- more functionality gets dropped so maybe at some point we need to ship our own dll/so
-- files. For instance, I'd like to have access to the current filename and other scite
-- properties. For instance, we could cache some info with each file, if only we had
-- knowledge of what file we're dealing with.
--
-- For huge files folding can be pretty slow and I do have some large ones that I keep
-- open all the time. Loading is normally no ussue, unless one has remembered the status
-- and the cursor is at the last line of a 200K line file. Optimizing the fold function
-- brought down loading of char-def.lua from 14 sec => 8 sec. Replacing the word_match
-- function and optimizing the lex function gained another 2+ seconds. A 6 second load
-- is quite ok for me. The changed lexer table structure (no subtables) brings loading
-- down to a few seconds.
--
-- When the lexer path is copied to the textadept lexer path, and the theme definition to
-- theme path (as lexer.lua), the lexer works there as well. When I have time and motive
-- I will make a proper setup file to tune the look and feel a bit and associate suffixes
-- with the context lexer. The textadept editor has a nice style tracing option but lacks
-- the tabs for selecting files that scite has. It also has no integrated run that pipes
-- to the log pane (I wonder if it could borrow code from the console2 project). Interesting
-- is that the jit version of textadept crashes on lexing large files (and does not feel
-- faster either).
--
-- Function load(lexer_name) starts with _M.WHITESPACE = lexer_name..'_whitespace' which
-- means that we need to have it frozen at the moment we load another lexer. Because spacing
-- is used to revert to a parent lexer we need to make sure that we load children as late
-- as possible in order not to get the wrong whitespace trigger. This took me quite a while
-- to figure out (not being that familiar with the internals). The lex and fold functions
-- have been optimized. It is a pitty that there is no proper print available. Another thing
-- needed is a default style in ourown theme style definition, as otherwise we get wrong
-- nested lexers, especially if they are larger than a view. This is the hardest part of
-- getting things right.
--
-- Eventually it might be safer to copy the other methods from lexer.lua here as well so
-- that we have no dependencies, apart from the c library (for which at some point the api
-- will be stable I hope).
--
-- It's a pitty that there is no scintillua library for the OSX version of scite. Even
-- better would be to have the scintillua library as integral part of scite as that way I
-- could use OSX alongside windows and linux (depending on needs). Also nice would be to
-- have a proper interface to scite then because currently the lexer is rather isolated and the
-- lua version does not provide all standard libraries. It would also be good to have lpeg
-- support in the regular scite lua extension (currently you need to pick it up from someplace
-- else).

local lpeg = require 'lpeg'

local R, P, S, C, V, Cp, Cs, Ct, Cmt, Cc, Cf, Cg, Carg = lpeg.R, lpeg.P, lpeg.S, lpeg.C, lpeg.V, lpeg.Cp, lpeg.Cs, lpeg.Ct, lpeg.Cmt, lpeg.Cc, lpeg.Cf, lpeg.Cg, lpeg.Carg
local lpegmatch = lpeg.match
local find, gmatch, match, lower, upper, gsub = string.find, string.gmatch, string.match, string.lower, string.upper, string.gsub
local concat = table.concat
local global = _G
local type, next, setmetatable, rawset = type, next, setmetatable, rawset

-- less confusing as we also use lexer for the current lexer and local _M = lexer is just ugly

local lexers = lexer or { } -- + fallback for syntax check

-- ok, let's also move helpers here (todo: all go here)

local sign      = S("+-")
local digit     = R("09")
local octdigit  = R("07")
local hexdigit  = R("09","AF","af")

lexers.sign     = sign
lexers.digit    = digit
lexers.octdigit = octdigit
lexers.hexdigit = hexdigit
lexers.xdigit   = hexdigit

lexers.dec_num  = digit^1
lexers.oct_num  = P("0")
                * octdigit^1
lexers.hex_num  = P("0") * S("xX")
                * (hexdigit^0 * '.' * hexdigit^1 + hexdigit^1 * '.' * hexdigit^0 + hexdigit^1)
                * (S("pP") * sign^-1 * hexdigit^1)^-1
lexers.float    = sign^-1
                * (digit^0 * '.' * digit^1 + digit^1 * '.' * digit^0 + digit^1)
                * S("eE") * sign^-1 * digit^1

lexers.dec_int  = sign^-1 * lexers.dec_num
lexers.oct_int  = sign^-1 * lexers.oct_num
lexers.hex_int  = sign^-1 * lexers.hex_num

-- these helpers are set afterwards so we delay their initialization ... there is no need to alias
-- each time again and this way we can more easily adapt to updates

local get_style_at, get_indent_amount, get_property, get_fold_level, FOLD_BASE, FOLD_HEADER, FOLD_BLANK, initialize

initialize = function()
    FOLD_BASE         = lexers.FOLD_BASE         or SC_FOLDLEVELBASE
    FOLD_HEADER       = lexers.FOLD_HEADER       or SC_FOLDLEVELHEADERFLAG
    FOLD_BLANK        = lexers.FOLD_BLANK        or SC_FOLDLEVELWHITEFLAG
    get_style_at      = lexers.get_style_at      or GetStyleAt
    get_indent_amount = lexers.get_indent_amount or GetIndentAmount
    get_property      = lexers.get_property      or GetProperty
    get_fold_level    = lexers.get_fold_level    or GetFoldLevel
    --
    initialize = nil
end

-- we create our own extra namespace for extensions and helpers

lexers.context   = lexers.context or { }
local context    = lexers.context

context.patterns = context.patterns or { }
local patterns   = context.patterns

lexers._CONTEXTEXTENSIONS = true

local locations = {
 -- lexers.context.path,
   "data", -- optional data directory
   "..",   -- regular scite directory
}

local function collect(name)
--  local definitions = loadfile(name .. ".luc") or loadfile(name .. ".lua")
    local okay, definitions = pcall(function () return require(name) end)
    if okay then
        if type(definitions) == "function" then
            definitions = definitions()
        end
        if type(definitions) == "table" then
            return definitions
        end
    end
end

function context.loaddefinitions(name)
    for i=1,#locations do
        local data = collect(locations[i] .. "/" .. name)
        if data then
            return data
        end
    end
end

function context.word_match(words,word_chars,case_insensitive)
    local chars = '%w_' -- maybe just "" when word_chars
    if word_chars then
        chars = '^([' .. chars .. gsub(word_chars,'([%^%]%-])', '%%%1') ..']+)'
    else
        chars = '^([' .. chars ..']+)'
    end
    if case_insensitive then
        local word_list = { }
        for i=1,#words do
            word_list[lower(words[i])] = true
        end
        return P(function(input, index)
            local s, e, word = find(input,chars,index)
            return word and word_list[lower(word)] and e + 1 or nil
        end)
    else
        local word_list = { }
        for i=1,#words do
            word_list[words[i]] = true
        end
        return P(function(input, index)
            local s, e, word = find(input,chars,index)
            return word and word_list[word] and e + 1 or nil
        end)
    end
end

local idtoken = R("az","AZ","\127\255","__")
local digit   = R("09")
local sign    = S("+-")
local period  = P(".")
local space   = S(" \n\r\t\f\v")

patterns.idtoken  = idtoken

patterns.digit    = digit
patterns.sign     = sign
patterns.period   = period

patterns.cardinal = digit^1
patterns.integer  = sign^-1 * digit^1

patterns.real     =
    sign^-1 * (                    -- at most one
        digit^1 * period * digit^0 -- 10.0 10.
      + digit^0 * period * digit^1 -- 0.10 .10
      + digit^1                    -- 10
   )

patterns.restofline = (1-S("\n\r"))^1
patterns.space      = space
patterns.spacing    = space^1
patterns.nospacing  = (1-space)^1
patterns.anything   = P(1)

local endof = S("\n\r\f")

patterns.startofline = P(function(input,index)
    return (index == 1 or lpegmatch(endof,input,index-1)) and index
end)

function context.exact_match(words,word_chars,case_insensitive)
    local characters = concat(words)
    local pattern -- the concat catches _ etc
    if word_chars == true or word_chars == false or word_chars == nil then
        word_chars = ""
    end
    if type(word_chars) == "string" then
        pattern = S(characters) + idtoken
        if case_insensitive then
            pattern = pattern + S(upper(characters)) + S(lower(characters))
        end
        if word_chars ~= "" then
            pattern = pattern + S(word_chars)
        end
    elseif word_chars then
        pattern = word_chars
    end
    if case_insensitive then
        local list = { }
        if #words == 0 then
            for k, v in next, words do
                list[lower(k)] = v
            end
        else
            for i=1,#words do
                list[lower(words[i])] = true
            end
        end
        return Cmt(pattern^1, function(_,i,s)
            return list[lower(s)] -- and i or nil
        end)
    else
        local list = { }
        if #words == 0 then
            for k, v in next, words do
                list[k] = v
            end
        else
            for i=1,#words do
                list[words[i]] = true
            end
        end
        return Cmt(pattern^1, function(_,i,s)
            return list[s] -- and i or nil
        end)
    end
end

function context.just_match(words)
    local p = P(words[1])
    for i=2,#words do
        p = p + P(words[i])
    end
    return p
end

-- spell checking (we can only load lua files)
--
-- return {
--     min = 3,
--     max = 40,
--     n = 12345,
--     words = {
--         ["someword"]    = "someword",
--         ["anotherword"] = "Anotherword",
--     },
-- }

local lists = { }

function context.setwordlist(tag,limit) -- returns hash (lowercase keys and original values)
    if not tag or tag == "" then
        return false, 3
    end
    local list = lists[tag]
    if not list then
        list = context.loaddefinitions("spell-" .. tag)
        if not list or type(list) ~= "table" then
            list = { words = false, min = 3 }
        else
            list.words = list.words or false
            list.min   = list.min or 3
        end
        lists[tag] = list
    end
    return list.words, list.min
end

patterns.wordtoken   = R("az","AZ","\127\255")
patterns.wordpattern = patterns.wordtoken^3 -- todo: if limit and #s < limit then

function context.checkedword(validwords,validminimum,s,i) -- ,limit
    if not validwords then -- or #s < validminimum then
        return true, "text", i -- true, "default", i
    else
        -- keys are lower
        local word = validwords[s]
        if word == s then
            return true, "okay", i -- exact match
        elseif word then
            return true, "warning", i -- case issue
        else
            local word = validwords[lower(s)]
            if word == s then
                return true, "okay", i -- exact match
            elseif word then
                return true, "warning", i -- case issue
            elseif upper(s) == s then
                return true, "warning", i -- probably a logo or acronym
            else
                return true, "error", i
            end
        end
    end
end

function context.styleofword(validwords,validminimum,s) -- ,limit
    if not validwords or #s < validminimum then
        return "text"
    else
        -- keys are lower
        local word = validwords[s]
        if word == s then
            return "okay" -- exact match
        elseif word then
            return "warning" -- case issue
        else
            local word = validwords[lower(s)]
            if word == s then
                return "okay" -- exact match
            elseif word then
                return "warning" -- case issue
            elseif upper(s) == s then
                return "warning" -- probably a logo or acronym
            else
                return "error"
            end
        end
    end
end

-- overloaded functions

local h_table, b_table, n_table = { }, { }, { } -- from the time small tables were used (optimization)

setmetatable(h_table, { __index = function(t,level) local v = { level, FOLD_HEADER } t[level] = v return v end })
setmetatable(b_table, { __index = function(t,level) local v = { level, FOLD_BLANK  } t[level] = v return v end })
setmetatable(n_table, { __index = function(t,level) local v = { level              } t[level] = v return v end })

local newline = P("\r\n") + S("\r\n")
local p_yes   = Cp() * Cs((1-newline)^1) * newline^-1
local p_nop   = newline

local folders = { }

local function fold_by_parsing(text,start_pos,start_line,start_level,lexer)
    local folder = folders[lexer]
    if not folder then
        --
        local pattern, folds, text, start_pos, line_num, prev_level, current_level
        --
        local fold_symbols = lexer._foldsymbols
        local fold_pattern = lexer._foldpattern -- use lpeg instead (context extension)
        --
        if fold_pattern then
            -- if no functions are found then we could have a faster one
            fold_pattern = Cp() * C(fold_pattern) / function(s,match)
                local symbols = fold_symbols[get_style_at(start_pos + s)]
                if symbols then
                    local l = symbols[match]
                    if l then
                        current_level = current_level + l
                    end
                end
            end
            local action_y = function()
                folds[line_num] = prev_level
                if current_level > prev_level then
                    folds[line_num] = prev_level + FOLD_HEADER
                end
                if current_level < FOLD_BASE then
                    current_level = FOLD_BASE
                end
                prev_level = current_level
                line_num = line_num + 1
            end
            local action_n = function()
                folds[line_num] = prev_level + FOLD_BLANK
                line_num = line_num + 1
            end
            pattern = ((fold_pattern + (1-newline))^1 * newline / action_y + newline/action_n)^0

         else
            -- the traditional one but a bit optimized
            local fold_symbols_patterns = fold_symbols._patterns
            local action_y = function(pos,line)
                for j = 1, #fold_symbols_patterns do
                    for s, match in gmatch(line,fold_symbols_patterns[j]) do -- '()('..patterns[i]..')'
                        local symbols = fold_symbols[get_style_at(start_pos + pos + s - 1)]
                        local l = symbols and symbols[match]
                        local t = type(l)
                        if t == 'number' then
                            current_level = current_level + l
                        elseif t == 'function' then
                            current_level = current_level + l(text, pos, line, s, match)
                        end
                    end
                end
                folds[line_num] = prev_level
                if current_level > prev_level then
                    folds[line_num] = prev_level + FOLD_HEADER
                end
                if current_level < FOLD_BASE then
                    current_level = FOLD_BASE
                end
                prev_level = current_level
                line_num = line_num + 1
            end
            local action_n = function()
                folds[line_num] = prev_level + FOLD_BLANK
                line_num = line_num + 1
            end
            pattern = (p_yes/action_y + p_nop/action_n)^0
        end
        --
        local reset_parser = lexer._reset_parser
        --
        folder = function(_text_,_start_pos_,_start_line_,_start_level_)
            if reset_parser then
                reset_parser()
            end
            folds         = { }
            text          = _text_
            start_pos     = _start_pos_
            line_num      = _start_line_
            prev_level    = _start_level_
            current_level = prev_level
            lpegmatch(pattern,text)
         -- make folds collectable
            local t = folds
            folds = nil
            return t
        end
        folders[lexer] = folder
    end
    return folder(text,start_pos,start_line,start_level,lexer)
end

local folds, current_line, prev_level

local function action_y()
    local current_level = FOLD_BASE + get_indent_amount(current_line)
    if current_level > prev_level then -- next level
        local i = current_line - 1
        local f
        while true do
            f = folds[i]
            if not f then
                break
            elseif f[2] == FOLD_BLANK then
                i = i - 1
            else
                f[2] = FOLD_HEADER -- low indent
                break
            end
        end
        folds[current_line] = { current_level } -- high indent
    elseif current_level < prev_level then -- prev level
        local f = folds[current_line - 1]
        if f then
            f[1] = prev_level -- high indent
        end
        folds[current_line] = { current_level } -- low indent
    else -- same level
        folds[current_line] = { prev_level }
    end
    prev_level = current_level
    current_line = current_line + 1
end

local function action_n()
    folds[current_line] = { prev_level, FOLD_BLANK }
    current_line = current_line + 1
end

local pattern = ( S("\t ")^0 * ( (1-S("\n\r"))^1 / action_y + P(true) / action_n) * newline )^0

local function fold_by_indentation(text,start_pos,start_line,start_level)
    -- initialize
    folds        = { }
    current_line = start_line
    prev_level   = start_level
    -- define
    -- -- not here .. pattern binds and local functions are not frozen
    -- analyze
    lpegmatch(pattern,text)
    -- flatten
    for line, level in next, folds do
        folds[line] = level[1] + (level[2] or 0)
    end
    -- done, make folds collectable
    local t = folds
    folds = nil
    return t
end

local function fold_by_line(text,start_pos,start_line,start_level)
    local folds = { }
    -- can also be lpeg'd
    for _ in gmatch(text,".-\r?\n") do
        folds[start_line] = n_table[start_level] -- { start_level } -- stile tables ? needs checking
        start_line = start_line + 1
    end
    return folds
end

local threshold_by_lexer       =  512 * 1024 -- we don't know the filesize yet
local threshold_by_parsing     =  512 * 1024 -- we don't know the filesize yet
local threshold_by_indentation =  512 * 1024 -- we don't know the filesize yet
local threshold_by_line        =  512 * 1024 -- we don't know the filesize yet

function context.fold(text,start_pos,start_line,start_level) -- hm, we had size thresholds .. where did they go
    if text == '' then
        return { }
    end
    if initialize then
        initialize()
    end
    local lexer           = global._LEXER
    local fold_by_lexer   = lexer._fold
    local fold_by_symbols = lexer._foldsymbols
    local filesize        = 0 -- we don't know that
    if fold_by_lexer then
        if filesize <= threshold_by_lexer then
            return fold_by_lexer(text,start_pos,start_line,start_level,lexer)
        end
    elseif fold_by_symbols then -- and get_property('fold.by.parsing',1) > 0 then
        if filesize <= threshold_by_parsing then
            return fold_by_parsing(text,start_pos,start_line,start_level,lexer)
        end
    elseif get_property('fold.by.indentation',1) > 0 then
        if filesize <= threshold_by_indentation then
            return fold_by_indentation(text,start_pos,start_line,start_level,lexer)
        end
    elseif get_property('fold.by.line',1) > 0 then
        if filesize <= threshold_by_line then
            return fold_by_line(text,start_pos,start_line,start_level,lexer)
        end
    end
    return { }
end

-- The following code is mostly unchanged:

local function add_rule(lexer,id,rule)
    if not lexer._RULES then
        lexer._RULES     = { }
        lexer._RULEORDER = { }
    end
    lexer._RULES[id] = rule
    lexer._RULEORDER[#lexer._RULEORDER + 1] = id
end

local function add_style(lexer,token_name,style)
    local len = lexer._STYLES.len
    if len == 32 then
        len = len + 8
    end
    if len >= 128 then
        print('Too many styles defined (128 MAX)')
    end
    lexer._TOKENS[token_name] = len
    lexer._STYLES[len]        = style
    lexer._STYLES.len         = len + 1
end

local function join_tokens(lexer)
    local patterns   = lexer._RULES
    local order      = lexer._RULEORDER
    local token_rule = patterns[order[1]]
    for i=2,#order do
        token_rule = token_rule + patterns[order[i]]
    end
    lexer._TOKENRULE = token_rule
    return token_rule
end

local function add_lexer(grammar, lexer, token_rule)
    local token_rule = join_tokens(lexer)
    local lexer_name = lexer._NAME
    local children   = lexer._CHILDREN
    for i=1,#children do
        local child = children[i]
        if child._CHILDREN then
            add_lexer(grammar, child)
        end
        local child_name        = child._NAME
        local rules             = child._EMBEDDEDRULES[lexer_name]
        local rules_token_rule  = grammar['__'..child_name] or rules.token_rule
        grammar[child_name]     = (-rules.end_rule * rules_token_rule)^0 * rules.end_rule^-1 * V(lexer_name)
        local embedded_child    = '_' .. child_name
        grammar[embedded_child] = rules.start_rule * (-rules.end_rule * rules_token_rule)^0 * rules.end_rule^-1
        token_rule              = V(embedded_child) + token_rule
    end
    grammar['__' .. lexer_name] = token_rule
    grammar[lexer_name]         = token_rule^0
end

local function build_grammar(lexer, initial_rule)
    local children = lexer._CHILDREN
    if children then
        local lexer_name = lexer._NAME
        if not initial_rule then
            initial_rule = lexer_name
        end
        local grammar = { initial_rule }
        add_lexer(grammar, lexer)
        lexer._INITIALRULE = initial_rule
        lexer._GRAMMAR = Ct(P(grammar))
    else
        lexer._GRAMMAR = Ct(join_tokens(lexer)^0)
    end
end

-- so far. We need these local functions in the next one.

local lineparsers = { }

function context.lex(text,init_style)
    local lexer = global._LEXER
    local grammar = lexer._GRAMMAR
    if initialize then
        initialize()
    end
    if not grammar then
        return { }
    elseif lexer._LEXBYLINE then -- we could keep token
        local tokens = { }
        local offset = 0
        local noftokens = 0
        local lineparser = lineparsers[lexer]
        if not lineparser then -- probably a cmt is more efficient
            lineparser = C((1-newline)^0 * newline) / function(line)
                local length = #line
                local line_tokens = length > 0 and lpegmatch(grammar,line)
                if line_tokens then
                    for i=1,#line_tokens,2 do
                        noftokens = noftokens + 1
                        tokens[noftokens] = line_tokens[i]
                        noftokens = noftokens + 1
                        tokens[noftokens] = line_tokens[i + 1] + offset
                    end
                end
                offset = offset + length
                if noftokens > 0 and tokens[noftokens] ~= offset then
                    noftokens = noftokens + 1
                    tokens[noftokens] = 'default'
                    noftokens = noftokens + 1
                    tokens[noftokens] = offset + 1
                end
            end
            lineparser = lineparser^0
            lineparsers[lexer] = lineparser
        end
        lpegmatch(lineparser,text)
        return tokens

    elseif lexer._CHILDREN then
        -- as we cannot print, tracing is not possible ... this might change as we can as well
        -- generate them all in one go (sharing as much as possible)
        local hash = lexer._HASH -- hm, was _hash
        if not hash then
            hash = { }
            lexer._HASH = hash
        end
        grammar = hash[init_style]
        if grammar then
            lexer._GRAMMAR = grammar
        else
            for style, style_num in next, lexer._TOKENS do
                if style_num == init_style then
                    -- the name of the lexers is filtered from the whitespace
                    -- specification
                    local lexer_name = match(style,'^(.+)_whitespace') or lexer._NAME
                    if lexer._INITIALRULE ~= lexer_name then
                        grammar = hash[lexer_name]
                        if not grammar then
                            build_grammar(lexer,lexer_name)
                            grammar = lexer._GRAMMAR
                            hash[lexer_name] = grammar
                        end
                    end
                    break
                end
            end
            grammar = grammar or lexer._GRAMMAR
            hash[init_style] = grammar
        end
        return lpegmatch(grammar,text)
    else
        return lpegmatch(grammar,text)
    end
end

-- todo: keywords: one lookup and multiple matches

-- function context.token(name, patt)
--     return Ct(patt * Cc(name) * Cp())
-- end
--
-- -- hm, changed in 3.24 .. no longer a table

function context.token(name, patt)
    return patt * Cc(name) * Cp()
end

lexers.fold        = context.fold
lexers.lex         = context.lex
lexers.token       = context.token
lexers.exact_match = context.exact_match
lexers.just_match  = context.just_match

-- helper .. alas ... the lexer's lua instance is rather crippled .. not even
-- math is part of it

local floor = math and math.floor
local char  = string.char

if not floor then

    floor = function(n)
        return tonumber(string.format("%d",n))
    end

    math = math or { }

    math.floor = floor

end

local function utfchar(n)
    if n < 0x80 then
        return char(n)
    elseif n < 0x800 then
        return char(
            0xC0 + floor(n/0x40),
            0x80 + (n % 0x40)
        )
    elseif n < 0x10000 then
        return char(
            0xE0 + floor(n/0x1000),
            0x80 + (floor(n/0x40) % 0x40),
            0x80 + (n % 0x40)
        )
    elseif n < 0x40000 then
        return char(
            0xF0 + floor(n/0x40000),
            0x80 + floor(n/0x1000),
            0x80 + (floor(n/0x40) % 0x40),
            0x80 + (n % 0x40)
        )
    else
     -- return char(
     --     0xF1 + floor(n/0x1000000),
     --     0x80 + floor(n/0x40000),
     --     0x80 + floor(n/0x1000),
     --     0x80 + (floor(n/0x40) % 0x40),
     --     0x80 + (n % 0x40)
     -- )
        return "?"
    end
end

context.utfchar = utfchar

-- a helper from l-lpeg:

local gmatch = string.gmatch

local function make(t)
    local p
    for k, v in next, t do
        if not p then
            if next(v) then
                p = P(k) * make(v)
            else
                p = P(k)
            end
        else
            if next(v) then
                p = p + P(k) * make(v)
            else
                p = p + P(k)
            end
        end
    end
    return p
end

function lpeg.utfchartabletopattern(list)
    local tree = { }
    for i=1,#list do
        local t = tree
        for c in gmatch(list[i],".") do
            if not t[c] then
                t[c] = { }
            end
            t = t[c]
        end
    end
    return make(tree)
end

patterns.invisibles = lpeg.utfchartabletopattern {
    utfchar(0x00A0), -- nbsp
    utfchar(0x2000), -- enquad
    utfchar(0x2001), -- emquad
    utfchar(0x2002), -- enspace
    utfchar(0x2003), -- emspace
    utfchar(0x2004), -- threeperemspace
    utfchar(0x2005), -- fourperemspace
    utfchar(0x2006), -- sixperemspace
    utfchar(0x2007), -- figurespace
    utfchar(0x2008), -- punctuationspace
    utfchar(0x2009), -- breakablethinspace
    utfchar(0x200A), -- hairspace
    utfchar(0x200B), -- zerowidthspace
    utfchar(0x202F), -- narrownobreakspace
    utfchar(0x205F), -- math thinspace
}

-- now we can make:

patterns.iwordtoken   = patterns.wordtoken - patterns.invisibles
patterns.iwordpattern = patterns.iwordtoken^3

-- require("themes/scite-context-theme")

-- In order to deal with some bug in additional styles (I have no cue what is
-- wrong, but additional styles get ignored and clash somehow) I just copy the
-- original lexer code ... see original for comments.

return lexers
