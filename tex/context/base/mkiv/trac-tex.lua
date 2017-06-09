if not modules then modules = { } end modules ['trac-tex'] = {
    version   = 1.001,
    comment   = "companion to trac-deb.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local texhashtokens = tex.hashtokens

local trackers  = trackers
local token     = token
local saved     = { }
local create    = token.create
local undefined = create("undefined").command

function trackers.savehash()
    saved = texhashtokens()
    return saved
end

function trackers.dumphashtofile(filename,delta)
    local list   = { }
    local hash   = texhashtokens()
    local create = token.create
    for i=1,#hash do
        local name = hash[i]
        if not delta or not saved[name] then
            local token = create(name)
            if token.command ~= undefined then
                local category = token.cmdname
                local dk = list[category]
                if not dk then
                    dk = {
                        names = { },
                        found = 0,
                     -- code  = token[1],
                    }
                    list[category] = dk
                end
                if token.protected then
                    if token.expandable then
                        dk.names[name] = "ep"
                    else
                        dk.names[name] = "-p"
                    end
                else
                    if token.expandable then
                        dk.names[name] = "ep"
                    else
                        dk.names[name] = "--"
                    end
                end
                dk.found = dk.found + 1
            end
        end
    end
    table.save(filename or tex.jobname .. "-hash.log",list)
end

local delta = nil

local function dump_hash(wanteddelta)
    if delta == nil then
        saved = saved or trackers.savehash()
        luatex.registerstopactions(1,function() dump_hash(nil,wanteddelta) end) -- at front
    end
    delta = wanteddelta
end

directives.register("system.dumphash",  function() dump_hash(false) end)
directives.register("system.dumpdelta", function() dump_hash(true ) end)

local function saveusedfilesintrees(format)
    local data = {
        jobname = environment.jobname or "?",
        version = environment.version or "?",
        kind    = environment.kind    or "?",
        files   = resolvers.foundintrees()
    }
    local filename = file.replacesuffix(environment.jobname or "context-job",'jlg')
    if format == "lua" then
        io.savedata(filename,table.serialize(data,true))
    else
        io.savedata(filename,table.toxml(data,"job"))
    end
end

directives.register("system.dumpfiles", function(v)
    luatex.registerstopactions(function() saveusedfilesintrees(v) end)
end)

