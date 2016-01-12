if not modules then modules = { } end modules ['m-escrito'] = {
    version   = 1.001,
    comment   = "companion to m-escrito.mkiv",
    author    = "Taco Hoekwater (BitText) and Hans Hagen (PRAGMA-ADE)",
    license   = "see below and context related readme files"
}

-- This file is derived from Taco's escrito interpreter. Because the project was
-- more or less stopped, after some chatting we decided to preserve the result
-- and make it useable in ConTeXt. Hans went over all code, fixed a couple of
-- things, messed other things, made the code more efficient, wrapped all in
-- some helpers. So, a diff between the original and this file is depressingly
-- large. This means that you shouldn't bother Taco with the side effects (better
-- or worse) that result from this.

-- Fonts need some work and I will do that when needed. I might cook up something
-- similar to what we do with MetaFun. First I need to run into a use case. After
-- all, this whole exercise is just that: getting an idea of what processing PS
-- code involves.

-- Here is the usual copyright blabla:
--
-- Copyright 2010 Taco Hoekwater <taco@luatex.org>. All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without modification,
-- are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice, this
--    list of conditions and the following disclaimer.
--
-- 2. Redistributions in binary form must reproduce the above copyright notice, this
--    list of conditions and the following disclaimer in the documentation and/or
--    other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY <COPYRIGHT HOLDER> ``AS IS'' AND ANY EXPRESS OR
-- IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
-- MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
-- SHALL CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
-- EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
-- OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
-- STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
-- DAMAGE.

-- We use a couple of do..ends later on because this rather large file has too many
-- locals otherwise. Possible optimizations are using insert/remove and getting rid
-- of the VM calls (in direct mode they are no-ops anyway). We can also share some
-- more code here and there.

local type, unpack, tonumber, tostring, next = type, unpack, tonumber, tostring, next

local format     = string.format
local gmatch     = string.gmatch
local match      = string.match
local sub        = string.sub
local char       = string.char
local byte       = string.byte

local insert     = table.insert
local remove     = table.remove
local concat     = table.concat
local reverse    = table.reverse

local abs        = math.abs
local ceil       = math.ceil
local floor      = math.floor
local sin        = math.sin
local cos        = math.cos
local rad        = math.rad
local sqrt       = math.sqrt
local atan2      = math.atan2
local tan        = math.tan
local deg        = math.deg
local pow        = math.pow
local log        = math.log
local log10      = math.log10
local random     = math.random
local setranseed = math.randomseed

local bitand     = bit32.band
local bitor      = bit32.bor
local bitxor     = bit32.bxor
local bitrshift  = bit32.rshift
local bitlshift  = bit32.lshift

local lpegmatch  = lpeg.match
local Ct, Cc, Cs, Cp, C, R, S, P, V = lpeg.Ct, lpeg.Cc, lpeg.Cs, lpeg.Cp, lpeg.C, lpeg.R, lpeg.S, lpeg.P, lpeg.V

local formatters        = string.formatters
local setmetatableindex = table.setmetatableindex

-- Namespace

-- HH: Here we assume just one session. If needed we can support more (just a matter
-- of push/pop) but it makes the code more complex and less efficient too.

escrito = { }

----- escrito      = escrito
local initializers = { }
local devices      = { }
local specials

local DEBUG     = false -- these will become trackers if needed
local INITDEBUG = false -- these will become trackers if needed
local MAX_INT   = 0x7FFFFFFF -- we could have slightly larger ints because lua internally uses doubles

