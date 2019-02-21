if not modules then modules = { } end modules ['math-fbk'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type

local trace_fallbacks   = false  trackers.register("math.fallbacks", function(v) trace_fallbacks = v end)

local report_fallbacks  = logs.reporter("math","fallbacks")

local formatters        = string.formatters
local fastcopy          = table.fastcopy
local byte              = string.byte
local sortedhash        = table.sortedhash

local fallbacks         = { }
mathematics.fallbacks   = fallbacks

local helpers           = fonts.helpers
local prependcommands   = helpers.prependcommands
local charcommand       = helpers.commands.char
local leftcommand       = helpers.commands.left
local rightcommand      = helpers.commands.right
local upcommand         = helpers.commands.up
local downcommand       = helpers.commands.down
local dummycommand      = helpers.commands.dummy
local popcommand        = helpers.commands.pop
local pushcommand       = helpers.commands.push

local virtualcharacters = { }

local hashes            = fonts.hashes
local identifiers       = hashes.identifiers
local lastmathids       = hashes.lastmathids

-- we need a trick (todo): if we define scriptscript, script and text in
-- that order we could use their id's .. i.e. we could always add a font
-- table with those id's .. in fact, we could also add a whole lot more
-- as it doesn't hurt

local scripscriptdelayed = { } -- 1.005 : add characters later
local scriptdelayed      = { } -- 1.005 : add characters later

function fallbacks.apply(target,original)
    local mathparameters = target.mathparameters
    if not mathparameters or not next(mathparameters) then
        return
    end
    -- we also have forcedsize ... at this moment we already passed through
    -- constructors.scale so we have this set
    local parameters = target.parameters
    local mathsize   = parameters.mathsize
    if mathsize < 1 or mathsize > 3 then
        return
    end
    local characters = target.characters
    local size       = parameters.size
    local usedfonts  = target.fonts
    if not usedfonts then
        usedfonts    = { { id = 0 } } -- we need at least one entry (automatically done anyway)
        target.fonts = usedfonts
    end
    -- not used
    local textid, scriptid, scriptscriptid
    local textindex, scriptindex, scriptscriptindex
    local textdata, scriptdata, scriptscriptdata
    if mathsize == 3 then
        -- scriptscriptsize
        textid         = 0
        scriptid       = 0
        scriptscriptid = 0
    elseif mathsize == 2 then
        -- scriptsize
        textid         = 0
        scriptid       = lastmathids[3] or 0
        scriptscriptid = lastmathids[3] or 0
    else
        -- textsize
        textid         = 0
        scriptid       = lastmathids[2] or 0
        scriptscriptid = lastmathids[3] or 0
    end
    if textid and textid ~= 0 then
        textindex = #usedfonts + 1
        textdata  = target
        usedfonts[textindex] = { id = textid }
    else
        textdata = target
    end
    if scriptid and scriptid ~= 0 then
        scriptindex = #usedfonts  + 1
        scriptdata  = identifiers[scriptid]
        usedfonts[scriptindex] = { id = scriptid }
    else
        scriptindex = textindex
        scriptdata  = textdata
    end
    if scriptscriptid and scriptscriptid ~= 0 then
        scriptscriptindex = #usedfonts  + 1
        scriptscriptdata  = identifiers[scriptscriptid]
        usedfonts[scriptscriptindex] = { id = scriptscriptid }
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
    --
    local fullname = trace_fallbacks and target.properties.fullname
    --
    for k, v in sortedhash(virtualcharacters) do
        if not characters[k] then
            local tv = type(v)
            local cd = nil
            if tv == "table" then
                cd = v
            elseif tv == "number" then
                cd = characters[v]
            elseif tv == "function" then
                cd = v(data) -- ,k
            end
            if cd then
                characters[k] = cd
            else
                -- something else
            end
            if trace_fallbacks and characters[k] then
                report_fallbacks("extending math font %a with %U",fullname,k)
            end
        end
    end
    data.unicode = nil
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
        return charcommand[char]
    end
end

local function raised(data,replacement,down)
    local character = data.scriptdata.characters[replacement]
    if character then
        local size = data.size
        return {
            width    = character.width,
            height   = character.height,
            depth    = character.depth,
            commands = {
                down and downcommand[size/4] or upcommand[size/2],
                reference(data.scriptindex,replacement)
            }
        }
    end
end

-- virtualcharacters[0x207A] = 0x2212
-- virtualcharacters[0x207B] = 0x002B
-- virtualcharacters[0x208A] = 0x2212
-- virtualcharacters[0x208B] = 0x002B

virtualcharacters[0x207A] = function(data) return raised(data,0x002B)      end
virtualcharacters[0x207B] = function(data) return raised(data,0x2212)      end
virtualcharacters[0x208A] = function(data) return raised(data,0x002B,true) end
virtualcharacters[0x208B] = function(data) return raised(data,0x2212,true) end

-- local function repeated(data,char,n,fraction)
--     local character = data.characters[char]
--     if character then
--         local width = character.width
--         local delta = width - character.italic -- width * fraction
--         local c = charcommand[char]
--         local r = rightcommand[right]
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

addextra(0xFE350) -- MATHEMATICAL DOUBLE ARROW LEFT END
addextra(0xFE351) -- MATHEMATICAL DOUBLE ARROW MIDDLE PART
addextra(0xFE352) -- MATHEMATICAL DOUBLE ARROW RIGHT END

local leftarrow  = charcommand[0x2190]
local relbar     = charcommand[0x2212]
local rightarrow = charcommand[0x2192]

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
                pushcommand,
                downcommand[size/2],
                leftarrow,
                popcommand,
                upcommand[size/2],
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
                pushcommand,
                downcommand[size/2],
                relbar,
                popcommand,
                upcommand[size/2],
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
                pushcommand,
                downcommand[size/2],
                relbar,
                popcommand,
                rightcommand[chartwo.width - charone.width],
                upcommand[size/2],
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
    if olddata and not olddata.commands then -- not: and olddata.width > 0
        local addprivate = fonts.helpers.addprivate
        if swap then
            swap   = characters[swap]
            height = swap.depth or 0
            depth  = 0
        else
            height = height or 0
            depth  = depth  or 0
        end
        local oldheight  = olddata.height or 0
        local correction = swap and
            downcommand[oldheight - height]
         or downcommand[oldheight + (offset or 0)]
        local newdata = {
            commands = { correction, charcommand[oldchr] },
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
                    commands = { correction, charcommand[nextglyph] },
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
                        commands = { correction, charcommand[oldglyph] },
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

virtualcharacters[0x203E] = function(data)
    local target = data.target
    local height = 0
    local depth  = 0
 -- local mathparameters = target.mathparameters
 -- if mathparameters then
 --     height = mathparameters.OverbarVerticalGap
 --     depth  = mathparameters.UnderbarVerticalGap
 -- else
        height = target.parameters.xheight/4
        depth  = height
 -- end
    return accent_to_extensible(target,0x203E,data.original,0x0305,height,depth,nil,nil,0x203E)
end

-- virtualcharacters[0xFE33E] = virtualcharacters[0x203E] -- convenient
-- virtualcharacters[0xFE33F] = virtualcharacters[0x203E] -- convenient

virtualcharacters[0xFE33E] = function(data)
    local target = data.target
    local height = 0
    local depth  = target.parameters.xheight/4
    return accent_to_extensible(target,0xFE33E,data.original,0x0305,height,depth,nil,nil,0x203E)
end

virtualcharacters[0xFE33F] = function(data)
    local target = data.target
    local height = target.parameters.xheight/8
    local depth  = height
    return accent_to_extensible(target,0xFE33F,data.original,0x0305,height,depth,nil,nil,0x203E)
end

-- spacing (no need for a cache of widths)

local c_zero   = byte('0')
local c_period = byte('.')

local function spacefraction(data,fraction)
    local width = fraction * data.target.parameters.space
    return {
        width    = width,
        commands = { rightcommand[width] }
    }
end

local function charfraction(data,char)
    local width = data.target.characters[char].width
    return {
        width    = width,
        commands = { rightcommand[width] }
    }
end

local function quadfraction(data,fraction)
    local width = fraction * data.target.parameters.quad
    return {
        width    = width,
        commands = { rightcommand[width] }
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

addextra(0xFE3DE) -- EXTENSIBLE OF 0x03DE
addextra(0xFE3DC) -- EXTENSIBLE OF 0x03DC
addextra(0xFE3B4) -- EXTENSIBLE OF 0x03B4

virtualcharacters[0xFE3DE] = function(data) return smashed(data,0x23DE,0x23DF,0xFE3DE) end
virtualcharacters[0xFE3DC] = function(data) return smashed(data,0x23DC,0x23DD,0xFE3DC) end
virtualcharacters[0xFE3B4] = function(data) return smashed(data,0x23B4,0x23B5,0xFE3B4) end

addextra(0xFE3DF) -- EXTENSIBLE OF 0x03DF
addextra(0xFE3DD) -- EXTENSIBLE OF 0x03DD
addextra(0xFE3B5) -- EXTENSIBLE OF 0x03B5

virtualcharacters[0xFE3DF] = function(data) local c = data.target.characters[0x23DF] if c then c.unicode = 0x23DF return c end end
virtualcharacters[0xFE3DD] = function(data) local c = data.target.characters[0x23DD] if c then c.unicode = 0x23DD return c end end
virtualcharacters[0xFE3B5] = function(data) local c = data.target.characters[0x23B5] if c then c.unicode = 0x23B5 return c end end

-- todo: add some more .. numbers might change

addextra(0xFE302) -- EXTENSIBLE OF 0x0302
addextra(0xFE303) -- EXTENSIBLE OF 0x0303

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

local function smashed(data,unicode,optional)
    local oldchar = data.characters[unicode]
    if oldchar then
     -- local height = 1.25 * data.target.parameters.xheight
        local height = 0.85 * data.target.mathparameters.AccentBaseHeight
        local shift  = oldchar.height - height
        local newchar = {
            commands = {
                downcommand[shift],
                charcommand[unicode],
            },
            height = height,
            width  = oldchar.width,
        }
        return newchar
    elseif not optional then
        report_fallbacks("missing %U prime in font %a",unicode,data.target.properties.fullname)
    end
end

addextra(0xFE932) -- SMASHED PRIME 0x02032
addextra(0xFE933) -- SMASHED PRIME 0x02033
addextra(0xFE934) -- SMASHED PRIME 0x02034
addextra(0xFE957) -- SMASHED PRIME 0x02057

addextra(0xFE935) -- SMASHED BACKWARD PRIME 0x02035
addextra(0xFE936) -- SMASHED BACKWARD PRIME 0x02036
addextra(0xFE937) -- SMASHED BACKWARD PRIME 0x02037

virtualcharacters[0xFE932] = function(data) return smashed(data,0x02032) end
virtualcharacters[0xFE933] = function(data) return smashed(data,0x02033) end
virtualcharacters[0xFE934] = function(data) return smashed(data,0x02034) end
virtualcharacters[0xFE957] = function(data) return smashed(data,0x02057) end

virtualcharacters[0xFE935] = function(data) return smashed(data,0x02035,true) end
virtualcharacters[0xFE936] = function(data) return smashed(data,0x02036,true) end
virtualcharacters[0xFE937] = function(data) return smashed(data,0x02037,true) end

local hack = nil

function mathematics.getridofprime(target,original)
--     local mathsize = specification.mathsize
--     if mathsize == 1 or mathsize == 2 or mathsize == 3) then
    local mathparameters = original.mathparameters
    if mathparameters and next(mathparameters) then
        local changed = original.changed
        if changed then
            hack = changed[0x02032]
            changed[0x02032] = nil
            changed[0x02033] = nil
            changed[0x02034] = nil
            changed[0x02057] = nil
            changed[0x02035] = nil
            changed[0x02036] = nil
            changed[0x02037] = nil
        end
    end
end

function mathematics.setridofprime(target,original)
    local mathparameters = original.mathparameters
    if mathparameters and next(mathparameters) and original.changed then
        target.characters[0xFE931] = target.characters[hack or 0x2032]
        hack = nil
    end
end

utilities.sequencers.appendaction("beforecopyingcharacters","system","mathematics.getridofprime")
utilities.sequencers.appendaction("aftercopyingcharacters", "system","mathematics.setridofprime")

-- actuarian (beware: xits has an ugly one)

addextra(0xFE940) -- SMALL ANNUITY SYMBOL

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
            rightcommand[2 * linewidth],
            downcommand[- baseheight - 3 * linewidth],
            { "rule", linewidth, basewidth + 4 * linewidth },
            leftcommand[linewidth],
            downcommand[baseheight + 4 * linewidth],
            { "rule", baseheight + 5 * linewidth, linewidth },
        },
    }
