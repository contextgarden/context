if not modules then modules = { } end modules ['scrn-wid'] = {
    version   = 1.001,
    comment   = "companion to scrn-wid.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Support for interactive features is handled elsewhere. Now that is some mess! In
-- the early days one had media features like sound and movies that were easy to set
-- up. Then at some point renditions came around which were more work and somewhat
-- unreliable. Now, both mechanism are obsolete and replaced by rich media which is
-- a huge mess and has no real concept of what media are supported. There's flash
-- cq. shockwave (basically obsolete too), and for instance mp4 needs to be handled
-- by a swf player, and there's u3d which somehow has its own specification. One
-- would expect native support for video and audio to be en-par with browsers but
-- alas ... pdf has lost the battle with html here due to a few decades of
-- unstability and changing support. So far we could catch on and even were ahead
-- but I wonder if we should keep doing that. As we can't trust support for media we
-- can better not embed anything and just use a hyperlink to an external resource. No
-- sane person will create media rich pdf's as long as it's that unpredictable. Just
-- look at the specification and viewer preferences and decide.

local next = next

interactions             = interactions or { }
local interactions       = interactions

local context            = context
local implement          = interfaces.implement

local allocate           = utilities.storage.allocate

local attachments        = allocate()
local comments           = allocate()
local soundclips         = allocate()
local renderings         = allocate()
local linkedlists        = allocate()

interactions.attachments = attachments
interactions.soundclips  = soundclips
interactions.renderings  = renderings
interactions.linkedlists = linkedlists

local texsetbox          = tex.setbox

local jobpasses          = job.passes

local texgetcount        = tex.getcount

local codeinjections     = backends.codeinjections
local nodeinjections     = backends.nodeinjections

local variables          = interfaces.variables
local v_auto             = variables.auto

local trace_attachments = false  trackers.register("widgets.attachments", function(v) trace_attachments = v end)

local report_attachments = logs.reporter("widgets","attachments")

-- Symbols

implement {
    name      = "presetsymbollist",
    arguments = "string",
    actions   = function(list)
        codeinjections.presetsymbollist(list)
    end
}

-- Attachments
--
-- registered : unique id
-- tag        : used at the tex end
-- file       : name that the file has on the filesystem
-- name       : name that the file will get in the output
-- title      : up to the backend
-- subtitle   : up to the backend
-- author     : up to the backend
-- method     : up to the backend (hidden == no rendering)

local nofautoattachments, lastregistered = 0, nil

local function checkregistered(specification)
    local registered = specification.registered
    if not registered or registered == "" or registered == v_auto then
        nofautoattachments = nofautoattachments + 1
        lastregistered = "attachment-" .. nofautoattachments
        specification.registered = lastregistered
        return lastregistered
    else
        return registered
    end
end

local function checkbuffer(specification)
    local buffer = specification.buffer
    if buffer ~= "" then
        specification.data = buffers.getcontent(buffer) or "<no data>"
    end
end

function attachments.register(specification) -- beware of tag/registered mixup(tag is namespace)
    local registered = checkregistered(specification)
    checkbuffer(specification)
    attachments[registered] = specification
    if trace_attachments then
        report_attachments("registering %a",registered)
    end
    return specification
end

function attachments.insert(specification)
    local registered = checkregistered(specification)
    local r = attachments[registered]
    if r then
        if trace_attachments then
            report_attachments("including registered %a",registered)
        end
        for k, v in next, r do
            local s = specification[k]
            if s == "" then
                specification[k] = v
            end
        end
    elseif trace_attachments then
        report_attachments("including unregistered %a",registered)
    end
    checkbuffer(specification)
    return nodeinjections.attachfile(specification)
end

implement {
    name      = "registerattachment",
    actions   = attachments.register,
    arguments = {
        {
            { "tag" },
            { "registered" },
            { "title" },
            { "subtitle" },
            { "author" },
            { "file" },
            { "name" },
            { "buffer" },
            { "mimetype" },
        }
    }
}

implement {
    name      = "insertattachment",
    actions   = function(specification)
                    texsetbox("b_scrn_attachment_link",(attachments.insert(specification)))
                end,
    arguments = {
        {
            { "tag" },
            { "registered" },
            { "method" },
            { "width", "dimen" },
            { "height", "dimen" },
            { "depth", "dimen" },
            { "colormodel", "integer" },
            { "colorvalue", "integer" },
            { "color" },
            { "transparencyvalue", "integer" },
            { "symbol" },
            { "layer" },
            { "title" },
            { "subtitle" },
            { "author" },
            { "file" },
            { "name" },
            { "buffer" },
            { "mimetype" },
        }
    }
}

-- Comment

function comments.insert(specification)
    local buffer = specification.buffer
    if buffer ~= "" then
        specification.data = buffers.getcontent(buffer) or ""
    end
    return nodeinjections.comment(specification)
end

implement {
    name      = "insertcomment",
    actions   = function(specification)
                    texsetbox("b_scrn_comment_link",(comments.insert(specification)))
                end,
    arguments = {
        {
            { "tag" },
            { "title" },
            { "subtitle" },
            { "author" },
            { "width", "dimen" },
            { "height", "dimen" },
            { "depth", "dimen" },
            { "nx" },
            { "ny" },
            { "colormodel", "integer" },
            { "colorvalue", "integer" },
            { "transparencyvalue", "integer" },
            { "option" },
            { "symbol" },
            { "buffer" },
            { "layer" },
            { "space" },
        }
    }
}

-- Soundclips

function soundclips.register(specification)
    local tag = specification.tag
    if tag and tag ~= "" then
        local filename = specification.file
        if not filename or filename == "" then
            filename = tag
            specification.file = filename
        end
        soundclips[tag] = specification
        return specification
    end
end

function soundclips.insert(tag)
    local sc = soundclips[tag]
    if not sc then
        -- todo: message
        return soundclips.register { tag = tag }
    else
        return sc
    end
end

implement {
    name      = "registersoundclip",
    actions   = soundclips.register,
    arguments = {
        {
            { "tag" },
            { "file" }
        }
    }
}

implement {
    name      = "insertsoundclip",
    actions   = soundclips.insert,
    arguments = {
        {
            { "tag" },
            { "repeat" }
        }
    }
}

-- Renderings

function renderings.register(specification)
    if specification.label then
        renderings[specification.label] = specification
        return specification
    end
end

function renderings.rendering(label)
    local rn = renderings[label]
    if not rn then
        -- todo: message
        return renderings.register { label = label }
    else
        return rn
    end
end

function renderings.var(label,key)
    local rn = renderings[label]
    return rn and rn[key] or ""
end

implement {
    name      = "renderingvar",
    actions   = { renderings.var, context },
    arguments = "2 strings",
}

implement {
    name      = "registerrendering",
    actions   = renderings.register,
    arguments = {
        {
            { "type" },
            { "label" },
            { "mime" },
            { "filename" },
            { "option" },
        }
    }
}

-- Rendering:

implement {
    name      = "insertrenderingwindow",
    actions   = function(specification)
                    codeinjections.insertrenderingwindow(specification)
                end,
    arguments = {
        {
            { "label" },
            { "width", "dimen" },
            { "height", "dimen"  },
            { "option" },
            { "page", "integer" },
        }
    }
}

-- Linkedlists (only a context interface)

implement {
    name      = "definelinkedlist",
    arguments = "string",
    actions   = function(tag)
                    -- no need
                end
}

implement {
    name      = "enhancelinkedlist",
    arguments = { "string", "integer" },
    actions   = function(tag,n)
                    local ll = jobpasses.gettobesaved(tag)
                    if ll then
                        ll[n] = texgetcount("realpageno")
                    end
                end
}

implement {
    name      = "addlinklistelement",
    arguments = "string",
    actions   = function(tag)
                    local tobesaved   = jobpasses.gettobesaved(tag)
                    local collected   = jobpasses.getcollected(tag) or { }
                    local currentlink = #tobesaved + 1
                    local noflinks    = #collected
                    tobesaved[currentlink] = 0
                    local f = collected[1] or 0
                    local l = collected[noflinks] or 0
                    local p = collected[currentlink-1] or f
                    local n = collected[currentlink+1] or l
                    context.setlinkedlistproperties(currentlink,noflinks,f,p,n,l)
                 -- context.ctxlatelua(function() commands.enhancelinkedlist(tag,currentlink) end)
                end
}
