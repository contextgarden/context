if not modules then modules = { } end modules ['meta-blb'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- This could be integrated in other modules but for me it also serves
-- as an example of usign the plugin mechanism.

local tonumber = tonumber

local setmetatableindex = table.setmetatableindex
local insert, remove = table.insert, table.remove

local topoints        = number.topoints
local mpprint         = mp.print
local mpinteger       = mp.integer
local mppoints        = mp.points
local mptriplet       = mp.triplet
local mptripletpoints = mp.tripletpoints

local texsetbox       = tex.setbox
local toutf           = nodes.toutf
local hpack_nodes     = nodes.hpack

local trace           = false
local report          = logs.reporter("metapost","blobs")

trackers.register("metapost.blobs", function(v) trace = v end)

-- We start with a text that comes from an analyze stage and can end up with
-- one or more results. For practical reasons we store the blobs in one array
-- and work with ranges.

local allblobs = { }

local function newcategory(t,k)
    if trace then
        report("new category %a",k)
    end
    local v = {
        name  = k,
        text  = "",
        blobs = { },
    }
    t[k] = v
    return v
end

local texblobs = setmetatableindex(newcategory)

local function blob_raw_reset(category)
    -- we need to keep the allblobs
    if category then
        if trace then
            report("reset category %a",category)
        end
        texblobs[category] = nil
    else
        if trace then
            report("reset all")
        end
        texblobs = setmetatableindex(newcategory)
    end
end

local function blob_raw_dimensions(i)
    local blob = allblobs[i]
    if blob then
        return blob.width, blob.height, blob.depth
    else
        return 0, 0, 0
    end
end

local function blob_raw_content(i)
    return allblobs[i]
end

local function blob_raw_toutf(i)
    return toutf(allblobs[i])
end

local function blob_raw_wipe(i)
    allblobs[i] = false
end

mp.blob_raw_dimensions = blob_raw_dimensions
mp.blob_raw_content    = blob_raw_content
mp.blob_raw_reset      = blob_raw_reset
mp.blob_raw_wipe       = blob_raw_wipe
mp.blob_raw_toutf      = blob_raw_toutf

function mp.blob_new(category,text)
    if trace then
        report("category %a, text %a",category,text)
    end
    texblobs[category].text = text
end

function mp.blob_add(category,blob)
    local tb = texblobs[category].blobs
    local tn = #allblobs + 1
    blob = hpack_nodes(blob)
    allblobs[tn] = blob
    tb[#tb+1] = tn
    if trace then
        report("category %a, blob %a set, content %a",category,tn,blob_raw_toutf(tn))
    end
end

function mp.blob_width(category,i)
    local index = texblobs[category].blobs[i]
    local blob  = allblobs[index]
    if blob then
        mppoints(blob.width or 0)
    else
        mpinteger(0)
    end
end

function mp.blob_size(category,i)
    mpprint(#texblobs[category].blobs or 0)
end

function mp.blob_index(category,i)
    mpprint(texblobs[category].blobs[i] or 0)
end

function mp.blob_dimensions(category,i)
    local index = texblobs[category].blobs[i]
    local blob  = allblobs[index]
    if blob then
        mptripletpoints(blob.width,blob.height,blob.depth)
    else
        mptriplet(0,0,0)
    end
end

local f_f  = string.formatters["%F"]
local sxsy = metapost.sxsy
local cm   = metapost.cm

local function injectblob(object,blob)
    local sx, rx, ry, sy, tx, ty = cm(object)
    local wd, ht, dp = blob_raw_dimensions(blob)
    if wd then
        object.path    = false
        object.color   = false
        object.grouped = true
        object.istext  = true
        return function()
            if trace then
                report("injecting blob %a, width %p, heigth %p, depth %p, text %a",blob,wd,ht,dp,blob_raw_toutf(blob))
            end
            context.MPLIBgetblobscaledcm(blob,
                f_f(sx), f_f(rx), f_f(ry),
                f_f(sy), f_f(tx), f_f(ty),
                sxsy(wd,ht,dp))
        end
    end
end

mp.blob_inject = injectblob

local function getblob(box,blob)
    texsetbox(box,blob_raw_content(blob))
    blob_raw_wipe(blob)
end

interfaces.implement {
    name      = "mpgetblob",
    actions   = getblob,
    arguments = { "integer", "integer" },
}

-- the plug:


local function reset()
    blob_raw_reset()
end

local function analyze(object,prescript)
    -- nothing
end

local function process(object,prescript,before,after)
--     if prescript.tb_stage == "inject" then
        local tb_blob = tonumber(prescript.tb_blob)
        if tb_blob then
            before[#before+1] = injectblob(object,tb_blob)
        end
--     end
end

metapost.installplugin {
    name    = "texblob",
    reset   = reset,
    analyze = analyze,
    process = process,
}

-- Here follows an example of usage of the above: a more modern
-- version of followokens (in meta-imp-txt.mkiv).

local nodecodes       = nodes.nodecodes
local kerncodes       = nodes.kerncodes

local glue_code       = nodecodes.glue
local kern_code       = nodecodes.kern
local c_userkern      = kerncodes.userkern
local c_fontkern      = kerncodes.fontkern
local c_italickern    = kerncodes.italickern
local a_fontkern      = attributes.private("fontkern")

local takebox         = tex.takebox
local flatten_list    = node.flatten_discretionaries
local remove_node     = nodes.remove
local flush_node      = nodes.flush

local addblob         = mp.blob_add
local newblob         = mp.blob_new

local visible_code = {
    [nodecodes.glyph] = true,
    [nodecodes.glue]  = true,
    [nodecodes.hlist] = true,
    [nodecodes.vlist] = true,
    [nodecodes.rule]  = true,
}

local function initialize(category,box)
    local wrap = takebox(box)
    if wrap then
        local head = wrap.list
        local tail = nil
        local temp = nil
        if head then
            local n = { }
            local s = 0
            head = flatten_list(head)
            local current = head
            while current do
                local id = current.id
                if visible_code[id] then
                    head, current, tail = remove_node(head,current)
                    s = s + 1
                    n[s] = tail
                elseif id == kern_code then
                    local subtype = current.subtype
                    if subtype == c_fontkern or subtype == italickern then -- or current[a_fontkern]
                        head, current, temp = remove_node(head,current)
                        tail.next = temp
                        temp.prev = tail
                        tail = temp
                    else
                        head, current, temp = remove_node(head,current)
                        s = s + 1
                        n[s] = temp
                    end
                elseif id == glue_code then
                    head, current, temp = remove_node(head,current)
                    s = s + 1
                    n[s] = temp
                else
                    current = current.next
                end
            end
            for i=1,s do
                n[i] = addblob(category,n[i])
            end
            wrap.list = head
        end
        flush_node(wrap)
    end
end

interfaces.implement {
    name      = "MPLIBconvertfollowtext",
    arguments = { "integer","integer" },
    actions   = initialize,
}

local ft_reset, ft_analyze, ft_process  do

    if metapost.use_one_pass then

        local mp_category = 0
        local mp_str      = ""

        function mp.InjectBlobB(category,str)
            newblob(category,str) -- only for tracing
            mp_category = category
            mp_str      = str
            tex.runtoks("mpblobtext")
        end

        interfaces.implement {
            name    = "mpblobtext",
            actions = function()
                context.MPLIBfollowtext(mp_category,mp_str)
            end
        }

        ft_process = function(object,prescript,before,after)
            if prescript.ft_category then
                object.path    = false
                object.color   = false
                object.grouped = true
                object.istext  = true
            end
        end


    else

        ft_reset = function()
            -- nothing
        end

        ft_analyze = function(object,prescript)
            if prescript.ft_stage == "trial" then
                local ft_category = tonumber(prescript.ft_category)
                if ft_category then
                    newblob(ft_category,object.postscript) -- only for tracing
                    context.MPLIBfollowtext(ft_category,object.postscript)
                    metapost.getjobdata().multipass = true
                end
            end
        end

        ft_process = function(object,prescript,before,after)
            if prescript.ft_stage == "final" then
                object.path    = false
                object.color   = false
                object.grouped = true
                object.istext  = true
            end
        end


    end

end

metapost.installplugin {
    name    = "followtext",
    reset   = ft_reset,
    analyze = ft_analyze,
    process = ft_process,
}
