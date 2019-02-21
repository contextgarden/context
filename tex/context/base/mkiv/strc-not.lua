if not modules then modules = { } end modules ['strc-not'] = {
    version   = 1.001,
    comment   = "companion to strc-not.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format
local next = next

local trace_notes      = false  trackers.register("structures.notes",            function(v) trace_notes      = v end)
local trace_references = false  trackers.register("structures.notes.references", function(v) trace_references = v end)

local report_notes     = logs.reporter("structure","notes")

local structures       = structures
local helpers          = structures.helpers
local lists            = structures.lists
local sections         = structures.sections
local counters         = structures.counters
local notes            = structures.notes
local references       = structures.references
local counterspecials  = counters.specials

local texgetcount      = tex.getcount
local texgetbox        = tex.getbox

-- todo: allocate

notes.states           = notes.states or { }
lists.enhancers        = lists.enhancers or { }
notes.numbers          = notes.numbers or { }

storage.register("structures/notes/states", notes.states, "structures.notes.states")

local notestates = notes.states
local notedata   = table.setmetatableindex("table")

local variables  = interfaces.variables
local context    = context
local commands   = commands

local implement  = interfaces.implement

-- state: store, insert, postpone

local function store(tag,n)
    -- somewhat weird but this is a cheap hook spot
    if not counterspecials[tag] then
        counterspecials[tag] = function(tag)
            context.doresetlinenotecompression(tag) -- maybe flag that controls it
        end
    end
    --
    local nd = notedata[tag]
    local nnd = #nd + 1
    nd[nnd] = n
    local state = notestates[tag]
    if not state then
        report_notes("unknown state for %a",tag)
    elseif state.kind ~= "insert" then
        if trace_notes then
            report_notes("storing %a with state %a as %a",tag,state.kind,nnd)
        end
        state.start = state.start or nnd
    end
    return nnd
end

notes.store = store

implement {
    name      = "storenote",
    actions   = { store, context },
    arguments = { "string", "integer" }
}

local function get(tag,n) -- tricky ... only works when defined
    local nd = notedata[tag]
    if not n then
        n = #nd
    end
    nd = nd[n]
    if nd then
        if trace_notes then
            report_notes("getting note %a of %a with listindex %a",n,tag,nd)
        end
        -- is this right?
        local newdata = lists.cached[nd]
        return newdata
    end
end

local function getn(tag)
    return #notedata[tag]
end

notes.get  = get
notes.getn = getn

-- we could make a special enhancer

local function listindex(tag,n)
    local ndt = notedata[tag]
    return ndt and ndt[n]
end

notes.listindex = listindex

implement {
    name      = "notelistindex",
    actions   = { listindex, context },
    arguments = { "string", "integer" }
}

local function setstate(tag,newkind)
    local state = notestates[tag]
    if trace_notes then
        report_notes("setting state of %a from %s to %s",tag,(state and state.kind) or "unset",newkind)
    end
    if not state then
        state = {
            kind = newkind
        }
        notestates[tag] = state
    elseif newkind == "insert" then
        if not state.start then
            state.kind = newkind
        end
    else
-- if newkind == "postpone" and state.kind == "store" then
-- else
        state.kind = newkind
-- end
    end
    --  state.start can already be set and will be set when an entry is added or flushed
    return state
end

local function getstate(tag)
    local state = notestates[tag]
    return state and state.kind or "unknown"
end

notes.setstate        = setstate
notes.getstate        = getstate



implement {
    name      = "setnotestate",
    actions   = setstate,
    arguments = "2 strings",
}

implement {
    name      = "getnotestate",
    actions   = { getstate, context },
    arguments = "string"
}

function notes.define(tag,kind,number)
    local state = setstate(tag,kind)
    notes.numbers[number] = state
    state.number = number
end

implement {
    name      = "definenote",
    actions   = notes.define,
    arguments = { "string", "string", "integer" }
}

function notes.save(tag,newkind)
    local state = notestates[tag]
    if state and not state.saved then
        if trace_notes then
            report_notes("saving state of %a, old: %a, new %a",tag,state.kind,newkind or state.kind)
        end
        state.saveddata = notedata[tag]
        state.savedkind = state.kind
        state.kind = newkind or state.kind
        state.saved = true
        notedata[tag] = { }
    end
end

function notes.restore(tag,forcedstate)
    local state = notestates[tag]
    if state and state.saved then
        if trace_notes then
            report_notes("restoring state of %a, old: %a, new: %a",tag,state.kind,state.savedkind)
        end
        notedata[tag] = state.saveddata
        state.kind = forcedstate or state.savedkind
        state.saveddata = nil
        state.saved = false
    end
end

implement { name = "savenote",    actions = notes.save,    arguments = "2 strings" }
implement { name = "restorenote", actions = notes.restore, arguments = "2 strings" }

local function hascontent(tag)
    local ok = notestates[tag]
    if ok then
        if ok.kind == "insert" then
            ok = texgetbox(ok.number)
            if ok then
                ok = tbs.list
                ok = lst and lst.next
            end
        else
            ok = ok.start
        end
    end
    return ok and true or false
end

notes.hascontent = hascontent

implement {
    name      = "doifnotecontent",
    actions   = { hascontent, commands.doif },
    arguments = "string",
}

local function internal(tag,n)
    local nd = get(tag,n)
    if nd then
        local r = nd.references
        if r then
            local i = r.internal
            return i and references.internals[i] -- dependency on references
        end
    end
    return nil
end

local function ordered(kind,name,n)
    local o = lists.ordered[kind]
    o = o and o[name]
    return o and o[n]
end

notes.internal = internal
notes.ordered  = ordered

-- local function onsamepageasprevious(tag)
--     local same     = false
--     local n        = getn(tag,n)
--     local current  = get(tag,n)
--     local previous = get(tag,n-1)
--     if current and previous then
--         local cr = current.references
--         local pr = previous.references
--         same = cr and pr and cr.realpage == pr.realpage
--     end
--     return same and true or false
-- end

local function onsamepageasprevious(tag)
    local n        = getn(tag,n)
    local current  = get(tag,n)
    if not current then
        return false
    end
    local cr = current.references
    if not cr then
        return false
    end
    local previous = get(tag,n-1)
    if not previous then
        return false
    end
    local pr = previous.references
    if not pr then
        return false
    end
    return cr.realpage == pr.realpage
end

notes.doifonsamepageasprevious = onsamepageasprevious

implement {
    name      = "doifnoteonsamepageasprevious",
    actions   = { onsamepageasprevious, commands.doifelse },
    arguments = "string",
}

function notes.checkpagechange(tag) -- called before increment !
    local nd = notedata[tag] -- can be unset at first entry
    if nd then
        local current = ordered("note",tag,#nd)
        local nextone = ordered("note",tag,#nd+1)
        if nextone then
            -- we can use data from the previous pass
            if nextone.pagenumber.number > current.pagenumber.number then
                counters.reset(tag)
            end
        elseif current then
            -- we need to locate the next one, best guess
            if texgetcount("realpageno") > current.pagenumber.number then
                counters.reset(tag)
            end
        end
    end
end

function notes.postpone()
    if trace_notes then
        report_notes("postponing all insert notes")
    end
    for tag, state in next, notestates do
        if state.kind ~= "store" then
            setstate(tag,"postpone")
        end
    end
end

implement {
    name    = "postponenotes",
    actions = notes.postpone
}

local function getinternal(tag,n)
    local li = internal(tag,n)
    if li then
        local references = li.references
        if references then
            return references.internal or 0
        end
    end
    return 0
end

local function getdeltapage(tag,n)
    -- 0:unknown 1:textbefore, 2:textafter, 3:samepage
    local li = internal(tag,n)
    if li then
        local references = li.references
        if references then
         -- local symb = structures.references.collected[""]["symb:"..tag..":"..n]
            local rymb = structures.references.collected[""]
            local symb = rymb and rymb["*"..(references.internal or 0)]
            local notepage   = references.realpage or 0
            local symbolpage = symb and symb.references.realpage or -1
            if trace_references then
                report_notes("note number %a of %a points from page %a to page %a",n,tag,symbolpage,notepage)
            end
            if notepage < symbolpage then
                return 3 -- after
            elseif notepage > symbolpage then
                return 2 -- before
            elseif notepage > 0 then
                return 1 -- same
            end
        else
            -- might be a note that is not flushed due to to deep
            -- nesting in a vbox
        end
    end
    return 0
end

notes.getinternal  = getinternal
notes.getdeltapage = getdeltapage

implement { name = "noteinternal",  actions = { getinternal,  context }, arguments = { "string", "integer" } }
implement { name = "notedeltapage", actions = { getdeltapage, context }, arguments = { "string", "integer" } }

local function flushnotes(tag,whatkind,how) -- store and postpone
    local state = notestates[tag]
    local kind = state.kind
    if kind == whatkind then
        local nd = notedata[tag]
        local ns = state.start -- first index
        if kind == "postpone" then
            if nd and ns then
                if trace_notes then
                    report_notes("flushing state %a of %a from %a to %a",whatkind,tag,ns,#nd)
                end
                for i=ns,#nd do
                    context.handlenoteinsert(tag,i)
                end
            end
            state.start = nil
            state.kind = "insert"
        elseif kind == "store" then
            if nd and ns then
                if trace_notes then
                    report_notes("flushing state %a of %a from %a to %a",whatkind,tag,ns,#nd)
                end
                -- todo: as registers: start, stop, inbetween
                for i=ns,#nd do
                    -- tricky : trialtypesetting
                    if how == variables.page then
                        local rp = get(tag,i)
                        rp = rp and rp.references
                        rp = rp and rp.symbolpage or 0
                        if rp > texgetcount("realpageno") then
                            state.start = i
                            return
                        end
                    end
                    if i > ns then
                        context.betweennoteitself(tag)
                    end
                    context.handlenoteitself(tag,i)
                end
            end
            state.start = nil
        elseif kind == "reset" then
            if nd and ns then
                if trace_notes then
                    report_notes("flushing state %a of %a from %a to %a",whatkind,tag,ns,#nd)
                end
            end
            state.start = nil
        elseif trace_notes then
            report_notes("not flushing state %a of %a",whatkind,tag)
        end
    elseif trace_notes then
        report_notes("not flushing state %a of %a",whatkind,tag)
    end
end

local function flushpostponednotes()
    if trace_notes then
        report_notes("flushing all postponed notes")
    end
    for tag, _ in next, notestates do
        flushnotes(tag,"postpone")
    end
end

implement {
    name    = "flushpostponednotes",
    actions = flushpostponednotes
}

implement {
    name      = "flushnotes",
    actions   = flushnotes,
    arguments = "3 strings",
}

function notes.resetpostponed()
    if trace_notes then
        report_notes("resetting all postponed notes")
    end
    for tag, state in next, notestates do
        if state.kind == "postpone" then
            state.start = nil
            state.kind = "insert"
        end
    end
end

implement {
    name      = "notetitle",
    actions   = function(tag,n) lists.savedlisttitle(tag,notedata[tag][n]) end,
    arguments = { "string", "integer" }
}

implement {
    name      = "noteprefixednumber",
    actions   = function(tag,n) lists.savedlistprefixednumber(tag,notedata[tag][n]) end,
    arguments = { "string", "integer" }
}

function notes.internalid(tag,n)
    local nd = get(tag,n)
    if nd then
        local r = nd.references
        return r.internal
    end
end

-- for the moment here but better in some builder modules

-- gets register "n" and location "i" (where 1 is before)

-- this is an experiment, we will make a more general handler instead
-- of the current note one

local report_insert = logs.reporter("pagebuilder","insert")
local trace_insert  = false  trackers.register("pagebuilder.insert",function(v) trace_insert = v end)

local texgetglue = tex.getglue
local texsetglue = tex.setglue

local function check_spacing(n,i)
    local gn, pn, mn = texgetglue(n)
    local gi, pi, mi = texgetglue(i > 1 and "s_strc_notes_inbetween" or "s_strc_notes_before")
    local gt, pt, mt = gn + gi, pn + pi, mn + mi
    if trace_insert then
        report_insert("%s %i: %p plus %p minus %p","always   ",n,gn,pn,mn)
        report_insert("%s %i: %p plus %p minus %p",i > 1 and "inbetween" or "before   ",n,gi,pi,mi)
        report_insert("%s %i: %p plus %p minus %p","effective",n,gt,pt,mt)
    end
    return gt, pt, mt
end

notes.check_spacing = check_spacing

callback.register("build_page_insert", function(n,i)
    local state = notes.numbers[n]
    if state then
        -- only notes, kind of hardcoded .. bah
        local gt, pt, mt = check_spacing(n,i)
        texsetglue(0,gt,pt,mt) -- for the moment we use skip register 0
        return 0
    else
        return n
    end
end)
