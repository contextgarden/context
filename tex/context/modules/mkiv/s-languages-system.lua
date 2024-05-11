if not modules then modules = { } end modules ['s-languages-system'] = {
    version   = 1.001,
    comment   = "companion to s-languages-system.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.languages        = moduledata.languages        or { }
moduledata.languages.system = moduledata.languages.system or { }

local NC, NR, HL = context.NC, context.NR, context.HL
local sortedhash = table.sortedhash
local registered = languages.registered
local context    = context
local ctx_NC     = context.NC
local ctx_NR     = context.NR
local ctx_bold   = context.bold
local ctx_type   = context.type

function moduledata.languages.system.loadinstalled()
    context.start()
    for k, v in sortedhash(registered) do
        context.language{ k }
    end
    context.stop()
end

function moduledata.languages.system.showinstalled()
    --
    context.starttabulate { "|l|p(8em)|r|l|l|r|p|" }
        context.FL()
        ctx_NC() ctx_bold("tag")
        ctx_NC() ctx_bold("synonyms")
        ctx_NC() ctx_bold("id")
        ctx_NC() ctx_bold("parent")
        ctx_NC() ctx_bold("file")
        ctx_NC() ctx_bold("patterns")
        ctx_NC() ctx_bold("characters")
        ctx_NC() ctx_NR()
        context.FL()
        for k, v in sortedhash(registered) do
            local parent    = v.parent
            local resources = v.resources and v.resources[1]
            local patterns  = resources and resources.patterns
            ctx_NC()
--                 if tokens.isdefined(k) then
--                     context.tex(k)
--                 else
                    context(k)
--                 end
            ctx_NC()
                for k, v in sortedhash(v.synonyms) do
--                     if tokens.isdefined(k) then
--                         context.tex(k)
--                     else
                        context(k)
--                     end
                    context.par()
                end
            ctx_NC()
                context(v.number)
            ctx_NC()
                context(parent)
            ctx_NC()
                context(v.patterns) -- file
            if patterns then
                ctx_NC() context(patterns.n)
                ctx_NC() context("% t",utf.split(patterns.characters))
            else
                ctx_NC()
                ctx_NC()
            end
            ctx_NC() ctx_NR()
        end
        context.LL()
    context.stoptabulate()
    --
end