end

virtualcharacters[0x020E7] = actuarian -- checked
virtualcharacters[0xFE940] = actuarian -- unchecked

local function equals(data,unicode,snippet,advance,n) -- mathpair needs them
    local characters = data.target.characters
    local parameters = data.target.parameters
    local basechar   = characters[snippet]
    local advance    = advance * parameters.quad
    return {
        unicode   = unicode,
        width     = n*basechar.width + (n-1)*advance,
        commands  = {
            charcommand[snippet],
            rightcommand[advance],
            charcommand[snippet],
            n > 2 and rightcommand[advance] or nil,
            n > 2 and charcommand[snippet] or nil,
        },
    }
end

virtualcharacters[0x2A75] = function(data) return equals(data,0x2A75,0x003D, 1/5,2) end -- ==
virtualcharacters[0x2A76] = function(data) return equals(data,0x2A76,0x003D, 1/5,3) end -- ===
virtualcharacters[0x2980] = function(data) return equals(data,0x2980,0x007C,-1/8,3) end -- |||

-- addextra(0xFE941) -- EXTREMELY IDENTICAL TO
--
-- virtualcharacters[0xFE941] = function(data) -- this character is only needed for mathpairs
--     local characters = data.target.characters
--     local parameters = data.target.parameters
--     local basechar   = characters[0x003D]
--     local width      = basechar.width or 0
--     local height     = basechar.height or 0
--     local depth      = basechar.depth or 0
--     return {
--         unicode   = 0xFE941,
--         width     = width,
--         height    = height,         -- we cheat (no time now)
--         depth     = depth,          -- we cheat (no time now)
--         commands  = {
--             upcommand[height/2], -- sort of works
--             charcommand[0x003D],
--             leftcommand[width],
--             downcommand[height],     -- sort of works
--             charcommand[0x003D],
--         },
--     }
-- end

-- lucida needs this

virtualcharacters[0x305] = function(data)
    local target = data.target
    local height = target.parameters.xheight/8
    local width  = target.parameters.emwidth/2
    local depth  = height
    local used   = 0.8 * width
    return {
        width    = width,
        height   = height,
        depth    = depth,
        commands = { { "rule", height, width } },
        horiz_variants = {
            {
              advance   = width,
              ["end"]   = used,
              glyph     = 0x305,
              start     = 0,
            },
            {
              advance   = width,
              ["end"]   = 0,
              extender  = 1,
              glyph     = 0x305,
              start     = used,
            },
        }
    }
end

