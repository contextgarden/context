if not modules then modules = { } end modules ['lxml-dir'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local gsub = string.gsub
local formatters = string.formatters

-- <?xml version="1.0" standalone="yes"?>
-- <!-- demo.cdx -->
-- <directives>
-- <!--
--     <directive attribute='id' value="100" setup="cdx:100"/>
--     <directive attribute='id' value="101" setup="cdx:101"/>
-- -->
-- <!--
--     <directive attribute='cdx' value="colors"   element="cals:table" setup="cdx:cals:table:colors"/>
--     <directive attribute='cdx' value="vertical" element="cals:table" setup="cdx:cals:table:vertical"/>
--     <directive attribute='cdx' value="noframe"  element="cals:table" setup="cdx:cals:table:noframe"/>
-- -->
-- <directive attribute='cdx' value="*" element="cals:table" setup="cdx:cals:table:*"/>
-- </directives>

local lxml        = lxml
local context     = context

local getid       = lxml.getid

local directives  = lxml.directives or { }
lxml.directives   = directives

local report_lxml = logs.reporter("xml","tex")

local data = {
    setup  = { },
    before = { },
    after  = { }
}

local function load_setup(filename)
    local fullname = resolvers.findtexfile(filename) or ""
    if fullname ~= "" then
        filename = fullname
    end
    local collection = xml.applylpath({ getid(xml.load(filename)) },"directive") -- is { } needed ?
    if collection then
        local valid = 0
        for i=1,#collection do
            local at = collection[i].at
            local attribute, value, element = at.attribute or "", at.value or "", at.element or '*'
            local setup, before, after = at.setup or "", at.before or "", at.after or ""
            if attribute ~= "" and value ~= "" then
                local key = formatters["%s::%s::%s"](element,attribute,value)
                local t = data[key] or { }
                if setup  ~= "" then t.setup  = setup  end
                if before ~= "" then t.before = before end
                if after  ~= "" then t.after  = after  end
                data[key] = t
                valid = valid + 1
            end
        end
        report_lxml("%s directives found in %a, valid %s",#collection,filename,valid)
    else
        report_lxml("no directives found in %a",filename)
    end
end

local function handle_setup(category,root,attribute,element)
    root = getid(root)
    if attribute then
        local value = root.at[attribute]
        if value then
            if not element then
                local ns, tg = root.rn or root.ns, root.tg
                if ns == "" then
                    element = tg
                else
                    element = ns .. ':' .. tg
                end
            end
            local setup = data[formatters["%s::%s::%s"](element,attribute,value)]
            if setup then
                setup = setup[category]
            end
            if setup then
                context.directsetup(setup)
            else
                setup = data[formatters["%s::%s::*"](element,attribute)]
                if setup then
                    setup = setup[category]
                end
                if setup then
                    setup = gsub(setup,'%*',value)
                    context.directsetup(setup)
                end
            end
        end
    end
end

directives.load   = load_setup
directives.handle = handle_setup

function directives.setup(root,attribute,element)
    handle_setup('setup',root,attribute,element)
end

function directives.before(root,attribute,element)
    handle_setup('before',root,attribute,element)
end

function directives.after(root,attribute,element)
    handle_setup('after',root,attribute,element)
end
