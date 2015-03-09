if not modules then modules = { } end modules ['trac-tex'] = {
    version   = 1.001,
    comment   = "companion to trac-deb.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- moved from trac-deb.lua

local next = next

local texhashtokens = tex.hashtokens

local trackers = trackers

local saved = { }

function trackers.savehash()
    saved = texhashtokens()
end

if newtoken then

    function trackers.dumphashtofile(filename,delta)
        local list   = { }
        local hash   = tex.hashtokens()
        local create = newtoken.create
        for name, token in next, hash do
            if not delta or not saved[name] then
                if token[2] ~= 0 then -- still old interface
                    local token = create(name)
                 -- inspect(token)
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

else

    function trackers.dumphashtofile(filename,delta)
        local list    = { }
        local hash    = texhashtokens()
        local getname = token.command_name
        for name, token in next, hash do
            if not delta or not saved[name] then
                -- token: cmd, chr, csid -- combination cmd,chr determines name
                local category = getname(token)
                local dk = list[category]
                if not dk then
                    -- a bit funny names but this sorts better (easier to study)
                    dk = { names = { }, found = 0, code = token[1] }
                    list[category] = dk
                end
                dk.names[name] = { token[2], token[3] }
                dk.found = dk.found + 1
            end
        end
        table.save(filename or tex.jobname .. "-hash.log",list)
    end

end

local delta = nil

local function dump_hash(wanteddelta)
    if delta == nil then
        saved = saved or texhashtokens() -- no need for trackers.dump_hash
        luatex.registerstopactions(1,function() dump_hash(nil,wanteddelta) end) -- at front
    end
    delta = wanteddelta
end

directives.register("system.dumphash",  function() dump_hash(false) end)
directives.register("system.dumpdelta", function() dump_hash(true ) end)

local report_dump = logs.reporter("resolvers","dump")

local function saveusedfilesintrees(format)
    local data = {
        jobname = environment.jobname or "?",
        version = environment.version or "?",
        kind    = environment.kind    or "?",
        files   = resolvers.instance.foundintrees
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

