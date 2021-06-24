if not modules then modules = { } end modules ['font-imp-tweaks'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not context then return end

local addfeature = fonts.handlers.otf.addfeature

-- The mapping directives avoids a check and copying of the (kind of special code
-- mapping tables.

addfeature {
    name    = "uppercasing",
    type    = "substitution",
    prepend = true,
    mapping = true,
 -- valid   = function() return true end,
    data    = characters.uccodes
}

addfeature {
    name    = "lowercasing",
    type    = "substitution",
    prepend = true,
    mapping = true,
 -- valid   = function() return true end,
    data    = characters.lccodes
}

if CONTEXTLMTXMODE > 0 then

    local nuts       = nodes.nuts
    local isnextchar = nuts.isnextchar
    local getdisc    = nuts.getdisc
    local setchar    = nuts.setchar

    local disc_code  = nodes.nodecodes.disc

    local lccodes    = characters.lccodes
    local uccodes    = characters.uccodes

    function fonts.handlers.otf.handlers.ctx_camelcasing(head,dataset,sequence,initialrl,font,dynamic)
        local first   = false
        local current = head
     -- local scale   = 1000
     -- local xscale  = 1000
     -- local yscale  = 1000
        local function check(current)
            while current do
                -- scale, xscale, yscale = getscales(current)
                local nxt, char, id = isnextchar(current,font,dynamic) -- ,scale,xscale,yscale)
                if char then
                    if first then
                        local lower = lccodes[char]
                        if lower ~= char then
                            setchar(current,lower)
                        end
                    else
                        local upper = uccodes[char]
                        if upper ~= char then
                            setchar(current,upper)
                        end
                        first = true
                    end
                elseif id == disc_code then
                    local pre, post, replace = getdisc(current)
                    if pre then
                        check(pre)
                    end
                    if post then
                        check(post)
                    end
                    if replace then
                        check(replace)
                    end
                else
                    first = false
                end
                current = nxt
            end
        end
        check(current)
        return head
    end

    addfeature {
        nocheck = true,
        name    = "camelcasing",
        type    = "ctx_camelcasing",
        prepend = true,
        data    = "action",
    }

end

do -- for the moment this is mostly a demo feature

    local digit  = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" }
    local single = { "'" }
    local double = { '"' }

    local singleprime = 0x2032 -- "′"
    local doubleprime = 0x2033 -- "″"

    addfeature {
     -- nocheck = true,
        name    = "primes",
        type    = "chainsubstitution",
        lookups = {
            {
                type = "substitution",
                data = { ["'"] = singleprime },
            },
            {
                type = "substitution",
                data = { ["'"] = doubleprime },
            },
        },
        data = {
            rules = {
                {
                    before  = { digit },
                    current = { single },
                    after   = { digit },
                    lookups = { 1 },
                },
                {
                    before  = { digit },
                    current = { single, single },
                    lookups = { 2, 0 }, -- zero: gsub_remove
                },
            },
        },
    }

end
