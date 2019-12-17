if not modules then modules = { } end modules ['spac-ali'] = {
    version   = 1.001,
    comment   = "companion to spac-ali.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local div = math.div
local format = string.format

local tasks            = nodes.tasks
local enableaction     = tasks.enableaction

local nuts             = nodes.nuts
local nodepool         = nuts.pool

local tonode           = nuts.tonode
local tonut            = nuts.tonut

local getnext          = nuts.getnext
local getprev          = nuts.getprev
local getid            = nuts.getid
local getlist          = nuts.getlist
local setlist          = nuts.setlist
local setlink          = nuts.setlink
local getdirection     = nuts.getdirection
local takeattr         = nuts.takeattr
local getsubtype       = nuts.getsubtype
local getwidth         = nuts.getwidth
local findtail         = nuts.tail

local righttoleft_code = nodes.dirvalues.righttoleft

local hpack_nodes      = nuts.hpack

local unsetvalue       = attributes.unsetvalue

local nodecodes        = nodes.nodecodes
local listcodes        = nodes.listcodes

local hlist_code       = nodecodes.hlist
local vlist_code       = nodecodes.vlist

local linelist_code    = listcodes.line

local new_stretch      = nodepool.stretch

local a_realign        = attributes.private("realign")

local texsetattribute  = tex.setattribute
local texgetcount      = tex.getcount

local isleftpage       = layouts.status.isleftpage

typesetters            = typesetters or { }
local alignments       = { }
typesetters.alignments = alignments

local report_realign   = logs.reporter("typesetters","margindata")
local trace_realign    = trackers.register("typesetters.margindata", function(v) trace_margindata = v end)

local nofrealigned     = 0

--                leftskip   rightskip parfillskip
-- raggedleft      0 +         0          -
-- raggedright     0           0         fil
-- raggedcenter    0 +         0 +        -

local function handler(head,leftpage,realpageno) -- traverse_list
    local current = head
    while current do
        local id = getid(current)
        if id == hlist_code then
            if getsubtype(current) == linelist_code then
                local a = takeattr(current,a_realign)
                if not a or a == 0 then
                    -- skip
                else
                    local align = a % 10
                    local pageno = div(a,10)
                    if pageno == realpageno then
                        -- already ok
                    else
                        local action = 0
                        if align == 1 then -- flushright
                            action = leftpage and 1 or 2
                        elseif align == 2 then -- flushleft
                            action = leftpage and 2 or 1
                        end
                        -- WS: watch this
                        local direction = getdirection(current)
                        -- or should this happen at the tex end:
                        if direction == righttoleft_code then
                            if action == 1 then
                                action = 2
                            elseif action == 2 then
                                action = 1
                            end
                        end
                        --
                        if action == 1 then
                            local head = getlist(current)
                            setlink(findtail(head),new_stretch(3)) -- append
                            setlist(current,hpack_nodes(head,getwidth(current),"exactly",direction))
                            if trace_realign then
                                report_realign("flushing left, align %a, page %a, realpage %a",align,pageno,realpageno)
                            end
                        elseif action == 2 then
                            local list = getlist(current)
                            local head = setlink(new_stretch(3),list) -- prepend
                            setlist(current,hpack_nodes(head,getwidth(current),"exactly",direction))
                            if trace_realign then
                                report_realign("flushing right. align %a, page %a, realpage %a",align,pageno,realpageno)
                            end
                        elseif trace_realign then
                            report_realign("invalid flushing, align %a, page %a, realpage %a",align,pageno,realpageno)
                        end
                        nofrealigned = nofrealigned + 1
                    end
                end
            end
            handler(getlist(current),leftpage,realpageno)
        elseif id == vlist_code then
            handler(getlist(current),leftpage,realpageno)
        end
        current = getnext(current)
    end
    return head
end

function alignments.handler(head)
    return handler(head,isleftpage(),texgetcount("realpageno"))
end

local enabled = false

function alignments.set(n)
    if not enabled then
        enableaction("shipouts","typesetters.alignments.handler")
        enabled = true
        if trace_realign then
            report_realign("enabled")
        end
    end
    texsetattribute(a_realign,texgetcount("realpageno") * 10 + n)
end

interfaces.implement {
    name      = "setrealign",
    actions   = alignments.set,
    arguments = "integer",
}

statistics.register("realigning", function()
    if nofrealigned > 0 then
        return format("%s processed",nofrealigned)
    else
        return nil
    end
end)
