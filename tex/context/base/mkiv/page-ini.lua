if not modules then modules = { } end modules ['page-ini'] = {
    version   = 1.001,
    comment   = "companion to page-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber, rawget = tonumber, rawget
local gmatch = string.gmatch

local texgetcount  = tex.getcount

local ctx_testcase = commands.testcase

local data = table.setmetatableindex("table")
local last = 0

interfaces.implement {
    name      = "markpage",
    arguments = { "string", "string" },
    actions   = function(name,list)
        local realpage = texgetcount("realpageno")
        if list and list ~= "" then
            for sign, page in gmatch(list,"([%+%-])(%d+)") do
                page = tonumber(page)
                if page then
                    if sign == "+" then
                        page = realpage + page
                    end
                    data[page][name] = true
                end
            end
        else
            data[realpage][name] = true
        end
    end
}

interfaces.implement {
    name      = "doifelsemarkedpage",
    arguments = "string",
    actions   = function(name)
        local realpage = texgetcount("realpageno")
        for i=last,realpage-1 do
            data[i] = nil
        end
        local pagedata = rawget(data,realpage)
        ctx_testcase(pagedata and pagedata[name])
    end
}