initializers[#initializers+1] = function(reset)
    if reset then
        specials = nil
    else
        specials = { }
    end
end

local devicename
local device

-- "boundingbox",
-- "randomseed",

-- Composite objects
--
-- Arrays, dicts and  strings are stored in VM. To do this, VM is an integer-indexed table. This appears
-- a bit silly in lua because we are actually just emulating a C implementation detail (pointers) but it
-- is documented behavior. There is also supposed to be a VM stack, but I will worry about that when it
-- becomes time to implement save/restore. (TH)

local VM -- todo: just a hash

initializers[#initializers+1] = function()
    VM = { }
end

local directvm = true

local add_VM, get_VM

if directvm then -- if ok then we remove the functions

    add_VM = function(a)
        return a
    end
    get_VM = function(i)
        return i
    end

else

    add_VM = function(a)
        local n = #VM + 1
        VM[n] = a
        return n
    end

    get_VM = function(i)
        return VM[i]
    end

end

-- Execution stack

local execstack
local execstackptr
local do_exec
local next_object
local stopped

initializers[#initializers+1] = function()
    execstack    = { }
    execstackptr = 0
    stopped      = false
end

local function pop_execstack()
    if execstackptr > 0 then
        local value  = execstack[execstackptr]
        execstackptr = execstackptr - 1
        return value
    else
        return nil -- stackunderflow
    end
end

local function push_execstack(v)
    execstackptr = execstackptr + 1
    execstack[execstackptr] = v
end

-- Operand stack
--
-- Most operand and exec stack entries are four-item arrays:
--
-- [1] = "[integer|real|boolean|name|mark|null|save|font]"  (a postscript interpreter type)
-- [2] = "[unlimited|read-only|execute-only|noaccess]"
-- [3] = "[executable|literal]" (exec attribute)
-- [4] = value (a VM index inthe case of names)
--
-- But there are some exceptions.
--
-- Dictionaries save the access attribute inside the value
--
-- [1] = "dict"
-- [2] = irrelevant
-- [3] = "[executable|literal]"
-- [4] = value (a VM index)
--
-- Operators have a fifth item:
--
-- [1] = "operator"
-- [2] = "[unlimited|read-only|execute-only|noaccess]"
-- [3] = "[executable|literal]"
-- [4] = value
-- [5] = identifier (the operator name)
--
-- Strings and files have a fifth and a sixth item, the fifth of which is
-- only relevant if the exec attribute is 'executable':
--
-- [1] = "[string|file]"
-- [2] = "[unlimited|read-only|execute-only|noaccess]"
-- [3] = "[executable|literal]"
-- [4] = value  (a VM index) (for input files, this holds the whole file)
-- [5] = exec-index
-- [6] = length
-- [7] = iomode (for files only)
-- [8] = filehandle (for files only)
--
-- Arrays also have a seven items, the fifth is only relevant if
-- the exec attribute is 'executable', and the seventh is used to differentiate
-- between direct and indirect interpreter views of the object.
--
-- [1] = "array"
-- [2] = "[unlimited|read-only|execute-only|noaccess]"
-- [3] = "[executable|literal]"
-- [4] = value (a VM index)
-- [5] = exec-index
-- [6] = length (a VM index)
-- [7] = "[d|i]" (direct vs. indirect)
--
-- The exec stack also has an object with [1] == ".stopped", which is used
-- for "stopped" execution contexts

local opstack
local opstackptr

initializers[#initializers+1] = function()
    opstack    = { }
    opstackptr = 0
end

local function pop_opstack()
    if opstackptr > 0 then
        local value = opstack[opstackptr]
        opstackptr  = opstackptr - 1
        return value
    else
        return nil -- stackunderflow
    end
end

local function push_opstack(v)
    opstackptr = opstackptr + 1
    opstack[opstackptr] = v
end

local function check_opstack(n)
    return opstackptr >= n
end

local function get_opstack()
    if opstackptr > 0 then
        return opstack[opstackptr]
    else
        return nil -- stackunderflow
    end
end

-- In case of error, the interpreter has to restore the opstack

local function copy_opstack()
    local t = { }
    for n=1,opstackptr do
        local sn = opstack[n]
        t[n] = { unpack(sn) }
    end
    return t
end

local function set_opstack(new)
   opstackptr = #new
   opstack    = new
end

-- Dict stack

local dictstack
local dictstackptr

initializers[#initializers+1] = function()
    dictstack    = { }
    dictstackptr = 0
end

-- this finds a name in the current dictionary stack

local function lookup(name)
    for n=dictstackptr,1,-1 do
        local found = get_VM(dictstack[n])
        if found then
            local dict = found.dict
            if dict then
                local d = dict[name]
                if d then
                    return d, n
                end
            end
        end
    end
    return nil
end

-- Graphics state stack

-- device backends are easier if gsstate items use bare data instead of
-- ps objects, much as possible

-- todo: just use one color array

local gsstate

initializers[#initializers+1] = function(reset)
    if reset then
        gsstate = nil
    else
        gsstate = {
            matrix      = { 1, 0, 0, 1, 0, 0 },
            color       = {
                gray = 0,
                hsb  = { },
                rgb  = { },
                cmyk = { },
                type = "gray"
            },
            position    = { }, -- actual x and y undefined
            path        = { },
            clip        = { },
            font        = nil,
            linewidth   = 1,
            linecap     = 0,
            linejoin    = 0,
            screen      = nil, -- by default, we don't use a screen, which matches "1 0 {pop}"
            transfer    = nil, -- by default, we don't have a transfer function, which matches "{}"
            flatness    = 0,
            miterlimit  = 10,
            dashpattern = { },
            dashoffset  = 0,
        }
    end
end

local function copy_gsstate()
    local old      = gsstate
    local position = old.position
    local matrix   = old.matrix
    local color    = old.color
    local rgb      = color.rgb
    local cmyk     = color.cmyk
    local hsb      = color.hsb
    return {
        matrix      = { matrix[1], matrix[2], matrix[3], matrix[4], matrix[5], matrix[6] },
        color       = {
            type = color.type,
            gray = color.gray,
            hsb  = { hsb[1], hsb[2], hsb[3] },
            rgb  = { rgb[1], rgb[2], rgb[3] },
            cmyk = { cmyk[1], cmyk[2], cmyk[3], cmyk[4] },
        },
        position    = { position[1], position[2] },
        path        = { unpack (old.path) },
        clip        = { unpack (old.clip) },
        font        = old.font,
        linewidth   = old.linewidth,
        linecap     = old.linecap,
        linejoin    = old.linejoin,
        screen      = old.screen,
        transfer    = nil,
        flatness    = old.flatness,
        miterlimit  = old.miterlimit,
        dashpattern = { },
        dashoffset  = 0,
    }
end

-- gsstack entries are of the form
-- [1] "[save|gsave]"
-- [2] {gsstate}

local gsstack
local gsstackptr

initializers[#initializers+1] = function(reset)
    if reset then
        gsstack    = nil
        gsstackptr = nil
    else
        gsstack    = { }
        gsstackptr = 0
    end
end

local function push_gsstack(v)
    gsstackptr = gsstackptr + 1
    gsstack[gsstackptr] = v
end

local function pop_gsstack()
    if gsstackptr > 0 then
        local v = gsstack[gsstackptr]
        gsstackptr = gsstackptr - 1
        return v
   end
end

-- Currentpage

local currentpage

initializers[#initializers+1] = function(reset)
    if reset then
        currentpage = nil
    else
        currentpage = { }
    end
end

-- Errordict

-- The standard errordict entry. The rest of these dictionaries will be filled
-- in the new() function.

local errordict
local dicterror

-- find an error handler

local function lookup_error(name)
    local dict = get_VM(errordict).dict
    return dict and dict[name]
end

-- error handling and reporting

local report = logs.reporter("escrito")

local function ps_error(a)
    -- can have print hook
    return false, a
end

-- Most entries in systemdict are operators, and the operators each have their own
-- implementation function. These functions are grouped by category cf. the summary
-- in the Adobe PostScript reference manual, the creation of the systemdict entries
-- is alphabetical.
--
-- In the summary at the start of the operator sections, the first character means:
--
-- "-" => todo
-- "+" => done
-- "*" => partial
-- "^" => see elsewhere

local operators = { }

-- Operand stack manipulation operators
--
-- +pop +exch +dup +copy +index +roll +clear +count +mark +cleartomark +counttomark

function operators.pop()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    return true
end

function operators.exch()
    if opstackptr < 2 then
        return ps_error('stackunderflow')
    end
    local prv = opstackptr-1
    opstack[opstackptr], opstack[prv] = opstack[prv], opstack[opstackptr]
    return true
end

function operators.dup()
    if opstackptr < 1 then
        return ps_error('stackunderflow')
    end
    local nxt = opstackptr+1
    opstack[nxt] = opstack[opstackptr]
    opstackptr = nxt
    return true
end

function operators.copy()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if ta == 'integer' then
        local va = a[4]
        if va < 0 then
            return ps_error('typecheck')
        end
        local thestack = opstackptr
        if va > thestack then
            return ps_error('stackunderflow')
        end
        -- use for loop
        local n = thestack - va + 1
        while n <= thestack do
            local b = opstack[n]
            local tb = b[1]
            if tb == 'array' or tb == 'string' or tb == 'dict' or tb == 'font' then
                b = { tb, b[2], b[3], add_VM(get_VM(b[4])), b[5], b[6], b[7] }
            end
            push_opstack(b)
            n = n + 1
        end
    elseif ta == 'dict' then
        local b = a
        local a = pop_opstack()
        if not a then
            return ps_error('stackunderflow')
        end
        if a[1] ~= 'dict' then
            return ps_error('typecheck')
        end
        local thedict    = get_VM(b[4])
        local tobecopied = get_VM(a[4])
        if thedict.maxsize < tobecopied.size then
            return ps_error('rangecheck')
        end
        if thedict.size ~= 0 then
            return ps_error('typecheck')
        end
        local access = thedict.access
        if access == 'read-only' or access == 'noaccess' then
            return ps_error('invalidaccess')
        end
        local dict = { }
        for k, v in next, tobecopied.dict do
            dict[k] = v -- fixed, was thedict[a], must be thedict.dict
        end
        thedict.access = tobecopied.access
        thedict.size   = tobecopied.size
        thedict.dict   = dict
        b = { b[1], b[2], b[3], add_VM(thedict) }
        push_opstack(b)
    elseif ta == 'array' then
        local b = a
        local a = pop_opstack()
        if not a then
            return ps_error('stackunderflow')
        end
        if a[1] ~= 'array' then
            return ps_error('typecheck')
        end
        if b[6] < a[6] then
            return ps_error('rangecheck')
        end
        local access = b[2]
        if access == 'read-only' or access == 'noaccess' then
            return ps_error('invalidaccess')
        end
        local array      = { }
        local thearray   = get_VM(b[4])
        local tobecopied = get_VM(a[4])
        for k, v in next, tobecopied do
            array[k] = v
        end
        b = { b[1], b[2], b[3], add_VM(array), a[5], a[6], a[7] } -- fixed, was thearray
        push_opstack(b)
   elseif ta == 'string' then
        local b = a
        local a = pop_opstack()
        if not a then
            return ps_error('stackunderflow')
        end
        if a[1] ~= 'string' then
            return ps_error('typecheck')
        end
        if b[6] < a[6] then
            return ps_error('rangecheck')
        end
        local access = b[2]
        if access == 'read-only' or access == 'noaccess' then
            return ps_error('invalidaccess')
        end
        local thestring = get_VM(b[4])
        local repl      = get_VM(a[4])
        VM[b[4]] = repl .. sub(thestring,#repl+1,-1)
        b = { b[1], b[2], b[3], add_VM(repl), a[5], b[6] }
        push_opstack(b)
    else
        return ps_error('typecheck')
    end
    return true
end

function operators.index()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if not ta == 'integer' then
        return ps_error('typecheck')
    end
    local n = a[4]
    if n < 0 then
        return ps_error('rangecheck')
    end
    if n >= opstackptr then
        return ps_error('stackunderflow')
    end
    push_opstack(opstack[opstackptr-n])
    return true
end

function operators.roll()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if b[1] ~= 'integer' then
        return ps_error('typecheck')
    end
    if a[1] ~= 'integer' then
        return ps_error('typecheck')
    end
    local stackcount = a[4]
    if stackcount < 0 then
        return ps_error('rangecheck')
    end
    if stackcount > opstackptr then
        return ps_error('stackunderflow')
    end
    local rollcount = b[4]
    if rollcount == 0 then
        return true
    end
    if rollcount > 0 then
        -- can be simplified
        while rollcount > 0 do
            local oldtop = opstack[opstackptr]
            local n = 0
            while n < stackcount do
                opstack[opstackptr-n] = opstack[opstackptr-n-1]
                n = n + 1
            end
            opstack[opstackptr-(stackcount-1)] = oldtop
            rollcount = rollcount - 1
        end
    else
        -- can be simplified
        while rollcount < 0 do
            local oldbot = opstack[opstackptr-stackcount+1]
            local n = stackcount - 1
            while n > 0 do
                opstack[opstackptr-n] = opstack[opstackptr-n+1]
                n = n - 1
            end
            opstack[opstackptr] = oldbot
            rollcount = rollcount + 1
        end
    end
    return true
end

function operators.clear()
    opstack    = { } -- or just keep it
    opstackptr = 0
    return true
end

function operators.count()
    push_opstack { 'integer', 'unlimited', 'literal', opstackptr }
    return true
end

function operators.mark()
    push_opstack { 'mark', 'unlimited', 'literal', null }
end

operators.beginarray = operators.mark

function operators.cleartomark()
    while opstackptr > 0 do
        local val = pop_opstack()
        if not val then
            return ps_error('unmatchedmark')
        end
        if val[1] == 'mark' then
            return true
        end
    end
    return ps_error('unmatchedmark')
end

function operators.counttomark()
    local v = 0
    for n=opstackptr,1,-1 do
        if opstack[n][1] == 'mark' then
            push_opstack { 'integer', 'unlimited', 'literal', v }
            return true
        end
        v = v + 1
    end
    return ps_error('unmatchedmark')
end

-- Arithmetic and math operators
--
-- +add +div +idiv +mod +mul +sub +abs +neg +ceiling +floor +round +truncate +sqrt +atan +cos
-- +sin +exp +ln +log +rand +srand +rrand

function operators.add()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, tb = a[1], b[1]
    if not (tb == 'real' or tb == 'integer') then
        return ps_error('typecheck')
    end
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    local c = a[4] + b[4]
    push_opstack {
        (ta == 'real' or tb == 'real' or c > MAX_INT) and "real" or "integer",
        'unlimited', 'literal', c
    }
    return true
end

function operators.sub()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, tb = a[1], b[1]
    if not (tb == 'real' or tb == 'integer') then
        return ps_error('typecheck')
    end
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    local c = a[4] - b[4]
    push_opstack {
        (ta == 'real' or tb == 'real' or c > MAX_INT) and "real" or "integer",
        'unlimited', 'literal', c
    }
    return true
end

function operators.div()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, tb = a[1], b[1]
    if not (tb == 'real' or tb == 'integer') then
        return ps_error('typecheck')
    end
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    local va, vb = a[4], b[4]
    if vb == 0 then
        return ps_error('undefinedresult')
    end
    push_opstack { 'real', 'unlimited', 'literal', va / vb }
    return true
end

function operators.idiv()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, tb = a[1], b[1]
    if tb ~= 'integer' then
        return ps_error('typecheck')
    end
    if ta ~= 'integer' then
        return ps_error('typecheck')
    end
    local va, vb = a[4], b[4]
    if vb == 0 then
        return ps_error('undefinedresult')
    end
    push_opstack { 'integer', 'unlimited', 'literal', floor(va / vb) }
    return true
end

function operators.mod()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, tb = a[1], b[1]
    if tb ~= 'integer' then
        return ps_error('typecheck')
    end
    if ta ~= 'integer' then
        return ps_error('typecheck')
    end
    local va, vb = a[4], b[4]
    if vb == 0 then
        return ps_error('undefinedresult')
    end
    local neg = false
    local v
    if va < 0 then
        v   = -va
        neg = true
    else
        v = va
    end
    local c = v % abs(vb)
    if neg then
        c = -c
    end
    push_opstack { 'integer', 'unlimited', 'literal', c }
    return true
end

function operators.mul()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, tb = a[1], b[1]
    if not (tb == 'real' or tb == 'integer') then
        return ps_error('typecheck')
    end
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    local c = a[4] * b[4]
    push_opstack {
        (ta == 'real' or tb == 'real' or abs(c) > MAX_INT) and 'real' or 'integer',
        'unlimited', 'literal', c
    }
    return true
end

function operators.abs()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    local v = a[4]
    local c = abs(v)
    push_opstack {
        (ta == 'real' or v == -(MAX_INT+1)) and 'real' or 'integer', -- hm, v or c
        'unlimited', 'literal', c
    }
    return true
end

function operators.neg()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    local v = a[4]
    push_opstack {
        (ta == 'real' or v == -(MAX_INT+1)) and 'real' or 'integer',
        'unlimited', 'literal', -v
    }
    return true
end

function operators.ceiling()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    local c = ceil(a[4])
    push_opstack { ta, 'unlimited', 'literal', c }
    return true
end

function operators.floor()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    local c = floor(a[4])
    push_opstack { ta, 'unlimited', 'literal', c }
    return true
end

function operators.round()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    local c = floor(a[4]+0.5)
    push_opstack { ta, 'unlimited', 'literal', c }
    return true
end

function operators.truncate()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    local v = a[4]
    local c =v < 0 and -floor(-v) or floor(v)
    push_opstack { ta, 'unlimited', 'literal', c }
    return true
end

function operators.sqrt()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    local v = a[4]
    if v < 0 then
        return ps_error('rangecheck')
    end
    local c = sqrt(v)
    push_opstack { 'real', 'unlimited', 'literal', c }
    return true
end

function operators.atan()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, tb = a[1], b[1]
    if not (tb == 'real' or tb == 'integer') then
        return ps_error('typecheck')
    end
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    local va, vb = a[4], b[4]
    if va == 0 and vb == 0 then
        return ps_error('undefinedresult')
    end
    local c = deg(atan2(rad(va),rad(vb)))
    if c < 0 then
        c = c + 360
    end
    push_opstack { 'real', 'unlimited', 'literal', c }
    return true
end

function operators.sin()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    local c = sin(rad(a[4]))
    -- this is because double calculation introduces a small error
    if abs(c) < 1.0e-16 then
        c = 0
    end
    push_opstack { 'real', 'unlimited', 'literal', c }
    return true
end

function operators.cos()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    local c = cos(rad(a[4]))
    -- this is because double calculation introduces a small error
    if abs(c) < 1.0e-16 then
        c = 0
    end
    push_opstack { 'real', 'unlimited', 'literal', c }
    return true
end

function operators.exp()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, tb = a[1], b[1]
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    if not (tb == 'real' or tb == 'integer') then
        return ps_error('typecheck')
    end
    local va, vb = a[4], b[4]
    if va < 0 and floor(vb) ~= vb then
        return ps_error('undefinedresult')
    end
    local c = pow(va,vb)
    push_opstack { 'real', 'unlimited', 'literal', c }
    return true
end

function operators.ln()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    local v = a[4]
    if v <= 0 then
        return ps_error('undefinedresult')
    end
    local c = log(v)
    push_opstack { 'real', 'unlimited', 'literal', c }
    return true
end

function operators.log()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    local v = a[4]
    if v <= 0 then
        return ps_error('undefinedresult')
    end
    local c = log10(v)
    push_opstack { 'real', 'unlimited', 'literal', c }
    return true
end

escrito.randomseed = os.time()

-- this interval is one off, but that'll do

function operators.rand()
    local c = random(MAX_INT) - 1
    push_opstack { 'integer', 'unlimited', 'literal', c }
    return true
end

function operators.srand()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if ta ~= 'integer' then
        return ps_error('typecheck')
    end
    escrito.randomseed = a[4]
    setranseed(escrito.randomseed)
    return true
end

function operators.rrand()
    push_opstack { 'integer', 'unlimited', 'literal', escrito.randomseed }
    return true
end

-- Array operators
--
-- +array ^[ +] +length +get +put +getinterval +putinterval +aload +astore ^copy +forall

function operators.array()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local t = a[1]
    local v = a[4]
    if t ~= 'integer' then
        return ps_error('typecheck')
    end
    if v < 0 then
        return ps_error('rangecheck')
    end
    local array = { }
    for i=1,v do
        array[n] = { 'null', 'unlimited', 'literal', true } -- todo: share this one
    end
    push_opstack { 'array', 'unlimited', 'literal', add_VM(array), 0, v, 'd'}
end

function operators.endarray()
    local n = opstackptr
    while n > 0 do
        if opstack[n][1] == 'mark' then
            break
        end
        n = n - 1
    end
    if n == 0 then
        return ps_error('unmatchedmark')
    end
    local top = opstackptr
    local i = opstackptr - n
    local array = { }
    while i > 0 do
        array[i] = pop_opstack()
        i = i - 1
    end
    pop_opstack() -- pop the mark
    push_opstack { 'array', 'unlimited', 'literal', add_VM(array), #array, #array, 'd' }
end

function operators.length()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local access = a[2]
    if access == "noaccess" or access == "executeonly" then
        return ps_error('invalidaccess')
    end
    local ta = a[1]
    local va = a[4]
    if ta == "dict" or ta == "font" then
        va = get_VM(va).size
    elseif ta == "array" or ta == "string" then
        va = get_VM(va)
        va = #va
    else
        return ps_error('typecheck')
    end
    push_opstack { 'integer', 'unlimited', 'literal', va }
    return true
end

function operators.get()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local access = a[2]
    if access == "noaccess" or access == "execute-only" then
        return ps_error('invalidaccess')
    end
    local ta = a[1]
    local va = a[4]
    if ta == "dict" then
        local dict = get_VM(va)
        local key = b
        local tb = b[1]
        local vb = b[4]
        if tb == "string" or tb == "name" then
            key = get_VM(vb)
        end
        local ddk = dict.dict[key]
        if ddk then
            push_opstack(ddk)
        else
            return ps_error('undefined')
        end
    elseif ta == "array" then
        local tb = b[1]
        local vb = b[4]
        if tb ~= 'integer' then
            return ps_error('typecheck')
        end
        if vb < 0 or vb >= a[6] then
            return ps_error('rangecheck')
        end
        local array = get_VM(va)
        local index = vb + 1
        push_opstack(array[index])
   elseif ta == "string" then
        local tb = b[1]
        local vb = b[4]
        if tb ~= 'integer' then
            return ps_error('typecheck')
        end
        if vb < 0 or vb >= a[6] then
            return ps_error('rangecheck')
        end
        local thestring = get_VM(va)
        local index = vb + 1
        local c = sub(thestring,index,index)
        push_opstack { 'integer', 'unlimited', 'literal', byte(c) }
    else
        return ps_error('typecheck')
    end
    return true
end

function operators.put()
    local c = pop_opstack()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if ta == "dict" then
        local dict = get_VM(a[4])
        if dict.access ~= 'unlimited' then
            return ps_error('invalidaccess')
        end
        local key = b
        local bt = b[1]
        if bt == "string" or bt == "name" then
            key = get_VM(b[4])
        end
        local dd  = dict.dict
        local ds  = dict.size
        local ddk = dd[key]
        if not ddk and (ds == dict.maxsize) then
            return ps_error('dictfull')
        end
        if c[1] == 'array' then
            c[7] = 'i'
        end
        if not ddk then
            dict.size = ds + 1
        end
        dd[key] = c
    elseif ta == "array" then
        if a[2] ~= 'unlimited' then
            return ps_error('invalidaccess')
        end
        if b[1] ~= 'integer' then
            return ps_error('typecheck')
        end
        local va, vb = a[4], b[4]
        if vb < 0 or vb >= a[6] then
            return ps_error('rangecheck')
        end
        local vm = VM[va]
        local vi = bv + 1
        if vm[vi][1] == 'null' then
            a[5] = a[5] + 1
        end
        vm[vi] = c
    elseif ta == "string" then
        if a[2] ~= 'unlimited' then
            return ps_error('invalidaccess')
        end
        if b[1] ~= 'integer' then
            return ps_error('typecheck')
        end
        if c[1] ~= 'integer' then
            return ps_error('typecheck')
        end
        local va, vb, vc = a[4], b[4], c[4]
        if vb < 0 or vb >= a[6] then
            return ps_error('rangecheck')
        end
        if vc < 0 or vc > 255 then
            return ps_error('rangecheck')
        end
        local thestring = get_VM(va)
        VM[va] = sub(thestring,1,vb) .. char(vc) .. sub(thestring,vb+2)
    else
        return ps_error('typecheck')
    end
    return true
end

function operators.getinterval()
    local c = pop_opstack()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, tb, tc = a[1], b[1], c[1]
    local aa, ab, ac = a[2], b[2], c[2]
    local va, vb, vc = a[4], b[4], c[4]
    if ta ~= "array" and ta ~= 'string' then
        return ps_error('typecheck')
    end
    if tb ~= 'integer' or tc ~= 'integer' then
        return ps_error('typecheck')
    end
    if aa == "execute-only" or aa == 'noaccess' then
        return ps_error('invalidaccess')
    end
    if vb < 0 or vc < 0 or vb + vc >= a[6] then
        return ps_error('rangecheck')
    end
    -- vb : start
    -- vc : number
    if ta == 'array' then
        local array    = get_VM(va)
        local subarray = { }
        local index    = 1
        while index <= vc do
            subarray[index] = array[index+vb]
            index = index + 1
        end
        push_opstack { 'array', aa, a[3], add_VM(subarray), vc, vc, 'd' }
    else
        local thestring = get_VM(va)
        local newstring = sub(thestring,vb+1,vb+vc)
        push_opstack { 'string', aa, a[3], add_VM(newstring), vc, vc }
    end
    return true
end

function operators.putinterval()
    local c = pop_opstack()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, tb, tc = a[1], b[1], c[1]
    local aa, ab, ac = a[2], b[2], c[2]
    local va, vb, vc = a[4], b[4], c[4]
    if ta ~= "array" and ta ~= 'string' then
        return ps_error('typecheck')
    end
    if tc ~= "array" and tc ~= 'string' then
        return ps_error('typecheck')
    end
    if ta ~= tc then
        return ps_error('typecheck')
    end
    if aa ~= "unlimited" then
        return ps_error('invalidaccess')
    end
    if tb ~= 'integer' then
        return ps_error('typecheck')
    end
    if vb < 0 or vb + c[6] >= a[6] then
        return ps_error('rangecheck')
    end
    if ta == 'array' then
        local newarr = get_VM(vc)
        local oldarr = get_VM(va)
        local index = 1
        local lastindex = c[6]
        local step = a[5]
        while index <= lastindex do
            if oldarr[vb+index][1] == 'null' then
                a[5] = a[5] + 1 -- needs checking, a[5] not used
             -- step = step + 1
            end
            oldarr[vb+index] = newarr[index]
            index = index + 1
        end
    else
        local thestring = get_VM(va)
        VM[va] = sub(thestring,1,vb) .. get_VM(vc) .. sub(thestring,vb+c[6]+1)
    end
    return true
end

function operators.aload()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, aa, va = a[1], a[2], a[4]
    if ta ~= "array" then
       return ps_error('typecheck')
    end
    if aa == "execute-only" or aa == 'noaccess' then
       return ps_error('invalidaccess')
    end
    local array = get_VM(va)
    for i=1,#array do
       push_opstack(array[i])
    end
    push_opstack(a)
    return true
end

function operators.astore()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, aa, va = a[1], a[2], a[4]
    if ta ~= "array" then
        return ps_error('typecheck')
    end
    if aa == "execute-only" or aa == 'noaccess' then
        return ps_error('invalidaccess')
    end
    local array = get_VM(va)
    local count = a[6]
    for i=1,count do
        local v = pop_opstack()
        if not v then
            return ps_error('stackunderflow')
        end
        array[i] = v
    end
    a[5] = a[5] + count
    push_opstack(a)
    return true
end

function operators.forall()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, aa, va = a[1], a[2], a[4]
    local tb, ab, vb = b[1], b[2], b[4]
    if not tb == "array" and b[3] == 'executable' then
        return ps_error('typecheck')
    end
    if tb == 'noaccess' then
        return ps_error('invalidaccess')
    end
    if not (ta == "array" or ta == 'dict' or ta == 'string' or ta == "font") then
        return ps_error('typecheck')
    end
    if aa == "execute-only" or aa == 'noaccess' then
        return ps_error('invalidaccess')
    end
    push_execstack { '.exit', 'unlimited', 'literal', false }
    local curstack = execstackptr
    if ta == 'array' then
        if a[6] == 0 then
            return true
        end
        b[7] = 'i'
        local thearray = get_VM(va)
        for i=1,#thearray do
            if stopped then
                stopped = false
                return false
            end
            push_opstack(thearray[i])
            b[5] = 1
            push_execstack(b)
            while curstack <= execstackptr do
                do_exec()
            end
        end
        local entry = execstack[execstackptr]
        if entry[1] == '.exit' and antry[4] == true then
            pop_execstack()
            return true
        end
    elseif ta == 'dict' or ta == 'font' then
        local thedict = get_VM(va)
        if thedict.size == 0 then
            return true
        end
        b[7] = 'i'
        local thedict = get_VM(va)
        for k, v in next, thedict.dict do
            if stopped then
                stopped = false
                return false
            end
            if type(k) == "string" then
                push_opstack { 'name', 'unlimited', 'literal', add_VM(k) }
            else
                push_opstack(k)
            end
            push_opstack(v)
            b[5] = 1
            push_execstack(b)
            while curstack < execstackptr do
                do_exec()
            end
            local entry = execstack[execstackptr]
            if entry[1] == '.exit' and antry[4] == true then
                pop_execstack()
                return true
            end
        end
    else -- string
        if a[6] == 0 then
            return true
        end
        b[7] = 'i'
        local thestring = get_VM(va)
        for v in gmatch(thestring,".") do -- we can use string.bytes
            if stopped then
                stopped = false
                return false
            end
            push_opstack { 'integer', 'unlimited', 'literal', byte(v) }
            b[5] = 1
            push_execstack(b)
            while curstack < execstackptr do
                do_exec()
            end
            local entry = execstack[execstackptr]
            if entry[1] == '.exit' and antry[4] == true then
                pop_execstack()
                return true;
            end
        end
    end
    return true
end

-- Dictionary operators
--
-- +dict ^length +maxlength +begin +end +def +load +store ^get ^put +known +where ^copy
-- ^forall ^errordict ^systemdict ^userdict +currentdict +countdictstack +dictstack

function operators.dict()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if not a[1] == 'integer' then
        return ps_error('typecheck')
    end
    local s = a[4]
    if s < 0 then
        return ps_error('rangecheck')
    end
    if s == 0 then -- level 2 feature
        s = MAX_INT
    end
    push_opstack {
        'dict',
        'unlimited',
        'literal',
        add_VM {
            access  = 'unlimited',
            size    = 0,
            maxsize = s,
            dict    = { },
        }
    }
end

function operators.maxlength()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, aa, va = a[1], a[2], a[4]
    if ta ~= 'dict' then
        return ps_error('typecheck')
    end
    if aa == 'execute-only' or aa == 'noaccess' then
        return ps_error('invalidaccess')
    end
    local thedict = get_VM(va)
    push_opstack { 'integer', 'unlimited', 'literal', thedict.maxsize }
end

function operators.begin()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] ~= 'dict' then
        return ps_error('typecheck')
    end
    dictstackptr = dictstackptr + 1
    dictstack[dictstackptr] = a[4]
end

operators["end"] = function()
    if dictstackptr < 3 then
        return ps_error('dictstackunderflow')
    end
    dictstack[dictstackptr] = nil
    dictstackptr = dictstackptr - 1
end

function operators.def()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if not (a[1] == 'name' and a[3] == 'literal') then
        return ps_error('typecheck')
    end
    if b[1] == 'array' then
        b[7] = 'i'
    end
    local thedict = get_VM(dictstack[dictstackptr])
    if not thedict.dict[get_VM(a[4])] then
        if thedict.size == thedict.maxsize then
         -- return ps_error('dictfull') -- level 1 only
        end
        thedict.size = thedict.size + 1
    end
    thedict.dict[get_VM(a[4])] = b
    return true
end

-- unclear: the book says this operator can return typecheck

function operators.load()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local aa = a[2]
    if aa == 'noaccess' or aa == 'execute-only' then
        return ps_error('invalidaccess')
    end
    local v = lookup(get_VM(a[4]))
    if not v then
        return ps_error('undefined')
    end
    push_opstack(v)
end

function operators.store()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if not (a[1] == 'name' and a[3] == 'literal') then
        return ps_error('typecheck')
    end
    if b[7] == 'array' then
        b[7] = 'i'
    end
    local val, dictloc = lookup(a[4])
    if val then
        local thedict = get_VM(dictstack[dictloc])
        if thedict.access == 'execute-only' or thedict.access == 'noaccess' then
            return ps_error('invalidaccess')
        end
        thedict.dict[a[4]] = b
    else
        local thedict = get_VM(dictstack[dictstackptr])
        local access  = thedict.access
        local size    = thedict.size
        if access == 'execute-only' or access == 'noaccess' then
            return ps_error('invalidaccess')
        end
        if size == thedict.maxsize then
            return ps_error('dictfull')
        end
        thedict.size = size + 1
        thedict.dict[a[4]] = b
    end
    return true
end

function operators.known()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, aa, va = a[1], a[2], a[4]
    local tb, vb = b[1], b[4]
    if ta ~= 'dict' then
        return ps_error('typecheck')
    end
    if not (tb == 'name' or tb == 'operator') then
        return ps_error('typecheck')
    end
    if aa == 'noaccess' or aa == 'execute-only' then
        return ps_error('invalidaccess')
    end
    local thedict = get_VM(va)
    push_opstack {'boolean', 'unlimited', 'literal', thedict.dict[vb] and true or false }
    return true
end

function operators.where()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if not (a[1] == 'name' and a[3] == 'literal') then
        return ps_error('typecheck')
    end
    local val, dictloc = lookup(get_VM(a[4]))
    local thedict = dictloc and get_VM(dictstack[dictloc]) -- fixed
    if val then
        if thedict.access == 'execute-only' or thedict.access == 'noaccess' then
            return ps_error('invalidaccess')
        end
        push_opstack {'dict', 'unlimited', 'literal', dictstack[dictloc]}
        push_opstack {'boolean', 'unlimited', 'literal', true}
    else
        push_opstack {'boolean', 'unlimited', 'literal', false}
    end
    return true
end

function operators.currentdict()
    push_opstack { 'dict', 'unlimited', 'literal', dictstack[dictstackptr] }
    return true
end

function operators.countdictstack()
    push_opstack { 'integer', 'unlimited', 'literal', dictstackptr }
    return true
end

function operators.dictstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if not a[1] == 'array' then
        return ps_error('typecheck')
    end
    if not a[2] == 'unlimited' then
        return ps_error('invalidaccess')
    end
    if a[6] < dictstackptr then
        return ps_error('rangecheck')
    end
    local thearray     = get_VM(a[4])
    local subarray     = { }
    for i=1,dictstackptr do
        thearray[n] = { 'dict', 'unlimited', 'literal', dictstack[i] }
        subarray[n] = thearray[i]
    end
    a[5] = a[5] + dictstackptr
    push_opstack { 'array', 'unlimited', 'literal', add_VM(subarray), dictstackptr, dictstackptr, '' }
    return true
end

-- String operators
--
-- +string ^length ^get ^put ^getinterval ^putinterval ^copy ^forall +anchorsearch +search
-- +token

function operators.string()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, va = a[1], a[4]
    if ta ~= 'integer' then
        return ps_error('typecheck')
    end
    if va < 0 then
        return ps_error('rangecheck')
    end
    push_opstack { 'string', 'unlimited', 'literal', add_VM(''), 1, va }
end

function operators.anchorsearch()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, aa, va = a[1], a[2], a[4]
    local tb, ab, vb = b[1], b[2], b[4]
    if not ta ~= 'string' then
        return ps_error('typecheck')
    end
    if tb ~= 'string' then
        return ps_error('typecheck')
    end
    if aa == 'noaccess' or aa == 'execute-only' then
        return ps_error('invalidaccess')
    end
    if ab == 'noaccess' or ab == 'execute-only' then
        return ps_error('invalidaccess')
    end
    local thestring = get_VM(va)
    local thesearch = get_VM(vb)
    local prefix    = sub(thestring,1,#thesearch)
    if prefix == thesearch then
        if aa == 'read-only' then
            return ps_error('invalidaccess')
        end
        local post = sub(thestring,#thesearch+1)
        push_opstack { 'string',  'unlimited', 'literal', add_VM(post), 1, #post }
        push_opstack { 'string',  'unlimited', 'literal', add_VM(prefix), 1, #prefix }
        push_opstack { 'boolean', 'unlimited', 'literal', true }
    else
        push_opstack(a)
        push_opstack { 'boolean', 'unlimited', 'literal', false }
    end
    return true
end

function operators.search()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, aa, va = a[1], a[2], a[4]
    local tb, ab, vb = b[1], b[2], b[4]
    if not ta ~= 'string' then
        return ps_error('typecheck')
    end
    if tb ~= 'string' then
        return ps_error('typecheck')
    end
    if aa == 'noaccess' or aa == 'execute-only' then
        return ps_error('invalidaccess')
    end
    if ab == 'noaccess' or ab == 'execute-only' then
        return ps_error('invalidaccess')
    end
    local thestring = get_VM(a[4])
    local thesearch = get_VM(b[4])
    -- hm, can't this be done easier?
    local n = 1
    local match
    while n + #thesearch-1 <= #thestring do
        match = sub(thestring,n,n+#thesearch-1)
        if match == thesearch then
            break
        end
        n = n + 1
    end
    if match == thesearch then
        if aa == 'read-only' then
            return ps_error('invalidaccess')
        end
        local prefix = sub(thestring,1,n-1)
        local post   = sub(thestring,#thesearch+n)
        push_opstack { 'string',  'unlimited', 'literal', add_VM(post), 1, #post }
        push_opstack { 'string',  'unlimited', 'literal', add_VM(thesearch), 1, #thesearch }
        push_opstack { 'string',  'unlimited', 'literal', add_VM(prefix), 1, #prefix }
        push_opstack { 'boolean', 'unlimited', 'literal', true }
    else
        push_opstack(a)
        push_opstack { 'boolean', 'unlimited', 'literal', false }
    end
    return true
end

function operators.token()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, aa, va = a[1], a[2], a[4]
    if not (ta == 'string' or ta == 'file') then
        return ps_error('typecheck')
    end
    if aa ~= 'unlimited' then
        return ps_error('invalidaccess')
    end
    -- some fiddling with the tokenization process is needed
    if ta == 'string' then
        local top = execstackptr
        push_execstack { '.token', 'unlimited', 'literal', false }
        push_execstack {  a[1], a[2], 'executable', va, 1, a[6] }
        local v, err = next_object()
        if not v then
            pop_execstack()
            pop_execstack()
            push_opstack { 'boolean', 'unlimited', 'literal', false }
        else
            local q = pop_execstack()
            if execstack[execstackptr][1] == '.token' then
                pop_execstack()
            end
            local tq, vq = q[1], q[4]
            if tq == 'string' and vq ~= va then
                push_execstack(q)
            end
            local thestring, substring
            if vq ~= va  then
                thestring = ""
                substring = ""
            else
                thestring = get_VM(vq)
                substring = sub(thestring,q[5] or 0)
            end
            push_opstack { ta, aa, a[3], add_VM(substring), 1, #substring}
            push_opstack(v)
            push_opstack { 'boolean', 'unlimited', 'literal', true }
        end
    else -- file
        if a[7] ~= 'r' then
            return ps_error('invalidaccess')
        end
        push_execstack { '.token', 'unlimited', 'literal', false }
        push_execstack { 'file',   'unlimited', 'executable', va, a[5], a[6], a[7], a[8] }
        local v, err = next_object()
        if not v then
            pop_execstack()
            pop_execstack()
            push_opstack { 'boolean', 'unlimited', 'literal', false }
        else
            local q = pop_execstack() -- the file
            a[5] = q[5]
            if execstack[execstackptr][1] == '.token' then
                pop_execstack()
            end
            push_opstack(v)
            push_opstack { 'boolean', 'unlimited', 'literal', true }
        end
    end
    return true
end

-- Relational, boolean and bitwise operators
--
-- +eq +ne +ge +gt +le +lt +and +not +or +xor ^true ^false +bitshift

local function both()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, aa = a[1], a[2]
    local tb, ab = b[1], b[2]
    if aa == 'noaccess' or aa == 'execute-only' then
        return ps_error('invalidaccess')
    end
    if ab == 'noaccess' or ab == 'execute-only' then
        return ps_error('invalidaccess')
    end
    if (ta == 'dict' and tb == 'dict') or (ta == 'array' and tb =='array') then
        return true, a[4], b[4]
    elseif ((ta == 'string' or ta == 'name') and (tb == 'string' or tb == 'name' )) then
        local astr = get_VM(a[4])
        local bstr = get_VM(b[4])
        return true, astr, bstr
    elseif ((ta == 'integer' or ta == 'real') and (tb == 'integer' or tb == 'real')) or (ta == tb) then
        return true, a[4], b[4]
    else
        return ps_error('typecheck')
    end
    return true
end

function operators.eq()
    local ok, a, b = both()
    if ok then
        push_opstack { 'boolean', 'unlimited', 'literal', a == b }
        return true
    else
        return a
    end
end

function operators.ne()
    local ok, a, b = both()
    if ok then
        push_opstack { 'boolean', 'unlimited', 'literal', a ~= b }
        return true
    else
        return a
    end
end

local function both()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local aa, ab = a[2], b[2]
    if aa == 'noaccess' or aa == 'execute-only' then
        return ps_error('invalidaccess')
    end
    if ab == 'noaccess' or ab == 'execute-only' then
        return ps_error('invalidaccess')
    end
    local ta, tb = a[1], b[1]
    local va, vb = a[4], b[4]
    if (ta == 'real' or ta == 'integer') and (tb == 'real' or tb == 'integer') then
        return true, va, vb
    elseif ta == 'string' and tb == 'string' then
        local va = get_VM(va)
        local vb = get_VM(vb)
        return true, va, vb
    else
        return ps_error('typecheck')
    end
end

function operators.ge()
    local ok, a, b = both()
    if ok then
        push_opstack { 'boolean', 'unlimited', 'literal', a >= b }
        return true
    else
        return a
    end
end

function operators.gt()
    local ok, a, b = both()
    if ok then
        push_opstack { 'boolean', 'unlimited', 'literal', a > b }
        return true
    else
        return a
    end
end

function operators.le()
    local ok, a, b = both()
    if ok then
        push_opstack { 'boolean', 'unlimited', 'literal', a <= b }
        return true
    else
        return a
    end
end

function operators.lt()
    local ok, a, b = both()
    if ok then
        push_opstack { 'boolean', 'unlimited', 'literal', a < b }
        return true
    else
        return a
    end
end

local function both()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local aa, ab = a[2], b[2]
    if aa == 'noaccess' or aa == 'execute-only' then
        return ps_error('invalidaccess')
    end
    if ab == 'noaccess' or ab == 'execute-only' then
        return ps_error('invalidaccess')
    end
    local ta, tb = a[1], b[1]
    local va, vb = a[4], b[4]
    if ta == 'boolean' and tb == 'boolean' then
        return ta, va, vb
    elseif ta == 'integer' and tb == 'integer' then
        return ta, va, vb
    else
        return ps_error('typecheck')
    end
end

operators["and"]= function()
    local ok, a, b = both()
    if ok == 'boolean' then
        push_opstack { 'boolean', 'unlimited', 'literal', a[1] and b[1] }
        return true
    elseif ok == 'integer' then
        push_opstack { 'integer', 'unlimited', 'literal', bitand(a[1],b[1]) }
        return true
    else
        return a
    end
end

operators["or"] = function()
    local ok, a, b = both()
    if ok == 'boolean' then
        push_opstack {'boolean', 'unlimited', 'literal', a[1] or b[1] }
        return true
    elseif ok == 'integer' then
        push_opstack {'integer', 'unlimited', 'literal', bitor(a[1],b[1]) }
        return true
    else
        return a
    end
end

function operators.xor()
    local ok, a, b = both()
    if ok == 'boolean' then
        push_opstack {'boolean', 'unlimited', 'literal', a[1] ~= b[1] }
        return true
    elseif ok == 'integer' then
        push_opstack {'integer', 'unlimited', 'literal', bitxor(a[1],b[1]) }
        return true
    else
        return a
    end
end

operators["not"] = function()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local aa = a[2]
    local ta = a[1]
    if aa == 'noaccess' or aa == 'execute-only' then
        return ps_error('invalidaccess')
    end
    if ta == 'boolean' then
        push_opstack { 'boolean', 'unlimited', 'literal', not a[4] }
    elseif ta == 'integer' then
        push_opstack { 'integer', 'unlimited', 'literal', -a[4] - 1 }
    else
        return ps_error('typecheck')
    end
    return true
end

function operators.bitshift()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local aa, ab = a[2], b[2]
    local ta, tb = a[1], b[1]
    local va, vb = a[4], b[4]
    if aa == 'noaccess' or aa == 'execute-only' then
        return ps_error('invalidaccess')
    end
    if ab == 'noaccess' or ab == 'execute-only' then
        return ps_error('invalidaccess')
    end
    if not (ta == 'integer' and tb == 'integer') then
        return ps_error('typecheck')
    end
    push_opstack { 'integer', 'unlimited', 'literal', bitrshift(va,vb < 0 and -vb or vb) }
    return true
end

-- Control operators
--
-- +exec +if +ifelse +for +repeat +loop +exit +stop +stopped +countexecstack +execstack
-- +quit +start

function operators.exec()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] == 'array' then
        a[7] = 'i'
        a[5] = 1
    end
    push_execstack(a)
    return true
end

operators["if"] = function()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] ~= 'boolean' then
        return ps_error('typecheck')
    end
    if b[1] ~= 'array' then
        return ps_error('typecheck')
    end
    if a[4] == true then
        b[7] = 'i'
        b[5] = 1
        push_execstack(b)
    end
    return true
end

function operators.ifelse()
    local c = pop_opstack()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] ~= 'boolean' then
        return ps_error('typecheck')
    end
    if b[1] ~= 'array' then
        return ps_error('typecheck')
    end
    if c[1] ~= 'array' then
        return ps_error('typecheck')
    end
    if a[4] == true then
        b[5] = 1
        b[7] = 'i'
        push_execstack(b)
    else
        c[5] = 1
        c[7] = 'i'
        push_execstack(c)
    end
    return true
end

operators["for"] = function()
    local d = pop_opstack()
    local c = pop_opstack()
    local b = pop_opstack()
    local a = pop_opstack()
    local ta, tb, tc, td = a[1], b[1], c[1], d[1]
    if not a then
        return ps_error('stackunderflow')
    end
    if not (ta == 'integer' or ta == 'real') then
        return ps_error('typecheck')
    end
    if not (tb == 'integer' or tb == 'real') then
        return ps_error('typecheck')
    end
    if not (tc == 'integer' or tc == 'real') then
        return ps_error('typecheck')
    end
    if not (td == 'array' and d[3] == 'executable') then
        return ps_error('typecheck')
    end
    local initial   = a[4]
    local increment = b[4]
    local limit     = c[4]
    if initial == limit then
        return true
    end
    push_execstack { '.exit', 'unlimited', 'literal', false }
    local curstack  = execstackptr
    local tokentype = (a[1] == 'real' or b[1] == 'real' or c[1] == 'real') and 'real' or 'integer'
    d[7] = 'i'
    local first, last
    if increment >= 0 then
        first, last = initial, limit
    else
        first, last = limit, limit
    end
    for control=first,last,increment do
        if stopped then
            stopped = false
            return false
        end
        push_opstack { tokentype, 'unlimited', 'literal', control }
        d[5] = 1
        push_execstack(d)
        while curstack < execstackptr do
            do_exec()
        end
        local entry = execstack[execstackptr]
        if entry[1] == '.exit' and entry[4] == true then
            pop_execstack()
            return true;
        end
    end
    return true
end

operators["repeat"] = function()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] ~= 'integer' then
        return ps_error('typecheck')
    end
    if a[4] < 0 then
        return ps_error('rangecheck')
    end
    if not (b[1] == 'array' and b[3] == 'executable') then
        return ps_error('typecheck')
    end
    local limit = a[4]
    if limit == 0 then
        return true
    end
    push_execstack { '.exit', 'unlimited', 'literal', false }
    local curstack = execstackptr
    b[7] = 'i'
    local control = 0
    while control < limit do
        if stopped then
            stopped = false
            return false
        end
        b[5] = 1
        push_execstack(b)
        while curstack < execstackptr do
            do_exec()
        end
        local entry = execstack[execstackptr]
        if entry[1] == '.exit' and entry[4] == true then
            pop_execstack()
            return true;
        end
        control = control + 1
    end
    return true
end

function operators.loop()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if not (a[1] == 'array'  and a[3] == 'executable') then
        return ps_error('typecheck')
    end
    push_execstack { '.exit', 'unlimited', 'literal', false }
    local curstack = execstackptr
    a[7] = 'i'
    while true do
        if stopped then
            stopped = false
            return false
        end
        a[5] = 1
        push_execstack(a)
        while curstack < execstackptr do
            do_exec()
        end
        if execstackptr > 0 then
            local entry = execstack[execstackptr]
            if entry[1] == '.exit' and entry[4] == true then
                pop_execstack()
                return true
            end
        end
    end
    return true
end

function operators.exit()
    local v = pop_execstack()
    while v do
        local tv = val[1]
        if tv == '.exit' then
            push_execstack { '.exit', 'unlimited', 'literal', true }
            return true
        elseif tv == '.stopped' or tv == '.run' then
            push_execstack(v)
            return ps_error('invalidexit')
        end
        v = pop_execstack()
    end
    report("exit without context, quitting")
    push_execstack { 'operator', 'unlimited', 'executable', operators.quit, "quit" }
    return true
end

function operators.stop()
    local v = pop_execstack()
    while v do
        if val[1] == '.stopped' then
            stopped = true
            push_opstack { 'boolean', 'unlimited', 'executable', true }
            return true
        end
        v = pop_execstack()
    end
    report("stop without context, quitting")
    push_execstack { 'operator', 'unlimited', 'executable', operators.quit, "quit" }
    return true
end

function operators.stopped()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    -- push a special token on the exec stack (handled by next_object):
    push_execstack { '.stopped', 'unlimited', 'literal', false }
    a[3] = 'executable'
    if a[1] == 'array' then
        a[7] = 'i'
        a[5] = 1
    end
    push_execstack(a)
    return true
end

function operators.countexecstack()
    push_opstack { 'integer', 'unlimited', 'literal', execstackptr }
    return true
end

function operators.execstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if not a[1] == 'array' then
        return ps_error('typecheck')
    end
    if not a[2] == 'unlimited' then
        return ps_error('invalidaccess')
    end
    if a[6] < execstackptr then
        return ps_error('rangecheck')
    end
    local thearray     = get_VM(a[4])
    local subarray     = { }
    for n=1,execstackptr do
     -- thearray[n] = execstack[n]
     -- subarray[n] = thearray[n]
        local v = execstack[n]
        thearray[n] = v
        subarray[n] = v
        a[5] = a[5] + 1
    end
    push_opstack { 'array', 'unlimited', 'literal', add_VM(subarray), execstackptr, execstackptr, "" }
    return true
end

-- clearing the execstack does the trick,
-- todo: leave open files to be handled by the lua interpreter, for now

function operators.quit()
    while execstackptr >= 0 do -- todo: for loop / slot 0?
        execstack[execstackptr] = nil
        execstackptr = execstackptr - 1
    end
    return true
end

-- does nothing, for now

function operators.start()
    return true
end

-- Type, attribute and conversion operators
--
-- +type +cvlit +cvx +xcheck +executeonly +noaccess +readonly +rcheck +wcheck +cvi
-- +cvn +cvr +cvrs +cvs

function operators.type()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    push_opstack { "name", "unlimited", "executable", add_VM(a[1] .. "type") }
    return true
end

function operators.cvlit() -- no need to push/pop
    local a = get_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    a[3] = 'literal'
    return true
end

function operators.cvx()
    local a = get_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    a[3] = 'executable'
    return true
end

function operators.xcheck()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    push_opstack { 'boolean', 'unlimited', 'literal', a[3] == 'executable' }
    return true
end

function operators.executeonly()
    local a = pop_opstack() -- get no push
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if ta == 'string' or ta == 'file' or ta == 'array' then
        if a[2] == 'noaccess' then
            return ps_error('invalidaccess')
        end
        a[2] = 'execute-only'
    else
        return ps_error('typecheck')
    end
    push_opstack(a)
    return true
end

function operators.noaccess()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if ta == 'string' or ta == 'file' or ta == 'array' then
        if a[2] == 'noaccess' then
            return ps_error('invalidaccess')
        end
        a[2] = 'noaccess'
    elseif ta == "dict" then
        local thedict = get_VM(a[4])
        if thedict.access == 'noaccess' then
            return ps_error('invalidaccess')
        end
        thedict.access = 'noaccess'
    else
        return ps_error('typecheck')
    end
    push_opstack(a)
    return true
end

function operators.readonly()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if ta == 'string' or ta == 'file' or ta == 'array' then
        local aa = a[2]
        if aa == 'noaccess' or aa == 'execute-only' then
            return ps_error('invalidaccess')
        end
        a[2] = 'read-only'
    elseif ta == 'dict' then
        local thedict = get_VM(a[4])
        local access  = thedict.access
        if access == 'noaccess' or access == 'execute-only' then
            return ps_error('invalidaccess')
        end
        thedict.access = 'read-only'
    else
        return ps_error('typecheck')
    end
    push_opstack(a)
    return true
end

function operators.rcheck()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    local aa
    if ta == 'string' or ta == 'file' or ta == 'array' then
        aa = a[2]
    elseif ta == 'dict' then
        aa = get_VM(a[4]).access
    else
        return ps_error('typecheck')
    end
    push_opstack { 'boolean', 'unlimited', 'literal', aa == 'unlimited' or aa == 'read-only' }
    return true
end

function operators.wcheck()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    local aa
    if ta == 'string' or ta == 'file' or ta == 'array' then
        aa = a[2]
    elseif ta == 'dict' then
        local thedict = get_VM(a[4])
        aa = thedict.access
    else
        return ps_error('typecheck')
    end
    push_opstack { 'boolean', 'unlimited', 'literal', aa == 'unlimited' }
    return true
end

function operators.cvi()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if ta == 'string' then
        push_opstack(a)
        local ret, err = operators.token()
        if not ret then
            return ret, err
        end
        local b = pop_opstack()
        if b[4] == false then
            return ps_error('syntaxerror')
        end
        a = pop_opstack()
        pop_opstack() -- get rid of the postmatch string remains
        ta = a[1]
    end
    local aa = a[2]
    if not (aa == 'unlimited' or aa == 'read-only') then
        return ps_error('invalidaccess')
    end
    if ta == 'integer' then
        push_opstack(a)
    elseif ta == 'real' then
        local va = a[4]
        local c = va < 0 and -floor(-va) or floor(ava)
        if abs(c) > MAX_INT then
            return ps_error('rangecheck')
        end
        push_opstack { 'integer', 'unlimited', 'literal', c }
    else
        return ps_error('typecheck')
    end
    return true
end

function operators.cvn()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, aa = a[1], a[2]
    local ta = a[1]
    if ta ~= 'string' then
        return ps_error('typecheck')
    end
    if aa == 'execute-only' or aa == 'noaccess' then
        return ps_error('invalidaccess')
    end
    push_opstack { 'name', aa, a[3], add_VM(get_VM(a[4])) }
    return true
end

function operators.cvr()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if ta == 'string' then
        push_opstack(a)
        local ret, err = operators.token()
        if not ret then
            return ret, err
        end
        local b = pop_opstack()
        if b[4] == false then
            return ps_error('syntaxerror')
        end
        a = pop_opstack()
        pop_opstack() -- get rid of the postmatch string remains
        ta = a[1]
    end
    local aa = a[2]
    if not (aa == 'unlimited' or aa == 'read-only') then
        return ps_error('invalidaccess')
    end
    if ta == 'integer' then
        push_opstack { 'real', 'unlimited', 'literal', a[4] }
    elseif ta == 'real' then
        push_opstack(a)
    else
        return ps_error('typecheck')
    end
    return true
end

do

    local byte0 = byte('0')
    local byteA = byte('A') - 10

    function operators.cvrs()
        local c = pop_opstack()
        local b = pop_opstack()
        local a = pop_opstack()
        if not a then
            return ps_error('stackunderflow')
        end
        local ta, tb, tc = a[1], b[1], c[1]
        if not (ta == 'integer' or ta == 'real') then
            return ps_error('typecheck')
        end
        if not tb == 'integer' then
            return ps_error('typecheck')
        end
        if not tc == 'string' then
            return ps_error('typecheck')
        end
        if not c[2] == 'unlimited' then
            return ps_error('invalidaccess')
        end
        local va, vb, vc = a[4], b[4], c[4]
        if (vb < 2 or vb > 36) then
            return ps_error('rangecheck')
        end
        if ta == 'real' then
            push_opstack(a)
            local ret, err = operators.cvi()
            if ret then
                return ret, err
            end
            a = pop_opstack()
        end
        -- todo: use an lpeg
        local decimal = va
        local str     = { }
        local n       = 0
        while decimal > 0 do
            local digit = decimal % vb
            n = n + 1
            str[n] = digit < 10 and char(digit+byte0) or char(digit+byteA)
            decimal = floor(decimal/vb)
        end
        if n > c[6] then
            return ps_error('rangecheck')
        end
        str = concat(reverse(str))
        local thestring = get_VM(vc)
        VM[va] = str .. sub(thestring,n+1,-1)
        push_opstack { c[1], c[2], c[3], add_VM(repl), n, n }
        return true
    end

end

function operators.cvs()
    local b = pop_opstack()
    local a = pop_opstack()
    if not 4 then
        return ps_error('stackunderflow')
    end
    local ta, tb = a[1], b[1]
    local ab = b[2]
    if not tb == 'string' then
        return ps_error('typecheck')
    end
    if not ab == 'unlimited' then
        return ps_error('invalidaccess')
    end
    local va, vb = a[4], b[4]
    if ta == 'real' then
        if floor(va) == va then
            va = tostring(va) .. '.0'
        else
            va = tostring(va)
        end
    elseif ta == 'integer' then
        va = tostring(va)
    elseif ta == 'string' or ta == 'name' then
        va = get_VM(va)
    elseif ta == 'operator' then
        va = a[5]
    elseif ta == 'boolean' then
        va = tostring(va)
    else
        va = "--nostringval--"
    end
    local n = #va
    if n > b[6] then
        return ps_error('rangecheck')
    end
    local thestring = get_VM(vb)
    VM[vb] = va .. sub(thestring,n+1,-1)
    push_opstack { tb, ab, b[3], add_VM(va), n, n }
    return true
end

-- File operators
--
-- +file +closefile +read +write +writestring +readhexstring +writehexstring +readline ^token
-- +bytesavailable +flush +flushfile +resetfile +status +run +currentfile +print ^= ^stack
-- +== ^pstack ^prompt +echo

function operators.file()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if b[1] ~= 'string' then
        return ps_error('typecheck')
    end
    if a[1] ~= 'string' then
        return ps_error('typecheck')
    end
    local fmode = get_VM(b[4])
    local fname = get_VM(a[4])
    -- only accept (r), (w) and (a)
    if fmode ~= "r" and fmode ~= "w" and fmode ~= "a"  then
        return ps_error('typecheck')
    end
    if fname == "%stdin" then
        -- can only read from stdin
        if fmode ~= "r" then
            return ps_error('invalidfileaccess')
        end
        push_opstack { 'file', 'unlimited', 'literal', 0, 0, 0, fmode, io.stdin }
    elseif fname == "%stdout" then
        -- can't read from stdout i.e. can only append, in fact, but lets ignore that
        if fmode == "r" then
            return ps_error('invalidfileaccess')
        end
        push_opstack { 'file', 'unlimited', 'literal', 0, 0, 0, fmode, io.stdout }
    elseif fname == "%stderr" then
        -- cant read from stderr i.e. can only append, in fact, but lets ignore that
        if fmode == "r" then
            return ps_error('invalidfileaccess')
        end
        push_opstack { 'file', 'unlimited', 'literal', 0, 0, 0, fmode, io.stderr }
    elseif fname == "%statementedit" or fname == "%lineedit"then
        return ps_error('invalidfileaccess')
    else
      -- so it is a normal file
        local myfile, error = io.open(fname,fmode)
        if not myfile then
            return ps_error('undefinedfilename')
        end
        if fmode == 'r' then
            l = myfile:read("*a")
            if not l then
                return ps_error('invalidfileaccess')
            end
            -- myfile:close() -- do not close here, easier later on
            push_opstack { 'file', 'unlimited', 'literal', add_VM(l), 1, #l, fmode, myfile}
        else
            push_opstack { 'file', 'unlimited', 'literal', 0, 0, 0, fmode, myfile}
        end
    end
    return true
end

function operators.read()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] ~= 'file' then
        return ps_error('typecheck')
    end
    if a[7] ~= 'r' then
        return ps_error('invalidaccess')
    end
    local b
    local v = a[4]
    local f = a[8]
    if v > 0 then
        local thestr = get_VM(v)
        local n = a[5]
        if n < a[6] then
            byte = sub(thestr,n,n+1)
         -- a[5] = n + 1
        end
    else -- %stdin
        b = f:read(1)
    end
    if b then
        push_opstack { 'integer', 'unlimited', 'literal', byte(b) }
        push_opstack { 'boolean', 'unlimited', 'literal', true }
    else
        f:close()
        push_opstack { 'boolean', 'unlimited', 'literal', false}
    end
    return true
end

function operators.write()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if b[1] ~= 'integer' then
        return ps_error('typecheck')
    end
    if a[1] ~= 'file' then
        return ps_error('typecheck')
    end
    if a[7] == 'r' then
        return ps_error('ioerror')
    end
    a[8]:write(char(b[4] % 256))
    return true
end

function operators.writestring()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if b[1] ~= 'string' then
        return ps_error('typecheck')
    end
    if a[1] ~= 'file' then
        return ps_error('typecheck')
    end
    if a[7] == 'r' then
        return ps_error('ioerror')
    end
    a[8]:write(get_VM(b[4]))
    return true
end

function operators.writehexstring()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if b[1] ~= 'string' then
        return ps_error('typecheck')
    end
    if a[1] ~= 'file' then
        return ps_error('typecheck')
    end
    if a[7] == 'r' then
        return ps_error('ioerror')
    end
    local f = a[8]
    local s = get_VM(b[4])
    for w in gmatch(s,".") do
        f:write(format("%x",byte(w))) -- we have a table for that somewhere
    end
   return true
end

do

    local function get_string_line(a)
        local str    = get_VM(a[4])
        local start  = a[5]
        local theend = a[6]
        if start == theend then
            return nil
        end
        str = match(str,"[\n\r]*([^\n\r]*)",start)
        a[5] = a[5] + #str + 1 -- ?
        return str
    end

    local function get_hexstring_line (a,b)
        local thestring = get_VM(a[4])
        local start, theend = a[5], a[6]
        if start == theend then
            return nil
        end
        local prefix, result, n = nil, { }, 0
        local nmax = b[6]
        while start < theend do
            local b = sub(thestring,start,start)
            if not b then
                break
            end
            local hexbyte = tonumber(b,16)
            if not hexbyte then
                -- skip
            elseif prefix then
                n = n + 1
                result[n] = char(prefix*16+hexbyte)
                if n == nmax then
                    break
                else
                    prefix = nil
                end
            else
                prefix = hexbyte
            end
            start = start + 1
        end
        a[5] = start + 1 -- ?
        return concat(result)
    end

    function operators.readline()
        local b = pop_opstack()
        local a = pop_opstack()
        if not a then
            return ps_error('stackunderflow')
        end
        if a[1] ~= 'file' then
            return ps_error('typecheck')
        end
        if a[7] ~= 'r' then
            return ps_error('invalidaccess')
        end
        local va = a[4]
        if va > 0 then
            va = get_string_line(a)
        else
            va = a[8]:read('*l')
        end
        if not va then
            push_opstack { 'string', 'unlimited', 'literal', add_VM(''), 0, 0 }
            push_opstack { 'boolean', 'unlimited', 'literal', false }
        else
            local n = #va
            if n > b[6] then
                return ps_error('rangecheck')
            end
            local thestring = get_VM(b[4])
            VM[b[4]] = va .. sub(thestring,#va+1, -1)
            push_opstack { 'string', 'unlimited', 'literal', add_VM(va), n, n }
            push_opstack { 'boolean', 'unlimited', 'literal', true }
        end
        return true
    end

    function operators.readhexstring()
        local b = pop_opstack()
        local a = pop_opstack()
        if not a then
            return ps_error('stackunderflow')
        end
        local ta = a[1]
        if not (ta == 'string' or ta == 'file') then
            return ps_error('typecheck')
        end
        local thefile = a[8]
        local va = a[4]
        if va > 0 then
            va = get_hexstring_line (a,b)
        else
            local prefix, result, n = nil, { }, 0
            -- todo: read #va bytes and lpeg
            while true do
                local b = thefile:read(1)
                if not b then
                    break
                end
                local hexbyte = tonumber(b,16)
                local nmax = b[6]
                if not hexbyte then
                    -- skip
                elseif prefix then
                    n = n + 1
                    result[n] = char(prefix*16+hexbyte)
                    if n == nmax then
                        break
                    else
                        prefix = nil
                    end
                else
                    prefix = hexbyte
                end
            end
            va = concat(result)
        end
        local thestring = get_VM(b[4])
        local n = #va
        VM[b[4]] = repl .. sub(thestring,n+1,-1)
        push_opstack { b[1], b[2], b[3], add_VM(va), n, n }
        push_opstack { 'boolean', 'unlimited', 'literal', n == b[6] }
        return true
    end

end

function operators.flush()
    io.flush()
    return true
end

function operators.bytesavailable()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] ~= 'file' then
        return ps_error('typecheck')
    end
    if a[7] ~= 'r' then
        return ps_error('typecheck')
    end
    local waiting = (a[4] > 0) and (a[6] - a[5] + 1) or -1
    push_opstack { "integer", "unlimited", "literal", waiting }
    return true
end

-- this does not really do anything useful

function operators.resetfile()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] ~= 'file' then
        return ps_error('typecheck')
    end
    return true
end

function operators.flushfile()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] ~= 'file' then
        return ps_error('typecheck')
    end
    if a[4] > 0 then
        a[5] = a[6]
    else
        a[8]:flush()
    end
    return true
end

function operators.closefile()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] ~= 'file' then
        return ps_error('typecheck')
    end
    if a[7] == 'r' then
        a[5] = a[6]
    else
        push_opstack(a)
        operators.flushfile()
    end
    a[8]:close()
    return true
end

function operators.status()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] ~= 'file' then
        return ps_error('typecheck')
    end
    local state = io.type(a[8])
    push_opstack { "boolean", 'unlimited', 'literal', not state or state == "closed file" }
    return true
end

function operators.run()
    push_opstack { "string", "unlimited", "literal", add_VM("r"), 1, 1 }
    local ret, err = operators.file()
    if not ret then
        return ret, err
    end
    ret, err = operators.cvx()
    if not ret then
        return ret, err
    end
    local a = pop_opstack() -- an executable file
    push_execstack { ".run", "unlimited", "literal", false } -- constant
    local curstack = execstackptr
    local thefile  = a[8]
    push_execstack(a)
    while curstack < execstackptr do
        do_exec()
    end
    local state = io.type(thefile)
    if not state or state == "closed file" then
        -- okay
    else
        thefile:close()
    end
    if execstackptr > 0 then
        local entry = execstack[execstackptr]
        if entry[1] == '.run' and entry[4] == true then
            pop_execstack()
        end
    end
    return true
end

function operators.currentfile()
    local n = execstackptr
    while n >= 0 do
        local entry = execstack[n]
        if entry[1] == 'file' and entry[7] == 'r' then
            push_opstack(entry)
            return true
        end
        n = n - 1
    end
    push_opstack { 'file', 'unlimited', 'executable', add_VM(''), 0, 0, 'r', stdin }
    return true
end

function operators.print()
    local a = pop_opstack()
    if not a then return
        ps_error('stackunderflow')
    end
    if a[1] ~= 'string' then
        return ps_error('typecheck')
    end
    report(get_VM(a[4]))
end

-- '=' is also defined as a procedure below;
--
-- it is actually supposed to do this: "equaldict begin dup type exec end"
-- where each of the entries in equaldict handles one type only, but this
-- works just as well

do

    local pattern = Cs(
        Cc("(")
      * (
            P("\n") / "\\n"
          + P("\r") / "\\r"
          + P("(")  / "\\("
          + P(")")  / "\\)"
          + P("\\") / "\\\\"
          + P("\b") / "\\b"
          + P("\t") / "\\t"
          + P("\f") / "\\f"
          + R("\000\032","\127\255") / tonumber / formatters["\\%03o"]
          + P(1)
        )^0
      * Cc(")")
    )

    -- print(lpegmatch(pattern,[[h(a\nn)s]]))

    local function do_operator_equal(a)
        local ta, va = a[1], a[4]
        if ta == 'real' then
            if floor(va) == va then
                return tostring(va .. '.0')
            else
                return tostring(va)
            end
        elseif ta == 'integer' then
            return tostring(va)
        elseif ta == 'string' then
            return lpegmatch(pattern,get_VM(va))
        elseif ta == 'boolean' then
            return tostring(va)
        elseif ta == 'operator' then
            return '--' .. a[5] .. '--'
        elseif ta == 'name' then
            if a[3] == 'literal' then
                return '/' .. get_VM(va)
            else
                return get_VM(va)
            end
        elseif ta == 'array' then
            va = get_VM(va)
            local isexec = a[3] == 'executable'
            local result = { isexec and "{" or "[" }
            local n      = 1
            for i=1,#va do
                n = n + 1
                result[n] = do_operator_equal(va[i])
            end
            result[n+1] = isexec and "}" or "]"
            return concat(result," ")
        elseif ta == 'null' then
            return 'null'
        elseif ta == 'dict' then
            return '-dicttype-'
        elseif ta == 'save' then
            return '-savetype-'
        elseif ta == 'mark' then
            return '-marktype-'
        elseif ta == 'file' then
            return '-filetype-'
        elseif ta == 'font' then
            return '-fonttype-'
        end
    end

    function operators.equal()
        local a = pop_opstack()
        if not a then
            return ps_error('stackunderflow')
        end
        report(do_operator_equal(a))
        return true
    end

end

local function commonstack(seperator)
    for n=1,opstackptr do
        push_opstack { 'string', 'unlimited', 'literal', add_VM(seperator), 1 ,1 }
        push_opstack(opstack[n])
        push_execstack { 'operator','unlimited','executable', operators.print, 'print'}
        push_execstack { 'operator','unlimited','executable', operators.equal, '=='}
    end
    return true
end

function operators.pstack()
    return commonstack("\n")
end

function operators.stack()
    return commonstack(" ")
end

-- this does not really do anything useful

function operators.echo()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] ~= 'boolean' then
        return ps_error('typecheck')
    end
    return true
end

-- Virtual memory operators
--
-- +save +restore +vmstatus

-- to be checked: we do a one-level shallow copy now, not sure if that
-- is good enough yet

local savelevel = 0

initializers[#initializers+1] = function(reset)
    savelevel = 0
end

function operators.save()
    local saved_VM = { }
    for k1, v1 in next, VM do
        if type(v1) == "table" then
            local t1 = { }
            saved_VM[k1] = t1
            for k2, v2 in next, t1 do
                if type(v2) == "table" then
                    local t2 = { }
                    t1[k2] = t2
                    for k3, v3 in next, v2 do
                        t2[k3] = v3
                    end
                else
                    t1[k2] = v2
                end
            end
        else
            saved_VM[k1] = v1
        end
    end
    push_gsstack { 'save', copy_gsstate() }
    savelevel = savelevel + 1
    push_opstack { 'save', 'unlimited', 'executable', add_VM(saved_VM) }
end

do

    local function validstack(stack,index,saved_VM)
        -- loop over pstack, execstack, and dictstack to make sure
        -- there are no entries with VM_id > #saved_VM
        for i=index,1,-1 do
            local v = stack[i]
            if type(v) == "table" then
                local tv = v[1]
                if tv == "save" or tv == "string" or tv == "array" or tv == "dict" or tv == "name" or tv == "file" then
                    -- todo: check on %stdin/%stdout, but should be ok
                    if v[4] > #saved_VM then
                        return false
                    end
                end
            end
            i = i - 1
        end
        return true
    end

    function operators.restore()
        local a = pop_opstack()
        if not a then
            return ps_error('stackunderflow')
        end
        if a[1] ~= 'save' then
            return ps_error('typecheck')
        end
        if a[4] == 0 or savelevel == 0 then
            return ps_error('invalidrestore')
        end
        local saved_VM = get_VM(a[4])
        if directvm then
        else
            if not validstack(execstack,execstackptr,saved_VM) then
                return ps_error('invalidrestore')
            end
            if not validstack(dictstack,dictstackptr,saved_VM) then
                return ps_error('invalidrestore')
            end
            if not validstack(opstack,opstackptr,saved_VM) then
                return ps_error('invalidrestore')
            end
        end
        while gsstackptr > 0 do
            local g = gsstack[gsstackptr]
            gsstackptr = gsstackptr - 1
            if g[1] == "save"  then
                gsstate = g[2]
                return
            end
        end
        a[4] = 0 -- invalidate save object
        savelevel = savelevel - 1
        VM = saved_VM
    end

end

function operators.vmstatus()
    local n = 0 -- #VM * 100
    push_opstack { 'integer', 'unlimited', 'literal', savelevel }
    push_opstack { 'integer', 'unlimited', 'literal', n }
    push_opstack { 'integer', 'unlimited', 'literal', n }
    return true
end

-- Miscellaneous operators
--
-- +bind +null +usertime +version

-- the reference manual says bind only ERRORS on typecheck

local function bind()
    local a = pop_opstack()
    if not a then
        return true -- ps_error('stackunderflow')
    end
    if not a[1] == 'array' then
        return ps_error('typecheck')
    end
    local proc = get_VM(a[4])
    for i=1,#proc do
        local v = proc[i]
        local t = v[1]
        if t == 'name' then
            if v[3] == 'executable' then
                local op = lookup(get_VM(v[4]))
                if op and op[1] == 'operator' then
                    proc[i] = op
                end
            end
        elseif t == 'array' then
            if v[2] == 'unlimited' then
                push_opstack(v)
                bind() -- recurse
                pop_opstack()
                proc[i][2] = 'read-only'
            end
        end
    end
    push_opstack(a)
end

operators.bind = bind

function operators.null()
    push_opstack { 'null', 'unlimited', 'literal' }
    return true
end

function operators.usertime()
    push_opstack { 'integer', 'unlimited', 'literal', floor(os.clock() * 1000) }
    return true
end

function operators.version()
    push_opstack { 'string', 'unlimited', 'literal', add_VM('23.0') }
    return true
end

-- Graphics state operators
--
-- +gsave +grestore +grestoreall +initgraphics +setlinewidth +currentlinewidth +setlinecap +currentlinecap
-- +setlinejoin +currentlinejoin +setmiterlimit +currentmiterlimit +setdash +currentdash +setflat +currentflat
-- +setgray +currentgray +sethsbcolor +currenthsbcolor +setrgbcolor +setcmykcolor +currentrgbcolor +setscreen
-- +currentscreen +settransfer +currenttransfer

function operators.gsave()
    push_gsstack { 'gsave', copy_gsstate() }
    return true
end

function operators.grestore()
    if gsstackptr > 0 then
        local g = gsstack[gsstackptr]
        if g[1] == "gsave" then
            gsstackptr = gsstackptr - 1
            gsstate = g[2]
        end
    end
    return true
end

function operators.grestoreall() -- needs checking
    for i=gsstackptr,1,-1 do
        local g = gsstack[i]
        if g[1] == "save"  then
            gsstate    = g[2]
            gsstackptr = i
            return true
        end
    end
    gsstackptr = 0
    return true
end

function operators.initgraphics()
    local newstate       = copy_gsstate() -- hm
    newstate.matrix      = { 1, 0, 0, 1, 0, 0 }
    newstate.color       = { gray = 0, hsb = { }, rgb = { }, cmyk = { }, type = "gray" }
    newstate.position    = { } -- actual x and y undefined
    newstate.path        = { }
    newstate.linewidth   = 1
    newstate.linecap     = 0
    newstate.linejoin    = 0
    newstate.miterlimit  = 10
    newstate.dashpattern = { }
    newstate.dashoffset  = 0
    gsstate = newstate
    device.initgraphics()
    operators.initclip()
    return true
end

function operators.setlinewidth()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local t = a[1]
    if not (t == 'integer' or t == 'real') then
        return ps_error('typecheck')
    end
    gsstate.linewidth = a[4]
    return true
end

function operators.currentlinewidth()
    local w = gsstate.linewidth
    push_opstack {
        (abs(w) > MAX_INT or floor(w) ~= w) and 'real' or 'integer',
        'unlimited',
        'literal',
        w,
    }
    return true
end

function operators.setlinecap()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] ~= 'integer' then
        return ps_error('typecheck')
    end
    local c =  a[4]
    if c > 2 or c < 0 then
        return ps_error('rangecheck')
    end
    gsstate.linecap = c
    return true
end

function operators.currentlinecap()
    push_opstack { 'integer', 'unlimited', 'literal', gsstate.linecap }
    return true
end

function operators.setlinejoin()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] ~= 'integer' then
        return ps_error('typecheck')
    end
    local j = a[4]
    if j > 2 or j < 0 then
        return ps_error('rangecheck')
    end
    gsstate.linejoin = j
    return true
end

function operators.currentlinejoin()
   push_opstack { 'integer', 'unlimited', 'literal', gsstate.linejoin }
   return true
end

function operators.setmiterlimit()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local t = a[1]
    if not (t == 'integer' or t == 'real') then
        return ps_error('typecheck')
    end
    local m = a[4]
    if m < 1 then
        return ps_error('rangecheck')
    end
    gsstate.miterlimit = m
    return true
end

function operators.currentmiterlimit()
    local w = gsstate.miterlimit
    push_opstack {
        (abs(w) > MAX_INT or floor(w) ~= w) and 'real' or 'integer',
        'unlimited',
        'literal',
        w
    }
    return true
end

function operators.setdash()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, tb = a[1], b[1]
    if ta ~= 'array' then
        return ps_error('typecheck')
    end
    if not (tb == 'integer' or tb == 'real') then
        return ps_error('typecheck')
    end
    local pattern  = { }
    local total    = 0
    local thearray = get_VM(a[4])
    for i=1,#thearray do
        local a = thearray[i]
        local ta, va = a[1], a[4]
        if ta ~= "integer" then
            return ps_error('typecheck')
        end
        if va < 0 then
            return ps_error('limitcheck')
        end
        total = total + va
        pattern[#pattern+1] = va
    end
    if #pattern > 0 and total == 0 then
        return ps_error('limitcheck')
    end
    gsstate.dashpattern = pattern
    gsstate.dashoffset  = b[4]
    return true
end

function operators.currentdash()
    local thearray = gsstate.dashpattern
    local pattern  = { }
    for i=1,#thearray do
        pattern[i] = { 'integer', 'unlimited', 'literal', thearray[i] }
    end
    push_opstack { 'array', 'unlimited', 'literal', add_VM(pattern), #pattern, #pattern }
    local w = gsstate.dashoffset
    push_opstack {
        (abs(w) > MAX_INT or floor(w) ~= w) and 'real' or 'integer', 'unlimited', 'literal', w
    }
    return true
end

function operators.setflat()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, va = a[1], a[4]
    if not (ta == 'integer' or ta == 'real') then
        return ps_error('typecheck')
    end
    gsstate.flatness = va
    return true
end

function operators.currentflat()
    local w = gsstate.flatness
    push_opstack {
        (abs(w) > MAX_INT or floor(w) ~= w) and 'real' or 'integer', 'unlimited', 'literal', w
    }
    return true
end

-- Color conversion functions
--
-- normally, level one colors are based on hsb, but for our backend it is better to
-- stick with the original request when possible

do

    local function rgb_to_gray (r, g, b)
        return 0.30 * r + 0.59 * g + 0.11 * b
    end

    local function cmyk_to_gray (c, m, y, k)
        return 0.30 * (1.0 - min(1.0,c+k)) + 0.59 * (1.0 - min(1.0,m+k)) + 0.11 * (1.0 - min(1.0,y+k))
    end

    local function cmyk_to_rgb (c, m, y, k)
        return 1.0 - min(1.0,c+k), 1.0 - min(1.0,m+k), 1.0 - min(1.0,y+k)
    end

    local function rgb_to_hsv(r, g, b)
        local offset, maximum, other_1, other_2
        if r >= g and r >= b then
            offset, maximum, other_1, other_2 = 0, r, g, b
        elseif g >= r and g >= b then
            offset, maximum, other_1, other_2 = 2, g, b, r
        else
            offset, maximum, other_1, other_2 = 4, b, r, g
        end
        if maximum == 0 then
            return 0, 0, 0
        end
        local minimum = other_1 < other_2 and other_1 or other_2
        if maximum == minimum then
            return 0, 0, maximum
        end
        local delta = maximum - minimum
        return (offset + (other_1-other_2)/delta)/6, delta/maximum, maximum
     end

    local function gray_to_hsv (col)
        return 0, 0, col
    end

    local function gray_to_rgb (col)
        return 1-col, 1-col, 1-col
    end

    local function gray_to_cmyk (col)
        return 0, 0, 0, col
    end

    local function hsv_to_rgb(h,s,v)
        local hi = floor(h * 6.0) % 6
        local f =  (h * 6) - floor(h * 6)
        local p = v * (1 - s)
        local q = v * (1 - f * s)
        local t = v * (1 - (1 - f) * s)
        if hi == 0 then
            return v, t, p
        elseif hi == 1 then
            return q, v, p
        elseif hi == 2 then
            return p, v, t
        elseif hi == 3 then
            return p, q, v
        elseif hi == 4 then
            return t, p, v
        elseif hi == 5 then
            return v, p, q
        end
    end

    local function hsv_to_gray(h,s,v)
        return rgb_to_gray(hsv_to_rgb(h,s,v))
    end

    -- color operators

    function operators.setgray()
        local g = pop_opstack()
        if not g then
            return ps_error('stackunderflow')
        end
        local gt = g[1]
        if not (gt == 'integer' or gt == 'real') then
            return ps_error('typecheck')
        end
        local gv = g[4]
        local color = gsstate.color
        color.type = "gray"
        color.gray = (gv < 0 and 0) or (gv > 1 and 1) or gv
        return true
    end

    function operators.currentgray()
        local color = gsstate.color
        local t = color.type
        local s
        if t == "gray" then
            s = color.gray
        elseif t == "rgb" then
            local col = color.rgb
            s = rgb_to_gray(col[1],col[2],col[3])
        elseif t == "cmyk" then
            local col = cmyk
            s = cmyk_to_gray(col[1],col[2],col[3],col[4])
        else
            local col = color.hsb
            s = hsv_to_gray(col[1],col[2],col[3])
        end
        push_opstack { (s == 0 or s == 1) and 'integer' or 'real', 'unlimited', 'literal', s }
        return true
    end

    function operators.sethsbcolor()
        local b = pop_opstack()
        local s = pop_opstack()
        local h = pop_opstack()
        if not h then
            return ps_error('stackunderflow')
        end
        local ht, st, bt = h[1], s[1], b[1]
        if not (ht == 'integer' or ht == 'real') then
            return ps_error('typecheck')
        end
        if not (st == 'integer' or st == 'real') then
            return ps_error('typecheck')
        end
        if not (bt == 'integer' or bt == 'real') then
            return ps_error('typecheck')
        end
        local hv, sv, bv = h[4], s[4], b[4]
        local color = gsstate.color
        color.type = "hsb"
        color.hsb  = {
           (hv < 0 and 0) or (hv > 1 and 1) or hv,
           (sv < 0 and 0) or (sv > 1 and 1) or sv,
           (bv < 0 and 0) or (bv > 1 and 1) or bv,
        }
        return true
    end

    function operators.currenthsbcolor()
        local color = gsstate.color
        local t = color.type
        local h, s, b
        if t == "gray" then
            h, s, b = gray_to_hsv(color.gray)
        elseif t == "rgb" then
            local col = color.rgb
            h, s, b = rgb_to_hsv(col[1],col[2],col[3])
        elseif t == "cmyk" then
            local col = color.cmyk
            h, s, b = cmyk_to_hsv(col[1],col[2],col[3],col[4])
        else
            local col = color.hsb
            h, s, b = col[1], col[2], col[3]
        end
        push_opstack { (h == 0 or h == 1) and 'integer' or 'real', 'unlimited', 'literal', h }
        push_opstack { (s == 0 or s == 1) and 'integer' or 'real', 'unlimited', 'literal', s }
        push_opstack { (b == 0 or b == 1) and 'integer' or 'real', 'unlimited', 'literal', b }
        return true
    end

    function operators.setrgbcolor()
        local b = pop_opstack()
        local g = pop_opstack()
        local r = pop_opstack()
        if not r then
            return ps_error('stackunderflow')
        end
        local rt, gt, bt = r[1], g[1], b[1]
        if not (rt == 'integer' or rt == 'real') then
            return ps_error('typecheck')
        end
        if not (gt == 'integer' or gt == 'real') then
            return ps_error('typecheck')
        end
        if not (bt == 'integer' or bt == 'real') then
            return ps_error('typecheck')
        end
        local rv, gv, bv = r[4], g[4], b[4]
        local color = gsstate.color
        color.type = "rgb"
        color.rgb  = {
            (rv < 0 and 0) or (rv > 1 and 1) or rv,
            (gv < 0 and 0) or (gv > 1 and 1) or gv,
            (bv < 0 and 0) or (bv > 1 and 1) or bv,
        }
        return true
    end

    function operators.currentrgbcolor()
        local color = gsstate.color
        local t = color.type
        local r, g, b
        if t == "gray" then
            r, g, b = gray_to_rgb(color.gray)
        elseif t == "rgb" then
            local col = color.rgb
            r, g, b = col[1], col[2], col[3]
        elseif t == "cmyk" then
            r, g, b = cmyk_to_rgb(color.cmyk)
        else
            local col = color.hsb
            r, g, b = hsv_to_rgb(col[1], col[2], col[3])
        end
        push_opstack { (r == 0 or r == 1) and "integer" or "real", 'unlimited', 'literal', r }
        push_opstack { (g == 0 or g == 1) and "integer" or "real", 'unlimited', 'literal', g }
        push_opstack { (b == 0 or b == 1) and "integer" or "real", 'unlimited', 'literal', b }
        return true
    end

    function operators.setcmykcolor()
        local k = pop_opstack()
        local y = pop_opstack()
        local m = pop_opstack()
        local c = pop_opstack()
        if not c then
            return ps_error('stackunderflow')
        end
        local ct, mt, yt, kt = c[1], m[1], y[1], k[1]
        if not (ct == 'integer' or ct == 'real') then
            return ps_error('typecheck')
        end
        if not (mt == 'integer' or mt == 'real') then
            return ps_error('typecheck')
        end
        if not (yt == 'integer' or yt == 'real') then
            return ps_error('typecheck')
        end
        if not (kt == 'integer' or kt == 'real') then
            return ps_error('typecheck')
        end
        local cv, mv, yv, kv = c[4], m[4], y[4], k[4]
        local color = gsstate.color
        color.type = "cmyk"
        color.cmyk = {
            (cv < 0 and 0) or (cv > 1 and 1) or cv,
            (mv < 0 and 0) or (mv > 1 and 1) or mv,
            (yv < 0 and 0) or (yv > 1 and 1) or yv,
            (kv < 0 and 0) or (kv > 1 and 1) or kv,
        }
        return true
    end

    function operators.currentcmykcolor()
        local color = gsstate.color
        local t = color.type
        local c, m, y, k
        if t == "gray" then
            c, m, y, k = gray_to_cmyk(color.gray)
        elseif t == "rgb" then
            c, m, y, k = rgb_to_cmyk(color.rgb)
        elseif t == "cmyk" then
            local col = color.cmyk
            c, m, y, k = col[1], col[2], col[3], col[4]
        else
            local col = color.hsb
            c, m, y, k = hsv_to_cmyk(col[1], col[2], col[3])
        end
        push_opstack { (c == 0 or c == 1) and "integer" or "real", 'unlimited', 'literal', c }
        push_opstack { (m == 0 or m == 1) and "integer" or "real", 'unlimited', 'literal', m }
        push_opstack { (y == 0 or y == 1) and "integer" or "real", 'unlimited', 'literal', y }
        push_opstack { (k == 0 or k == 1) and "integer" or "real", 'unlimited', 'literal', k }
        return true
    end

end

function operators.setscreen()
    local c = pop_opstack()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, tb, tc, ac = a[1], b[1], c[1], c[3]
    if not (tc == 'array' and ac == 'executable') then
        return ps_error('typecheck')
    end
    if not (tb == 'real' or tb == 'integer') then
        return ps_error('typecheck')
    end
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    local va, vb, vc = a[4], b[4], c[4]
    if vb < 0 or vb > 360 then
        return ps_error('rangecheck')
    end
    if va < 0 then
        return ps_error('rangecheck')
    end
    gsstate.screen = { va, vb, vc }
    return true
end

function operators.currentscreen()
    local w
    if not gsstate.screen then
        local popper = { 'operator', 'unlimited', 'executable', operators.pop, 'pop' }
        push_opstack { 'integer', 'unlimited', 'literal', 1 }
        push_opstack { 'integer', 'unlimited', 'literal', 0 }
        push_opstack { 'array',   'unlimited', 'executable', add_VM{ popper }, 1, 1, 'd' }
    else
        local w1 = gsstate.screen[1]
        local w2 = gsstate.screen[2]
        local w3 = gsstate.screen[3]
        push_opstack {
            (abs(w) > MAX_INT or floor(w1) ~= w1) and 'real' or 'integer', 'unlimited', 'literal', w1
        }
        push_opstack {
            (abs(w) > MAX_INT or floor(w2) ~= w2) and 'real' or 'integer', 'unlimited', 'literal', w2
        }
        local thearray = get_VM(w3)
        push_opstack { 'array', 'unlimited', 'executable', w3, 1, #thearray, 'd' } -- w3 or thearray ?
    end
    return true
end

function operators.settransfer()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if not (a[1] == 'array' and a[3] == 'executable') then
        return ps_error('typecheck')
    end
    local va = a[4]
    if va < 0 then
        return ps_error('rangecheck')
    end
    gsstate.transfer = va
    return true
end

function operators.currenttransfer()
    local transfer = gsstate.transfer
    if not transfer then
        push_opstack { 'array', 'unlimited', 'executable', add_VM{ }, 0, 0, 'd'}
    else
        local thearray = get_VM(transfer)
        push_opstack { 'array', 'unlimited', 'executable', transfer, 1, #thearray, 'd' }
    end
    return true
end

-- Coordinate system and matrix operators
--
-- +matrix +initmatrix +identmatrix +defaultmatrix +currentmatrix +setmatrix +translate
-- +scale +rotate +concat +concatmatrix +transform +dtransform +itransform +idtransform
-- +invertmatrix

-- are these changed in place or not? if not then we can share

function operators.matrix()
    local matrix = {
        {'real', 'unlimited', 'literal', 1},
        {'real', 'unlimited', 'literal', 0},
        {'real', 'unlimited', 'literal', 0},
        {'real', 'unlimited', 'literal', 1},
        {'real', 'unlimited', 'literal', 0},
        {'real', 'unlimited', 'literal', 0},
    }
    push_opstack { 'array', 'unlimited', 'literal', add_VM(matrix), 6, 6 }
    return true
end

function operators.initmatrix()
    gsstate.matrix = { 1, 0, 0, 1, 0, 0 }
    return true
end

function operators.identmatrix()
    local a = pop_opstack()
    if not a then return
        ps_error('stackunderflow')
    end
    if a[1] ~= 'array' then
        return ps_error('typecheck')
    end
    if a[6] < 6 then
        return ps_error('rangecheck')
    end
    local m = VM[a[4]] -- or can we replace the numbers
    m[1] = { 'real', 'unlimited', 'literal', 1 }
    m[2] = { 'real', 'unlimited', 'literal', 0 }
    m[3] = { 'real', 'unlimited', 'literal', 0 }
    m[4] = { 'real', 'unlimited', 'literal', 1 }
    m[5] = { 'real', 'unlimited', 'literal', 0 }
    m[6] = { 'real', 'unlimited', 'literal', 0 }
    a[5] = 6
    push_opstack(a)
    return true
end

operators.defaultmatrix = operators.identmatrix

function operators.currentmatrix()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] ~= 'array' then
        return ps_error('typecheck')
    end
    if a[6] < 6 then
        return ps_error('rangecheck')
    end
    local thearray = get_VM(a[4])
    local matrix = gsstate.matrix
    for i=1,6 do
        thearray[i] = {'real', 'unlimited', 'literal', matrix[i]}
    end
    push_opstack { 'array', 'unlimited', 'literal', a[4], 6, 6 }
    return true
end

function operators.setmatrix()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] ~= 'array' then
        return ps_error('typecheck')
    end
    if a[6] ~= 6 then
        return ps_error('rangecheck')
    end
    local thearray = get_VM(a[4])
    local matrix   = gsstate.matrix
    for i=1,#thearray do
        local a = thearray[i]
        local ta, tv = a[1], a[4]
        if not (ta == 'real' or ta == 'integer') then
            return ps_error('typecheck')
        end
        if i > 6 then
            return ps_error('rangecheck')
        end
        matrix[i] = va
    end
    return true
end

local function do_transform(matrix,a,b)
    local x = matrix[1] * a + matrix[3] * b + matrix[5]
    local y = matrix[2] * a + matrix[4] * b + matrix[6]
    return x, y
end

local function do_itransform(matrix,a,b)
    local m1 = matrix[1]
    local m4 = matrix[4]
    if m1 == 0 or m4 == 0 then
        return nil
    end
    local x = (a - matrix[5] - matrix[3] * b) / m1
    local y = (b - matrix[6] - matrix[2] * a) / m4
    return x, y
end

local function do_concat (a,b)
    local a1, a2, a3, a4, a5, a6 = a[1], a[2], a[3], a[4], a[5], a[6]
    local b1, b2, b3, b4, b5, b6 = b[1], b[2], b[3], b[4], b[5], b[6]
    local c1 = a1 * b1 + a2 * b3
    local c2 = a1 * b2 + a2 * b4
    local c3 = a1 * b3 + a3 * b4
    local c4 = a3 * b2 + a4 * b4
    local c5 = a5 * b1 + a6 * b3 + b5
    local c6 = a5 * b2 + a6 * b4 + b6
    -- this is because double calculation introduces a small error
    return {
        abs(c1) < 1.0e-16 and 0 or c1,
        abs(c2) < 1.0e-16 and 0 or c2,
        abs(c3) < 1.0e-16 and 0 or c3,
        abs(c4) < 1.0e-16 and 0 or c4,
        abs(c5) < 1.0e-16 and 0 or c5,
        abs(c6) < 1.0e-16 and 0 or c6,
    }
end

local function do_inverse (a)
    local a1, a2, a3, a4, a5, a6 = a[1], a[2], a[3], a[4], a[5], a[6]
    local det = a1 * a4 - a3 * a2
    if det == 0 then
        return nil
    end
    local c1 =  a4 / det
    local c3 = -a3 / det
    local c2 = -a2 / det
    local c4 =  a1 / det
    local c5 = (a3 * a6 - a5 * a4) / det
    local c6 = (a5 * a2 - a1 * a6) / det
    return {
        abs(c1) < 1.0e-16 and 0 or c1,
        abs(c2) < 1.0e-16 and 0 or c2,
        abs(c3) < 1.0e-16 and 0 or c3,
        abs(c4) < 1.0e-16 and 0 or c4,
        abs(c5) < 1.0e-16 and 0 or c5,
        abs(c6) < 1.0e-16 and 0 or c6,
    }
end

function operators.translate()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] == 'array' then
        if a[6] ~= 6 then
            return ps_error('typecheck')
        end
        local tf = a
        local a = pop_opstack()
        local b = pop_opstack()
        if not b then
            return ps_error('stackunderflow')
        end
        local ta, tb = a[1], b[1]
        if not (ta == 'real' or ta == 'integer') then
            return ps_error('typecheck')
        end
        if not (tb == 'real' or tb == 'integer') then
            return ps_error('typecheck')
        end
        local m   = VM[tf[4]]
        local old = { m[1][4], m[2][4], m[3][4], m[4][4], m[5][4], m[6][4] }
        local c   = do_concat(old,{1,0,0,1,b[4],a[4]})
        for i=1,6 do
            m[i] = { 'real', 'unlimited', 'literal', c[i] }
        end
        tf[5] = 6
        push_opstack(tf)
    else
        local b = pop_opstack()
        local ta = a[1]
        local tb = b[1]
        if not (ta == 'real' or ta == 'integer') then
            return ps_error('typecheck')
        end
        if not (tb == 'real' or tb == 'integer') then
            return ps_error('typecheck')
        end
        gsstate.matrix = do_concat(gsstate.matrix,{1,0,0,1,b[4],a[4]})
    end
    return true
end

function operators.scale()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if ta == 'array' then
        local tf = a
        if a[6] ~= 6 then
            return ps_error('typecheck')
        end
        local a = pop_opstack()
        local b = pop_opstack()
        if not b then
            return ps_error('stackunderflow')
        end
        local ta, tb = a[1], b[1]
        if not (ta == 'real' or ta == 'integer') then
            return ps_error('typecheck')
        end
        if not (tb == 'real' or tb == 'integer') then
            return ps_error('typecheck')
        end
        local v = VM[tf[4]]
        local c = do_concat (
            { v[1][4], v[2][4], v[3][4], v[4][4], v[5][4], v[6][4] },
            { b[4], 0, 0, a[4], 0, 0 }
        )
        for i=1,6 do
            v[i] = { 'real', 'unlimited', 'literal', c[i] }
        end
        tf[5] = 6
        push_opstack(tf)
    else
        local b = pop_opstack()
        if not b then
            return ps_error('stackunderflow')
        end
        local ta, tb = a[1], b[1]
        if not (ta == 'real' or ta == 'integer') then
            return ps_error('typecheck')
        end
        if not (tb == 'real' or tb == 'integer') then
            return ps_error('typecheck')
        end
        gsstate.matrix = do_concat(gsstate.matrix, { b[4], 0, 0, a[4], 0, 0 })
    end
    return true
end

function operators.concat()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] ~= "array" then
        return ps_error('typecheck')
    end
    if a[6] ~= 6 then
        return ps_error('typecheck')
    end
    local thearray = get_VM(a[4])
    local l = { }
    for i=1,#thearray do
        local v = thearray[i]
        local t = v[1]
        if not (t == 'real' or t == 'integer') then
            return ps_error('typecheck')
        end
        l[i] = v[4]
    end
    gsstate.matrix = do_concat(gsstate.matrix,l)
    return true
end

function operators.concatmatrix()
    local tf = pop_opstack()
    local b  = pop_opstack()
    local a  = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if tf[1] ~= "array" then return ps_error('typecheck') end
    if b [1] ~= "array" then return ps_error('typecheck') end
    if a [1] ~= "array" then return ps_error('typecheck') end
    if tf[6] ~= 6       then return ps_error('typecheck') end
    if b [6] ~= 6       then return ps_error('typecheck') end
    if a [6] ~= 6       then return ps_error('typecheck') end
    local al = { }
    local thearray = get_VM(a[4])
    for i=1,#thearray do
        local v = thearray[i]
        local tv = v[1]
        if not (tv == 'real' or tv == 'integer') then
            return ps_error('typecheck')
        end
        al[i] = v[4]
    end
    local bl = { }
    local thearray = get_VM(b[4])
    for i=1,#thearray do
        local v = thearray[i]
        local tv = v[1]
        if not (tv == 'real' or tv == 'integer') then
            return ps_error('typecheck')
        end
        bl[i] = v[4]
    end
    local c = do_concat(al, bl)
    local m = VM[tf[4]]
    for i=1,6 do
        m[i] = { 'real', 'unlimited', 'literal', c[i] }
    end
    tf[5] = 6
    push_opstack(tf)
    return true
end

function operators.rotate()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    if ta == 'array' then
        local tf
        if a[6] ~= 6 then
            return ps_error('typecheck')
        end
        tf = a
        a = pop_opstack()
        if not a then
            return ps_error('stackunderflow')
        end
        if not (a[1] == 'real' or a[1] == 'integer') then
            return ps_error('typecheck')
        end
        local m   = VM[tf[4]]
        local old = { m[1][4], m[2][4], m[3][4], m[4][4], m[5][4], m[6][4] }
        local av  = a[4]
        local c   = do_concat (old, {cos(rad(av)),sin(rad(av)),-sin(rad(av)),cos(rad(av)), 0, 0})
        for i=1,6 do
            m[i] = { 'real', 'unlimited', 'literal', c[i] }
        end
        push_opstack(tf)
    elseif ta == 'real' or ta == 'integer' then
        local av = a[4]
        gsstate.matrix = do_concat(gsstate.matrix,{cos(rad(av)),sin(rad(av)),-sin(rad(av)),cos(rad(av)),0,0})
    else
        return ps_error('typecheck')
    end
    return true
end

function operators.transform()
    local a = pop_opstack()
    local b = pop_opstack()
    if not b then
        ps_error('stackunderflow')
    end
    local tf
    if a[1] == 'array' then
        if a[6] ~= 6 then
            return ps_error('typecheck')
        end
        local thearray = get_VM(a[4])
        tf = { }
        for i=1,#thearray do
            local v  = thearray[i]
            local v1 = v[1]
            if not (v1 == 'real' or v1 == 'integer') then
                return ps_error('typecheck')
            end
            tf[i] = v[4]
        end
        a = pop_opstack()
        if not a then
            return ps_error('stackunderflow')
        end
    else
        tf = gsstate.matrix
    end
    local a1 = a[1]
    local b1 = b[1]
    if not (a1 == 'real' or a1 == 'integer') then
        return ps_error('typecheck')
    end
    if not (b1 == 'real' or b1 == 'integer') then
        return ps_error('typecheck')
    end
    local x, y = do_transform(tf,b[4],a[4]);
    push_opstack { 'real', 'unlimited', 'literal', x }
    push_opstack { 'real', 'unlimited', 'literal', y }
    return true
end

local function commontransform()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local tf
    if a[1] == 'array' then
        if a[6] ~= 6 then
            return ps_error('typecheck')
        end
        tf = { }
        local thearray = get_VM(a[4])
        for i=1,#thearray do
            local v = thearray[i]
            local tv = v[1]
            if not (tv == 'real' or tv == 'integer') then
                return ps_error('typecheck')
            end
            tf[i] = v[4]
        end
        a = pop_opstack()
        if not a then
            return ps_error('stackunderflow')
        end
    else
        tf = gsstate.matrix
    end
    local b = pop_opstack()
    if not b then
        return ps_error('stackunderflow')
    end
    local ta = a[1]
    local tb = b[1]
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    if not (tb == 'real' or tb == 'integer') then
        return ps_error('typecheck')
    end
    return true, tf, a, b
end

function operators.dtransform()
    local ok, tf, a, b = commontransform()
    if ok then
        local x, y = do_transform({tf[1],tf[2],tf[3],tf[4],0,0},b[4],a[4])
        if not x then
            return ps_error('undefinedresult')
        end
        push_opstack { 'real', 'unlimited', 'literal', x }
        push_opstack { 'real', 'unlimited', 'literal', y }
        return true
    else
        return false, tf
    end
end

function operators.itransform()
    local ok, tf, a, b = commontransform()
    if ok then
        local x, y = do_itransform(tf,b[4],a[4])
        if not x then
            return ps_error('undefinedresult')
        end
        push_opstack { 'real', 'unlimited', 'literal', x }
        push_opstack { 'real', 'unlimited', 'literal', y }
        return true
    else
        return false, tf
    end
end

function operators.idtransform()
    local ok, tf, a, b = commontransform()
    if ok then
        local x,y = do_itransform({tf[1],tf[2],tf[3],tf[4],0,0},b[4],a[4]);
        if not x then
            return ps_error('undefinedresult')
        end
        push_opstack { 'real', 'unlimited', 'literal', x }
        push_opstack { 'real', 'unlimited', 'literal', y }
        return true
    else
        return false, tf
    end
end

function operators.invertmatrix()
    local tf = pop_opstack()
    if not tf then
        return ps_error('stackunderflow')
    end
    if tf[1] ~= "array" then
        return ps_error('typecheck')
    end
    if tf[6] ~= 6 then
        return ps_error('typecheck')
    end
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] ~= "array" then
        return ps_error('typecheck')
    end
    if a[6] ~= 6 then
        return ps_error('typecheck')
    end
    local al = { }
    local thearray = get_VM(a[4])
    for i=1,#thearray do
        local v = thearray[i]
        local tv = v[1]
        if not (tv == 'real' or tv == 'integer') then
            return ps_error('typecheck')
        end
        al[i] = v[4]
    end
    local c = do_inverse(al)
    if not c then
        return ps_error('undefinedresult')
    end
    local m = VM[tf[4]]
    for i=1,6 do
        m[i] = { 'real', 'unlimited', 'literal', c[i] }
    end
    tf[5] = 6
    push_opstack(tf)
    return true
end

-- Path construction operators
--
-- +newpath +currentpoint +moveto +rmoveto +lineto +rlineto +arc +arcn +arcto +curveto +rcurveto
-- +closepath +flattenpath -reversepath -strokepath -charpath +clippath -pathbbox -pathforall
-- +initclip *clip *eoclip

function operators.newpath()
    gsstate.path     = { }
    gsstate.position = { }
    return true
end

function operators.currentpoint()
    local position = gsstate.position
    if #position == 0 then
        return ps_error('nocurrentpoint')
    end
    local x, y = do_itransform(gsstate.matrix, position[1], position[2])
    if not x then
        return ps_error('undefinedresult')
    end
    push_opstack { 'real', 'unlimited', 'literal', x }
    push_opstack { 'real', 'unlimited', 'literal', y }
end

function operators.moveto()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local b1 = b[1]
    local a1 = a[1]
    if not (b1 == 'real' or b1 == 'integer') then
        return ps_error('typecheck')
    end
    if not (a1 == 'real' or a1 == 'integer') then
        return ps_error('typecheck')
    end
    local path    = gsstate.path
    local length  = #path
    local x, y = do_transform(gsstate.matrix, a[4], b[4])
    if length > 0 and path[length][1] == "moveto" then
        -- replace last moveto
    else
        length = length + 1
    end
    path[length] = { "moveto", x, y }
    gsstate.position = { x, y }
    return true
end

function operators.rmoveto()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local bt = b[1]
    local at = a[1]
    if not (bt == 'real' or bt == 'integer') then
        return ps_error('typecheck')
    end
    if not (at == 'real' or at == 'integer') then
        return ps_error('typecheck')
    end
    local position = gsstate.position
    local path     = gsstate.path
    local length   = #path
    if #position == 0 then
        return ps_error('nocurrentpoint')
    end
    local x, y = do_transform(gsstate.matrix, a[4], b[4])
    x = position[1] + x
    y = position[2] + y
    position[1] = x
    position[2] = y
    if length > 0 and path[length][1] == "moveto" then
        -- replace last moveto
    else
        length = length + 1
    end
    path[length] = { "moveto", x, y }
    return true
end

function operators.lineto()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local at = a[1]
    local bt = b[1]
    if not (bt == 'real' or bt == 'integer') then
        return ps_error('typecheck')
    end
    if not (at == 'real' or at == 'integer') then
        return ps_error('typecheck')
    end
    local position = gsstate.position
    local path     = gsstate.path
    local length   = #path
    if #position == 0 then
        return ps_error('nocurrentpoint')
    end
    local x, y = do_transform(gsstate.matrix, a[4], b[4])
    gsstate.position = { x, y }
    path[length+1] = { "lineto", x, y }
    return true
end

function operators.rlineto()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local at = a[1]
    local bt = b[1]
    if not (bt == 'real' or bt == 'integer') then
        return ps_error('typecheck')
    end
    if not (at == 'real' or at == 'integer') then
        return ps_error('typecheck')
    end
    local position = gsstate.position
    local path     = gsstate.path
    local length   = #path
    if #position == 0 then
        return ps_error('nocurrentpoint')
    end
    local x, y = do_transform(gsstate.matrix, a[4], b[4])
    x = position[1] + x
    y = position[2] + y
    position[1] = x
    position[2] = y
    path[length+1] = { "lineto", x, y }
    return true
end

local function arc_to_curve (x, y, r, aa, theta)
    local th = rad(theta/2.0)
    local x0 = cos(th)
    local y0 = sin(th)
    local x1 = (4.0-x0)/3.0
    local y1 = ((1.0-x0)*(3.0-x0))/(3.0*y0)  -- y0 != 0...
    local x2 =  x1
    local y2 = -y1
 -- local x3 =  x0
 -- local y3 = -y0

    local bezAng  = rad(aa) + th
    local cBezAng = cos(bezAng)
    local sBezAng = sin(bezAng)

    local rx0 = (cBezAng * x0) - (sBezAng * y0)
    local ry0 = (sBezAng * x0) + (cBezAng * y0)
    local rx1 = (cBezAng * x1) - (sBezAng * y1)
    local ry1 = (sBezAng * x1) + (cBezAng * y1)
    local rx2 = (cBezAng * x2) - (sBezAng * y2)
    local ry2 = (sBezAng * x2) + (cBezAng * y2)
 -- local rx3 = (cBezAng * x3) - (sBezAng * y3)
 -- local ry3 = (sBezAng * x3) + (cBezAng * y3)

    local px0 = x + r*rx0
    local py0 = y + r*ry0
    local px1 = x + r*rx1
    local py1 = y + r*ry1
    local px2 = x + r*rx2
    local py2 = y + r*ry2
 -- local px3 = x + r*rx3
 -- local py3 = y + r*ry3

    return px2, py2, px1, py1, px0, py0 -- no px3, py3
end

local function arc_start(x,y,r,aa)
    local x3 = 1
    local y3 = 0
    local bezAng  = rad(aa)
    local cBezAng = cos(bezAng)
    local sBezAng = sin(bezAng)
    local rx3 = (cBezAng * x3) - (sBezAng * y3)
    local ry3 = (sBezAng * x3) + (cBezAng * y3)
    local px3 = x + r*rx3
    local py3 = y + r*ry3
    return px3, py3
end

local function do_arc(matrix,path,x,y,r,aa,ab)
    local endx, endy
    local segments = floor((ab-aa+44.999999999)/45)
    if segments == 0 then
        return do_transform(gsstate.matrix, x,y)
    end
    local theta = (ab-aa) / segments
    while segments>0 do
        local x1, y1, x2, y2, x3, y3  = arc_to_curve(x,y,r,aa,theta)
        local px2, py2 = do_transform(matrix,x2,y2)
        local px1, py1 = do_transform(matrix,x1,y1)
        endx, endy = do_transform(matrix, x3,y3)
        path[#path+1] = { "curveto", px1, py1, px2, py2, endx, endy }
        segments = segments - 1
        aa = aa + theta
    end
    return endx, endy
end

local function do_arcn(matrix,path,x,y,r,aa,ab)
    local endx, endy
    local segments = floor((aa-ab+44.999999999)/45)
    if segments == 0 then
        return do_transform(matrix, x,y)
    end
    local theta = (aa-ab) / segments
    while segments > 0 do
        local x1, y1, x2, y2, x3, y3 = arc_to_curve(x,y,r,aa,-theta)
        local px1, py1 = do_transform(matrix,x1,y1)
        local px2, py2 = do_transform(matrix,x2,y2)
        endx, endy = do_transform(matrix,x3,y3)
        path[#path+1] = { "curveto", px1 , py1 , px2 , py2 , endx , endy  }
        segments = segments - 1
        aa = aa - theta
    end
    return endx, endy
end

local function commonarc(action)
    local e = pop_opstack()
    local d = pop_opstack()
    local c = pop_opstack()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, tb, tc, td, te = a[1], b[1], c[1], d[1], e[1], f[1]
    if not (ta == 'real' or ta == 'integer') then return ps_error('typecheck') end
    if not (tb == 'real' or tb == 'integer') then return ps_error('typecheck') end
    if not (tc == 'real' or tc == 'integer') then return ps_error('typecheck') end
    if not (td == 'real' or td == 'integer') then return ps_error('typecheck') end
    if not (te == 'real' or te == 'integer') then return ps_error('typecheck') end
    local position = gsstate.position
    local path     = gsstate.path
    local matrix   = gsstate.matrix
    local vd = d[4]
    local ve = e[4]
    if vd < 0 or ve < 0 or vd > 360 or ve > 360 or (vd-ve) <= 0 then
        return ps_error('limitcheck')
    end
    local r = c[4]
    if r == 0 then
        ps_error('limitcheck')
    end
    local x = a[4]
    local y = b[4]
    local x0, y0 = arc_start(x,y,r,vd) -- find starting points
    local startx, starty = do_transform(matrix,x0,y0)
    path[#path+1] = { #position == 2 and "lineto" or "moveto", startx, starty }
    position[1], position[2] = action(matrix,path,x,y,r,vd,ve)
    return true
end

function operators.arc()
    commonarc(do_arc)
end

function operators.arcn()
    commonarc(do_arcn)
end

local function vlength (a,b)
    return sqrt(a^2+b^2)
end

local function vscal_ (a,b,c)
    return a*b, a*c
end

-- this is of_the_way

local function between (dist, pa, pb)
    local pa1, pa2 = pa[1], pa[2]
    local pb1, pb2 = pb[1], pb[2]
    return {
        pa1 + dist * (pb1 - pa1),
        pa2 + dist * (pb2 - pa2),
    }
end

local function sign (a)
    return a < 0 and -1 or 1
end

local function do_arcto(x,y,r) -- todo: check with original
    local h  = gsstate.position
    local tx1, tx2, ty1, ty2
    local c1, c2
    local x1, x2 = x[1], x[2]
    local y1, y2 = y[1], y[2]
    local h1, h2 = h[1], h[2]
    local ux, uy = x1 - h1, x2 - h2
    local vx, vy = y1 - x1, y2 - x2
    local lx, ly = vlength(ux,uy), vlength(vx,vy)
    local sx, sy = ux*vy - uy*vx, ux*vx + uy*vy
    if sx == 0 and sy == 0 then
        sx = r
        sy = 0
    else
        sx = r
        sy = atan2(sx,sy)
    end
    local a_arcto = sx*tan(abs(sy)/2)
    if sx*sy*lx*ly == 0 then
        tx1 = x1
        tx2 = x2
        ty1 = x1
        ty2 = x2
        c1  = x1
        c2  = x2
    else
        local tx = between(a_arcto/lx,x,h)
        local ty = between(a_arcto/ly,x,y)
        local cc, dd = vscal_(sign(sy)*sx/lx,-uy,ux)
        tx1 = tx[1]
        tx2 = tx[2]
        ty1 = ty[1]
        ty2 = ty[2]
        c1  = tx1 + cc
        c2  = tx2 + dd
    end
    -- now tx is the starting point, ty is the endpoint,
    -- c is the center of the circle. find the two angles
    local anga = deg(atan2(tx2-c2,tx1-c1)) -- todo, -90 is wrong
    local angb = deg(atan2(ty2-c2,ty1-c1)) -- todo, -90 is wrong
    return c1, c2, r, anga, angb, tx1, tx2, ty1, ty2
end

function operators.arcto()
    local e = pop_opstack()
    local d = pop_opstack()
    local c = pop_opstack()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, tb, tc, td, te = a[1], b[2], c[1], d[1], e[1]
    if not (ta == 'real' or ta == 'integer') then
        return ps_error('typecheck')
    end
    if not (tb == 'real' or tb == 'integer') then
        return ps_error('typecheck')
    end
    if not (tc == 'real' or tc == 'integer') then
        return ps_error('typecheck')
    end
    if not (td == 'real' or td == 'integer') then
        return ps_error('typecheck')
    end
    if not (te == 'real' or te == 'integer') then
        return ps_error('typecheck')
    end
    local x1, y1, x2, y2, r = a[4], b[4], c[4], d[4], e[4]
    local position = gsstate.position
    local path     = gsstate.path
    if #position == 0 then
        return ps_error('nocurrentpoint')
    end
    local x, y, r, anga, angb, tx1, tx2, ty1, ty2 = do_arcto({x1,y1},{x2, y2},r)
    local vx, vy = do_transform(gsstate.matrix,tx1,tx2)
    path[#path+1] = { "lineto", vx, vy }
    if anga == angb then
        -- do nothing
    elseif anga > angb then
        position[1], position[2] = do_arcn(x,y,r,anga,angb)
    else
        position[1], position[2] = do_arc (x,y,r,anga,angb)
    end
    push_opstack { 'real', 'unlimited', 'literal', tx1 }
    push_opstack { 'real', 'unlimited', 'literal', tx2 }
    push_opstack { 'real', 'unlimited', 'literal', ty1 }
    push_opstack { 'real', 'unlimited', 'literal', ty2 }
end

function operators.curveto()
    local f = pop_opstack()
    local e = pop_opstack()
    local d = pop_opstack()
    local c = pop_opstack()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local f1 = f[1] if not (f1 == 'real' or f1 == 'integer') then return ps_error('typecheck') end
    local e1 = e[1] if not (e1 == 'real' or e1 == 'integer') then return ps_error('typecheck') end
    local d1 = d[1] if not (d1 == 'real' or d1 == 'integer') then return ps_error('typecheck') end
    local c1 = c[1] if not (c1 == 'real' or c1 == 'integer') then return ps_error('typecheck') end
    local b1 = b[1] if not (b1 == 'real' or b1 == 'integer') then return ps_error('typecheck') end
    local a1 = a[1] if not (a1 == 'real' or a1 == 'integer') then return ps_error('typecheck') end
    --
    if #gsstate.position == 0 then
        return ps_error('nocurrentpoint')
    end
    --
    local matrix = gsstate.matrix
    local x, y   = do_transform(matrix, e[4], f[4])
    local ax, ay = do_transform(matrix, a[4], b[4])
    local bx, by = do_transform(matrix, c[4], d[4])
    gsstate.position = { x, y }
    --
    local path = gsstate.path
    path[#path+1] = { "curveto", ax, ay, bx, by, x, y }
    return true
end

function operators.rcurveto()
    local f = pop_opstack()
    local e = pop_opstack()
    local d = pop_opstack()
    local c = pop_opstack()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ft if not (ft == 'real' or ft == 'integer') then return ps_error('typecheck') end
    local et if not (et == 'real' or et == 'integer') then return ps_error('typecheck') end
    local dt if not (dt == 'real' or dt == 'integer') then return ps_error('typecheck') end
    local ct if not (ct == 'real' or ct == 'integer') then return ps_error('typecheck') end
    local bt if not (bt == 'real' or bt == 'integer') then return ps_error('typecheck') end
    local at if not (at == 'real' or at == 'integer') then return ps_error('typecheck') end
    local position = gsstate.position
    local path     = gsstate.path
    if #position == 0 then
        return ps_error('nocurrentpoint')
    end
    local x,   y = do_transform(matrix, e[4], f[4])
    local ax, ay = do_transform(matrix, a[4], b[4])
    local bx, by = do_transform(matrix, c[4], d[4])
    local px = position[1] + x
    local py = position[2] + y
    path[#path+1] = {
        "curveto",
        position[1] + ax,
        position[2] + ay,
        position[1] + bx,
        position[2] + by,
        px,
        py
    }
    position[1] = px
    position[2] = py
    return true
end

function operators.closepath()
    local path    = gsstate.path
    local length  = #path
    if length > 0 and path[length][1] ~= 'closepath' then
        local m = path[1]
        local a = m[2]
        local b = m[3]
        local x, y = do_transform(gsstate.matrix, a, b)
        gsstate.position = { x, y }
        path[length+1] = { "closepath", x, y }
    end
    return true
end

-- finds a point on a bezier curve
-- P(x,y) = (1-t)^3*(x0,y0)+3*(1-t)^2*t*(x1,y1)+3*(1-t)*t^2*(x2,y2)+t^3*(x3,y3)

local function bezier_at(t,x0,y0,x1,y1,x2,y2,x3,y3)
   local v = (1 - t)
   local x = (v^3)*x0 + 3*(v^2)*t*x1 + 3*v*(t^2)*x2 + (t^3)*x3
   local y = (v^3)*y0 + 3*(v^2)*t*y1 + 3*v*(t^2)*y2 + (t^3)*y3
   return x, y
end

local delta = 10 -- 100

local function good_enough (flatness,c,ct1,ct2,l)
    local c0x, c0y, c1x, c1y, c2x, c2y, c3x, c3y = c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8]
    local l0x, l0y, l1x, l1y = l[1], l[2], l[3], l[4]
    local t = 0
    while t < delta do
        local td = t/delta
        local bx, by = bezier_at(ct1+(ct2-ct1)*td,c0x,c0y,c1x,c1y,c2x,c2y,c3x,c3y)
        local lx, ly = (1-td)*l0x + td*l1x, (1-td)*l0y + td*l1y
        local dist = vlength(bx-lx,by-ly)
        if dist > flatness then
            return false
        end
        t = t + 1
    end
    return true
end

-- argument d is recursion depth, 10 levels should be enough to reach a conclusion
-- (and already generates over 1000 lineto's in the worst case)

local function splitter (flatness,p,d,c,ct1,ct2,l)
    local c0x, c0y, c1x, c1y, c2x, c2y, c3x, c3y = c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8]
    d = d + 1
    local r = good_enough(flatness,c,ct1,ct1+ct2,l)
    if r or d > 10 then
        p[#p + 1] = { 'lineto', l[3], l[4] }
    else
        local ct22 = ct2/2
        local l2x, l2y = bezier_at(ct1+ct22,c0x,c0y,c1x,c1y,c2x,c2y,c3x,c3y)
        local l1 = { l[1], l[2], l2x, l2y }
        local l2 = { l2x, l2y, l[3], l[4] }
        splitter(flatness,p,d,c,ct1,ct22,l1)
        splitter(flatness,p,d,c,ct1+ct22,ct22,l2)
    end
end

local function flattencurve( homex, homey, curve, flatness)
    local p = { }
    local c6 = curve[6]
    local c7 = curve[7]
    local thecurve = { homex, homey, curve[2], curve[3], curve[4], curve[5], c6, c7 }
    local theline  = { homex, homey, c6, c7 }
    splitter(flatness, p, 0, thecurve, 0, 1, theline)
    return p
end

local function do_flattenpath (p, flatness)
    local x, y
    local px = { }
    local nx = 0
    -- we don't care about differences less than a a permille of a point, ever
    if flatness < 0.001  then
        flatness = 0.001
    end
    if p then
        for i=1,#p do
            local v = p[i]
            local t = v[1]
            if t == "curveto" then
                local pxl = flattencurve(x,y,v,flatness)
                for i=1,#pxl do
                    nx = nx + 1 ; px[nx] = pxl[i]
                end
                x, y = v[6], v[7]
            elseif t == "lineto" or t == "moveto" then
                x, y = v[2], v[3]
                nx = nx + 1 ; px[nx] = v
            else
                nx = nx + 1 ; px[nx] = v
            end
        end
    end
    return px
end

function operators.flattenpath()
    gsstate.path = do_flattenpath(gsstate.path,gsstate.flatness)
end

function operators.clippath()
    gsstate.path = gsstate.clip
    return true
end

function operators.initclip()
    device.initclip()
    return true
end

function operators.eofill()
    local color    = gsstate.color
    local thecolor = color[color.type]
    if type(thecolor) == "table" then
        thecolor = { unpack(thecolor) }
    end
    currentpage[#currentpage+1] = {
        type      = 'eofill',
        path      = gsstate.path,
        colortype = color.type,
        color     = thecolor,
    }
    operators.newpath()
    return true
end

-- todo: this only fixes the output, not the actual clipping path
-- in the gsstate !

function operators.clip()
    currentpage[#currentpage+1] = {
        type = 'clip',
        path = gsstate.path,
    }
    return true
end

-- todo: this only fixes the output, not the actual clipping path
-- in the gsstate !

function operators.eoclip()
    currentpage[#currentpage+1] = {
        type = 'eoclip',
        path = gsstate.path,
    }
    return true
end

-- Painting operators
--
-- +erasepage +fill +eofill +stroke -image -imagemask

-- general graphics todo: transfer function, flatness

function operators.erasepage()
    currentpage = { }
    return true
end

function operators.stroke()
    local color       = gsstate.color
    local ctype       = color.type
    local thecolor    = color[ctype]
 -- if type(thecolor) == "table" then
 --     thecolor = { unpack(thecolor) }
 -- end
    currentpage[#currentpage+1] = {
        type        = 'stroke',
        path        = gsstate.path,
        colortype   = ctype,
        color       = thecolor,
        miterlimit  = gsstate.miterlimit,
        linewidth   = gsstate.linewidth,
        linecap     = gsstate.linecap,
        linejoin    = gsstate.linejoin,
     -- dashpattern = { unpack (gsstate.dashpattern) }, -- unpack? we don't manipulate
        dashpattern = gsstate.dashpattern,
        dashoffset  = gsstate.dashoffset
    }
    operators.newpath()
    return true
end

function operators.fill()
    local color       = gsstate.color
    local ctype       = color.type
    local thecolor    = color[ctype]
 -- if type(thecolor) == "table" then
 --     thecolor = { unpack(thecolor) }
 -- end
    currentpage[#currentpage+1] = {
        type      = 'fill',
        path      = gsstate.path,
        colortype = ctype,
        color     = thecolor,
    }
    operators.newpath()
    return true
end

-- Device setup and output operators
--
-- +showpage +copypage +banddevice +framedevice +nulldevice +renderbands

-- will be replaced by the argument of 'new'

-- this reports the bounding box of a page

-- todo: linewidth for strokes
-- todo: clips
-- todo: strings (width&height)

local calculatebox = false

initializers[#initializers+1] = function()
    calculatebox = true
end

local function boundingbox(page)

    local bounding = specials.boundingbox
    if bounding and not calculatebox then
        return unpack(bounding)
    end

    local minx, miny, maxx, maxy
    local startx, starty
    local linewidth

    local function update_bbox (x,y)
        if not minx then
            minx = x
            miny = y
            maxx = x
            maxy = y
        end
        if linewidth then
            local xx = x + linewidth/2
            if xx > maxx then maxx = xx elseif xx < minx then minx = xx end
            local xx = x - linewidth/2
            if xx > maxx then maxx = xx elseif xx < minx then minx = xx end
            local yy = y + linewidth/2
            if yy > maxy then maxy = yy elseif yy < miny then miny = yy end
            local yy = y - linewidth/2
            if yy > maxy then maxy = yy elseif yy < miny then miny = yy end
        else
            if x > maxx then maxx = x elseif x < minx then minx = x end
            if y > maxy then maxy = y elseif y < miny then miny = y end
        end
        startx, starty = x, y
    end

    for i=1,#page do
        local object = page[i]
        local p = do_flattenpath(object.path,0.5)
        linewidth = object.type == "stroke" and object.linewidth
        for i=1,#p do
            local segment = p[i]
            local type = segment[1]
            if type == "lineto" then
                if startx then
                    update_bbox(startx,starty)
                end
                update_bbox(segment[2],segment[3])
            elseif type == "curveto" then
                if startx then
                    update_bbox(startx,starty)
                end
                update_bbox(segment[6],segment[7])
            elseif type == "moveto" then
                startx, starty = segment[2], segment[3]
            end
        end
    end
    if minx then
        return minx, miny, maxx, maxy
    else
        return 0, 0, 0, 0
    end
end

------------------------------------------------------------------

local function boundingbox (page)

    local bounding = specials.boundingbox
    if bounding and not calculatebox then
        return unpack(bounding)
    end

    local minx, miny, maxx, maxy
    local startx, starty
    local linewidth

    local function update_bbox (x,y)
        if not minx then
            minx = x
            miny = y
            maxx = x
            maxy = y
        end
        if linewidth then
            local xx = x + linewidth/2
            if xx > maxx then
                maxx = xx
            elseif xx < minx then
                minx = xx
            end
            local xx = x - linewidth/2
            if xx > maxx then
                maxx = xx
            elseif xx < minx then
                minx = xx
            end
            local yy = y + linewidth/2
            if yy > maxy then
                maxy = yy
            elseif yy < miny then
                miny = yy
            end
            local yy = y - linewidth/2
            if yy > maxy then
                maxy = yy
            elseif yy < miny then
                miny = yy
            end
        else
            if x > maxx then
                maxx = x
            elseif x < minx then
                minx = x
            end
            if y > maxy then
                maxy = y
            elseif y < miny then
                miny = y
            end
        end
        startx, starty = x, y
    end

    local delta = 10 -- 100

    local function good_enough (ct1,ct2, c0x, c0y, c1x, c1y, c2x, c2y, c3x, c3y, l0x, l0y, l1x, l1y)
        local t = 0
        while t < delta do
            local td = t/delta
            local bx, by = bezier_at(ct1+(ct2-ct1)*td,c0x,c0y,c1x,c1y,c2x,c2y,c3x,c3y)
            local lx, ly = (1-td)*l0x + td*l1x, (1-td)*l0y + td*l1y
            local dist = sqrt((bx-lx)^2+(by-ly)^2) -- vlength(bx-lx,by-ly)
            if dist > 0.5 then
                return false
            end
            t = t + 1
        end
        return true
    end

    local function splitter (d,ct1,ct2, c0x, c0y, c1x, c1y, c2x, c2y, c3x, c3y, l0x, l0y, l1x, l1y)
        d = d + 1
        local r = good_enough(ct1,ct1+ct2, c0x, c0y, c1x, c1y, c2x, c2y, c3x, c3y, l0x, l0y, l1x, l1y)
        if r or d > 10 then
            if startx then
                update_bbox(l1x, l1y)
            end
        else
            local ct22 = ct2/2
            local l2x, l2y = bezier_at(ct1+ct22,c0x,c0y,c1x,c1y,c2x,c2y,c3x,c3y)
            splitter(d,ct1,     ct22, c0x, c0y, c1x, c1y, c2x, c2y, c3x, c3y, l0x, l0y, l2x, l2y)
            splitter(d,ct1+ct22,ct22, c0x, c0y, c1x, c1y, c2x, c2y, c3x, c3y, l2x, l2y, l1x, l1y)
        end
    end

    for i=1,#page do
        local object = page[i]
        local p = object.path
        linewidth = object.type == "stroke" and object.linewidth
        for i=1,#p do
            local segment = p[i]
            local type = segment[1]
            if type == "lineto" then
                if startx then
                    update_bbox(startx,starty)
                end
                update_bbox(segment[2],segment[3])
            elseif type == "curveto" then
                local c6 = segment[6]
                local c7 = segment[7]
                splitter(0, 0, 1, startx, starty, segment[2], segment[3], segment[4], segment[5], c6, c7, startx, starty, c6, c7)
            elseif type == "moveto" then
                startx, starty = segment[2], segment[3]
            end
        end
    end
    if minx then
        return minx, miny, maxx, maxy
    else
        return 0, 0, 0, 0
    end
end

------------------------------------------------------------------

-- most time is spend in calculating the boundingbox

-- NULL output

devices.null = {
    initgraphics = function() gsstate.matrix = { 1, 0, 0, 1, 0, 0 } end,
    initclip     = function() gsstate.clip = { } end,
    showpage     = function() return "" end,
}

-- PDF output

local pdf = {
    initgraphics = function() gsstate.matrix = { 1, 0, 0, 1, 0, 0 } end,
    initclip     = function() gsstate.clip = { } end,
 -- startpage    = function(llc,lly,urx,ury) end,
 -- flushpage    = function() end,
 -- stoppage     = function() end,
}

devices.pdf = pdf

function pdf.showpage(page)
    --
    local startpage = pdf.startpage
    local stoppage  = pdf.stoppage
    local flushpage = pdf.flushpage
    local showfont  = pdf.showfont
    --
    if not flushpage then
        return
    end
    --
    if startpage then
        startpage(boundingbox(page))
    end
    --
    local t = { "q" }
    local n = 1
    local g_colortype   = "notacolor"
    local g_color       = ""
    local g_miterlimit  = -1
    local g_linejoin    = -1
    local g_linecap     = -1
    local g_linewidth   = -1
    local g_dashpattern = nil
    local g_dashoffset  = -1
    local flush = devices.pdf.flush
    for i=1,#page do
        local object = page[i]
        local path   = object.path
        local otyp   = object.type
        if otype ~= "clip" and otype ~= "eoclip" then
            local colortype = object.colortype
            local color     = object.color
            if colortype == "gray" then
                local v = formatters["%f g %f G"](color,color)
                if g_color ~= v then
                    g_colortype = "gray"
                    g_color     = v
                    n = n + 1 ; t[n] = v
                end
            elseif colortype == "rgb" then
                local r, g, b = color[1], color[2], color[3]
                local v = formatters["%f %f %f rg %f %f %f RG"](r,g,b,r,g,b)
                if g_color ~= v then
                    g_colortype = "rgb"
                    g_color     = v
                    n = n + 1 ; t[n] = v
                end
            elseif colortype == "cmyk" then
                local c, m, y, k = color[1], color[2], color[3], color[4]
                local v = formatters["%f %f %f %f k %f %f %f %f K"](c,m,y,k,c,m,y,k)
                if g_color ~= v then
                    g_colortype = "cmyk"
                    g_color     = v
                    n = n + 1 ; t[n] = v
                end
            elseif colortype == "hsb" then
                local r, g, b = hsv_to_rgb(color[1],color[2],color[3])
                local v = formatters["%f %f %f rg %f %f %f RG"](r,g,b,r,g,b)
                if g_color ~= v then
                    g_colortype = "rgb"
                    g_color     = v
                    n = n + 1 ; t[n] = v
                end
            end
        end
        if otype == "stroke" then
            local miterlimit = object.miterlimit
            if g_miterlimit ~= miterlimit then
                g_miterlimit = miterlimit
                n = n + 1 ; t[n] = formatters["%f M"](miterlimit)
            end
            local linejoin = object.linejoin
            if g_linejoin ~= linejoin then
                g_linejoin = linejoin
                n = n + 1 ; t[n] = formatters["%d j"](linejoin)
            end
            local linecap = object.linecap
            if g_linecap ~= linecap then
                g_linecap = linecap
                n = n + 1 ; t[n] = formatters["%d J"](linecap)
            end
            local linewidth = object.linewidth
            if g_linewidth ~= linewidth then
                g_linewidth = linewidth
                n = n + 1 ; t[n] = formatters["%f w"](linewidth)
            end
            local dashpattern = object.dashpattern
            local dashoffset  = object.dashoffset
            if g_dashpattern ~= dashpattern or g_dashoffset ~= dashoffset then
                g_dashpattern = dashpattern
                g_dashoffset  = dashoffset
                local l = #dashpattern
                if l == 0 then
                    n = n + 1 ; t[n] = "[] 0 d"
                else
                    n = n + 1 ; t[n] = formatters["[% t] %d d"](dashpattern,dashoffset)
                end
            end
        end
        if path then
            for i=1,#path do
                local segment = path[i]
                local styp    = segment[1]
                if styp == "moveto" then
                    n = n + 1 ; t[n] = formatters["%f %f m"](segment[2],segment[3])
                elseif styp == "lineto" then
                    n = n + 1 ; t[n] = formatters["%f %f l"](segment[2],segment[3])
                elseif styp == "curveto" then
                    n = n + 1 ; t[n] = formatters["%f %f %f %f %f %f c"](segment[2],segment[3],segment[4],segment[5],segment[6],segment[7])
                elseif styp == "closepath" then
                    n = n + 1 ; t[n] = "h"
                else
                    report("unknown path segment type %a",styp)
                end
            end
        end
        if otyp == "stroke" then
            n = n + 1 ; t[n] = "S"
        elseif otyp == "fill" then
            n = n + 1 ; t[n] = "f"
        elseif otyp == "eofill" then
            n = n + 1 ; t[n] = "f*"
        elseif otyp == "clip" then
            n = n + 1 ; t[n] = "W n"
        elseif otyp == "eoclip" then
            n = n + 1 ; t[n] = "W* n"
        elseif otyp == "show" then
            if showfont then
                if n > 0 then
                    flushpage(concat(t,"\n"))
                    n = 0 ; t = { }
                end
                showfont(object)
            end
        else
            -- nothing to do
        end
    end
    n = n + 1 ; t[n] = "Q"
    flushpage(concat(t,"\n"))
    --
    if startpage then
        stoppage()
    end
end

function operators.showpage()
    local copies = lookup("#copies")
    if copies and copies[1] == 'integer' and copies[4] >= 1 then
        local amount = floor(copies[4])
        local render = device.showpage
        if render then
            for i=1,amount do
                render(currentpage)
            end
        end
    end
    operators.erasepage()
    operators.initgraphics()
    return true
end

function operators.copypage()
    local render = device.showpage
    if render then
        render(currentpage)
    end
    return true
end

function operators.banddevice()
    local d = pop_opstack()
    local c = pop_opstack()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, tb, tc, td = a[1], b[1], c[1], d[1]
    if not (ta == 'array' and a[5] == 6) then
        return ps_error('typecheck')
    end
    if not (td == 'array' and d[3] == 'executable') then
        return ps_error('typecheck')
    end
    if not (tb == 'real'  or tb == 'integer') then
        return ps_error('typecheck')
    end
    if not (tc == 'real'  or tc == 'integer') then
        return ps_error('typecheck')
    end
    local dev = device.banddevice
    if dev then
        dev(a,b,c,d)
    else
        return ps_error('undefined') -- fixed
    end
    return true
end

function operators.renderbands()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if not (a[1] == 'array' and a[3] == 'executable') then
        return ps_error('typecheck')
    end
    local dev = device.renderbands
    if dev then
        dev(d)
    else
        return ps_error('undefined')
    end
    return true
end

function operators.framedevice()
    local d = pop_opstack()
    local c = pop_opstack()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    local ta, tb, tc, td = a[1], b[1], c[1], d[1]
    if not (ta == 'array' and a[5] == 6) then
        return ps_error('typecheck')
    end
    if not (tb == 'real' or tb == 'integer') then
        return ps_error('typecheck')
    end
    if not (tc == 'real' or tc == 'integer') then
        return ps_error('typecheck')
    end
    if not (td == 'array' and d[3] == 'executable') then
        return ps_error('typecheck')
    end
    local dev = device.framedevice
    if dev then
        dev(a,b,c,d)
    else
        return ps_error('undefined')
    end
    return true
end

function operators.nulldevice()
    gsstate.device = "null"
    operators.initgraphics()
    return true
end

-- Character and font operators
--
-- +definefont *findfont +scalefont +makefont +setfont +currentfont +show -ashow -widthshow
-- -awidthshow +kshow -stringwidth ^FontDirectory ^StandardEncoding

-- Fonts are a bit special because it is needed to cooperate with the enclosing PDF document.

local FontDirectory

initializers[#initializers+1] = function(reset)
    if reset then
        FontDirectory = nil
    else
        FontDirectory = add_VM {
            access  = 'unlimited',
            size    = 0,
            maxsize = 5000,
            dict    = { },
        }
    end
end

-- loading actual fonts is a worryingly slow exercise

local fontmap

initializers[#initializers+1] = function()
    if reset then
        fontmap = nil
    else
        fontmap = {
            ['Courier-Bold']          = 'NimbusMonL-Bold.ps',
            ['Courier-BoldOblique']   = 'NimbusMonL-BoldObli.ps',
            ['Courier']               = 'NimbusMonL-Regu.ps',
            ['Courier-Oblique']       = 'NimbusMonL-ReguObli.ps',
            ['Times-Bold']            = 'NimbusRomNo9L-Medi.ps',
            ['Times-BoldItalic']      = 'NimbusRomNo9L-MediItal.ps',
            ['Times-Roman']           = 'NimbusRomNo9L-Regu.ps',
            ['Times-Italic']          = 'NimbusRomNo9L-ReguItal.ps',
            ['Helvetica-Bold']        = 'NimbusSanL-Bold.ps',
            ['Helvetica-BoldOblique'] = 'NimbusSanL-BoldItal.ps',
            ['Helvetica']             = 'NimbusSanL-Regu.ps',
            ['Helvetica-Oblique']     = 'NimbusSanL-ReguItal.ps',
            ['Symbol']                = 'StandardSymL.ps',
        }
    end
end

-- this can be overwritten by the user

local function findfont(fontname)
    return fontmap[fontname]
end

-- tests required keys in a font dict

local function checkfont(f)
    -- FontMatrix
    local matrix = f['FontMatrix']
    if not matrix or matrix[1] ~= 'array' or matrix[5] ~= 6 then
        return false
    end
    local thearray = get_VM(matrix[4])
    for i=1,#thearray do
        local v = thearray[i]
        local tv = v[1]
        if not (tv == 'real' or tv == 'integer') then
            return false
        end
    end
    -- FontType
    local ftype = f['FontType']
    if not ftype or ftype[1] ~= 'integer' then
        return false
    end
    -- FontBBox
    local bbox = f['FontBBox']
    -- do not test [5] here, because it can be '1' (executable array)
    if not bbox or bbox[1] ~= 'array' or bbox[6] ~= 4 then
        return false
    end
    local thearray = get_VM(bbox[4])
    for i=1,#thearray do
        local v = thearray[i]
        local tv = v[1]
        if not (tv == 'real' or tv == 'integer') then
            return false
        end
    end
    -- Encoding
    local bbox = f['Encoding']
    if not bbox or bbox[1] ~= 'array' or bbox[5] ~= 256 then
        return false
    end
    local thearray = get_VM(bbox[4])
    for i=1,#thearray do
        local v = thearray[i]
        local tv = v[1]
        if tv[1] ~= 'name' then
            return false
        end
    end
    return true
end

-- objects of type font as essentially the same as objects of type dict

function operators.definefont()
    local b = pop_opstack()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if b[1] ~= 'dict' then
        return ps_error('typecheck')
    end
    -- force keys to be names
    if a[1] ~= 'name' then
        return ps_error('typecheck')
    end
    local fontdict = get_VM(b[4])
    if not checkfont(fontdict.dict) then
        return ps_error('invalidfont')
    end
    -- check that a FID will fit
    if fontdict.size == fontdict.maxsize then
        return ps_error('invalidfont')
    end
    fontdict.dict['FID'] = {'font', 'executable', 'literal', b[4]}
    fontdict.size = fontdict.size + 1
    fontdict.access = 'read-only'
    local dict = get_VM(FontDirectory)
    local key  = get_VM(a[4])
    if not dict.dict[key] and dict.size == dict.maxsize then
        -- return ps_error('dictfull') -- level 1 only
    end
    if not dict.dict[key] then
        dict.size = dict.size + 1
    end
    dict.dict[key] = fontdict.dict['FID']
    push_opstack(b)
    return true
end

function operators.findfont()
    local a = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if a[1] ~= 'name' then
        return ps_error('typecheck')
    end
    local fontdict = get_VM(FontDirectory)
    local key      = get_VM(a[4])
    local dict     = dict.dict
    if not dict[key] then
        fname = findfont(key)
        if not fname then
            return ps_error('invalidfont')
        end
        local oldfontkeys = { }
        for k, v in next, dict do
            oldfontkeys[i] = 1
        end
        report("loading font file %a",fname)
        local theopstack = opstackptr
        local run = formatters['/eexec {pop} def (%s) run'](fname)
        push_execstack { '.stopped', 'unlimited', 'literal', false }
        local curstack = execstackptr
        push_execstack { 'string', 'unlimited', 'executable', add_VM(run), 1, #run }
        while curstack < execstackptr do
            do_exec()
        end
        if execstack[execstackptr][1] == '.stopped' then
            pop_execstack()
        end
        opstackptr = theopstack
        local fkey, ftab
        for k, v in next, dict do
            if not oldfontkeys[k] then
                -- this is the new dict
                fkey = k
                ftab = v
                break
            end
        end
        if not fkey then
            return ps_error('invalidfont')
        end
        dict[key] = ftab -- set up the user requested name as well
    end
    push_opstack(dict[key])
    return true
end

local function pushscaledcopy(fontdict,matrix)
    local olddict  = fontdict.dict
    if not checkfont(olddict) then
        return ps_error('invalidfont')
    end
    local newdict = { }
    local oldsize = fontdict.size
    local newfontdict = {
        dict    = newdict,
        access  = 'read-only',
        size    = oldsize,
        maxsize = oldsize,
    }
    for k, v in next, olddict do
        if k == "FontMatrix" then
            local oldmatrix = get_VM(v[4])
            local old = {
                oldmatrix[1][4],
                oldmatrix[2][4],
                oldmatrix[3][4],
                oldmatrix[4][4],
                oldmatrix[5][4],
                oldmatrix[6][4],
            }
            local c = do_concat(old,matrix)
            local new = {
                { 'real', 'unlimited', 'literal', c[1] },
                { 'real', 'unlimited', 'literal', c[2] },
                { 'real', 'unlimited', 'literal', c[3] },
                { 'real', 'unlimited', 'literal', c[4] },
                { 'real', 'unlimited', 'literal', c[5] },
                { 'real', 'unlimited', 'literal', c[6] }
             }
            newdict[k] = { 'array', 'unlimited', 'literal', add_VM(new), 6, 6 }
        elseif k == "FID" then
            -- updated later
        else
            newfontdict.dict[k] = v
        end
    end
    local f = add_VM(newfontdict)
    newdict['FID'] = { 'font', 'read-only', 'literal', f }
    push_opstack { 'font', 'read-only', 'literal', f } -- share ?
    return true
end

function operators.scalefont()
    local s = pop_opstack()
    local b = pop_opstack()
    if not b then
        return ps_error('stackunderflow')
    end
    if b[1] ~= 'font' then
        return ps_error('typecheck')
    end
    if not (s[1] == 'integer' or s[1] == 'real') then
        return ps_error('typecheck')
    end
    local scals    = s[4]
    local matrix   = { scale, 0, 0, scale, 0, 0 }
    local fontdict = get_VM(b[4])
    return pushscaledcopy(fontdict,matrix)
end

function operators.makefont()
    local s = pop_opstack()
    local b = pop_opstack()
    if not b then
        return ps_error('stackunderflow')
    end
    if b[1] ~= 'font' then
        return ps_error('typecheck')
    end
    if s[1] ~= 'array' then
        return ps_error('typecheck')
    end
    if s[6] ~= 6 then
        return ps_error('rangecheck')
    end
    local matrix = { }
    local array  = get_VM(s[4])
    for i=1,#array do
        local v = array[i]
        local tv = v[1]
        if not (tv == 'real' or tv == 'integer') then
            return ps_error('typecheck')
        end
        matrix[i] = v[4]
    end
    local fontdict = get_VM(b[4])
    pushscaledcopy(fontdict,matrix)
    return true
end

function operators.setfont()
    local b = pop_opstack()
    if not b then
        return ps_error('stackunderflow')
    end
    if b[1] ~= 'font' then
        return ps_error('typecheck')
    end
    gsstate.font = b[4]
    return true
end

-- todo: the invalidfont error is temporary. 'start' should set up at least one font in
-- FontDirectory and assing it as the current font

function operators.currentfont()
    if not gsstate.font then
        return ps_error('invalidfont')
    end
    push_opstack {'font', 'read-only', 'literal', gsstate.font }
    return true
end

function do_show(fontdict,s)
    local stringmatrix   = { }
    local truematrix     = { }
    local stringencoding = { }
    --
    local dict           = fontdict.dict
    local fontname       = get_VM(dict['FontName'][4])
    local fontmatrix     = get_VM(dict['FontMatrix'][4])
    local encoding       = get_VM(dict['Encoding'][4])
    local matrix         = gsstate.matrix
    local position       = gsstate.position
    local color          = gsstate.color
    local colortype      = color.type
    local colordata      = color[colortype]
    --
    if fontmatrix then
        for i=1,#fontmatrix do
            stringmatrix[i] = fontmatrix[i][4]
        end
    end
    if matrix then
        for i=1,#matrix do
            truematrix[i] = matrix[i]
        end
    end
    if encoding then
        for i=1,#m do
            stringencoding[i] = get_VM(e[i][4])
        end
    end
    if type(colordata) == "table" then
        colordata = { unpack(colordata) } -- copy
    end
    currentpage[#currentpage+1] = {
      type       = 'show',
      string     = s,
      fontname   = fontname,
      adjust     = nil,
      x          = position[1],
      y          = position[2],
      encoding   = stringencoding,
      fontmatrix = stringmatrix,
      matrix     = truematrix,
      colortype  = colortype,
      color      = colordata,
   }
   -- todo: update currentpoint, needing 'stringwidth'
end

function operators.show()
    local s = pop_opstack()
    if not s then
        return ps_error('stackunderflow')
    end
    if s[1] ~= 'string' then
        return ps_error('typecheck')
    end
    if #gsstate.position == 0 then
        return ps_error('nocurrentpoint')
    end
    if not gsstate.font then
        return ps_error('invalidfont')
    end
    local fontdict = get_VM(gsstate.font)
    if fontdict.access == "noaccess" then
        return ps_error('invalidaccess')
    end
    if not checkfont(fontdict.dict) then
        return ps_error('invalidfont')
    end
    do_show(fontdict,get_VM(s[4]))
end


function operators.kshow()
    local a = pop_opstack()
    local b = pop_opstack()
    if not a then
        return ps_error('stackunderflow')
    end
    if b[1] ~= "array" and b[3] == 'executable' then
        return ps_error('typecheck')
    end
    if b[2] == 'noaccess' then
        return ps_error('invalidaccess')
    end
    if not a[1] == 'string' then
        return ps_error('typecheck')
    end
    if a[2] == "execute-only" or a[2] == 'noaccess' then
        return ps_error('invalidaccess')
    end
    local fontdict = get_VM(gsstate.font)
    if fontdict.access == "noaccess" then
        return ps_error('invalidaccess')
    end
    if #gsstate.position == 0 then
        return ps_error('nocurrentpoint')
    end
    -- ok, that were the errors
    push_execstack { '.exit', 'unlimited', 'literal', false }
    local curstack = execstackptr
    if a[6] == 0 then
        return true
    end
    b[7] = 'i'
    local thestring = get_VM(a[4])
    local v = sub(thestring,1,1)
    thestring = sub(thestring,2,-1)
    do_show(fontdict,v)
    for w in gmatch(thestring,".") do
        if stopped then
            stopped = false
            return false
        end
        push_opstack { 'integer', 'unlimited', 'literal', byte(v) }
        push_opstack { 'integer', 'unlimited', 'literal', byte(w) }
        b[5] = 1
        push_execstack(b)
        while curstack < execstackptr do
            do_exec()
        end
        local entry = execstack[execstackptr]
        if entry[1] == '.exit' and entry[4] == true then
            pop_execstack()
            return true;
        end
        do_show(fontdict,w)
        v = w
    end
    return true
end

local the_standardencoding = {
    '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef',
    '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef',
    '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef',
    '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef',
    '', 'space', 'exclam', 'quotedbl', 'numbersign', 'dollar', 'percent', 'ampersand',
    'quoteright', 'parenleft', 'parenright', 'asterisk', 'plus', 'comma',
    'hyphen', 'period', 'slash', 'zero', 'one', 'two', 'three', 'four',
    'five', 'six', 'seven', 'eight', 'nine', 'colon', 'semicolon', 'less',
    'equal', 'greater', 'question', 'at', 'A', 'B', 'C', 'D', 'E', 'F',
    'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
    'U', 'V', 'W', 'X', 'Y', 'Z', 'bracketleft', 'backslash',
    'bracketright', 'asciicircum', 'underscore', 'quoteleft', 'a', 'b',
    'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p',
    'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'braceleft', 'bar',
    'braceright', 'asciitilde', '.notdef', '.notdef', '.notdef',
    '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef',
    '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef',
    '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef',
    '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef',
    '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef',
    '.notdef', 'exclamdown', 'cent', 'sterling', 'fraction', 'yen',
    'florin', 'section', 'currency', 'quotesingle', 'quotedblleft',
    'guillemotleft', 'guilsinglleft', 'guilsinglright', 'fi', 'fl',
    '.notdef', 'endash', 'dagger', 'daggerdbl', 'periodcentered', '.notdef',
    'paragraph', 'bullet', 'quotesinglbase', 'quotedblbase',
    'quotedblright', 'guillemotright', 'ellipsis', 'perthousand', '.notdef',
    'questiondown', 'grave', 'acute', 'circumflex', 'tilde', 'macron',
    'breve', 'dotaccent', 'dieresis', '.notdef', 'ring', 'cedilla',
    '.notdef', 'hungarumlaut', 'ogonek', 'caron', 'emdash', '.notdef',
    '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef',
    '.notdef', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef',
    '.notdef', '.notdef', '.notdef', 'AE', '.notdef', 'ordfeminine',
    '.notdef', '.notdef', '.notdef', '.notdef', 'Lslash', 'Oslash', 'OE',
    'ordmasculine', '.notdef', '.notdef', '.notdef', '.notdef', '.notdef',
    'ae', '.notdef', '.notdef', '.notdef', 'dotlessi', '.notdef',
    '.notdef', 'lslash', 'oslash', 'oe', 'germandbls', '.notdef',
    '.notdef', '.notdef', '.notdef'
}

local function standardencoding()
    local a = { }
    for i=1,#the_standardencoding do
        a[i] = { 'name', 'unlimited', 'literal', add_VM(the_standardencoding[i]) }
    end
    return a
end

-- Font cache operators
--
-- -cachestatus -setcachedevice -setcharwidth -setcachelimit

-- userdict (initially empty)

local systemdict
local userdict

initializers[#initializers+1] = function(reset)
    if reset then
        systemdict = nil
    else
        dictstackptr = dictstackptr + 1
        dictstack[dictstackptr] = add_VM {
            access  = 'unlimited',
            maxsize = MAX_INTEGER,
            size    = 0,
            dict    = { },
        }
        if directvm then
            systemdict = dictstack[dictstackptr]
        else
            systemdict = dictstackptr
        end
    end
end

initializers[#initializers+1] = function(reset)
    if reset then
        userdict = nil
    else
        dictstackptr = dictstackptr + 1
        dictstack[dictstackptr] = add_VM {
            access  = 'unlimited',
            maxsize = MAX_INTEGER,
            size    = 0,
            dict    = { },
        }
        if directvm then
            userdict = dictstack[dictstackptr]
        else
            userdict = dictstackptr
        end
    end
end

initializers[#initializers+1] = function(reset)
    if reset then
        -- already done
    else
        local dict = {
            ['$error']            = { 'dict',     'unlimited', 'literal',    dicterror },
            ['[']                 = { 'operator', 'unlimited', 'executable', operators.beginarray, '[' },
            [']']                 = { 'operator', 'unlimited', 'executable', operators.endarray, ']' },
         -- ['=']                 = { 'operator', 'unlimited', 'executable', operators.EQ, '=' },
            ['==']                = { 'operator', 'unlimited', 'executable', operators.equal, '==' },
            ['abs']               = { 'operator', 'unlimited', 'executable', operators.abs, 'abs' },
            ['add']               = { 'operator', 'unlimited', 'executable', operators.add, 'add' },
            ['aload']             = { 'operator', 'unlimited', 'executable', operators.aload, 'aload' },
            ['anchorsearch']      = { 'operator', 'unlimited', 'executable', operators.anchorsearch, 'anchorsearch' },
            ['and']               = { 'operator', 'unlimited', 'executable', operators["and"], 'and' },
            ['arc']               = { 'operator', 'unlimited', 'executable', operators.arc, 'arc' },
            ['arcn']              = { 'operator', 'unlimited', 'executable', operators.arcn, 'arcn' },
            ['arcto']             = { 'operator', 'unlimited', 'executable', operators.arcto, 'arcto' },
            ['array']             = { 'operator', 'unlimited', 'executable', operators.array, 'array' },
            ['astore']            = { 'operator', 'unlimited', 'executable', operators.astore, 'astore' },
            ['atan']              = { 'operator', 'unlimited', 'executable', operators.atan, 'atan' },
            ['banddevice']        = { 'operator', 'unlimited', 'executable', operators.banddevice, 'banddevice' },
            ['bind']              = { 'operator', 'unlimited', 'executable', operators.bind, 'bind' },
            ['bitshift']          = { 'operator', 'unlimited', 'executable', operators.bitshift, 'bitshift' },
            ['begin']             = { 'operator', 'unlimited', 'executable', operators.begin, 'begin' },
            ['bytesavailable']    = { 'operator', 'unlimited', 'executable', operators.bytesavailable, 'bytesavailable' },
            ['ceiling']           = { 'operator', 'unlimited', 'executable', operators.ceiling, 'ceiling' },
            ['clear']             = { 'operator', 'unlimited', 'executable', operators.clear, 'clear' },
            ['cleartomark']       = { 'operator', 'unlimited', 'executable', operators.cleartomark, 'cleartomark' },
            ['clip']              = { 'operator', 'unlimited', 'executable', operators.clip, 'clip' },
            ['clippath']          = { 'operator', 'unlimited', 'executable', operators.clippath, 'clippath' },
            ['closefile']         = { 'operator', 'unlimited', 'executable', operators.closefile, 'closefile' },
            ['closepath']         = { 'operator', 'unlimited', 'executable', operators.closepath, 'closepath' },
            ['concat']            = { 'operator', 'unlimited', 'executable', operators.concat, 'concat' },
            ['concatmatrix']      = { 'operator', 'unlimited', 'executable', operators.concatmatrix, 'concatmatrix' },
            ['copy']              = { 'operator', 'unlimited', 'executable', operators.copy, 'copy' },
            ['copypage']          = { 'operator', 'unlimited', 'executable', operators.copypage, 'copypage' },
            ['cos']               = { 'operator', 'unlimited', 'executable', operators.cos, 'cos' },
            ['count']             = { 'operator', 'unlimited', 'executable', operators.count, 'count' },
            ['countdictstack']    = { 'operator', 'unlimited', 'executable', operators.countdictstack, 'countdictstack' },
            ['countexecstack']    = { 'operator', 'unlimited', 'executable', operators.countexecstack, 'countexecstack' },
            ['counttomark']       = { 'operator', 'unlimited', 'executable', operators.counttomark, 'counttomark' },
            ['currentdash']       = { 'operator', 'unlimited', 'executable', operators.currentdash, 'currentdash' },
            ['currentdict']       = { 'operator', 'unlimited', 'executable', operators.currentdict, 'currentdict' },
            ['currentfile']       = { 'operator', 'unlimited', 'executable', operators.currentfile, 'currentfile' },
            ['currentflat']       = { 'operator', 'unlimited', 'executable', operators.currentflat, 'currentflat' },
            ['currentfont']       = { 'operator', 'unlimited', 'executable', operators.currentfont, 'currentfont' },
            ['currentgray']       = { 'operator', 'unlimited', 'executable', operators.currentgray, 'currentgray' },
            ['currenthsbcolor']   = { 'operator', 'unlimited', 'executable', operators.currenthsbcolor, 'currenthsbcolor' },
            ['currentlinecap']    = { 'operator', 'unlimited', 'executable', operators.currentlinecap, 'currentlinecap' },
            ['currentlinejoin']   = { 'operator', 'unlimited', 'executable', operators.currentlinejoin, 'currentlinejoin' },
            ['currentlinewidth']  = { 'operator', 'unlimited', 'executable', operators.currentlinewidth, 'currentlinewidth' },
            ['currentmatrix']     = { 'operator', 'unlimited', 'executable', operators.currentmatrix,  'currentmatrix' },
            ['currentmiterlimit'] = { 'operator', 'unlimited', 'executable', operators.currentmiterlimit,  'currentmiterlimit' },
            ['currentpoint']      = { 'operator', 'unlimited', 'executable', operators.currentpoint, 'currentpoint' },
            ['currentrgbcolor']   = { 'operator', 'unlimited', 'executable', operators.currentrgbcolor, 'currentrgbcolor' },
            ['currentcmykcolor']  = { 'operator', 'unlimited', 'executable', operators.currentcmykcolor, 'currentcmykcolor' },
            ['currentscreen']     = { 'operator', 'unlimited', 'executable', operators.currentscreen, 'currentscreen' },
            ['currenttransfer']   = { 'operator', 'unlimited', 'executable', operators.currenttransfer, 'currenttransfer' },
            ['curveto']           = { 'operator', 'unlimited', 'executable', operators.curveto, 'curveto' },
            ['cvi']               = { 'operator', 'unlimited', 'executable', operators.cvi, 'cvi' },
            ['cvlit']             = { 'operator', 'unlimited', 'executable', operators.cvlit, 'cvlit' },
            ['cvn']               = { 'operator', 'unlimited', 'executable', operators.cvn, 'cvn' },
            ['cvr']               = { 'operator', 'unlimited', 'executable', operators.cvr, 'cvr' },
            ['cvrs']              = { 'operator', 'unlimited', 'executable', operators.cvrs, 'cvrs' },
            ['cvs']               = { 'operator', 'unlimited', 'executable', operators.cvs, 'cvs' },
            ['cvx']               = { 'operator', 'unlimited', 'executable', operators.cvx, 'cvx' },
            ['def']               = { 'operator', 'unlimited', 'executable', operators.def, 'def' },
            ['definefont']        = { 'operator', 'unlimited', 'executable', operators.definefont, 'definefont' },
            ['dict']              = { 'operator', 'unlimited', 'executable', operators.dict, 'dict' },
            ['dictstack']         = { 'operator', 'unlimited', 'executable', operators.dictstack, 'dictstack' },
            ['div']               = { 'operator', 'unlimited', 'executable', operators.div, 'div' },
            ['dtransform']        = { 'operator', 'unlimited', 'executable', operators.dtransform, 'dtransform' },
            ['dup']               = { 'operator', 'unlimited', 'executable', operators.dup, 'dup' },
            ['echo']              = { 'operator', 'unlimited', 'executable', operators.echo, 'echo' },
            ['end']               = { 'operator', 'unlimited', 'executable', operators["end"], 'end' },
            ['eoclip']            = { 'operator', 'unlimited', 'executable', operators.eoclip, 'eoclip' },
            ['eofill']            = { 'operator', 'unlimited', 'executable', operators.eofill, 'eofill' },
            ['eq']                = { 'operator', 'unlimited', 'executable', operators.eq, 'eq' },
            ['errordict']         = { 'dict',     'unlimited', 'literal',    errordict },
            ['exch']              = { 'operator', 'unlimited', 'executable', operators.exch, 'exch' },
            ['exec']              = { 'operator', 'unlimited', 'executable', operators.exec, 'exec' },
            ['execstack']         = { 'operator', 'unlimited', 'executable', operators.execstack, 'execstack' },
            ['executeonly']       = { 'operator', 'unlimited', 'executable', operators.executeonly, 'executeonly' },
            ['exit']              = { 'operator', 'unlimited', 'executable', operators.exit, 'exit' },
            ['exp']               = { 'operator', 'unlimited', 'executable', operators.exp, 'exp' },
            ['false']             = { 'boolean',  'unlimited', 'literal',    false },
            ['file']              = { 'operator', 'unlimited', 'executable', operators.file, 'file' },
            ['fill']              = { 'operator', 'unlimited', 'executable', operators.fill, 'fill' },
            ['findfont']          = { 'operator', 'unlimited', 'executable', operators.findfont, 'findfont' },
            ['FontDirectory']     = { 'dict',     'unlimited', 'literal',    escrito['FontDirectory'] },
            ['flattenpath']       = { 'operator', 'unlimited', 'executable', operators.flattenpath, 'flattenpath' },
            ['floor']             = { 'operator', 'unlimited', 'executable', operators.floor, 'floor' },
            ['flush']             = { 'operator', 'unlimited', 'executable', operators.flush, 'flush' },
            ['flushfile']         = { 'operator', 'unlimited', 'executable', operators.flushfile, 'flushfile' },
            ['for']               = { 'operator', 'unlimited', 'executable', operators["for"], 'for' },
            ['forall']            = { 'operator', 'unlimited', 'executable', operators.forall, 'forall' },
            ['framedevice']       = { 'operator', 'unlimited', 'executable', operators.framedevice, 'framedevice' },
            ['ge']                = { 'operator', 'unlimited', 'executable', operators.ge, 'ge' },
            ['get']               = { 'operator', 'unlimited', 'executable', operators.get, 'get' },
            ['getinterval']       = { 'operator', 'unlimited', 'executable', operators.getinterval, 'getinterval' },
            ['grestore']          = { 'operator', 'unlimited', 'executable', operators.grestore, 'grestore' },
            ['grestoreall']       = { 'operator', 'unlimited', 'executable', operators.grestoreall, 'grestoreall' },
            ['gsave']             = { 'operator', 'unlimited', 'executable', operators.gsave, 'gsave' },
            ['gt']                = { 'operator', 'unlimited', 'executable', operators.gt, 'gt' },
            ['identmatrix']       = { 'operator', 'unlimited', 'executable', operators.identmatrix, 'identmatrix' },
            ['idiv']              = { 'operator', 'unlimited', 'executable', operators.idiv, 'idiv' },
            ['if']                = { 'operator', 'unlimited', 'executable', operators["if"], 'if' },
            ['ifelse']            = { 'operator', 'unlimited', 'executable', operators.ifelse, 'ifelse' },
            ['index']             = { 'operator', 'unlimited', 'executable', operators.index, 'index' },
            ['initclip']          = { 'operator', 'unlimited', 'executable', operators.initclip, 'initclip' },
            ['initgraphics']      = { 'operator', 'unlimited', 'executable', operators.initgraphics, 'initgraphics' },
            ['initmatrix']        = { 'operator', 'unlimited', 'executable', operators.initmatrix, 'initmatrix' },
            ['invertmatrix']      = { 'operator', 'unlimited', 'executable', operators.invertmatrix, 'invertmatrix' },
            ['idtransform']       = { 'operator', 'unlimited', 'executable', operators.idtransform, 'idtransform' },
            ['itransform']        = { 'operator', 'unlimited', 'executable', operators.itransform, 'itransform' },
            ['known']             = { 'operator', 'unlimited', 'executable', operators.known, 'known' },
            ['kshow']             = { 'operator', 'unlimited', 'executable', operators.kshow, 'kshow' },
            ['le']                = { 'operator', 'unlimited', 'executable', operators.le, 'le' },
            ['length']            = { 'operator', 'unlimited', 'executable', operators.length, 'length' },
            ['lineto']            = { 'operator', 'unlimited', 'executable', operators.lineto, 'lineto' },
            ['ln']                = { 'operator', 'unlimited', 'executable', operators.ln, 'ln' },
            ['load']              = { 'operator', 'unlimited', 'executable', operators.load, 'load' },
            ['log']               = { 'operator', 'unlimited', 'executable', operators.log, 'log' },
            ['loop']              = { 'operator', 'unlimited', 'executable', operators.loop, 'loop' },
            ['lt']                = { 'operator', 'unlimited', 'executable', operators.lt, 'lt' },
            ['makefont']          = { 'operator', 'unlimited', 'executable', operators.makefont, 'makefont' },
            ['mark']              = { 'operator', 'unlimited', 'executable', operators.mark, 'mark' },
            ['matrix']            = { 'operator', 'unlimited', 'executable', operators.matrix, 'matrix' },
            ['maxlength']         = { 'operator', 'unlimited', 'executable', operators.maxlength, 'maxlength' },
            ['mod']               = { 'operator', 'unlimited', 'executable', operators.mod, 'mod' },
            ['moveto']            = { 'operator', 'unlimited', 'executable', operators.moveto, 'moveto' },
            ['mul']               = { 'operator', 'unlimited', 'executable', operators.mul, 'mul' },
            ['ne']                = { 'operator', 'unlimited', 'executable', operators.ne, 'ne' },
            ['neg']               = { 'operator', 'unlimited', 'executable', operators.neg, 'neg' },
            ['newpath']           = { 'operator', 'unlimited', 'executable', operators.newpath, 'newpath' },
            ['noaccess']          = { 'operator', 'unlimited', 'executable', operators.noaccess, 'noaccess' },
            ['not']               = { 'operator', 'unlimited', 'executable', operators["not"], 'not' },
            ['null']              = { 'operator', 'unlimited', 'executable', operators.null, 'null' },
            ['or']                = { 'operator', 'unlimited', 'executable', operators["or"], 'or' },
            ['pop']               = { 'operator', 'unlimited', 'executable', operators.pop, 'pop' },
            ['print']             = { 'operator', 'unlimited', 'executable', operators.print, 'print' },
            ['pstack']            = { 'operator', 'unlimited', 'executable', operators.pstack, 'pstack' },
            ['put']               = { 'operator', 'unlimited', 'executable', operators.put, 'put' },
            ['putinterval']       = { 'operator', 'unlimited', 'executable', operators.putinterval, 'putinterval' },
            ['quit']              = { 'operator', 'unlimited', 'executable', operators.quit, 'quit' },
            ['rand']              = { 'operator', 'unlimited', 'executable', operators.rand, 'rand' },
            ['rcheck']            = { 'operator', 'unlimited', 'executable', operators.rcheck, 'rcheck' },
            ['rcurveto']          = { 'operator', 'unlimited', 'executable', operators.rcurveto, 'rcurveto' },
            ['read']              = { 'operator', 'unlimited', 'executable', operators.read, 'read' },
            ['readhexstring']     = { 'operator', 'unlimited', 'executable', operators.readhexstring, 'readhexstring' },
            ['readline']          = { 'operator', 'unlimited', 'executable', operators.readline, 'readline' },
            ['readonly']          = { 'operator', 'unlimited', 'executable', operators.readonly, 'readonly' },
            ['renderbands']       = { 'operator', 'unlimited', 'executable', operators.renderbands, 'renderbands' },
            ['repeat']            = { 'operator', 'unlimited', 'executable', operators["repeat"], 'repeat' },
            ['resetfile']         = { 'operator', 'unlimited', 'executable', operators.resetfile, 'resetfile' },
            ['restore']           = { 'operator', 'unlimited', 'executable', operators.restore, 'restore' },
            ['rlineto']           = { 'operator', 'unlimited', 'executable', operators.rlineto, 'rlineto' },
            ['rmoveto']           = { 'operator', 'unlimited', 'executable', operators.rmoveto, 'rmoveto' },
            ['roll']              = { 'operator', 'unlimited', 'executable', operators.roll, 'roll' },
            ['rotate']            = { 'operator', 'unlimited', 'executable', operators.rotate, 'rotate' },
            ['round']             = { 'operator', 'unlimited', 'executable', operators.round, 'round' },
            ['rrand']             = { 'operator', 'unlimited', 'executable', operators.rrand, 'rrand' },
            ['run']               = { 'operator', 'unlimited', 'executable', operators.run, 'run' },
            ['save']              = { 'operator', 'unlimited', 'executable', operators.save, 'save' },
            ['scale']             = { 'operator', 'unlimited', 'executable', operators.scale, 'scale' },
            ['scalefont']         = { 'operator', 'unlimited', 'executable', operators.scalefont, 'scalefont' },
            ['search']            = { 'operator', 'unlimited', 'executable', operators.search, 'search' },
            ['setdash']           = { 'operator', 'unlimited', 'executable', operators.setdash,  'setdash' },
            ['setflat']           = { 'operator', 'unlimited', 'executable', operators.setflat,  'setflat' },
            ['setfont']           = { 'operator', 'unlimited', 'executable', operators.setfont,  'setfont' },
            ['setgray']           = { 'operator', 'unlimited', 'executable', operators.setgray,  'setgray' },
            ['sethsbcolor']       = { 'operator', 'unlimited', 'executable', operators.sethsbcolor,  'sethsbcolor' },
            ['setlinecap']        = { 'operator', 'unlimited', 'executable', operators.setlinecap,  'setlinecap' },
            ['setlinejoin']       = { 'operator', 'unlimited', 'executable', operators.setlinejoin,  'setlinejoin' },
            ['setlinewidth']      = { 'operator', 'unlimited', 'executable', operators.setlinewidth,  'setlinewidth' },
            ['setmatrix']         = { 'operator', 'unlimited', 'executable', operators.setmatrix,  'setmatrix' },
            ['setmiterlimit']     = { 'operator', 'unlimited', 'executable', operators.setmiterlimit,  'setmiterlimit' },
            ['setrgbcolor']       = { 'operator', 'unlimited', 'executable', operators.setrgbcolor,  'setrgbcolor' },
            ['setcmykcolor']      = { 'operator', 'unlimited', 'executable', operators.setcmykcolor,  'setcmykcolor' },
            ['setscreen']         = { 'operator', 'unlimited', 'executable', operators.setscreen,  'setscreen' },
            ['settransfer']       = { 'operator', 'unlimited', 'executable', operators.settransfer,  'settransfer' },
            ['show']              = { 'operator', 'unlimited', 'executable', operators.show, 'show' },
            ['showpage']          = { 'operator', 'unlimited', 'executable', operators.showpage, 'showpage' },
            ['sin']               = { 'operator', 'unlimited', 'executable', operators.sin, 'sin' },
            ['sqrt']              = { 'operator', 'unlimited', 'executable', operators.sqrt, 'sqrt' },
            ['srand']             = { 'operator', 'unlimited', 'executable', operators.srand, 'srand' },
            ['stack']             = { 'operator', 'unlimited', 'executable', operators.stack, 'stack' },
            ['start']             = { 'operator', 'unlimited', 'executable', operators.start, 'start' },
            ['StandardEncoding']  = { 'array',    'unlimited', 'literal',    add_VM(standardencoding()), 256, 256 },
            ['status']            = { 'operator', 'unlimited', 'executable', operators.status, 'status' },
            ['stop']              = { 'operator', 'unlimited', 'executable', operators.stop, 'stop' },
            ['stopped']           = { 'operator', 'unlimited', 'executable', operators.stopped, 'stopped' },
            ['store']             = { 'operator', 'unlimited', 'executable', operators.store, 'store' },
            ['string']            = { 'operator', 'unlimited', 'executable', operators.string, 'string' },
            ['stroke']            = { 'operator', 'unlimited', 'executable', operators.stroke, 'stroke' },
            ['sub']               = { 'operator', 'unlimited', 'executable', operators.sub, 'sub' },
            ['systemdict']        = { 'dict',     'unlimited', 'literal',    systemdict },
            ['token']             = { 'operator', 'unlimited', 'executable', operators.token, 'token' },
            ['translate']         = { 'operator', 'unlimited', 'executable', operators.translate, 'translate' },
            ['transform']         = { 'operator', 'unlimited', 'executable', operators.transform, 'transform' },
            ['true']              = { 'boolean',  'unlimited', 'literal',    true },
            ['truncate']          = { 'operator', 'unlimited', 'executable', operators.truncate, 'truncate' },
            ['type']              = { 'operator', 'unlimited', 'executable', operators.type, 'type' },
            ['userdict']          = { 'dict',     'unlimited', 'literal',    userdict },
            ['usertime']          = { 'operator', 'unlimited', 'executable', operators.usertime, 'usertime' },
            ['version']           = { 'operator', 'unlimited', 'executable', operators.version, 'version' },
            ['vmstatus']          = { 'operator', 'unlimited', 'executable', operators.vmstatus, 'vmstatus' },
            ['wcheck']            = { 'operator', 'unlimited', 'executable', operators.wcheck, 'wcheck' },
            ['where']             = { 'operator', 'unlimited', 'executable', operators.where, 'where' },
            ['write']             = { 'operator', 'unlimited', 'executable', operators.write, 'write' },
            ['writehexstring']    = { 'operator', 'unlimited', 'executable', operators.writehexstring, 'writehexstring' },
            ['writestring']       = { 'operator', 'unlimited', 'executable', operators.writestring, 'writestring' },
            ['xcheck']            = { 'operator', 'unlimited', 'executable', operators.xcheck, 'xcheck' },
            ['xor']               = { 'operator', 'unlimited', 'executable', operators.xor, 'xor' },
        }
        if directvm then
            systemdict.dict = dict
        else
            VM[dictstack[systemdict]].dict = dict
        end
    end
end

initializers[#initializers+1] = function(reset)
    if reset then
        dicterror = nil
        errordict = nil
    else
        dicterror = add_VM {
            access  = 'unlimited',
            size    = 1,
            maxsize = 40,
            dict    = {
                newerror = { 'boolean', 'unlimited', 'literal', false }
            },
        }
        --
        errordict = add_VM {
            access  = 'unlimited',
            size    = 0,
            maxsize = 40,
            dict    = { },
        }
        --
        local d
        if directvm then
            d = systemdict.dict
        else
            d = VM[dictstack[systemdict]].dict
        end
        -- still needed ?
        d['errordict']  = { 'dict', 'unlimited', 'literal', errordict }
        d['systemdict'] = { 'dict', 'unlimited', 'literal', systemdict }
        d['userdict']   = { 'dict', 'unlimited', 'literal', userdict }
        d['$error']     = { 'dict', 'unlimited', 'literal', dicterror }
    end
end

-- What follows is the main interpreter, with the tokenizer first

-- procedure scanning stack for the tokenizer

local procstack
local procstackptr

initializers[#initializers+1] = function(reset)
    if reset then
        procstack    = nil
        procstackptr = nil
    else
        procstack    = { }
        procstackptr = 0
    end
end

-- lpeg parser for tokenization

do

    local function push(v)
        if procstackptr > 0 then
            local top = procstack[procstackptr]
            if top then
                top[#top+1] = v
            else
                procstack[procstackptr] = { v }
            end
            return false
        else
            push_execstack(v)
            return true
        end
    end

    local function start()
        procstackptr = procstackptr + 1
        return true
    end

    local function stop()
        local v = procstack[procstackptr]
        procstack[procstackptr] = { }
        procstackptr = procstackptr - 1
        if push {'array', 'unlimited', 'executable', add_VM(v), 1, #v, 'd' } then
            return true
        end
    end

    local function hexify(a)
        return char(tonumber(a,16))
    end

    local function octify(a)
        return char(tonumber(a,8))
    end

    local function radixed(base,value)
        base = tonumber(base)
        if base > 36 or base < 2 then
            return nil
        end
        value = tonumber(value,base)
        if not value then
            return "error", false
        elseif value > MAX_INT then
            return "integer", value
        else
            return "real", value
        end
    end

    local space      = S(' ')
    local spacing    = S(' \t\r\n\f')
    local sign       = S('+-')^-1
    local digit      = R('09')
    local period     = P('.')
    local letters    = R('!~') - S('[]<>{}()%')
    local hexdigit   = R('09','af','AF')
    local radixdigit = R('09','az','AZ')

    local p_integer  = (sign * digit^1 * #(1-letters)) / tonumber
    local p_real     = ((sign * digit^0 * period * digit^0 + period * digit^1) * (S('eE') * sign * digit^1)^-1 * #(1-letters)) / tonumber
    local p_literal  = Cs(P("/")/"" * letters^1 * letters^0)
    local p_symbol   = C(letters^1 * letters^0)
    ----- p_radixed  = C(digit^1) * P("#") * C(radixdigit^1) * #(1-letters)  / radixed-- weird #() here
    local p_radixed  = C(digit^1) * P("#") * C(radixdigit^1) / radixed
    local p_unhexed  = P("<") * Cs(((C(hexdigit*hexdigit) * Cc(16))/tonumber/char+spacing/"")^0) * P(">")
    local p_comment  = P('%') * (1 - S('\r\n'))^0 * Cc(true)
    local p_bounding = P('%%BoundingBox:') * Ct((space^0 * p_integer)^4) * (1 - S('\r\n'))^0
    local p_lbrace   = C("{")
    local p_rbrace   = C("}")
    local p_lbracket = C("[")
    local p_rbracket = C("]")
    local p_finish   = Cc(false)

    local p_string   =
        P("(")
      * Cs( P {
            (
                (1 - S("()\\"))^1
              + P("\\")/"" * (
                    (C(digit *digit * digit) * Cc(8)) / tonumber / char
                  + P("n") / "\n" + P("r") / "\r" + P("t") / "\t"
                  + P("b") / "\b" + P("f") / "\f" + P("\\") / "\\"
                  + 1
                )
              + P("(") * V(1) * P(")")
            )^0
        })
    * P(")")

    -- inspect(lpegmatch(p_radixed,"10#123"))
    -- inspect(lpegmatch(p_unhexed,"<A2B3  C3>"))
    -- inspect(lpegmatch(p_string,[[(foo(bar \124\125 \( bar\n bar\\bar))]]))

    local p_unhexed     = Cc('string')   * p_unhexed
    local p_string      = Cc('string')   * p_string
    local p_array_start = Cc('name')     * p_lbracket
    local p_array_stop  = Cc('name')     * p_rbracket
    local p_exec_start  = Cc('start')    * p_lbrace
    local p_exec_stop   = Cc('stop')     * p_rbrace
    local p_integer     = Cc('integer')  * p_integer
    local p_real        = Cc('real')     * p_real
    local p_radixed     =                  p_radixed
    local p_symbol      = Cc('name')     * p_symbol
    local p_literal     = Cc('literal')  * p_literal
    local p_comment     = Cc('comment')  * p_comment
    local p_bounding    = Cc('bounding') * p_bounding
    local p_finish      = Cc("eof")      * p_finish
    local p_whitespace  = spacing^0

    local tokens =  p_whitespace
                 * (
                    p_bounding
                  + p_comment
                  + p_string
                  + p_unhexed
                  + p_array_start
                  + p_array_stop
                  + p_exec_start
                  + p_exec_stop
                  + p_real
                  + p_radixed
                  + p_integer
                  + p_literal
                  + p_symbol
                  + p_finish
                )^-1
                * Cp()

    -- we can do push etc in the lpeg but the call is not faster than the check
    -- and this stays closer to the original

    local function tokenize()
        local object    = execstack[execstackptr]
        local sequence  = object[4]
        local position  = object[5]
        local length    = object[6]
        local tokentype = nil
        local value     = nil
        while position < length do
            tokentype, value, position = lpegmatch(tokens,get_VM(sequence),position)
            if not position then
                return false
            elseif position >= length then
                pop_execstack()
            else
                object[5] = position
            end
            if not value then
                return false -- handle_error('syntaxerror')
            elseif tokentype == 'integer' or tokentype == 'real' then
                if push { tokentype, 'unlimited', 'literal', value } then
                    return true
                end
            elseif tokentype == 'name' then
                if push { 'name', 'unlimited', 'executable', add_VM(value) } then
                    return true
                end
            elseif tokentype == 'literal' then
                if push { 'name', 'unlimited', 'literal', add_VM(value) } then
                    return true
                end
            elseif tokentype == 'string' then
                if push { 'string', 'unlimited', 'literal', add_VM(value), 1, #value } then
                    return true
                end
            elseif tokentype == 'start' then
                if start() then
                    -- stay
                end
            elseif tokentype == 'stop' then
                if stop() then
                    return true
                end
            elseif tokentype == 'bounding' then
                specials.boundingbox = value
            end
        end
        return position >= length
    end

    -- the exec stack can contain a limited amount of interesting item types
    -- to be handled by next_object:
    -- executable arrays (procedures)
    -- executable strings
    -- executable files

    next_object = function()
        if execstackptr == 0 then
            return nil
        end
        local object = execstack[execstackptr]
        if not object then
            return nil
        end
        local otyp = object[1]
        local exec = object[3] == 'executable'
        if not exec then
            return pop_execstack()
        elseif otyp == 'array' then
            if object[7] == 'd' then
                return pop_execstack()
            else
                local proc = get_VM(object[4])
                local o = object[5]
                local val = proc[o]
                if o >= #proc then
                    object[5] = 1
                    pop_execstack()
                else
                    object[5] = o + 1
                end
                return val
            end
        elseif otyp == 'string' then
            if not tokenize() then
                report("tokenizer failed on string")
                return nil
            else
                return next_object() -- recurse
            end
        elseif otyp == 'file' then
            if object[4] == 0 then
                report('sorry, interactive mode is not supported')
            end
            if not tokenize() then
                report("tokenizer failed on file")
                return nil
            else
                return next_object() -- recurse
            end
        else
            return pop_execstack()
        end
    end

-- The main execution control function

    local detail = false -- much faster

    local report_exec = logs.reporter("escrito","exec")

    do_exec = function() -- already a local
        local ret
        local savedopstack = detail and copy_opstack()
        local object = next_object()
        if not object then
            return false
        end
        local otyp = object[1]
        if DEBUG then
            if otyp == 'operator' then
                report_exec("%s %s %s",otyp,object[3],object[5])
            elseif otyp == 'dict' then
                local d = get_VM(object[4])
                report_exec("%s %s <%s:%s>",otyp,object[3],d.size or '',d.maxsize or '')
            elseif otyp == 'array' or otyp == 'file' or otyp == 'save' then
                report_exec("%s <%s:%s>",object[3],object[5] or '',object[6] or '')
            elseif otyp == 'string' or otyp == 'name' then
                report_exec("%s %s %s",otyp,object[3],get_VM(object[4]))
            else
                report_exec("%s %s %s",otyp,object[3],tostring(object[4]))
            end
        end
        if otyp == 'real' or otyp == 'integer' or otyp == 'boolean' or otyp == 'mark' or otyp == 'save' or otyp == 'font' then
            push_opstack(object)
        elseif otyp == '.stopped' then
            -- when .stopped is seen here, stop was never called
            push_opstack { 'boolean', 'unlimited', 'executable', false}
        elseif otyp == '.exit' then
            -- when .exit is seen here, exit was never called
        elseif otyp == 'array' then
            if object[2] == 'noaccess' then
                escrito.errorname = 'noaccess'
            else
                push_opstack(object)
            end
        elseif otyp == 'string' then
            if object[2] == 'noaccess' then
                escrito.errorname = 'noaccess'
            else
                push_opstack(object)
            end
        elseif otyp == 'dict' then
            local dict = get_VM(object[4])
            if dict.access == 'noaccess' then
                escrito.errorname = 'noaccess'
            else
                push_opstack(object)
            end
        elseif otyp == 'file' then
            if object[2] == 'noaccess' then
                errorname = 'noaccess'
            else
                push_opstack(object)
            end
        elseif otyp == 'null' then
            push_opstack(object)
        elseif otyp == 'operator' then
            if object[3]=='executable' then
                ret, escrito.errorname = object[4]()
            else
                push_opstack(object)
            end
        elseif otyp == 'save' then
          -- todo
        elseif otyp == 'name' then
            if object[3] == 'executable' then
                local v = lookup(get_VM(object[4]))
                if not v then
                    if escrito.errorname then
                        -- doesn't work, needs thinking
                        error ("recursive error detected inside '" .. escrito.errorname .. "'")
                    end
                    escrito.errorname = 'undefined'
                else
                    if DEBUG then
                        local vt = v[1]
                        if vt == 'operator' then
                            print ('exec2: ' .. vt .. ' ' .. v[3] .. ' '.. v[5])
                        elseif vt == 'dict' or vt == 'array' or vt == 'file' or vt == 'save'  then
                            print ('exec2: ' .. vt .. ' ' .. v[3] .. ' <'.. (v[5] or '') .. '>')
                        elseif vt == 'string' or vt == 'name' then
                            print ('exec2: ' .. vt .. ' ' .. v[3] .. ' '.. get_VM(v[4]))
                        else
                            print ('exec2: ' .. vt .. ' ' .. v[3] .. ' '.. tostring(v[4]))
                        end
                    end
                    push_execstack(v)
                end
            else
                push_opstack(object)
            end
        elseif otyp == 'null' then
            -- do nothing
        elseif otyp == 'array' then
            push_opstack(object)
        end

        if escrito.errorname then
            if savedopstack then
                local v = lookup_error(escrito.errorname)
                if not v then
                    print("unknown error handler for '" .. escrito.errorname .. "', quitting")
                    return false
                else
                    set_opstack(savedopstack)
                    push_opstack { otyp, object[2], "literal", object[4], object[5], object[6], object[7] }
                    push_opstack { 'string','unlimited','literal',add_VM(escrito.errorname), 1 }
                    push_execstack(v)
                end
                escrito.errorname = nil
            else
                print("error '" .. escrito.errorname .. "', quitting")
             -- os.exit()
            end
        end

        return true
    end

end

do

    -- some of the errors will never actually happen

    local errornames = {
        "dictfull", "dictstackoverflow", "dictstackunderflow", "execstackoverflow",
        "interrupt", "invalidaccess", "invalidexit", "invalidfileaccess", "invalidfont", "invalidrestore",
        "ioerror", "limitcheck", "nocurrentpoint", "rangecheck", "stackoverflow", "stackunderflow",
        "syntaxerror", "timeout", "typecheck", "undefined", "undefinedfilename", "undefinedresult",
        "unmatchedmark", "unregistered", "VMerror"
    }

    local generic_error_proc = [[{
        $error /newerror true put
        $error exch /errorname exch put
        $error exch /command exch put
        count array astore $error /ostack 3 -1 roll put
        $error /dstack countdictstack array dictstack put
        countexecstack array execstack aload pop pop count array astore $error /estack 3 -1 roll put
        stop
    } bind ]]

    local generic_handleerror_proc = [[{
        $error begin
            /newerror false def
            (%%[ Error: ) print
            errorname print
            (; OffendingCommand: ) print
            command ==
            ( ]%%\n) print flush
        end
    }]]

    local enabled

    local function interpret(data)
        if enabled then
            push_opstack { 'file', 'unlimited', 'executable', add_VM(data), 1, #data, 'r', stdin }
            push_execstack { 'operator', 'unlimited', 'executable', operators.stopped, 'stopped' }
            while true do
                if not do_exec() then
                    local v = pop_opstack()
                    if v and v[4] == true then
                        local proc = {
                            { 'name',     'unlimited', 'executable', add_VM('errordict') }, -- hm, errordict
                            { 'name',     'unlimited', 'literal',    add_VM('handleerror') },
                            { 'operator', 'unlimited', 'executable', operators.get,  'get' },
                            { 'operator', 'unlimited', 'executable', operators.exec, 'exec' },
                        }
                        push_execstack { 'array', 'unlimited', 'executable', add_VM(proc), 1, #proc, 'i' }
                    else
                        return
                    end
                end
            end
        end
    end

    local function close()
        for i=1,#initializers do
            initializers[i](true)
        end
        enabled = false
    end

    local function open(options)
        enabled = true
        local starttime = os.clock()
        local stoptime  = nil
        for i=1,#initializers do
            initializers[i]()
        end
        if type(options) == "table" then
            devicename   = options.device or "pdf"
            findfont     = options.findfont   or findfont
            randomseed   = options.randomseed or randomseed -- todo
            calculatebox = options.calculatebox
        else
            devicename = "pdf"
        end
        device = devices[devicename] or devices.pdf
        operators.initgraphics()
        for i=1,#errornames do
            interpret(formatters["errordict /%s %s put"](errornames[i],generic_error_proc), INITDEBUG)
        end
        -- set up the error handler
        interpret("systemdict /= { 20 string cvs print } bind put", INITDEBUG)
        interpret("systemdict /prompt { (PS>) print flush } bind put", INITDEBUG)
        interpret(format("errordict /handleerror %s bind put", generic_handleerror_proc), INITDEBUG)
        interpret("systemdict /handleerror {errordict /handleerror get exec } bind put", INITDEBUG)
        -- user dict initializations
        interpret(format("/quit { stop } bind def"), INITDEBUG)
        interpret(format("userdict /#copies 1 put"), INITDEBUG)
        local job = {
            runtime     = 0,
            interpret   = interpret,
            boundingbox = boundingbox,
            close       = function()
                close()
                local runtime = os.clock() - starttime
                job.runtime = runtime
                return runtime
            end,
        }
        return job
    end

    escrito.open = open

    if context then

        function escrito.convert(options)
            if type(options) == "table" then
                local data = options.data
                if not data or data == "" then
                    local buffer   = options.buffer
                    local filename = options.filename -- needs escaping
                    if buffer and buffer ~= "" then
                        data = buffers.getcontent(buffer)
                    elseif filename and filename ~= "" then
                        data = io.loaddata(filename) -- use resolver
                    end
                end
                if data and data ~= "" then
                    local e = open(options)
-- print(data)
                    e.interpret(data)
                    return e.close()
                end
            end
            return 0
        end

    end

    escrito.devices = devices

end

return escrito
