if not modules then modules = { } end modules ['math-fbk'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_fallbacks   = false  trackers.register("math.fallbacks", function(v) trace_fallbacks = v end)

local report_fallbacks  = logs.reporter("math","fallbacks")

local formatters        = string.formatters
local fastcopy          = table.fastcopy
local byte              = string.byte

local fallbacks         = { }
mathematics.fallbacks   = fallbacks

local virtualcharacters = { }

local identifiers       = fonts.hashes.identifiers
local lastmathids       = fonts.hashes.lastmathids

-- we need a trick (todo): if we define scriptscript, script and text in
-- that order we could use their id's .. i.e. we could always add a font
-- table with those id's .. in fact, we could also add a whole lot more
-- as it doesn't hurt
--
-- todo: use index 'true when luatex provides that feature (on the agenda)

-- to be considered:
--
-- in luatex provide reserve_id (and pass id as field of tfmdata)
-- in context define three sizes but pass them later i.e. do virtualize afterwards

function fallbacks.apply(target,original)
    local mathparameters = target.mathparameters -- why not hasmath
    if mathparameters then
        local characters = target.characters
        local parameters = target.parameters
        local mathsize   = parameters.mathsize
        local size       = parameters.size
        local usedfonts  = target.fonts
        if not usedfonts then
            usedfonts    = {  }
            target.fonts = usedfonts
        end
        -- This is not okay yet ... we have no proper way to refer to 'self'
        -- otherwise I will make my own id allocator).
        local self = #usedfonts == 0 and font.nextid() or nil -- will be true
        local textid, scriptid, scriptscriptid
        local textindex, scriptindex, scriptscriptindex
        local textdata, scriptdata, scriptscriptdata
        if mathsize == 3 then
            -- scriptscriptsize
         -- textid         = nil -- self
         -- scriptid       = nil -- no smaller
         -- scriptscriptid = nil -- no smaller
            textid         = self
            scriptid       = self
            scriptscriptid = self
        elseif mathsize == 2 then
            -- scriptsize
         -- textid         = nil -- self
            textid         = self
            scriptid       = lastmathids[3]
            scriptscriptid = lastmathids[3]
        else
            -- textsize
         -- textid         = nil -- self
            textid         = self
            scriptid       = lastmathids[2]
            scriptscriptid = lastmathids[3]
        end
        if textid then
            textindex = #usedfonts + 1
            usedfonts[textindex] = { id = textid }
--             textdata = identifiers[textid] or target
            textdata = target
        else
            textdata = target
        end
        if scriptid then
            scriptindex = #usedfonts  + 1
            usedfonts[scriptindex] = { id = scriptid }
            scriptdata = identifiers[scriptid]
        else
            scriptindex = textindex
            scriptdata  = textdata
        end
        if scriptscriptid then
            scriptscriptindex = #usedfonts  + 1
            usedfonts[scriptscriptindex] = { id = scriptscriptid }
            scriptscriptdata = identifiers[scriptscriptid]
        else
            scriptscriptindex = scriptindex
            scriptscriptdata  = scriptdata
        end
     -- report_fallbacks("used textid: %S, used script id: %S, used scriptscript id: %S",textid,scriptid,scriptscriptid)
        local data = {
            textdata          = textdata,
            scriptdata        = scriptdata,
            scriptscriptdata  = scriptscriptdata,
            textindex         = textindex,
            scriptindex       = scriptindex,
            scriptscriptindex = scriptscriptindex,
            textid            = textid,
            scriptid          = scriptid,
            scriptscriptid    = scriptscriptid,
            characters        = characters,
            unicode           = k,
            target            = target,
            original          = original,
            size              = size,
            mathsize          = mathsize,
        }
        target.mathrelation = data
     -- inspect(usedfonts)
        for k, v in next, virtualcharacters do
            if not characters[k] then
                local tv = type(v)
                local cd = nil
                if tv == "table" then
                    cd = v
                elseif tv == "number" then
                    cd = characters[v]
                elseif tv == "function" then
                    cd = v(data)
                end
                if cd then
                    characters[k] = cd
                else
                    -- something else
                end
                if trace_fallbacks and characters[k] then
                    report_fallbacks("extending math font %a with %U",target.properties.fullname,k)
                end
            end
        end
        data.unicode = nil
    end
