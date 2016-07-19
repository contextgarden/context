if not modules then modules = { } end modules ['scrn-hlp'] = {
    version   = 1.001,
    comment   = "companion to scrn-hlp.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber = tonumber

local help            = { }
interactions.help     = help

local context         = context
local implement       = interfaces.implement

local formatters      = string.formatters

local a_help          = attributes.private("help")

local copy_node_list  = node.copy_list
local hpack_node_list = node.hpack

local register_list   = nodes.pool.register

local texgetbox       = tex.getbox

local nodecodes       = nodes.nodecodes

local hlist_code      = nodecodes.hlist
local vlist_code      = nodecodes.vlist

local data, references = { }, { }

local helpscript = [[
    function Hide_All_Help(prefix) {
        var n = 0
        while (true) {
            n += 1 ;
            v = this.getField(prefix + n) ;
            if (v) {
                v.hidden = true ;
                this.dirty = false ;
            } else {
                return ;
            }
        }
    }
]]

local template = "javascript(Hide_All_Help{help:}),action(show{help:%s})"

local function register(specification)
    local number = specification.number
    local name   = specification.name
    local box    = specification.box
    if number and name and box then
        if helpscript then
            interactions.javascripts.setpreamble("HelpTexts",helpscript)
            helpscript = false
        end
        local b = copy_node_list(texgetbox(box))
        register_list(b)
        data[number] = b
        if name and name ~= "" then
            references[name] = number
            structures.references.define("",name,formatters[template](number))
        end
    end
end

local function collectused(head,used)
    while head do
        local id = head.id
        if id == hlist_code then
            local a = head[a_help]
            if a then
                if not used then
                    used = { a }
                else
                    used[#used+1] = a
                end
            else
                used = collectused(head.list,used)
            end
        elseif id == vlist_code then
            used = collectused(head.list,used)
        end
        head = head.next
    end
    return used
end

local function collect(box)
    if next(data) then
        return collectused(texgetbox(box).list)
    end
end

local function reference(name)
    return references[name] or tonumber(name) or 0
end

help.register  = register
help.collect   = collect
help.reference = reference

implement {
    name    = "registerhelp",
    actions = register,
    arguments = {
        {
            { "number", "integer" },
            { "name" },
            { "box" , "integer" }
        }
    }
}

implement {
    name      = "collecthelp",
    arguments = "integer",
    actions   = function(box)
        local used = collect(box)
        if used then
            local done = { }
            context.startoverlay()
            for i=1,#used do
                local d = data[used[i]]
                if d and not done[d] then
                    local box = hpack_node_list(copy_node_list(d))
                    context(false,box)
                    done[d] = true
                else
                    -- error
                end
            end
            context.stopoverlay()
        end
    end
}

implement {
    name      = "helpreference",
    arguments = "string",
    actions   = function(name)
        context(reference(name))
    end
}

implement {
    name      = "helpaction",
    arguments = "string",
    actions   = function(name)
        context(template,reference(name))
    end
}
