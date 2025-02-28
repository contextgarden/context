if not modules then modules = { } end modules ['data-ctx'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- only loaded in mtx-tool

local match = string.match
local basename, filesuffix = file.basename, file.suffix

local report = logs.reporter("libraries")

function resolvers.collectlibraries(root)
    root = (root or ".") .. "/"
    if lfs.isfile(root .. "tex/context/base/mkxl/context.mkxl") then
        local found = dir.glob(root .. "**")
        local files = { }
        for i=1,#found do
            local wanted = basename(found[i])
            local suffix = filesuffix(wanted)
            if suffix == "lfg" or suffix == "llg" then
                files[wanted] = true
                report("goodie : %s",name)
            else
                local category, name = match(wanted,"^(.*)%-imp%-(.*)$")
                if category and name then
                    files[wanted] = true
                    report("%s : %s",category,name)
                end
            end
        end
        --
        files["type-imp-tmatestonly.mkxl"] = true
        files["tmatestonly.lfg"] = true
        files["tmatestonly.llg"] = true
        --
        local name = "tex/context/base/mkxl/context-libraries.tma"
        report()
        report("saving %a", name)
        table.save(root .. name, {
            version = 1.0,
            name    = "libraries",
            comment = "these *-imp-* files should be distributed, if not complain",
            files   = files,
        })
    else
        report("run this on the distribution root, not %a",lfs.currentdir())
    end
end
