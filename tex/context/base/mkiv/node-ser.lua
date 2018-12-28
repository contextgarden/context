if not modules then modules = { } end modules ['node-ser'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- beware, some field names will change in a next releases
-- of luatex; this is pretty old code that needs an overhaul

local type, tostring = type, tostring
local concat, tohash, sortedkeys, printtable, serialize = table.concat, table.tohash, table.sortedkeys, table.print, table.serialize
local formatters, format, rep = string.formatters, string.format, string.rep

local allocate = utilities.storage.allocate

local context     = context
local nodes       = nodes
local node        = node

local traverse    = nodes.traverse
local is_node     = nodes.is_node

local nodecodes   = nodes.nodecodes
local subtcodes   = nodes.codes
local getfields   = nodes.fields

local tonode      = nodes.tonode
local tonut       = nodes.tonut

local hlist_code  = nodecodes.hlist
local vlist_code  = nodecodes.vlist

----- utfchar     = utf.char
local f_char      = formatters["%U"]
local f_attr      = formatters["<%i>"]
----- fontchars   = { } table.setmetatableindex(fontchars,function(t,k) fontchars = fonts.hashes.characters return fontchars[k] end)

----- f_char      = utilities.strings.chkuni -- formatters["%!chkuni!"]

-- this needs checking with the latest state of affairs:

local expand = allocate ( tohash {
    -- text:
    "list",         -- list_ptr & ins_ptr & adjust_ptr
    "pre",          --
    "post",         --
    "replace",      -- nobreak
    "top_skip",     --
    "attr",         --
    "components",   -- lig_ptr
    "box_left",     --
    "box_right",    --
    "glyph",        -- margin_char
    "leader",       -- leader_ptr
    "action",       -- action_ptr
    "value",        -- user_defined nodes with subtype 'a' en 'n'
    "head",
    -- math:
    "nucleus",
    "sup",
    "sub",
    "list",
    "num",
    "denom",
    "left",
    "right",
    "display",
    "text",
    "script",
    "scriptscript",
    "delim",
    "degree",
    "accent",
    "bot_accent",
} )

-- page_insert: "height", "last_ins_ptr", "best_ins_ptr"
-- split_insert:  "height", "last_ins_ptr", "best_ins_ptr", "broken_ptr", "broken_ins"

local ignore = allocate ( tohash {
    "page_insert",
    "split_insert",
    "ref_count",
} )

local dimension = allocate ( tohash {
    "width", "height", "depth", "shift",
    "stretch", "shrink",
    "xoffset", "yoffset",
    "surround",
    "kern",
    "box_left_width", "box_right_width"
} )

-- flat    : don't use next, but indexes
-- verbose : also add type
-- todo    : speed up

nodes.dimensionfields = dimension
nodes.listablefields  = expand
nodes.ignorablefields = ignore

-- not ok yet:

local function astable(n,sparse) -- not yet ok, might get obsolete anyway
    n = tonode(n)
    local f = getfields(n)
    local t = { }
    for i=1,#f do
        local v = f[i]
        local d = n[v]
        if d then
            if ignore[v] or v == "id" then
                -- skip
            elseif expand[v] then -- or: type(n[v]) ~= "string" or type(n[v]) ~= "number" or type(n[v]) ~= "table"
                t[v] = "<list>"
            elseif sparse then
                if (type(d) == "number" and d ~= 0) or (type(d) == "string" and d ~= "") then
                    t[v] = d
                end
            else
                t[v] = d
            end
        end
    end
    t.type = nodecodes[n.id]
    return t
end

nodes.astable = astable

setinspector("node",function(v) if is_node(v) then printtable(astable(v),tostring(v)) return true end end)

-- under construction:

local function totable(n,flat,verbose,noattributes) -- nicest: n,true,true,true
    local function to_table(n,flat,verbose,noattributes) -- no need to pass
        local f  = getfields(n)
        local tt = { }
        for k=1,#f do
            local v = f[k]
            local nv = v and n[v]
            if nv then
                if ignore[v] then
                    -- skip
                elseif noattributes and v == "attr" then
                    tt[v] = f_attr(tonut(nv))
                    -- skip
                elseif v == "prev" then
                    tt[v] = "<node>"
                elseif expand[v] then
                    if type(nv) == "number" or type(nv) == "string" then
                        tt[v] = nv
                    else
                        tt[v] = totable(nv,flat,verbose,noattributes)
                    end
                elseif type(nv) == "table" then
                    tt[v] = nv -- totable(nv,flat,verbose) -- data
                else
                    tt[v] = nv
                end
            end
        end
        if verbose then
            local subtype = tt.subtype
            local id = tt.id
            local nodename = nodecodes[id]
            tt.id = nodename
            local subtypes = subtcodes[nodename]
            if subtypes then
                tt.subtype = subtypes[subtype]
            elseif subtype == 0 then
                tt.subtype = nil
            else
                -- we need a table
            end
            if tt.char then
                tt.char = f_char(tt.char)
            end
            if tt.small_char then
                tt.small_char = f_char(tt.small_char)
            end
            if tt.large_char then
                tt.large_char = f_char(tt.large_char)
            end
        end
        return tt
    end
    if n then
        if flat then
            local t, tn = { }, 0
            while n do
                tn = tn + 1
                local nt = to_table(n,flat,verbose,noattributes)
                t[tn] = nt
                nt.next = nil
                nt.prev = nil
                n = n.next
            end
            return t
        else
            local t = to_table(n,flat,verbose,noattributes)
            local n = n.next
            if n then
                t.next = totable(n,flat,verbose,noattributes)
            end
            return t
        end
    else
        return { }
    end
end

nodes.totable = function(n,...) return totable(tonode(n),...) end
nodes.totree  = function(n)     return totable(tonode(n),true,true,true) end -- no attributes, todo: attributes in k,v list

local function key(k)
    return ((type(k) == "number") and "["..k.."]") or k
end

function nodes.serialize(root,flat,verbose,noattributes,name)
    return serialize(totable(tonode(root),flat,verbose,noattributes),name)
end

function nodes.serializebox(n,flat,verbose,noattributes,name)
    return serialize(totable(tex.box[n],flat,verbose,noattributes),name)
end

function nodes.visualizebox(n,flat,verbose,noattributes,name)
    context.tocontext(totable(tex.box[n],flat,verbose,noattributes),name)
end

function nodes.list(head,n) -- name might change to nodes.type -- to be checked .. will move to module anyway
    head = tonode(head)
    if not n then
        context.starttyping(true)
    end
    while head do
        local id = head.id
        context(rep(" ",n or 0) .. tostring(head) .. "\n")
        if id == hlist_code or id == vlist_code then
            nodes.list(head.list,(n or 0)+1)
        end
        head = head.next
    end
    if not n then
        context.stoptyping(true)
    end
end

function nodes.print(head,n)
    head = tonode(head)
    while head do
        local id = head.id
        logs.writer(string.formatters["%w%S"],n or 0,head)
        if id == hlist_code or id == vlist_code then
            nodes.print(head.list,(n or 0)+1)
        end
        head = head.next
    end
end

-- quick hack, nicer is to have a proper expand per node type
-- already prepared

local function apply(n,action)
    while n do
        action(n)
        local id = n.id
        if id == hlist_code or id == vlist_code then
            apply(n.list,action)
        end
        n = n.next
    end
end

nodes.apply = apply

local nuts    = nodes.nuts
local getid   = nuts.getid
local getlist = nuts.getlist
local getnext = nuts.getnext

local function apply(n,action)
    while n do
        action(n)
        local id = getid(n)
        if id == hlist_code or id == vlist_code then
            local list = getlist(n,action)
            if list then
                apply(list,action)
            end
        end
        n = getnext(n)
    end
end

nuts.apply = apply
