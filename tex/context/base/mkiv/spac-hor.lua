if not modules then modules = { } end modules ['spac-hor'] = {
    version   = 1.001,
    comment   = "companion to spac-hor.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lpegmatch, P, C = lpeg.match, lpeg.P, lpeg.C

local context  = context

local chardata = characters.data

local p_check  = P("the ") * (P("letter") + P("character")) * P(" ") * lpeg.patterns.utf8byte -- is a capture already

local can_have_space = table.tohash {
    "lu", "ll", "lt", "lm", "lo", -- letters
 -- "mn", "mc", "me",             -- marks
    "nd", "nl", "no",             -- numbers
    "ps", "pi",                   -- initial
 -- "pe", "pf",                   -- final
 -- "pc", "pd", "po",             -- punctuation
    "sm", "sc", "sk", "so",       -- symbols
 -- "zs", "zl", "zp",             -- separators
 -- "cc", "cf", "cs", "co", "cn", -- others
}

local function autonextspace(str) -- todo: make a real not intrusive lookahead
    local b = lpegmatch(p_check,str)
    if b then
        local d = chardata[b]
        if d and can_have_space[d.category] then
            context.space()
        end
    end
end

interfaces.implement {
    name      = "autonextspace",
    actions   = autonextspace,
    arguments = "string",
}