end

utilities.sequencers.appendaction("aftercopyingcharacters","system","mathematics.fallbacks.apply")

function fallbacks.install(unicode,value)
    virtualcharacters[unicode] = value
end

-- a few examples:

local function reference(index,char)
    if index then
        return { "slot", index, char }
    else
        return { "char", char }
    end
end

local function raised(data,down)
    local replacement = data.replacement
    local character = data.scriptdata.characters[replacement]
    if character then
        return {
            width    = character.width,
            height   = character.height,
            depth    = character.depth,
            commands = {
                { "down", down and data.size/4 or -data.size/2 }, -- maybe exheight
                reference(data.scriptindex,replacement)
            }
        }
    end
end

-- virtualcharacters[0x207A] = 0x2212
-- virtualcharacters[0x207B] = 0x002B
-- virtualcharacters[0x208A] = 0x2212
-- virtualcharacters[0x208B] = 0x002B

virtualcharacters[0x207A] = function(data)
    data.replacement = 0x002B
    return raised(data)
end

virtualcharacters[0x207B] = function(data)
    data.replacement = 0x2212
    return raised(data)
end

virtualcharacters[0x208A] = function(data)
    data.replacement = 0x002B
    return raised(data,true)
end

virtualcharacters[0x208B] = function(data)
    data.replacement = 0x2212
    return raised(data,true)
end

