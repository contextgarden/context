if not modules then modules = { } end modules ['node-dir'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Taco Hoekwater and Hans Hagen",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is experimental code, so when I change it I need to check other modules
-- too.
--
-- Local par nodes are somewhat special. They start a paragraph and then register
-- the par direction. But they can also show op mid paragraph in which case they
-- register boxes and penalties. In that case the direction should not be affected.
--
-- We can assume that when hpack and prelinebreak filters are called, a local par
-- still sits at the head, but after a linebreak pass this node can be after the
-- leftskip (when present).

local nodes         = nodes
local nuts          = nodes.nuts

local nodecodes     = nodes.nodecodes
local localpar_code = nodecodes.localpar

local getid         = nuts.getid
local getsubtype    = nuts.getsubtype
local getdirection  = nuts.getdirection

local dirvalues     = nodes.dirvalues
local lefttoright   = dirvalues.lefttoright
local righttoleft   = dirvalues.righttoleft

local localparcodes = nodes.localparcodes
local hmodepar_code = localparcodes.vmode_par
local vmodepar_code = localparcodes.hmode_par

function nodes.dirstack(head,direction)
    local stack = { }
    local top   = 0
    if head and getid(head) == localpar_code then
        local s = getsubtype(head)
        if s == hmodepar_code or s == vmodepar_code then
            direction = getdirection(head)
        end
    end
    if not direction then
        direction = lefttoright
    elseif direction == "TLT" then
        direction = lefttoright
    elseif direction == "TRT" then
        direction = righttoleft
    end
    local function update(node)
        local dir, pop = getdirection(node)
        if not pop then
            top = top + 1
            stack[top] = dir
            return dir
        elseif top == 0 then
            return direction
        elseif top == 1 then
            top = 0
            return direction
        else
            top = top - 1
            return stack[top]
        end
    end
    return direction, update
end
