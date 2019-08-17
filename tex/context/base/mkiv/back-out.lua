if not modules then modules = { } end modules ['back-out'] = {
    version   = 1.001,
    comment   = "companion to back-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type = type
local loadstring = loadstring

local context             = context

-- tokens.scanners.....

local get                 = token.get_index
local scaninteger         = token.scan_int
local scanstring          = token.scan_string
local scankeyword         = token.scan_keyword
local scantokenlist       = token.scan_tokenlist
----- scancode            = token.scan_code

local tokentostring       = token.to_string

local logwriter           = logs.writer
local openfile            = io.open
local flushio             = io.flush

local nuts                = nodes.nuts
local tonode              = nuts.tonode
local copynode            = nuts.copy
local nodepool            = nuts.pool

local getdata             = nuts.getdata

local whatsit_code        = nodes.nodecodes.whatsit

local whatsitcodes        = nodes.whatsitcodes

local literalvalues       = nodes.literalvalues
local originliteral_code  = literalvalues.origin
local pageliteral_code    = literalvalues.page
local directliteral_code  = literalvalues.direct
local rawliteral_code     = literalvalues.raw

local nodeproperties      = nodes.properties.data

local channels            = { }

local register            = nodepool.register
local newnut              = nuts.new

local opennode            = register(newnut(whatsit_code,whatsitcodes.open))
local writenode           = register(newnut(whatsit_code,whatsitcodes.write))
local closenode           = register(newnut(whatsit_code,whatsitcodes.close))
local lateluanode         = register(newnut(whatsit_code,whatsitcodes.latelua))
local literalnode         = register(newnut(whatsit_code,whatsitcodes.literal))
local savenode            = register(newnut(whatsit_code,whatsitcodes.save))
local restorenode         = register(newnut(whatsit_code,whatsitcodes.restore))
local setmatrixnode       = register(newnut(whatsit_code,whatsitcodes.setmatrix))

local tomatrix            = drivers.helpers.tomatrix

local immediately         = false -- not watertight

local open_command, write_command, close_command

backends = backends or { }

local function openout()
    local channel = scaninteger()
    scankeyword("=") -- hack
    local filename = scanstring()
    if not immediately then
        local n = copynode(opennode)
        nodeproperties[n] = { channel = channel, filename = filename } -- action = "open"
        return context(tonode(n))
    elseif not channels[channel] then
        local handle = openfile(filename,"wb") or false
        if handle then
            channels[channel] = handle
        else
            -- error
        end
    end
    immediately = false
end

function backends.openout(n)
    local p = nodeproperties[n]
    if p then
        local handle = openfile(p.filename,"wb") or false
        if handle then
            channels[p.channel] = handle
        else
            -- error
        end
    end
end

local function write()
    local channel = scaninteger()
    if not immediately then
        local t = scantokenlist()
        local n = copynode(writenode)
        nodeproperties[n] = { channel = channel, data = t } -- action = "write"
        return context(tonode(n))
    else
        local content = scanstring()
        local handle  = channels[channel]
        if handle then
            handle:write(content,"\n")
        else
           logwriter(content,"\n")
        end
    end
    immediately = false
end

function backends.writeout(n)
    local p = nodeproperties[n]
    if p then
        local handle  = channels[p.channel]
        local content = tokentostring(p.data)
        if handle then
            handle:write(content,"\n")
        else
           logwriter(content,"\n")
        end
    end
end

local function closeout()
    local channel = scaninteger()
    if not immediately then
        local n = copynode(closenode)
        nodeproperties[n] = { channel = channel } -- action = "close"
        return context(tonode(n))
    else
        local handle = channels[channel]
        if handle then
            handle:close()
            channels[channel] = false
            flushio()
        else
            -- error
        end
    end
    immediately = false
end

function backends.closeout(n)
    local p = nodeproperties[n]
    if p then
        local channel = p.channel
        local handle  = channels[channel]
        if handle then
            handle:close()
            channels[channel] = false
            flushio()
        else
            -- error
        end
    end
end

local function immediate()
    immediately = true
end

local noflatelua = 0

local function latelua()
    local node = copynode(lateluanode)
    local name = "latelua"
    if scankeyword("name") then
        name = scanstring()
    end
    local data = scantokenlist()
    nodeproperties[node] = { name = name, data = data }
    return context(tonode(node))
end

function backends.latelua(current,pos_h,pos_v) -- todo: pass pos_h and pos_v (more efficient in lmtx)
    local p = nodeproperties[current]
    if p then
        data = p.data
    else
        data = getdata(current)
    end
    noflatelua = noflatelua + 1
    local kind = type(data)
    if kind == "table" then
        data.action(data.specification or data)
    elseif kind == "function" then
        data()
    else
        if kind ~= "string" then
            data = tokentostring(data)
        end
        if #data ~= "" then
            local code = loadstring(data)
            if code then
                code()
            end
        end
    end
end

function backends.noflatelua()
    return noflatelua
end

function nodepool.originliteral(str) local t = copynode(literalnode) nodeproperties[t] = { data = str, mode = originliteral_code } return t end
function nodepool.pageliteral  (str) local t = copynode(literalnode) nodeproperties[t] = { data = str, mode = pageliteral_code   } return t end
function nodepool.directliteral(str) local t = copynode(literalnode) nodeproperties[t] = { data = str, mode = directliteral_code } return t end
function nodepool.rawliteral   (str) local t = copynode(literalnode) nodeproperties[t] = { data = str, mode = rawliteral_code    } return t end

local pdfliterals = {
    [originliteral_code] = originliteral_code, [literalvalues[originliteral_code]] = originliteral_code,
    [pageliteral_code]   = pageliteral_code,   [literalvalues[pageliteral_code]]   = pageliteral_code,
    [directliteral_code] = directliteral_code, [literalvalues[directliteral_code]] = directliteral_code,
    [rawliteral_code]    = rawliteral_code,    [literalvalues[rawliteral_code]]    = rawliteral_code,
}

function nodepool.literal(mode,str)
    local t = copynode(literalnode)
    if str then
        nodeproperties[t] = { data = str, mode = pdfliterals[mode] or pageliteral_code }
    else
        nodeproperties[t] = { data = mode, mode = pageliteral_code }
    end
    return t
end

function nodepool.save()
    return copynode(savenode)
end

function nodepool.restore()
    return copynode(restorenode)
end

function nodepool.setmatrix(rx,sx,sy,ry,tx,ty)
    local t = copynode(setmatrixnode)
    nodeproperties[t] = { matrix = tomatrix(rx,sx,sy,ry,tx,ty) }
    return t
end

interfaces.implement { name = "immediate", actions = immediate,  public = true, protected = true }
interfaces.implement { name = "openout",   actions = openout,    public = true, protected = true }
interfaces.implement { name = "write",     actions = write,      public = true, protected = true }
interfaces.implement { name = "closeout",  actions = closeout,   public = true, protected = true }
interfaces.implement { name = "latelua",   actions = latelua,    public = true, protected = true }
interfaces.implement { name = "special",   actions = scanstring, public = true, protected = true }

open_command  = get(token.create("openout"))
write_command = get(token.create("write"))
close_command = get(token.create("closeout"))