-- local function repeated(data,char,n,fraction)
--     local character = data.characters[char]
--     if character then
--         local width = character.width
--         local delta = width - character.italic -- width * fraction
--         local c = { "char", char }
--         local r = { "right", right }
--         local commands = { }
--         for i=1,n-1 do
--             width = width + delta
--             commands[#commands+1] = c
--             commands[#commands+1] = -delta
--         end
--         commands[#commands+1] = c
--         return {
--             width    = width,
--             height   = character.height,
--             depth    = character.depth,
--             commands = commands,
--         }
--     end
-- end

-- virtualcharacters[0x222C] = function(data)
--     return repeated(data,0x222B,2,1/8)
-- end

-- virtualcharacters[0x222D] = function(data)
--     return repeated(data,0x222B,3,1/8)
-- end

local addextra = mathematics.extras.add

addextra(0xFE350, {
    category="sm",
    description="MATHEMATICAL DOUBLE ARROW LEFT END",
    mathclass="relation",
    mathname="ctxdoublearrowfillleftend",
    unicodeslot=0xFE350,
} )

addextra(0xFE351, {
    category="sm",
    description="MATHEMATICAL DOUBLE ARROW MIDDLE PART",
    mathclass="relation",
    mathname="ctxdoublearrowfillmiddlepart",
    unicodeslot=0xFE351,
} )

addextra(0xFE352, {
    category="sm",
    description="MATHEMATICAL DOUBLE ARROW RIGHT END",
    mathclass="relation",
    mathname="ctxdoublearrowfillrightend",
    unicodeslot=0xFE352,
} )

local push       = { "push" }
local pop        = { "pop" }
local leftarrow  = { "char", 0x2190 }
local relbar     = { "char", 0x2212 }
local rightarrow = { "char", 0x2192 }

virtualcharacters[0xFE350] = function(data)
 -- return combined(data,0x2190,0x2212) -- leftarrow relbar
    local charone = data.characters[0x2190]
    local chartwo = data.characters[0x2212]
    if charone and chartwo then
        local size = data.size/2
        return {
            width    = chartwo.width,
            height   = size,
            depth    = size,
            commands = {
                push,
                { "down", size/2 },
                leftarrow,
                pop,
                { "down", -size/2 },
                relbar,
            }
        }
    end
end

virtualcharacters[0xFE351] = function(data)
 -- return combined(data,0x2212,0x2212) -- relbar, relbar  (isn't that just equal)
    local char = data.characters[0x2212]
    if char then
        local size = data.size/2
        return {
            width    = char.width,
            height   = size,
            depth    = size,
            commands = {
                push,
                { "down", size/2 },
                relbar,
                pop,
                { "down", -size/2 },
                relbar,
            }
        }
    end
end

virtualcharacters[0xFE352] = function(data)
 -- return combined(data,0x2192,0x2212) -- rightarrow relbar
    local charone = data.characters[0x2192]
    local chartwo = data.characters[0x2212]
    if charone and chartwo then
        local size = data.size/2
        return {
            width    = chartwo.width,
            height   = size,
            depth    = size,
            commands = {
                push,
                { "down", size/2 },
                relbar,
                pop,
                { "right", chartwo.width - charone.width },
                { "down", -size/2 },
                rightarrow,
            }
        }
    end
end

-- we could move the defs from math-act here

local function accent_to_extensible(target,newchr,original,oldchr,height,depth,swap,offset,unicode)
    local characters = target.characters
    local olddata = characters[oldchr]
    -- brrr ... pagella has only next
    if olddata and not olddata.commands and olddata.width > 0 then
        local addprivate = fonts.helpers.addprivate
        if swap then
            swap = characters[swap]
            height = swap.depth or 0
            depth  = 0
        else
            height = height or 0
            depth  = depth  or 0
        end
        local correction = swap and { "down", (olddata.height or 0) - height } or { "down", olddata.height + (offset or 0)}
        local newdata = {
            commands = { correction, { "slot", 1, oldchr } },
            width    = olddata.width,
            height   = height,
            depth    = depth,
            unicode  = unicode,
        }
        local glyphdata = newdata
        local nextglyph = olddata.next
        while nextglyph do
            local oldnextdata = characters[nextglyph]
            if oldnextdata then
                local newnextdata = {
                    commands = { correction, { "slot", 1, nextglyph } },
                    width    = oldnextdata.width,
                    height   = height,
                    depth    = depth,
                }
                local newnextglyph = addprivate(target,formatters["M-N-%H"](nextglyph),newnextdata)
                newdata.next = newnextglyph
                local nextnextglyph = oldnextdata.next
                if nextnextglyph == nextglyph then
                    break
                else
                    olddata   = oldnextdata
                    newdata   = newnextdata
                    nextglyph = nextnextglyph
                end
            else
                report_fallbacks("error in fallback: no valid next, slot %X",nextglyph)
                break
            end
        end
        local hv = olddata.horiz_variants
        if hv then
            hv = fastcopy(hv)
            newdata.horiz_variants = hv
            for i=1,#hv do
                local hvi = hv[i]
                local oldglyph = hvi.glyph
                local olddata = characters[oldglyph]
                if olddata then
                    local newdata = {
                        commands = { correction, { "slot", 1, oldglyph } },
                        width    = olddata.width,
                        height   = height,
                        depth    = depth,
                    }
                    hvi.glyph = addprivate(target,formatters["M-H-%H"](oldglyph),newdata)
                else
                    report_fallbacks("error in fallback: no valid horiz_variants, slot %X, index %i",oldglyph,i)
                end
            end
        end
        return glyphdata, true
    else
        return olddata, false
    end
end

virtualcharacters[0x203E] = function(data) -- could be FE33E instead
    local target = data.target
    local height, depth = 0, 0
    local mathparameters = target.mathparameters
    if mathparameters then
        height = mathparameters.OverbarVerticalGap
        depth  = mathparameters.UnderbarVerticalGap
    else
        height = target.parameters.xheight/4
        depth  = height
    end
    return accent_to_extensible(target,0x203E,data.original,0x0305,height,depth,nil,nil,0x203E)
end

virtualcharacters[0xFE33E] = virtualcharacters[0x203E] -- convenient
virtualcharacters[0xFE33F] = virtualcharacters[0x203E] -- convenient

-- spacing

local c_zero   = byte('0')
local c_period = byte('.')

local function spacefraction(data,fraction)
    local width = fraction * data.target.parameters.space
    return {
        width    = width,
        commands = { right = width }
    }
end

local function charfraction(data,char)
    local width = data.target.characters[char].width
    return {
        width    = width,
        commands = { right = width }
    }
end

local function quadfraction(data,fraction)
    local width = fraction * data.target.parameters.quad
    return {
        width    = width,
        commands = { right = width }
    }
end

virtualcharacters[0x00A0] = function(data) return spacefraction(data,1)        end -- nbsp
virtualcharacters[0x2000] = function(data) return quadfraction (data,1/2)      end -- enquad
virtualcharacters[0x2001] = function(data) return quadfraction (data,1)        end -- emquad
virtualcharacters[0x2002] = function(data) return quadfraction (data,1/2)      end -- enspace
virtualcharacters[0x2003] = function(data) return quadfraction (data,1)        end -- emspace
virtualcharacters[0x2004] = function(data) return quadfraction (data,1/3)      end -- threeperemspace
virtualcharacters[0x2005] = function(data) return quadfraction (data,1/4)      end -- fourperemspace
virtualcharacters[0x2006] = function(data) return quadfraction (data,1/6)      end -- sixperemspace
virtualcharacters[0x2007] = function(data) return charfraction (data,c_zero)   end -- figurespace
virtualcharacters[0x2008] = function(data) return charfraction (data,c_period) end -- punctuationspace
virtualcharacters[0x2009] = function(data) return quadfraction (data,1/8)      end -- breakablethinspace
virtualcharacters[0x200A] = function(data) return quadfraction (data,1/8)      end -- hairspace
virtualcharacters[0x200B] = function(data) return quadfraction (data,0)        end -- zerowidthspace
virtualcharacters[0x202F] = function(data) return quadfraction (data,1/8)      end -- narrownobreakspace
virtualcharacters[0x205F] = function(data) return spacefraction(data,1/2)      end -- math thinspace

--

local function smashed(data,unicode,swap,private)
    local target   = data.target
    local original = data.original
    local chardata = target.characters[unicode]
    if chardata and chardata.height > target.parameters.xheight then
        return accent_to_extensible(target,private,original,unicode,0,0,swap,nil,unicode)
    else
        return original.characters[unicode]
    end
end

addextra(0xFE3DE, { description="EXTENSIBLE OF 0x03DE", unicodeslot=0xFE3DE, mathextensible = "r", mathstretch = "h", mathclass = "topaccent" } )
addextra(0xFE3DC, { description="EXTENSIBLE OF 0x03DC", unicodeslot=0xFE3DC, mathextensible = "r", mathstretch = "h", mathclass = "topaccent" } )
addextra(0xFE3B4, { description="EXTENSIBLE OF 0x03B4", unicodeslot=0xFE3B4, mathextensible = "r", mathstretch = "h", mathclass = "topaccent" } )

virtualcharacters[0xFE3DE] = function(data) return smashed(data,0x23DE,0x23DF,0xFE3DE) end
virtualcharacters[0xFE3DC] = function(data) return smashed(data,0x23DC,0x23DD,0xFE3DC) end
virtualcharacters[0xFE3B4] = function(data) return smashed(data,0x23B4,0x23B5,0xFE3B4) end

addextra(0xFE3DF, { description="EXTENSIBLE OF 0x03DF", unicodeslot=0xFE3DF, mathextensible = "r", mathstretch = "h", mathclass = "botaccent" } )
addextra(0xFE3DD, { description="EXTENSIBLE OF 0x03DD", unicodeslot=0xFE3DD, mathextensible = "r", mathstretch = "h", mathclass = "botaccent" } )
addextra(0xFE3B5, { description="EXTENSIBLE OF 0x03B5", unicodeslot=0xFE3B5, mathextensible = "r", mathstretch = "h", mathclass = "botaccent" } )

virtualcharacters[0xFE3DF] = function(data) local c = data.target.characters[0x23DF] if c then c.unicode = 0x23DF return c end end
virtualcharacters[0xFE3DD] = function(data) local c = data.target.characters[0x23DD] if c then c.unicode = 0x23DD return c end end
virtualcharacters[0xFE3B5] = function(data) local c = data.target.characters[0x23B5] if c then c.unicode = 0x23B5 return c end end

-- todo: add some more .. numbers might change

addextra(0xFE302, { description="EXTENSIBLE OF 0x0302", unicodeslot=0xFE302, mathstretch = "h", mathclass = "topaccent" } )
addextra(0xFE303, { description="EXTENSIBLE OF 0x0303", unicodeslot=0xFE303, mathstretch = "h", mathclass = "topaccent" } )

local function smashed(data,unicode,private)
    local target = data.target
    local height = target.parameters.xheight / 2
    local c, done = accent_to_extensible(target,private,data.original,unicode,height,0,nil,-height,unicode)
    if done then
        c.top_accent = nil -- or maybe also all the others
    end
    return c
end

virtualcharacters[0xFE302] = function(data) return smashed(data,0x0302,0xFE302) end
virtualcharacters[0xFE303] = function(data) return smashed(data,0x0303,0xFE303) end

-- another crazy hack .. doesn't work as we define scrscr first .. we now have smaller
-- primes so we have smaller primes for the moment, big ones will become an option ..
-- these primes in fonts are a real mess .. kind of a dead end, so don't wonder about
-- the values below

-- local function smashed(data,unicode,optional)
--     local oldchar = data.characters[unicode]
--     if oldchar then
--         local xheight = data.target.parameters.xheight
--         local height  = 1.25 * xheight
--         local shift   = oldchar.height - height
--         local newchar = {
--             commands = {
--                 { "down", shift },
--                 { "char", unicode },
--             },
--             height = height,
--             width  = oldchar.width,
--         }
--         return newchar
--     elseif not optional then
--         report_fallbacks("missing %U prime in font %a",unicode,data.target.properties.fullname)
--     end
-- end

-- addextra(0xFE932, { description = "SMASHED PRIME 0x02032", unicodeslot = 0xFE932 } )
-- addextra(0xFE933, { description = "SMASHED PRIME 0x02033", unicodeslot = 0xFE933 } )
-- addextra(0xFE934, { description = "SMASHED PRIME 0x02034", unicodeslot = 0xFE934 } )
-- addextra(0xFE957, { description = "SMASHED PRIME 0x02057", unicodeslot = 0xFE957 } )

-- addextra(0xFE935, { description = "SMASHED BACKWARD PRIME 0x02035", unicodeslot = 0xFE935 } )
-- addextra(0xFE936, { description = "SMASHED BACKWARD PRIME 0x02036", unicodeslot = 0xFE936 } )
-- addextra(0xFE937, { description = "SMASHED BACKWARD PRIME 0x02037", unicodeslot = 0xFE937 } )

-- virtualcharacters[0xFE932] = function(data) return smashed(data,0x02032) end
-- virtualcharacters[0xFE933] = function(data) return smashed(data,0x02033) end
-- virtualcharacters[0xFE934] = function(data) return smashed(data,0x02034) end
-- virtualcharacters[0xFE957] = function(data) return smashed(data,0x02057) end

-- virtualcharacters[0xFE935] = function(data) return smashed(data,0x02035,true) end
-- virtualcharacters[0xFE936] = function(data) return smashed(data,0x02036,true) end
-- virtualcharacters[0xFE937] = function(data) return smashed(data,0x02037,true) end

-- actuarian (beware: xits has an ugly one)

addextra(0xFE940, { category = "mn", description="SMALL ANNUITY SYMBOL", unicodeslot=0xFE940, mathclass="topaccent", mathname="smallactuarial" })

local function actuarian(data)
    local characters = data.target.characters
    local parameters = data.target.parameters
    local basechar   = characters[0x0078] -- x (0x0058 X) or 0x1D431
    local linewidth  = parameters.xheight / 10
    local basewidth  = basechar.width
    local baseheight = basechar.height
    return {
        -- todo: add alttext
        -- compromise: lm has large hooks e.g. \actuarial{a}
        width     = basewidth + 4 * linewidth,
        unicode   = 0x20E7,
        commands  = {
            { "right", 2 * linewidth },
            { "down", - baseheight - 3 * linewidth },
            { "rule", linewidth, basewidth + 4 * linewidth },
            { "right", -linewidth },
            { "down", baseheight + 4 * linewidth },
            { "rule", baseheight + 5 * linewidth, linewidth },
        },
    }
end

virtualcharacters[0x020E7] = actuarian -- checked
virtualcharacters[0xFE940] = actuarian -- unchecked
