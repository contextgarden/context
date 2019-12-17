if not modules then modules = { } end modules ['math-vfu'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- All these math vectors .. thanks to Aditya and Mojca they become
-- better and better. If you have problems with math fonts or miss
-- characters report it to the ConTeXt mailing list. Also thanks to
-- Boguslaw for finding a couple of errors.
--
-- This mechanism will stay around. Even when we've switched to the
-- real fonts, one can still say:
--
-- \enablemode[lmmath,pxmath,txmath]
--
-- to get the virtual counterparts. There are still areas where the
-- virtuals are better.

-- 20D6 -> 2190
-- 20D7 -> 2192

local type, next, tonumber = type, next, tonumber
local max = math.max
local fastcopy = table.copy

local fonts, nodes, mathematics = fonts, nodes, mathematics

local trace_virtual = false  trackers.register("math.virtual", function(v) trace_virtual = v end)
local trace_timings = false  trackers.register("math.timings", function(v) trace_timings = v end)

local add_optional  = false  directives.register("math.virtual.optional",function(v) add_optional = v end)

local report_virtual    = logs.reporter("fonts","virtual math")

local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex
local formatters        = string.formatters

local chardata          = characters.data

local mathencodings     = allocate()
fonts.encodings.math    = mathencodings -- better is then: fonts.encodings.vectors
local vfmath            = allocate()
fonts.handlers.vf.math  = vfmath

local helpers           = fonts.helpers
local vfcommands        = helpers.commands
local rightcommand      = vfcommands.right
local leftcommand       = vfcommands.left
local downcommand       = vfcommands.down
local upcommand         = vfcommands.up
local push              = vfcommands.push
local pop               = vfcommands.pop

local shared            = { }

-- local back = { "slot", 1, 0x2215 }
--
-- local function negate(main,characters,id,size,unicode,basecode)
--     if not characters[unicode] then
--         local basechar = characters[basecode]
--         if basechar then
--             local ht, wd = basechar.height, basechar.width
--             characters[unicode] = {
--                 width    = wd,
--                 height   = ht,
--                 depth    = basechar.depth,
--                 italic   = basechar.italic,
--                 kerns    = basechar.kerns,
--                 commands = {
--                     { "slot", 1, basecode },
--                     push,
--                     downcommand[ht/5],
--                     leftcommand[wd/2],
--                     back,
--                     push,
--                 }
--             }
--         end
--     end
-- end
--
-- \Umathchardef\braceld="0 "1 "FF07A
-- \Umathchardef\bracerd="0 "1 "FF07B
-- \Umathchardef\bracelu="0 "1 "FF07C
-- \Umathchardef\braceru="0 "1 "FF07D

local function brace(main,characters,id,size,unicode,first,rule,left,right,rule,last)
    if not characters[unicode] then
        characters[unicode] = {
            horiz_variants = {
                { extender = 0, glyph = first },
                { extender = 1, glyph = rule  },
                { extender = 0, glyph = left  },
                { extender = 0, glyph = right },
                { extender = 1, glyph = rule  },
                { extender = 0, glyph = last  },
            }
        }
    end
end

local function extension(main,characters,id,size,unicode,first,middle,last)
    local chr = characters[unicode]
    if not chr then
        return -- skip
    end
    local fw = characters[first]
    if not fw then
        return
    end
    local mw = characters[middle]
    if not mw then
        return
    end
    local lw = characters[last]
    if not lw then
        return
    end
    fw = fw.width
    mw = mw.width
    lw = lw.width
    if fw == 0 then
        fw = 1
    end
    if lw == 0 then
        lw = 1
    end
    chr.horiz_variants = {
        { extender = 0, glyph = first,  ["end"] = fw/2, start = 0,    advance = fw },
        { extender = 1, glyph = middle, ["end"] = mw/2, start = mw/2, advance = mw },
        { extender = 0, glyph = last,   ["end"] = 0,    start = lw/2, advance = lw },
    }
end

local function parent(main,characters,id,size,unicode,first,rule,last)
    if not characters[unicode] then
        characters[unicode] = {
            horiz_variants = {
                { extender = 0, glyph = first },
                { extender = 1, glyph = rule  },
                { extender = 0, glyph = last  },
            }
        }
    end
end

local step = 0.2 -- 0.1 is nicer but gives larger files

local function make(main,characters,id,size,n,m)
    local old = 0xFF000 + n
    local c   = characters[old]
    if c then
        local upslot    = 0xFF100 + n
        local dnslot    = 0xFF200 + n
        local uprule    = 0xFF300 + m
        local dnrule    = 0xFF400 + m
        local xu        = main.parameters.x_height + 0.3*size
        local xd        = 0.3*size
        local w         = c.width or 0
        local h         = c.height or 0
        local d         = c.depth or 0
        local thickness = h - d
        local rulewidth = step*size -- we could use an overlap
        local slot      = { "slot", id, old }
        local rule      = { "rule", thickness, rulewidth  }
        local up        = upcommand[xu]
        local dn        = downcommand[xd]
        local ht        = xu + 3*thickness
        local dp        = 0
        if not characters[uprule] then
            characters[uprule] = {
                width    = rulewidth,
                height   = ht,
                depth    = dp,
                commands = { push, up, rule, pop },
            }
        end
        characters[upslot] = {
            width    = w,
            height   = ht,
            depth    = dp,
            commands = { push, up, slot, pop },
        }
        local ht = 0
        local dp = xd + 3*thickness
        if not characters[dnrule] then
            characters[dnrule] = {
                width    = rulewidth,
                height   = ht,
                depth    = dp,
                commands = { push, dn, rule, pop }
            }
        end
        characters[dnslot] = {
            width    = w,
            height   = ht,
            depth    = dp,
            commands = { push, dn, slot, pop },
        }
    end
end

local function clipped(main,characters,id,size,unicode,original) -- push/pop needed?
    local minus = characters[original]
    if minus then
        local mu    = size/18
        local step  = 3*mu
        local width = minus.width
        if width > step then
            width = width - step
            step  = step / 2
        else
            width = width / 2
            step  = width
        end
        characters[unicode] = {
            width    = width,
            height   = minus.height,
            depth    = minus.depth,
            commands = {
                push,
                leftcommand[step],
                { "slot", id, original },
                pop,
            }
        }
    end
end

local function raise(main,characters,id,size,unicode,private,n,id_of_smaller) -- this is a real fake mess
    local raised = fonts.hashes.characters[main.fonts[id_of_smaller].id][private]  -- characters[private]
    if raised then
        local up   = 0.85 * main.parameters.x_height
        local slot = { "slot", id_of_smaller, private }
        local commands = {
            push, upcommand[up], slot,
        }
        for i=2,n do
            commands[#commands+1] = slot
        end
        commands[#commands+1] = pop
        characters[unicode] = {
            width    = n * raised.width,
            height   = (raised.height or 0) + up,
            depth    = (raised.depth or 0) - up,
            italic   = raised.italic,
            commands = commands,
        }
    end
end

local function dots(main,characters,id,size,unicode)
    local c = characters[0x002E]
    if c then
        local w         = c.width
        local h         = c.height
        local d         = c.depth
        local mu        = size/18
        local right3mu  = rightcommand[3*mu]
        local right1mu  = rightcommand[1*mu]
        local up1size   = upcommand[.1*size]
        local up4size   = upcommand[.4*size]
        local up7size   = upcommand[.7*size]
        local right2muw = rightcommand[2*mu + w]
        local slot      = { "slot", id, 0x002E }
        if unicode == 0x22EF then
            local c = characters[0x022C5]
            if c then
                local width  = c.width
                local height = c.height
                local depth  = c.depth
                local slot   = { "slot", id, 0x022C5 }
                characters[unicode] = {
                    width    = 3*width + 2*3*mu,
                    height   = height,
                    depth    = depth,
                    commands = {
                        push, slot, right3mu, slot, right3mu, slot, pop,
                    }
                }
            end
        elseif unicode == 0x22EE then
            -- weird height !
            characters[unicode] = {
                width    = w,
                height   = h+(1.4)*size,
                depth    = 0,
                commands = {
                    push, push, slot, pop, up4size, push, slot, pop, up4size, slot, pop,
                }
            }
        elseif unicode == 0x22F1 then
            characters[unicode] = {
                width    = 3*w + 6*size/18,
                height   = 1.5*size,
                depth    = 0,
                commands = {
                    push,
                    right1mu,
                    push, up7size, slot, pop,
                    right2muw,
                    push, up4size, slot, pop,
                    right2muw,
                    push, up1size, slot, pop,
                    right1mu,
                    pop
                }
            }
        elseif unicode == 0x22F0 then
            characters[unicode] = {
                width    = 3*w + 6*size/18,
                height   = 1.5*size,
                depth    = 0,
                commands = {
                    push,
                    right1mu,
                    push, up1size, slot, pop,
                    right2muw,
                    push, up4size, slot, pop,
                    right2muw,
                    push, up7size, slot, pop,
                    right1mu,
                    pop
                }
            }
        else
            characters[unicode] = {
                width    = 3*w + 2*3*mu,
                height   = h,
                depth    = d,
                commands = {
                    push, slot, right3mu, slot, right3mu, slot, pop,
                }
            }
        end
    end
end

local function vertbar(main,characters,id,size,parent,scale,unicode)
    local cp = characters[parent]
    if cp then
        local sc = scale * size
        local pc = { "slot", id, parent }
        characters[unicode] = {
            width    = cp.width,
            height   = cp.height + sc,
            depth    = cp.depth + sc,
            next     = cp.next, -- can be extensible
            commands = {
                push, upcommand  [sc], pc, pop,
                push, downcommand[sc], pc, pop,
                                       pc,
            },
        }
        cp.next = unicode
    end
end

local function jointwo(main,characters,id,size,unicode,u1,d12,u2,what)
    local c1 = characters[u1]
    local c2 = characters[u2]
    if c1 and c2 then
        local w1 = c1.width
        local w2 = c2.width
        local mu = size/18
        characters[unicode] = {
            width    = w1 + w2 - d12 * mu,
            height   = max(c1.height or 0, c2.height or 0),
            depth    = max(c1.depth  or 0, c2.depth  or 0),
            commands = {
                { "slot", id, u1 },
                leftcommand[d12*mu],
                { "slot", id, u2 },
            },
        }
    end
end

local function jointhree(main,characters,id,size,unicode,u1,d12,u2,d23,u3)
    local c1 = characters[u1]
    local c2 = characters[u2]
    local c3 = characters[u3]
    if c1 and c2 and c3 then
        local w1 = c1.width
        local w2 = c2.width
        local w3 = c3.width
        local mu = size/18
        characters[unicode] = {
            width    = w1 + w2 + w3 - d12*mu - d23*mu,
            height   = max(c1.height or 0, c2.height or 0, c3.height or 0),
            depth    = max(c1.depth  or 0, c2.depth  or 0, c3.depth  or 0),
            commands = {
                { "slot", id, u1 },
                leftcommand[d12*mu],
                { "slot", id, u2 },
                leftcommand[d23*mu],
                { "slot", id, u3 },
            }
        }
    end
end

local function stack(main,characters,id,size,unicode,u1,d12,u2)
    local c1 = characters[u1]
    if not c1 then
        return
    end
    local c2 = characters[u2]
    if not c2 then
        return
    end
    local w1 = c1.width  or 0
    local h1 = c1.height or 0
    local d1 = c1.depth  or 0
    local w2 = c2.width  or 0
    local h2 = c2.height or 0
    local d2 = c2.depth  or 0
    local mu = size/18
    characters[unicode] = {
        width    = w1,
        height   = h1 + h2 + d12,
        depth    = d1,
        commands = {
            { "slot", id, u1 },
            leftcommand[w1/2 + w2/2],
            downcommand[-h1 + d2 -d12*mu],
            { "slot", id, u2 },
        }
    }
end

local function repeated(main,characters,id,size,unicode,u,n,private,fraction) -- math-fbk.lua
    local c = characters[u]
    if c then
        local width  = c.width
        local italic = fraction*width -- c.italic or 0 -- larger ones have funny italics
        local tc     = { "slot", id, u }
        local tr     = leftcommand[italic] -- see hack elsewhere
        local commands = { }
        for i=1,n-1 do
            commands[#commands+1] = tc
            commands[#commands+1] = tr
        end
        commands[#commands+1] = tc
        local next = c.next
        if next then
            repeated(main,characters,id,size,private,next,n,private+1,fraction)
            next = private
        end
        characters[unicode] = {
            width    = width + (n-1)*(width-italic),
            height   = c.height,
            depth    = c.depth,
            italic   = italic,
            commands = commands,
            next     = next,
        }
    end
end

local function cloned(main,characters,id,size,source,target)
    local data = characters[source]
    if data then
        characters[target] = data
        return true
    end
end

-- we use the fact that context defines the smallest sizes first .. a real dirty and ugly hack

local data_of_smaller = nil
local size_of_smaller = 0

function vfmath.addmissing(main,id,size)

    local id_of_smaller = nil

    if size < size_of_smaller or size_of_smaller == 0 then
        data_of_smaller = main.fonts[id]
        id_of_smaller = id
    else
        id_of_smaller = #main.fonts + 1
        main.fonts[id_of_smaller] = data_of_smaller
    end

    -- here id is the index in fonts (normally 14 or so) and that slot points to self

    local characters    = main.characters
    local shared        = main.shared
    local variables     = main.goodies.mathematics and main.goodies.mathematics.variables or { }
    local joinrelfactor = variables.joinrelfactor or 3

    for i=0x7A,0x7D do
        make(main,characters,id,size,i,1)
    end

    brace    (main,characters,id,size,0x23DE,0xFF17A,0xFF301,0xFF17D,0xFF17C,0xFF301,0xFF17B)
    brace    (main,characters,id,size,0x23DF,0xFF27C,0xFF401,0xFF27B,0xFF27A,0xFF401,0xFF27D)

    parent   (main,characters,id,size,0x23DC,0xFF17A,0xFF301,0xFF17B)
    parent   (main,characters,id,size,0x23DD,0xFF27C,0xFF401,0xFF27D)

 -- negate   (main,characters,id,size,0x2260,0x003D)
    dots     (main,characters,id,size,0x2026) -- ldots
    dots     (main,characters,id,size,0x22EE) -- vdots
    dots     (main,characters,id,size,0x22EF) -- cdots
    dots     (main,characters,id,size,0x22F1) -- ddots
    dots     (main,characters,id,size,0x22F0) -- udots

    vertbar  (main,characters,id,size,0x0007C,0.10,0xFF601) -- big  : 0.85 bodyfontsize
    vertbar  (main,characters,id,size,0xFF601,0.30,0xFF602) -- Big  : 1.15 bodyfontsize
    vertbar  (main,characters,id,size,0xFF602,0.30,0xFF603) -- bigg : 1.45 bodyfontsize
    vertbar  (main,characters,id,size,0xFF603,0.30,0xFF604) -- Bigg : 1.75 bodyfontsize
    vertbar  (main,characters,id,size,0x02016,0.10,0xFF605)
    vertbar  (main,characters,id,size,0xFF605,0.30,0xFF606)
    vertbar  (main,characters,id,size,0xFF606,0.30,0xFF607)
    vertbar  (main,characters,id,size,0xFF607,0.30,0xFF608)

    clipped  (main,characters,id,size,0xFF501,0x0002D) -- minus
    clipped  (main,characters,id,size,0xFF502,0x02190) -- lefthead
    clipped  (main,characters,id,size,0xFF503,0x02192) -- righthead
    clipped  (main,characters,id,size,0xFF504,0xFE321) -- mapsto
    clipped  (main,characters,id,size,0xFF505,0xFE322) -- lhook
    clipped  (main,characters,id,size,0xFF506,0xFE323) -- rhook
    clipped  (main,characters,id,size,0xFF507,0xFE324) -- mapsfrom
    clipped  (main,characters,id,size,0xFF508,0x021D0) -- double lefthead
    clipped  (main,characters,id,size,0xFF509,0x021D2) -- double righthead
    clipped  (main,characters,id,size,0xFF50A,0x0003D) -- equal
    clipped  (main,characters,id,size,0xFF50B,0x0219E) -- lefttwohead
    clipped  (main,characters,id,size,0xFF50C,0x021A0) -- righttwohead
    clipped  (main,characters,id,size,0xFF50D,0xFF350) -- lr arrow combi snippet
    clipped  (main,characters,id,size,0xFF50E,0xFF351) -- lr arrow combi snippet
    clipped  (main,characters,id,size,0xFF50F,0xFF352) -- lr arrow combi snippet
    clipped  (main,characters,id,size,0xFF510,0x02261) -- equiv

    extension(main,characters,id,size,0x2190,0xFF502,0xFF501,0xFF501)                 -- \leftarrow
    extension(main,characters,id,size,0x2192,0xFF501,0xFF501,0xFF503)                 -- \rightarrow

    extension(main,characters,id,size,0x002D,0xFF501,0xFF501,0xFF501)                 -- \rel
    extension(main,characters,id,size,0x003D,0xFF50A,0xFF50A,0xFF50A)                 -- \equal
    extension(main,characters,id,size,0x2261,0xFF510,0xFF510,0xFF510)                 -- \equiv

    jointwo  (main,characters,id,size,0x21A6,0xFE321,0,0x02192)                       -- \mapstochar\rightarrow
    jointwo  (main,characters,id,size,0x21A9,0x02190,joinrelfactor,0xFE323)           -- \leftarrow\joinrel\rhook
    jointwo  (main,characters,id,size,0x21AA,0xFE322,joinrelfactor,0x02192)           -- \lhook\joinrel\rightarrow
    jointwo  (main,characters,id,size,0x27F5,0x02190,joinrelfactor,0x0002D)           -- \leftarrow\joinrel\relbar
    jointwo  (main,characters,id,size,0x27F6,0x0002D,joinrelfactor,0x02192,2)         -- \relbar\joinrel\rightarrow
    jointwo  (main,characters,id,size,0x27F7,0x02190,joinrelfactor,0x02192)           -- \leftarrow\joinrel\rightarrow
    jointwo  (main,characters,id,size,0x27F8,0x021D0,joinrelfactor,0x0003D)           -- \Leftarrow\joinrel\Relbar
    jointwo  (main,characters,id,size,0x27F9,0x0003D,joinrelfactor,0x021D2)           -- \Relbar\joinrel\Rightarrow
    jointwo  (main,characters,id,size,0x27FA,0x021D0,joinrelfactor,0x021D2)           -- \Leftarrow\joinrel\Rightarrow
    jointhree(main,characters,id,size,0x27FB,0x02190,joinrelfactor,0x0002D,0,0xFE324) -- \leftarrow\joinrel\relbar\mapsfromchar
    jointhree(main,characters,id,size,0x27FC,0xFE321,0,0x0002D,joinrelfactor,0x02192) -- \mapstochar\relbar\joinrel\rightarrow

    extension(main,characters,id,size,0x21A6,0xFF504,0xFF501,0xFF503)                 -- \mapstochar\rightarrow
    extension(main,characters,id,size,0x21A9,0xFF502,0xFF501,0xFF506)                 -- \leftarrow\joinrel\rhook
    extension(main,characters,id,size,0x21AA,0xFF505,0xFF501,0xFF503)                 -- \lhook\joinrel\rightarrow
    extension(main,characters,id,size,0x27F5,0xFF502,0xFF501,0xFF501)                 -- \leftarrow\joinrel\relbar
    extension(main,characters,id,size,0x27F6,0xFF501,0xFF501,0xFF503)                 -- \relbar\joinrel\rightarrow
    extension(main,characters,id,size,0x27F7,0xFF502,0xFF501,0xFF503)                 -- \leftarrow\joinrel\rightarrow
    extension(main,characters,id,size,0x27F8,0xFF508,0xFF50A,0xFF50A)                 -- \Leftarrow\joinrel\Relbar
    extension(main,characters,id,size,0x27F9,0xFF50A,0xFF50A,0xFF509)                 -- \Relbar\joinrel\Rightarrow
    extension(main,characters,id,size,0x27FA,0xFF508,0xFF50A,0xFF509)                 -- \Leftarrow\joinrel\Rightarrow
    extension(main,characters,id,size,0x27FB,0xFF502,0xFF501,0xFF507)                 -- \leftarrow\joinrel\relbar\mapsfromchar
    extension(main,characters,id,size,0x27FC,0xFF504,0xFF501,0xFF503)                 -- \mapstochar\relbar\joinrel\rightarrow

    extension(main,characters,id,size,0x219E,0xFF50B,0xFF501,0xFF501)                 -- \twoheadleftarrow\joinrel\relbar
    extension(main,characters,id,size,0x21A0,0xFF501,0xFF501,0xFF50C)                 -- \relbar\joinrel\twoheadrightarrow
    extension(main,characters,id,size,0x21C4,0xFF50D,0xFF50E,0xFF50F)                 -- leftoverright

    -- 21CB leftrightharpoon
    -- 21CC rightleftharpoon

    stack(main,characters,id,size,0x2259,0x0003D,3,0x02227)                       -- \buildrel\wedge\over=

    jointwo(main,characters,id,size,0x22C8,0x022B3,joinrelfactor,0x022B2)           -- \mathrel\triangleright\joinrel\mathrel\triangleleft (4 looks better than 3)
    jointwo(main,characters,id,size,0x22A7,0x0007C,joinrelfactor,0x0003D)           -- \mathrel|\joinrel=
    jointwo(main,characters,id,size,0x2260,0x00338,0,0x0003D)                       -- \not\equal
    jointwo(main,characters,id,size,0x2284,0x00338,0,0x02282)                       -- \not\subset
    jointwo(main,characters,id,size,0x2285,0x00338,0,0x02283)                       -- \not\supset
    jointwo(main,characters,id,size,0x2209,0x00338,0,0x02208)                       -- \not\in
    jointwo(main,characters,id,size,0x2254,0x03A,0,0x03D)                           -- := (≔)

    repeated(main,characters,id,size,0x222C,0x222B,2,0xFF800,1/3)
    repeated(main,characters,id,size,0x222D,0x222B,3,0xFF810,1/3)

    if cloned(main,characters,id,size,0x2032,0xFE325) then
        raise(main,characters,id,size,0x2032,0xFE325,1,id_of_smaller) -- prime
        raise(main,characters,id,size,0x2033,0xFE325,2,id_of_smaller) -- double prime
        raise(main,characters,id,size,0x2034,0xFE325,3,id_of_smaller) -- triple prime
        -- to satisfy the prime resolver
        characters[0xFE932] = characters[0x2032]
        characters[0xFE933] = characters[0x2033]
        characters[0xFE934] = characters[0x2034]
    end

    -- there are more (needs discussion first):

 -- characters[0x20D6] = characters[0x2190]
 -- characters[0x20D7] = characters[0x2192]

    characters[0x02B9] = characters[0x2032] -- we're nice

    data_of_smaller = main.fonts[id]
    size_of_smaller = size

end

local unique = 0 -- testcase: \startTEXpage \math{!\text{-}\text{-}\text{-}} \stopTEXpage

local reported = { }
local reverse  = { } -- index -> unicode

setmetatableindex(reverse, function(t,name)
    if trace_virtual then
        report_virtual("initializing math vector %a",name)
    end
    local m = mathencodings[name]
    local r = { }
    for u, i in next, m do
        r[i] = u
    end
    reverse[name] = r
    return r
end)

-- use char and font hash
--
-- commands  = { { "font", slot }, { "char", unicode } },

local function copy_glyph(main,target,original,unicode,slot)
    local addprivate = fonts.helpers.addprivate
    local olddata    = original[unicode]
    if olddata then
        local newdata = {
            width     = olddata.width,
            height    = olddata.height,
            depth     = olddata.depth,
            italic    = olddata.italic,
            kerns     = olddata.kerns,
            tounicode = olddata.tounicode,
            commands  = { { "slot", slot, unicode } },
        }
        local glyphdata = newdata
        local nextglyph = olddata.next
        while nextglyph do
            local oldnextdata = original[nextglyph]
            local newnextdata = {
                width     = oldnextdata.width,
                height    = oldnextdata.height,
                depth     = oldnextdata.depth,
                tounicode = olddata.tounicode,
                commands  = { { "slot", slot, nextglyph } },
            }
            local newnextglyph = addprivate(main,formatters["M-N-%H"](nextglyph),newnextdata)
            newdata.next = newnextglyph
            local nextnextglyph = oldnextdata.next
            if nextnextglyph == nextglyph then
                break
            else
                olddata   = oldnextdata
                newdata   = newnextdata
                nextglyph = nextnextglyph
            end
        end
        local hv = olddata.horiz_variants
        if hv then
            hv = fastcopy(hv)
            newdata.horiz_variants = hv
            for i=1,#hv do
                local hvi = hv[i]
                local oldglyph = hvi.glyph
                local olddata = original[oldglyph]
                local newdata = {
                    width     = olddata.width,
                    height    = olddata.height,
                    depth     = olddata.depth,
                    tounicode = olddata.tounicode,
                    commands  = { { "slot", slot, oldglyph } },
                }
                hvi.glyph = addprivate(main,formatters["M-H-%H"](oldglyph),newdata)
            end
        end
        local vv = olddata.vert_variants
        if vv then
            vv = fastcopy(vv)
            newdata.vert_variants = vv
            for i=1,#vv do
                local vvi = vv[i]
                local oldglyph = vvi.glyph
                local olddata = original[oldglyph]
                local newdata = {
                    width     = olddata.width,
                    height    = olddata.height,
                    depth     = olddata.depth,
                    tounicode = olddata.tounicode,
                    commands  = { { "slot", slot, oldglyph } },
                }
                vvi.glyph = addprivate(main,formatters["M-V-%H"](oldglyph),newdata)
            end
        end
        return newdata
    end
end

vfmath.copy_glyph = copy_glyph

function vfmath.define(specification,set,goodies)
    local name     = specification.name -- symbolic name
    local size     = specification.size -- given size
    local loaded   = { }
    local fontlist = { }
    local names    = { }
    local main     = nil
    local start    = (trace_virtual or trace_timings) and os.clock()
    local okset    = { }
    local n        = 0
    for s=1,#set do
        local ss     = set[s]
        local ssname = ss.name
        if add_optional and ss.optional then
            if trace_virtual then
                report_virtual("loading font %a subfont %s with name %a at %p is skipped",name,s,ssname,size)
            end
        else
            if ss.features then
                ssname = ssname .. "*" .. ss.features
            end
            if ss.main then
                main = s
            end
            local alreadyloaded = names[ssname] -- for px we load one twice (saves .04 sec)
            local f, id
            if alreadyloaded then
                f, id = alreadyloaded.f, alreadyloaded.id
                if trace_virtual then
                    report_virtual("loading font %a subfont %s with name %a is reused",name,s,ssname)
                end
            else
                f, id = fonts.constructors.readanddefine(ssname,size)
                names[ssname] = { f = f, id = id }
            end
            if not f or id == 0 then
                report_virtual("loading font %a subfont %s with name %a at %p is skipped, not found",name,s,ssname,size)
            else
                n = n + 1
                okset[n] = ss
                loaded[n] = f
                fontlist[n] = { id = id, size = size }
                if not shared[s] then
                    shared[n] = { }
                end
                if trace_virtual then
                    report_virtual("loading font %a subfont %s with name %a at %p as id %s using encoding %a",name,s,ssname,size,id,ss.vector)
                end
                if not ss.checked then
                    ss.checked = true
                    local vector = mathencodings[ss.vector]
                    if vector then
                        -- we resolve named glyphs only once as we can assume that vectors
                        -- are unique to a font set (when we read an afm we get those names
                        -- mapped onto the private area)
                        for unicode, index in next, vector do
                            if not tonumber(index) then
                                local u = f.unicodes
                                u = u and u[index]
                                if u then
                                    if trace_virtual then
                                        report_virtual("resolving name %a to %s",index,u) -- maybe more detail for u
                                    end
                                else
                                    report_virtual("unable to resolve name %a",index)
                                end
                                vector[unicode] = u
                            end
                        end
                    end
                end
            end
        end
    end
    -- beware, loaded[1] is already passed to tex (we need to make a simple copy then .. todo)
    local parent         = loaded[1] or { } -- a text font
    local characters     = { }
    local parameters     = { }
    local mathparameters = { }
    local descriptions   = { }
    local metadata       = { }
    local properties     = { }
    local goodies        = { }
    local main           = {
        metadata         = metadata,
        properties       = properties,
        characters       = characters,
        descriptions     = descriptions,
        parameters       = parameters,
        mathparameters   = mathparameters,
        fonts            = fontlist,
        goodies          = goodies,
    }
    --
    --
    for key, value in next, parent do
        if type(value) ~= "table" then
            main[key] = value
        end
    end
    --
    if parent.characters then
        for unicode, character in next, parent.characters do
            characters[unicode] = character
        end
    else
        report_virtual("font %a has no characters",name)
    end
    --
    if parent.parameters then
        for key, value in next, parent.parameters do
            parameters[key] = value
        end
    else
        report_virtual("font %a has no parameters",name)
    end
    --
    local description = { name = "<unset>" }
    setmetatableindex(descriptions,function() return description end)
    --
    if parent.properties then
        setmetatableindex(properties,parent.properties)
    end
    --
    if parent.goodies then
        setmetatableindex(goodies,parent.goodies)
    end
    --
    properties.virtualized = true
    properties.hasitalics  = true
    properties.hasmath     = true
    --
    local fullname = properties.fullname -- parent via mt
    if fullname then
        unique = unique + 1
        properties.fullname = fullname .. "-" .. unique
    end
    --
    -- we need to set some values in main as well (still?)
    --
    main.fullname      = properties.fullname
    main.type          = "virtual"
    main.nomath        = false
    --
    parameters.x_height = parameters.x_height or 0
    --
    local already_reported = false
    local parameters_done = false
    for s=1,n do
        local ss, fs = okset[s], loaded[s]
        if not fs then
            -- skip, error
        elseif add_optional and ss.optional then
            -- skip, redundant
        else
            local newparameters     = fs.parameters
            local newmathparameters = fs.mathparameters
            if newmathparameters then
                if not parameters_done or ss.parameters then
                    mathparameters  = newmathparameters
                    parameters_done = true
                end
            elseif not newparameters then
                report_virtual("no parameters set in font %a",name)
            elseif ss.extension then
                mathparameters.math_x_height          = newparameters.x_height or 0        -- math_x_height          : height of x
                mathparameters.default_rule_thickness = newparameters[ 8]      or 0        -- default_rule_thickness : thickness of \over bars
                mathparameters.big_op_spacing1        = newparameters[ 9]      or 0        -- big_op_spacing1        : minimum clearance above a displayed op
                mathparameters.big_op_spacing2        = newparameters[10]      or 0        -- big_op_spacing2        : minimum clearance below a displayed op
                mathparameters.big_op_spacing3        = newparameters[11]      or 0        -- big_op_spacing3        : minimum baselineskip above displayed op
                mathparameters.big_op_spacing4        = newparameters[12]      or 0        -- big_op_spacing4        : minimum baselineskip below displayed op
                mathparameters.big_op_spacing5        = newparameters[13]      or 0        -- big_op_spacing5        : padding above and below displayed limits
            --  report_virtual("loading and virtualizing font %a at size %p, setting ex parameters",name,size)
            elseif ss.parameters then
                mathparameters.x_height      = newparameters.x_height or mathparameters.x_height
                mathparameters.x_height      = mathparameters.x_height or fp.x_height or 0 -- x_height               : height of x
                mathparameters.num1          = newparameters[ 8] or 0                      -- num1                   : numerator shift-up in display styles
                mathparameters.num2          = newparameters[ 9] or 0                      -- num2                   : numerator shift-up in non-display, non-\atop
                mathparameters.num3          = newparameters[10] or 0                      -- num3                   : numerator shift-up in non-display \atop
                mathparameters.denom1        = newparameters[11] or 0                      -- denom1                 : denominator shift-down in display styles
                mathparameters.denom2        = newparameters[12] or 0                      -- denom2                 : denominator shift-down in non-display styles
                mathparameters.sup1          = newparameters[13] or 0                      -- sup1                   : superscript shift-up in uncramped display style
                mathparameters.sup2          = newparameters[14] or 0                      -- sup2                   : superscript shift-up in uncramped non-display
                mathparameters.sup3          = newparameters[15] or 0                      -- sup3                   : superscript shift-up in cramped styles
                mathparameters.sub1          = newparameters[16] or 0                      -- sub1                   : subscript shift-down if superscript is absent
                mathparameters.sub2          = newparameters[17] or 0                      -- sub2                   : subscript shift-down if superscript is present
                mathparameters.sup_drop      = newparameters[18] or 0                      -- sup_drop               : superscript baseline below top of large box
                mathparameters.sub_drop      = newparameters[19] or 0                      -- sub_drop               : subscript baseline below bottom of large box
                mathparameters.delim1        = newparameters[20] or 0                      -- delim1                 : size of \atopwithdelims delimiters in display styles
                mathparameters.delim2        = newparameters[21] or 0                      -- delim2                 : size of \atopwithdelims delimiters in non-displays
                mathparameters.axis_height   = newparameters[22] or 0                      -- axis_height            : height of fraction lines above the baseline
            --  report_virtual("loading and virtualizing font %a at size %p, setting sy parameters",name,size)
            end
            if ss.overlay then
                local fc    = fs.characters
                local first = ss.first
                if first then
                    local last = ss.last or first
                    for unicode = first, last do
                        characters[unicode] = copy_glyph(main,characters,fc,unicode,s)
                    end
                else
                    for unicode, data in next, fc do
                        characters[unicode] = copy_glyph(main,characters,fc,unicode,s)
                    end
                end
            else
                local vectorname = ss.vector
                if vectorname then
                    local offset      = 0xFF000
                    local vector      = mathencodings[vectorname]
                    local rotcev      = reverse[vectorname]
                    local isextension = ss.extension
                    if vector and rotcev then
                        local fc       = fs.characters
                        local fd       = fs.descriptions
                        local si       = shared[s]
                        local skewchar = ss.skewchar
                        for unicode, index in next, vector do
                            local fci = fc[index]
                            if not fci then
                                local fontname = fs.properties.name or "unknown"
                                local rf = reported[fontname]
                                if not rf then rf = { } reported[fontname] = rf end
                                local rv = rf[vectorname]
                                if not rv then rv = { } rf[vectorname] = rv end
                                local ru = rv[unicode]
                                if not ru then
                                    if trace_virtual then
                                        report_virtual("unicode slot %U has no index %H in vector %a for font %a (%S)",unicode,index,vectorname,fontname,chardata[unicode].description)
                                    elseif not already_reported then
                                        report_virtual("the mapping is incomplete for %a at %p",name,size)
                                        already_reported = true
                                    end
                                    rv[unicode] = true
                                end
                            else
                                local ref = si[index]
                                if not ref then
                                    ref = { { 'slot', s, index } }
                                    si[index] = ref
                                end
                                local kerns  = fci.kerns
                                local width  = fci.width
                                local italic = fci.italic
                                if italic and italic > 0 then
                                        -- int_a^b
                                    if isextension then
                                        width = width + italic -- for obscure reasons the integral as a width + italic correction
                                    end
                                end
                                if kerns then
                                    local krn = { }
                                    for k, v in next, kerns do -- kerns is sparse
                                        local rk = rotcev[k]
                                        if rk then
                                            krn[rk] = v -- kerns[k]
                                        end
                                    end
                                    if not next(krn) then
                                        krn = nil
                                    end
                                    local t = {
                                        width    = width,
                                        height   = fci.height,
                                        depth    = fci.depth,
                                        italic   = italic,
                                        kerns    = krn,
                                        commands = ref,
                                    }
                                    if skewchar then
                                        local k = kerns[skewchar]
                                        if k then
                                            t.top_accent = width/2 + k
                                        end
                                    end
                                    characters[unicode] = t
                                else
                                    characters[unicode] = {
                                        width    = width,
                                        height   = fci.height,
                                        depth    = fci.depth,
                                        italic   = italic,
                                        commands = ref,
                                    }
                                end
                            end
                        end
                        if isextension then
                            -- todo: if multiple ex, then 256 offsets per instance
                            local extension = mathencodings["large-to-small"]
                            local variants_done = fs.variants_done
                            for index, fci in next, fc do -- the raw ex file
                                if type(index) == "number" then
                                    local ref = si[index]
                                    if not ref then
                                        ref = { { 'slot', s, index } }
                                        si[index] = ref
                                    end
                                    local italic = fci.italic
                                    local t = {
                                        width    = fci.width,
                                        height   = fci.height,
                                        depth    = fci.depth,
                                        italic   = italic,
                                        commands = ref,
                                    }
                                    local n = fci.next
                                    if n then
                                        t.next = offset + n
                                    elseif variants_done then
                                        local vv = fci.vert_variants
                                        if vv then
                                            t.vert_variants = vv
                                        end
                                        local hv = fci.horiz_variants
                                        if hv then
                                            t.horiz_variants = hv
                                        end
                                    else
                                        local vv = fci.vert_variants
                                        if vv then
                                            for i=1,#vv do
                                                local vvi = vv[i]
                                                vvi.glyph = vvi.glyph + offset
                                            end
                                            t.vert_variants = vv
                                        end
                                        local hv = fci.horiz_variants
                                        if hv then
                                            for i=1,#hv do
                                                local hvi = hv[i]
                                                hvi.glyph = hvi.glyph + offset
                                            end
                                            t.horiz_variants = hv
                                        end
                                    end
                                    characters[offset + index] = t
                                end
                            end
                            fs.variants_done = true
                            for unicode, index in next, extension do
                                local cu = characters[unicode]
                                if cu then
                                    cu.next = offset + index
                                else
                                    local fci = fc[index]
                                    if not fci then
                                        -- do nothing
                                    else
                                        -- probably never entered
                                        local ref = si[index]
                                        if not ref then
                                            ref = { { 'slot', s, index } }
                                            si[index] = ref
                                        end
                                        local kerns = fci.kerns
                                        if kerns then
                                            local krn = { }
                                         -- for k=1,#kerns do
                                         --     krn[offset + k] = kerns[k]
                                         -- end
                                            for k, v in next, kerns do -- is kerns sparse?
                                                krn[offset + k] = v
                                            end
                                            characters[unicode] = {
                                                width    = fci.width,
                                                height   = fci.height,
                                                depth    = fci.depth,
                                                italic   = fci.italic,
                                                commands = ref,
                                                kerns    = krn,
                                                next     = offset + index,
                                            }
                                        else
                                            characters[unicode] = {
                                                width    = fci.width,
                                                height   = fci.height,
                                                depth    = fci.depth,
                                                italic   = fci.italic,
                                                commands = ref,
                                                next     = offset + index,
                                            }
                                        end
                                    end
                                end
                            end
                        end
                    else
                        report_virtual("error in loading %a, problematic vector %a",name,vectorname)
                    end
                end
            end
            mathematics.extras.copy(main) --not needed here (yet)
        end
    end
    --
    main.mathparameters = mathparameters -- still traditional ones
    -- This should change (some day) as it's the only place where we look forward,
    -- so better is to also reserve the id already which then involves some more
    -- management (so not now).
    fontlist[#fontlist+1] = {
        id   = font.nextid(),
        size = size,
    }
    vfmath.addmissing(main,#fontlist,size)
    --
    mathematics.addfallbacks(main)
    --
    main.properties.math_is_scaled = true -- signal
    fonts.constructors.assignmathparameters(main,main)
    --
    main.MathConstants = main.mathparameters -- we directly pass it to TeX (bypasses the scaler) so this is needed
    --
    if trace_virtual or trace_timings then
        report_virtual("loading and virtualizing font %a at size %p took %0.3f seconds",name,size,os.clock()-start)
    end
    --
    main.oldmath = true
    return main
end

function mathematics.makefont(name,set,goodies)
    fonts.definers.methods.variants[name] = function(specification)
        return vfmath.define(specification,set,goodies)
    end
end

-- helpers

function vfmath.setletters(font_encoding, name, uppercase, lowercase)
    local enc = font_encoding[name]
    for i = 0,25 do
        enc[uppercase+i] = i + 0x41
        enc[lowercase+i] = i + 0x61
    end
end

function vfmath.setdigits(font_encoding, name, digits)
    local enc = font_encoding[name]
    for i = 0,9 do
        enc[digits+i] = i + 0x30
    end
end
