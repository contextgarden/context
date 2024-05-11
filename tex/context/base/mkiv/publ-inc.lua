if not modules then modules = { } end modules ['publ-inc'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local fullstrip = string.fullstrip
local datasets, savers = publications.datasets, publications.savers
local assignbuffer = buffers.assign

interfaces.implement {
    name      = "btxentrytobuffer",
    arguments = "3 strings",
    actions   = function(dataset,tag,target)
        local d = datasets[dataset]
        if d then
            d = d.luadata[tag]
        end
        if d then
            d = fullstrip(savers.bib(dataset,false,{ [tag] = d }))
        end
        assignbuffer(target,d or "")
    end
}

do

    local expandmacro = token.expandmacro
    local nodelisttoutf = nodes.toutf
    local texgetbox = tex.getbox
    local settings_to_array = utilities.parsers.settings_to_array

    local meanings        = { }
    local done            = { }
    publications.meanings = meanings

    table.setmetatableindex(meanings,function(t,k)
        expandmacro("publ_cite_set_meaning",true,k)
        local v = nodelisttoutf(texgetbox("b_btx_cmd").list)
        t[k] = v
        return v
    end)

    interfaces.implement {
        name      = "btxentrytostring",
        public    = true,
        protected = true,
        arguments = "3 strings",
        actions   = function(command,again,tag)
            -- we need to collect multiple
            local set = settings_to_array(tag)
            for i=1,#set do
                tag = set[i]
                if i > 1 then
                    context.thinspace()
                end
                local meaning = meanings[tag]
                if done[tag] then
                    context[again]( { "publ:" .. tag } )
                else
                    context[command]( { "publ:" .. tag }, meaning )
                    done[tag] = true
                end
            end
        end
    }

end
