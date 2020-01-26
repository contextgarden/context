if not modules then modules = { } end modules ['strc-itm'] = {
    version   = 1.001,
    comment   = "companion to strc-itm.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local structures  = structures
local itemgroups  = structures.itemgroups
local jobpasses   = job.passes

local implement   = interfaces.implement

local setvariable = jobpasses.save
local getvariable = jobpasses.getfield

local texsetcount = tex.setcount
local texsetdimen = tex.setdimen

local f_stamp     = string.formatters["itemgroup:%s:%s"]
local counts      = table.setmetatableindex("number")

-- We keep the counter at the Lua end so we can group the items within
-- an itemgroup which in turn makes for less passes when one itemgroup
-- entry is added or removed.

local trialtypesetting = context.trialtypesetting

local function analyzeitemgroup(name,level)
    local n = counts[name]
    if level == 1 then
        n = n + 1
        counts[name] = n
    end
    local stamp = f_stamp(name,n)
    local n = getvariable(stamp,level,1,0)
    local w = getvariable(stamp,level,2,0)
    texsetcount("c_strc_itemgroups_max_items",n)
    texsetdimen("d_strc_itemgroups_max_width",w)
end

local function registeritemgroup(name,level,nofitems,maxwidth)
    local n = counts[name]
    if not trialtypesetting() then
        -- no trialtypsetting
        setvariable(f_stamp(name,n), { nofitems, maxwidth }, level)
    elseif level == 1 then
        counts[name] = n - 1
    end
end

implement {
    name      = "analyzeitemgroup",
    actions   = analyzeitemgroup,
    arguments = { "string", "integer" }
}

implement {
    name      = "registeritemgroup",
    actions   = registeritemgroup,
    arguments = { "string", "integer", "integer", "dimen" }
}
