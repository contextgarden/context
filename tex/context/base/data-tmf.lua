if not modules then modules = { } end modules ['data-tmf'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local resolvers  = resolvers

local report_tds = logs.reporter("resolvers","tds")

--  =  <<
--  ?  ??
--  <  +=
--  >  =+

function resolvers.load_tree(tree,resolve)
    if type(tree) == "string" and tree ~= "" then

        local getenv, setenv = resolvers.getenv, resolvers.setenv

        -- later might listen to the raw osenv var as well
        local texos   = "texmf-" .. os.platform

        local oldroot = environment.texroot
        local newroot = file.collapsepath(tree)

        local newtree = file.join(newroot,texos)
        local newpath = file.join(newtree,"bin")

        if not lfs.isdir(newtree) then
            report_tds("no %a under tree %a",texos,tree)
            os.exit()
        end
        if not lfs.isdir(newpath) then
            report_tds("no '%s/bin' under tree %a",texos,tree)
            os.exit()
        end

        local texmfos = newtree

        environment.texroot = newroot
        environment.texos   = texos
        environment.texmfos = texmfos

        -- Beware, we need to obey the relocatable autoparent so we
        -- set TEXMFCNF to its raw value. This is somewhat tricky when
        -- we run a mkii job from within. Therefore, in mtxrun, there
        -- is a resolve applied when we're in mkii/kpse mode or when
        -- --resolve is passed to mtxrun. Maybe we should also set the
        -- local AUTOPARENT etc. although these are alwasy set new.

        if resolve then
         -- resolvers.luacnfspec = resolvers.joinpath(resolvers.resolve(resolvers.expandedpathfromlist(resolvers.splitpath(resolvers.luacnfspec))))
            resolvers.luacnfspec = resolvers.resolve(resolvers.luacnfspec)
        end

        setenv('SELFAUTOPARENT', newroot)
        setenv('SELFAUTODIR',    newtree)
        setenv('SELFAUTOLOC',    newpath)
        setenv('TEXROOT',        newroot)
        setenv('TEXOS',          texos)
        setenv('TEXMFOS',        texmfos)
        setenv('TEXMFCNF',       resolvers.luacnfspec,true) -- already resolved
        setenv('PATH',           newpath .. io.pathseparator .. getenv('PATH'))

        report_tds("changing from root %a to %a",oldroot,newroot)
        report_tds("prepending %a to PATH",newpath)
        report_tds("setting TEXMFCNF to %a",resolvers.luacnfspec)
        report_tds()
    end
end
