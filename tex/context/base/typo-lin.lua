if not modules then modules = { } end modules ['typo-lin'] = {
    version   = 1.001,
    comment   = "companion to typo-lin.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- can become typo-par or so

local trace_anchors  = false  trackers.register("paragraphs.anchors",  function(v) trace_anchors = v end)

local nuts           = nodes.nuts
local nodecodes      = nodes.nodecodes
local gluecodes      = nodes.gluecodes
local listcodes      = nodes.listcodes
local whatcodes      = nodes.whatsitcodes

local hlist_code     = nodecodes.hlist
local glue_code      = nodecodes.glue
local whatsit_code   = nodecodes.whatsit
local line_code      = listcodes.line
local leftskip_code  = gluecodes.leftskip
local rightskip_code = gluecodes.rightskip
local textdir_code   = whatcodes.textdir
local localpar_code  = whatcodes.localpar

local tonut          = nodes.tonut
local tonode         = nodes.tonode

local traverse_id    = nuts.traverse_id
local insert_before  = nuts.insert_before
local insert_after   = nuts.insert_after
local findtail       = nuts.tail
local remove_node    = nuts.remove
local hpack_nodes    = nuts.hpack

local getsubtype     = nuts.getsubtype
local getlist        = nuts.getlist
local getid          = nuts.getid
local getnext        = nuts.getnext
local getfield       = nuts.getfield
local setfield       = nuts.setfield

local setprop        = nuts.setprop
local getprop        = nuts.getprop

local nodepool       = nuts.pool
local new_glue       = nodepool.glue
local new_kern       = nodepool.kern
local new_leftskip   = nodepool.leftskip
local new_rightskip  = nodepool.rightskip
local new_hlist      = nodepool.hlist
local new_vlist      = nodepool.vlist
local new_rule       = nodepool.rule

local texgetcount    = tex.getcount

local paragraphs       = { }
typesetters.paragraphs = paragraphs

-- also strip disc

-- We only need to normalize the left side because when we mess around
-- we keep the page stream order (and adding content to the right of the
-- line is a no-go for tagged etc. For the same reason we don't use two
-- left anchors (each side fo leftskip) because there can be stretch. But,
-- maybe there are good reasons for having just that anchor (mostly for
-- educational purposes I guess.)

-- At this stage the localpar node is no longer of any use so we remove
-- it (each line has the direction attached). We might at some point also
-- strip the disc nodes as they no longer serve a purpose but that can
-- better be a helper. Anchoring left has advantage of keeping page stream.

-- indent     : hlist type 3
-- hangindent : shift and width

-- new_glue(0,65536,65536,2,2) -- hss (or skip -width etc)

-- -- rightskip checking
--
--  local tail      = findtail(head)
--  local rightskip = nil
--  local right     = new_hlist()
--  local id        = getid(tail)
--  if id == glue_code then
--      local subtype = getsubtype(tail)
--      if subtype == rightskip_code then
--          rightskip = tail
--      end
--  end
--  if not rightskip then
--      print("inserting rightskip")
--      rightskip = new_rightskip()
--      insert_after(head,tail,rightskip)
--      tail = rightskip
--  end
--  insert_after(head,tail,right)
--
--      tail    = tail,
--      right   = {
--          pack = right,
--          head = nil,
--          tail = nil,
--      }

-- todo: see if we can hook into box in buildpagefilter .. saves traverse

function paragraphs.normalize(head,...)
    if texgetcount("pagebodymode") > 0 then
        -- can be an option, maybe we need a proper state in lua itself
        return head, false
    end
    for line in traverse_id(hlist_code,tonut(head)) do
        if getsubtype(line) == line_code then
            local head     = getlist(line)
            local leftskip = nil
            local anchor   = new_hlist()
            local id       = getid(head)
            local shift    = getfield(line,"shift")
            local width    = getfield(line,"width")
            local hsize    = tex.hsize
            local reverse  = getfield(line,"dir") == "TRT" or false
            if id == glue_code then
                local subtype = getsubtype(head)
                if subtype == leftskip_code then
                    leftskip  = head
                end
                local next = getnext(head)
                if next and getsubtype(next) == localpar_code then
                    head = remove_node(head,next,true)
                end
            elseif id == whatsit_code then
                if getsubtype(head) == localpar_code then
                    head = remove_node(head,head,true)
                end
            end
            head = insert_before(head,head,anchor)
            if reverse then
                shift = shift + width - hsize
                head  = insert_before(head,head,new_kern(shift))
                insert_after(head,anchor,new_kern(-shift))
            else
                head = insert_before(head,head,new_kern(-shift))
            end
            if not leftskip then
                head = insert_before(head,head,new_leftskip(0))
            end
setfield(anchor,"attr",getfield(line,"attr"))
-- print(nodes.idstostring(head))
-- print("NORMALIZE",line)
            setfield(line,"list",head)
            setprop(line,"line",{
                reverse = reverse,
                width   = width,
                hsize   = hsize,
                shift   = shift,
                head    = head,
                anchor  = {
                    pack = anchor,
                    head = nil,
                    tail = nil,
                },
            })
        end
    end
    return head, true
end

function paragraphs.addtoline(n,list)
    local line = getprop(n,"line")
    if line then
        if trace_anchors and not line.traced then
            line.traced = true
            local rule = new_rule(2*65536,2*65536,1*65536)
            local list = insert_before(rule,rule,new_kern(-1*65536))
            paragraphs.addtoline(n,list)
        end
        local list = tonut(list)
        local what = line.anchor
        local tail = what.tail
        local blob = new_hlist(list)
        if tail then
            insert_after(what.head,what.tail,blob)
        else
            setfield(what.pack,"list",blob)
            what.head = blob
        end
        what.tail = blob
    end
end
