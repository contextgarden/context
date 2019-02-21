if not modules then modules = { } end modules ['font-vir'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This is very experimental code! Not yet adapted to recent changes. This will change.</p>
--ldx]]--

-- present in the backend but unspecified:
--
-- vf.rule vf.special vf.right vf.push vf.down vf.char vf.node vf.fontid vf.pop vf.image vf.nop

local next, setmetatable, getmetatable = next, setmetatable, getmetatable

local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex
local fastcopy          = table.fastcopy

local fonts             = fonts
local constructors      = fonts.constructors
local vf                = constructors.handlers.vf
vf.version              = 1.000 -- same as tfm

--[[ldx--
<p>We overload the <l n='vf'/> reader.</p>
--ldx]]--

-- general code / already frozen
--
-- function vf.find(name)
--     name = file.removesuffix(file.basename(name))
--     if constructors.resolvevirtualtoo then
--         local format = fonts.loggers.format(name)
--         if format == 'tfm' or format == 'ofm' then
--             if trace_defining then
--                 report_defining("locating vf for %a",name)
--             end
--             return findbinfile(name,"ovf") or ""
--         else
--             if trace_defining then
--                 report_defining("vf for %a is already taken care of",name)
--             end
--             return ""
--         end
--     else
--         if trace_defining then
--             report_defining("locating vf for %a",name)
--         end
--         return findbinfile(name,"ovf") or ""
--     end
-- end
--
-- callbacks.register('find_vf_file', vf.find, "locating virtual fonts, insofar needed") -- not that relevant any more

-- specific code (will move to other module)

local definers     = fonts.definers
local methods      = definers.methods

local variants     = allocate()
local combinations = { }
local combiner     = { }
local whatever     = allocate()
local helpers      = allocate()
local predefined   = fonts.helpers.commands

methods.variants   = variants -- todo .. wrong namespace
vf.combinations    = combinations
vf.combiner        = combiner
vf.whatever        = whatever
vf.helpers         = helpers
vf.predefined      = predefined

setmetatableindex(whatever, function(t,k) local v = { } t[k] = v return v end)

local function checkparameters(g,f)
    if f and g and not g.parameters and #g.fonts > 0 then
        local p = { }
        for k,v in next, f.parameters do
            p[k] = v
        end
        g.parameters = p
        setmetatable(p, getmetatable(f.parameters))
    end
end

function methods.install(tag, rules)
    vf.combinations[tag] = rules
    variants[tag] = function(specification)
        return vf.combine(specification,tag)
    end
end

local function combine_load(g,name)
    return constructors.readanddefine(name or g.specification.name,g.specification.size)
end

local function combine_assign(g, name, from, to, start, force)
    local f, id = combine_load(g,name)
    if f and id then
        -- optimize for whole range, then just g = f
        if not from  then from, to = 0, 0xFF00 end
        if not to    then to       = from      end
        if not start then start    = from      end
        local fc = f.characters
        local gc = g.characters
        local fd = f.descriptions
        local gd = g.descriptions
        local hn = #g.fonts+1
        g.fonts[hn] = { id = id } -- no need to be sparse
        for i=from,to do
            if fc[i] and (force or not gc[i]) then
                gc[i] = fastcopy(fc[i],true) -- can be optimized
                gc[i].commands = { { "slot", hn, start } }
                gd[i] = fd[i]
            end
            start = start + 1
        end
        checkparameters(g,f)
    end
end

local function combine_process(g,list)
    if list then
        for _,v in next, list do
            (combiner.commands[v[1]] or nop)(g,v)
        end
    end
end

local function combine_names(g,name,force)
    local f, id = constructors.readanddefine(name,g.specification.size)
    if f and id then
        local fc = f.characters
        local gc = g.characters
        local fd = f.descriptions
        local gd = g.descriptions
        g.fonts[#g.fonts+1] = { id = id } -- no need to be sparse
        local hn = #g.fonts
        for k, v in next, fc do
            if force or not gc[k] then
                gc[k] = fastcopy(v,true)
                gc[k].commands = { { "slot", hn, k } }
                gd[i] = fd[i]
            end
        end
        checkparameters(g,f)
    end
end

local combine_feature = function(g,v)
    local key   = v[2]
    local value = v[3]
    if key then
        if value == nil then
            value = true
        end
        local specification = g.specification
        if specification then
            local normalfeatures = specification.features.normal
            if normalfeatures then
                normalfeatures[key] = value -- otf?
            end
        end
    end
end

--~ combiner.load    = combine_load
--~ combiner.assign  = combine_assign
--~ combiner.process = combine_process
--~ combiner.names   = combine_names
--~ combiner.feature = combine_feature

combiner.commands = allocate {
    ["initialize"]      = function(g,v) combine_assign    (g,g.properties.name) end,
    ["include-method"]  = function(g,v) combine_process   (g,combinations[v[2]])  end, -- name
 -- ["copy-parameters"] = function(g,v) combine_parameters(g,v[2]) end, -- name
    ["copy-range"]      = function(g,v) combine_assign    (g,v[2],v[3],v[4],v[5],true) end, -- name, from-start, from-end, to-start
    ["copy-char"]       = function(g,v) combine_assign    (g,v[2],v[3],v[3],v[4],true) end, -- name, from, to
    ["fallback-range"]  = function(g,v) combine_assign    (g,v[2],v[3],v[4],v[5],false) end, -- name, from-start, from-end, to-start
    ["fallback-char"]   = function(g,v) combine_assign    (g,v[2],v[3],v[3],v[4],false) end, -- name, from, to
    ["copy-names"]      = function(g,v) combine_names     (g,v[2],true) end,
    ["fallback-names"]  = function(g,v) combine_names     (g,v[2],false) end,
    ["feature"]         =               combine_feature,
}

function vf.combine(specification,tag)
    local g = {
        name          = specification.name,
        properties    = {
            virtualized = true,
        },
        fonts         = {
        },
        characters    = {
        },
        descriptions  = {
        },
        specification = fastcopy(specification),
    }
    combine_process(g,combinations[tag])
    return g
end
