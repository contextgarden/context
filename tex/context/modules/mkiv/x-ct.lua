if not modules then modules = { } end modules ['x-ct'] = {
    version   = 1.001,
    comment   = "companion to x-ct.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- needs testing

local xmlsprint, xmlcprint, xmlfilter, xmlcollected = xml.sprint, xml.cprint, xml.filter, xml.collected
local format, concat, rep, find = string.format, table.concat, string.rep, string.find

moduledata.ct = moduledata.ct or { }

local halignments = {
    left       = 'l',
    flushleft  = 'l',
    right      = 'r',
    flushright = 'r',
    center     = 'c',
    middle     = 'c',
    centre     = 'c',
    justify    = '',
}

local templates = { }

function moduledata.ct.registertabulatetemplate(name,str)
    templates[name] = str
end

local function roottemplate(root)
    local rt = root.at.template
    if rt then
        local template = templates[rt]
        if template then
            return template
        else
            if not find(rt,"|",1,true) then
                rt = gsub(rt,",","|")
            end
            if not find(rt,"^|") then rt = "|" .. rt end
            if not find(rt,"|$") then rt = rt .. "|" end
            return rt
        end
    end
end

local function specifiedtemplate(root,templatespec)
    local template = { }
    for e in xmlcollected(root,templatespec) do
        local at = e.at
        local tm = halignments[at.align] or ""
        if toboolean(at.paragraph) then
            tm = tm .. "p"
        end
        template[#template+1] = tm
    end
    if #template > 0 then
        return "|" .. concat(template,"|") .. "|"
    else
        return nil
    end
end

local function autotemplate(root,rowspec,cellspec)
    local max = 0
    for e in xmlcollected(root,rowspec) do
        local n = xml.count(e,cellspec)
        if n > max then max = n end
    end
    if max == 2 then
        return "|l|p|"
    elseif max > 0 then
        return "|" .. rep("p|",max)
    else
        return nil
    end
end

local defaulttemplate = "|l|p|"

function moduledata.ct.tabulate(root,namespace)
    if not root then
        return
    else
        root = lxml.id(root)
    end

    local prefix = (namespace or "context") .. ":"

    local templatespec = "/" .. prefix .. "template" .. "/" .. prefix .. "column"
    local bodyrowspec  = "/" .. prefix .. "body"     .. "/" .. prefix .. "row"
    local cellspec     = "/" .. prefix .. "cell"

    local template =
        roottemplate      (root) or
        specifiedtemplate (root,templatespec) or
        autotemplate      (root,bodyrowspec,cellspec) or
        defaulttemplate

    -- todo: head and foot

    local NC, NR = context.NC, context.NR

    lxml.directives.before(root,'cdx')
    context.bgroup()
    lxml.directives.setup(root,'cdx')
    context.starttabulate { template }
    for e in xmlcollected(root,bodyrowspec) do
        NC()
        for e in xmlcollected(e,cellspec) do
            xmlcprint(e)
            NC()
        end
        NR()
    end
    context.stoptabulate()
    context.egroup()
    lxml.directives.after(root,'cdx')

end

-- todo: use content and caption

function moduledata.ct.combination(root,namespace)

    if not root then
        return
    else
        root = lxml.id(root)
    end

    local prefix = (namespace or "context") .. ":"

    local pairspec    = "/" .. prefix .. "pair"
    local contentspec = "/" .. prefix .. "content" .. "/text()"
    local captionspec = "/" .. prefix .. "caption" .. "/text()"

    local nx, ny = root.at.nx, root.at.ny

    if not (nx or ny) then
        nx = xml.count(root,pairspec) or 2
    end
    local template = format("%s*%s", nx or 1, ny or 1)

    lxml.directives.before(root,'cdx')
    context.bgroup()
    lxml.directives.setup(root,'cdx')
    context.startcombination { template }
    for e in xmlcollected(root,pairspec) do
     -- context.combination(
     --     function() xmlfilter(e,contentspec) end,
     --     function() xmlfilter(e,captionspec) end
     -- )
        context("{")
        xmlfilter(e,contentspec)
        context("}{")
        xmlfilter(e,captionspec)
        context("}")
    end
    context.stopcombination()
    context.egroup()
    lxml.directives.after(root,'cdx')

end
