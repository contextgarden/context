if not modules then modules = { } end modules ['grph-mem'] = {
    version   = 1.001,
    comment   = "companion to grph-inc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- very experimental and likely to change
--
-- \startluacode
--     figures.setmemstream("whatever",io.loaddata("t:/sources/cow.pdf"))
-- \stopluacode
--
-- \externalfigure[memstream:///t:/sources/cow.pdf]
-- \externalfigure[memstream:///whatever]

local report = logs.reporter("memstream")
local data   = { }
local trace  = false

function resolvers.finders.memstream(specification)
    local original   = specification.original
    local identifier = data[original]
    if identifier then
        if trace then
            report("reusing %a",identifier)
        end
        return identifier
    end
    local stream = io.loaddata(specification.path)
    if not stream or stream == "" then
        return resolvers.finders.notfound()
    end
    local memstream  = { epdf.openMemStream(stream,#stream,original) }
    local identifier = memstream[2]
    if not identifier then
        report("invalid %a",name)
        identifier = "invalid-memstream"
    elseif trace then
        report("using %a",identifier)
    end
    data[original]   = identifier
    return identifier
end

function resolvers.setmemstream(name,stream)
    local original   = "memstream:///" .. name
    local memstream  = { epdf.openMemStream(stream,#stream,original) }
    local identifier = memstream[2]
    if not identifier then
        report("invalid %a",name)
        identifier = "invalid-memstream"
    elseif trace then
        report("setting %a",identifier)
    end
    data[original] = identifier
end

figures.identifiers.list[#figures.identifiers.list+1] = function(specification)
    local name = specification.request.name
    if name and data[name] then
        specification.status.status = 1
        specification.used.fullname = name
    end
end

figures.setmemstream = resolvers.setmemstream
