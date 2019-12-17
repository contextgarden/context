if not modules then modules = { } end modules ['lpdf-wid'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- It's about time to give up on media in pdf and admit that pdf lost it to html.
-- First we had movies and sound, quite easy to deal with, but obsolete now. Then we
-- had renditions but they turned out to be unreliable from the start and look
-- obsolete too or at least they are bound to the (obsolete) flash technology for
-- rendering. They were already complex constructs. Now we have rich media which
-- instead of providing a robust future proof framework for general media types
-- again seems to depend on viewers built in (yes, also kind of obsolete) flash
-- technology, and we cannot expect this non-open technology to show up in open
-- browsers. So, in the end we can best just use links to external resources to be
-- future proof. Just look at the viewer preferences pane to see how fragile support
-- is. Interestingly u3d support is kind of built in, while e.g. mp4 support relies
-- on wrapping in swf. We used to stay ahead of the pack with support of the fancy
-- pdf features but it backfires and is not worth the trouble. And yes, for control
-- (even simple like starting and stopping videos) one has to revert to JavaScript,
-- the other fragile bit. And, now that adobe quits flash in 2020 we're without any
-- video anyway. Also, it won't play on all platforms and devices so let's wait for
-- html5 media in pdf then.

local tonumber, next = tonumber, next
local gmatch, gsub, find, lower = string.gmatch, string.gsub, string.find, string.lower
local filenameonly, basefilename, filesuffix, addfilesuffix = file.nameonly, file.basename, file.suffix, file.addsuffix
local isfile, modificationtime = lfs.isfile, lfs.modification
local stripstring = string.strip
local settings_to_array = utilities.parsers.settings_to_array
local settings_to_hash = utilities.parsers.settings_to_hash
local sortedhash, sortedkeys = table.sortedhash, table.sortedkeys

local report_media             = logs.reporter("backend","media")
local report_attachment        = logs.reporter("backend","attachment")

local backends                 = backends
local lpdf                     = lpdf
local nodes                    = nodes
local context                  = context

local texgetcount              = tex.getcount

local nodeinjections           = backends.pdf.nodeinjections
local codeinjections           = backends.pdf.codeinjections
local registrations            = backends.pdf.registrations

local executers                = structures.references.executers
local variables                = interfaces.variables

local v_hidden                 = variables.hidden
local v_auto                   = variables.auto
local v_embed                  = variables.embed
local v_max                    = variables.max
local v_yes                    = variables.yes

local pdfconstant              = lpdf.constant
local pdfnull                  = lpdf.null
local pdfdictionary            = lpdf.dictionary
local pdfarray                 = lpdf.array
local pdfreference             = lpdf.reference
local pdfunicode               = lpdf.unicode
local pdfstring                = lpdf.string
local pdfboolean               = lpdf.boolean
local pdfflushobject           = lpdf.flushobject
local pdfflushstreamobject     = lpdf.flushstreamobject
local pdfflushstreamfileobject = lpdf.flushstreamfileobject
local pdfreserveobject         = lpdf.reserveobject
local pdfpagereference         = lpdf.pagereference
local pdfshareobjectreference  = lpdf.shareobjectreference
local pdfaction                = lpdf.action
local pdfborder                = lpdf.border

local pdftransparencyvalue     = lpdf.transparencyvalue
local pdfcolorvalues           = lpdf.colorvalues

local hpack_node               = node.hpack
local write_node               = node.write -- test context(...) instead

-- symbols

local presets = { } -- xforms

local function registersymbol(name,n)
    presets[name] = pdfreference(n)
end

local function registeredsymbol(name)
    return presets[name]
end

local function presetsymbol(symbol)
    if not presets[symbol] then
        context.predefinesymbol { symbol }
    end
end

local function presetsymbollist(list)
    if list then
        for symbol in gmatch(list,"[^, ]+") do
            presetsymbol(symbol)
        end
    end
end

codeinjections.registersymbol   = registersymbol
codeinjections.registeredsymbol = registeredsymbol
codeinjections.presetsymbol     = presetsymbol
codeinjections.presetsymbollist = presetsymbollist

-- comments

-- local symbols = {
--     Addition     = pdfconstant("NewParagraph"),
--     Attachment   = pdfconstant("Attachment"),
--     Balloon      = pdfconstant("Comment"),
--     Check        = pdfconstant("Check Mark"),
--     CheckMark    = pdfconstant("Check Mark"),
--     Circle       = pdfconstant("Circle"),
--     Cross        = pdfconstant("Cross"),
--     CrossHairs   = pdfconstant("Cross Hairs"),
--     Graph        = pdfconstant("Graph"),
--     InsertText   = pdfconstant("Insert Text"),
--     New          = pdfconstant("Insert"),
--     Paperclip    = pdfconstant("Paperclip"),
--     RightArrow   = pdfconstant("Right Arrow"),
--     RightPointer = pdfconstant("Right Pointer"),
--     Star         = pdfconstant("Star"),
--     Tag          = pdfconstant("Tag"),
--     Text         = pdfconstant("Note"),
--     TextNote     = pdfconstant("Text Note"),
--     UpArrow      = pdfconstant("Up Arrow"),
--     UpLeftArrow  = pdfconstant("Up-Left Arrow"),
-- }

local attachment_symbols = {
    Graph     = pdfconstant("Graph"),
    Paperclip = pdfconstant("Paperclip"),
    Pushpin   = pdfconstant("PushPin"),
}

attachment_symbols.PushPin = attachment_symbols.Pushpin
attachment_symbols.Default = attachment_symbols.Pushpin

function lpdf.attachmentsymbols()
    return sortedkeys(comment_symbols)
end

local comment_symbols = {
    Comment      = pdfconstant("Comment"),
    Help         = pdfconstant("Help"),
    Insert       = pdfconstant("Insert"),
    Key          = pdfconstant("Key"),
    Newparagraph = pdfconstant("NewParagraph"),
    Note         = pdfconstant("Note"),
    Paragraph    = pdfconstant("Paragraph"),
}

comment_symbols.NewParagraph = Newparagraph
comment_symbols.Default      = Note

function lpdf.commentsymbols()
    return sortedkeys(comment_symbols)
end

local function analyzesymbol(symbol,collection)
    if not symbol or symbol == "" then
        return collection and collection.Default, nil
    elseif collection and collection[symbol] then
        return collection[symbol], nil
    else
        local setn, setr, setd
        local set = settings_to_array(symbol)
        if #set == 1 then
            setn, setr, setd = set[1], set[1], set[1]
        elseif #set == 2 then
            setn, setr, setd = set[1], set[1], set[2]
        else
            setn, setr, setd = set[1], set[2], set[3]
        end
        local appearance = pdfdictionary {
            N = setn and registeredsymbol(setn),
            R = setr and registeredsymbol(setr),
            D = setd and registeredsymbol(setd),
        }
        local appearanceref = pdfshareobjectreference(appearance)
        return nil, appearanceref
    end
end

local function analyzenormalsymbol(symbol)
    local appearance = pdfdictionary {
        N = registeredsymbol(symbol),
    }
    local appearanceref = pdfshareobjectreference(appearance)
    return appearanceref
end

codeinjections.analyzesymbol       = analyzesymbol
codeinjections.analyzenormalsymbol = analyzenormalsymbol

local function analyzelayer(layer)
    -- todo:  (specification.layer ~= "" and pdfreference(specification.layer)) or nil, -- todo: ref to layer
end

local function analyzecolor(colorvalue,colormodel)
    local cvalue = colorvalue and tonumber(colorvalue)
    local cmodel = colormodel and tonumber(colormodel) or 3
    return cvalue and pdfarray { pdfcolorvalues(cmodel,cvalue) } or nil
end

local function analyzetransparency(transparencyvalue)
    local tvalue = transparencyvalue and tonumber(transparencyvalue)
    return tvalue and pdftransparencyvalue(tvalue) or nil
end

-- Attachments

local nofattachments    = 0
local attachments       = { }
local filestreams       = { }
local referenced        = { }
local ignorereferenced  = true -- fuzzy pdf spec .. twice in attachment list, can become an option
local tobesavedobjrefs  = utilities.storage.allocate()
local collectedobjrefs  = utilities.storage.allocate()
local permitted         = true
local enabled           = true

function codeinjections.setattachmentsupport(option)
    if option == false then
        permitted = false
        enabled   = false
    end
end

local fileobjreferences = {
    collected = collectedobjrefs,
    tobesaved = tobesavedobjrefs,
}

job.fileobjreferences = fileobjreferences

local function initializer()
    collectedobjrefs = job.fileobjreferences.collected or { }
    tobesavedobjrefs = job.fileobjreferences.tobesaved or { }
end

job.register('job.fileobjreferences.collected', tobesavedobjrefs, initializer)

local function flushembeddedfiles()
    if enabled and next(filestreams) then
        local e = pdfarray()
        for tag, reference in sortedhash(filestreams) do
            if not reference then
                report_attachment("unreferenced file, tag %a",tag)
--             elseif referenced[tag] == "hidden" then
            elseif referenced[tag] ~= "hidden" then
                e[#e+1] = pdfstring(tag)
                e[#e+1] = reference -- already a reference
            else
         --     -- messy spec ... when annot not in named else twice in menu list acrobat
            end
        end
        if #e > 0 then
            lpdf.addtonames("EmbeddedFiles",pdfreference(pdfflushobject(pdfdictionary{ Names = e })))
        end
    end
end

lpdf.registerdocumentfinalizer(flushembeddedfiles,"embeddedfiles")

function codeinjections.embedfile(specification)
    if enabled then
        local data      = specification.data
        local filename  = specification.file
        local name      = specification.name or ""
        local title     = specification.title or ""
        local hash      = specification.hash or filename
        local keepdir   = specification.keepdir -- can change
        local usedname  = specification.usedname
        local filetype  = specification.filetype
        local compress  = specification.compress
        local mimetype  = specification.mimetype or specification.mime
        if filename == "" then
            filename = nil
        end
        if compress == nil then
            compress = true
        end
        if data then
            local r = filestreams[hash]
            if r == false then
                return nil
            elseif r then
                return r
            elseif not filename then
                filename = specification.tag
                if not filename or filename == "" then
                    filename = specification.registered
                end
                if not filename or filename == "" then
                    filename = hash
                end
            end
        else
            if not filename then
                return nil
            end
            local r = filestreams[hash]
            if r == false then
                return nil
            elseif r then
                return r
            else
                local foundname = resolvers.findbinfile(filename) or ""
                if foundname == "" or not isfile(foundname) then
                    filestreams[filename] = false
                    return nil
                else
                    specification.foundname = foundname
                end
            end
        end
        -- needs to be cleaned up:
        usedname = usedname ~= "" and usedname or filename or name
        local basename  = keepdir == true and usedname or basefilename(usedname)
        local basename  = gsub(basename,"%./","")
        local savename  = name ~= "" and name or basename
        local foundname = specification.foundname or filename
        if not filetype or filetype == "" then
            filetype = name and (filename and filesuffix(filename)) or "txt"
        end
        savename = addfilesuffix(savename,filetype) -- type is mandate for proper working in viewer
        local a = pdfdictionary {
            Type    = pdfconstant("EmbeddedFile"),
            Subtype = mimetype and mimetype ~= "" and pdfconstant(mimetype) or nil,
        }
        local f
        if data then
            f = pdfflushstreamobject(data,a)
            specification.data = true -- signal that still data but already flushed
        else
            local modification = modificationtime(foundname)
            if attributes then
                a.Params = {
                    Size    = attributes.size,
                    ModDate = lpdf.pdftimestamp(modification),
                }
            end
            f = pdfflushstreamfileobject(foundname,a,compress)
        end
        local d = pdfdictionary {
            Type           = pdfconstant("Filespec"),
            F              = pdfstring(savename),
         -- UF             = pdfstring(savename),
            UF             = pdfunicode(savename),
            EF             = pdfdictionary { F = pdfreference(f) },
            Desc           = title ~= "" and pdfunicode(title) or nil,
            AFRelationship = pdfconstant("Unspecified"), -- Supplement, Data, Source, Alternative, Data
        }
        local r = pdfreference(pdfflushobject(d))
        filestreams[hash] = r
        return r
    end
end

function nodeinjections.attachfile(specification)
    if enabled then
        local registered = specification.registered or "<unset>"
        local data = specification.data
        local hash
        local filename
        if data then
            hash = md5.HEX(data)
        else
            filename = specification.file
            if not filename or filename == "" then
                report_attachment("no file specified, using registered %a instead",registered)
                filename = registered
                specification.file = registered
            end
            local foundname = resolvers.findbinfile(filename) or ""
            if foundname == "" or not isfile(foundname) then
                report_attachment("invalid filename %a, ignoring registered %a",filename,registered)
                return nil
            else
                specification.foundname = foundname
            end
            hash = filename
        end
        specification.hash = hash
        nofattachments = nofattachments + 1
        local registered = specification.registered or ""
        local title      = specification.title      or ""
        local subtitle   = specification.subtitle   or ""
        local author     = specification.author     or ""
        local onlyname   = filename and filenameonly(filename) or ""
        if registered == "" then
            registered = filename
        end
        if author == "" and title ~= "" then
            author = title
            title  = onlyname or ""
        end
        if author == "" then
            author = onlyname or "<unknown>"
        end
        if title == "" then
            title = registered
        end
        if title == "" and filename then
            title = onlyname
        end
        local aref = attachments[registered]
        if not aref then
            aref = codeinjections.embedfile(specification)
            attachments[registered] = aref
        end
        local reference = specification.reference
        if reference and aref then
            tobesavedobjrefs[reference] = aref[1]
        end
        if not aref then
            report_attachment("skipping attachment, registered %a",registered)
            -- already reported
        elseif specification.method == v_hidden then
            referenced[hash] = "hidden"
        else
            referenced[hash] = "annotation"
            local name, appearance = analyzesymbol(specification.symbol,attachment_symbols)
            local d = pdfdictionary {
                Subtype  = pdfconstant("FileAttachment"),
                FS       = aref,
                Contents = pdfunicode(title),
                Name     = name,
                NM       = pdfstring("attachment:"..nofattachments),
                T        = author ~= "" and pdfunicode(author) or nil,
                Subj     = subtitle ~= "" and pdfunicode(subtitle) or nil,
                C        = analyzecolor(specification.colorvalue,specification.colormodel),
                CA       = analyzetransparency(specification.transparencyvalue),
                AP       = appearance,
                OC       = analyzelayer(specification.layer),
                F        = pdfnull(), -- another rediculous need to satisfy validation
            }
            local width  = specification.width  or 0
            local height = specification.height or 0
            local depth  = specification.depth  or 0
            local box    = hpack_node(nodeinjections.annotation(width,height,depth,d()))
            box.width    = width
            box.height   = height
            box.depth    = depth
            return box
        end
    end
end

function codeinjections.attachmentid(filename) -- not used in context
    return filestreams[filename]
end

-- Comments

local nofcomments      = 0
local usepopupcomments = false

local defaultattributes = {
    ["xmlns"]           = "http://www.w3.org/1999/xhtml",
    ["xmlns:xfa"]       = "http://www.xfa.org/schema/xfa-data/1.0/",
    ["xfa:contentType"] = "text/html",
    ["xfa:APIVersion"]  = "Acrobat:8.0.0",
    ["xfa:spec"]        = "2.4",
}

local function checkcontent(text,option)
    if option and option.xml then
        local root = xml.convert(text)
        if root and not root.er then
            xml.checkbom(root)
            local body = xml.first(root,"/body")
            if body then
                local at = body.at
                for k, v in next, defaultattributes do
                    if not at[k] then
                        at[k] = v
                    end
                end
             -- local content = xml.textonly(root)
                local richcontent = xml.tostring(root)
                return nil, pdfunicode(richcontent)
            end
        end
    end
    return pdfunicode(text)
end

function nodeinjections.comment(specification) -- brrr: seems to be done twice
    nofcomments = nofcomments + 1
    local text = specification.data or ""
    if specification.space ~= v_yes then
        text = stripstring(text)
        text = gsub(text,"[\n\r] *","\n")
    end
    text = gsub(text,"\r","\n")
    local name, appearance = analyzesymbol(specification.symbol,comment_symbols)
    local tag      = specification.tag      or "" -- this is somewhat messy as recent
    local title    = specification.title    or "" -- versions of acrobat see the title
    local subtitle = specification.subtitle or "" -- as author
    local author   = specification.author   or ""
    local option   = settings_to_hash(specification.option or "")
    if author ~= "" then
        if subtitle == "" then
            subtitle = title
        elseif title ~= "" then
            subtitle = subtitle .. ", " .. title
        end
        title = author
    end
    if title == "" then
        title = tag
    end
    local content, richcontent = checkcontent(text,option)
    local d = pdfdictionary {
        Subtype   = pdfconstant("Text"),
        Open      = option[v_max] and pdfboolean(true) or nil,
        Contents  = content,
        RC        = richcontent,
        T         = title ~= "" and pdfunicode(title) or nil,
        Subj      = subtitle ~= "" and pdfunicode(subtitle) or nil,
        C         = analyzecolor(specification.colorvalue,specification.colormodel),
        CA        = analyzetransparency(specification.transparencyvalue),
        OC        = analyzelayer(specification.layer),
        Name      = name,
        NM        = pdfstring("comment:"..nofcomments),
        AP        = appearance,
        F         = pdfnull(), -- another rediculous need to satisfy validation
    }
    local width  = specification.width  or 0
    local height = specification.height or 0
    local depth  = specification.depth  or 0
    local box
    if usepopupcomments then
        -- rather useless as we can hide/vide
        local nd = pdfreserveobject()
        local nc = pdfreserveobject()
        local c = pdfdictionary {
            Subtype = pdfconstant("Popup"),
            Parent  = pdfreference(nd),
        }
        d.Popup = pdfreference(nc)
        box = hpack_node(
            nodeinjections.annotation(0,0,0,d(),nd),
            nodeinjections.annotation(width,height,depth,c(),nc)
        )
    else
        box = hpack_node(nodeinjections.annotation(width,height,depth,d()))
    end
    box.width  = width  -- redundant
    box.height = height -- redundant
    box.depth  = depth  -- redundant
    return box
end

-- rendering stuff
--
-- object_1  -> <</Type /Rendition /S /MR /C << /Type /MediaClip ... >> >>
-- object_2  -> <</Type /Rendition /S /MR /C << /Type /MediaClip ... >> >>
-- rendering -> <</Type /Rendition /S /MS [objref_1 objref_2]>>
--
-- we only work foreward here (currently)
-- annotation is to be packed at the tex end

-- aiff audio/aiff
-- au   audio/basic
-- avi  video/avi
-- mid  audio/midi
-- mov  video/quicktime
-- mp3  audio/x-mp3 (mpeg)
-- mp4  audio/mp4
-- mp4  video/mp4
-- mpeg video/mpeg
-- smil application/smil
-- swf  application/x-shockwave-flash

-- P  media play parameters (evt /BE for controls etc
-- A  boolean (audio)
-- C  boolean (captions)
-- O  boolean (overdubs)
-- S  boolean (subtitles)
-- PL pdfconstant("ADBE_MCI"),

-- F        = flags,
-- T        = title,
-- Contents = rubish,
-- AP       = irrelevant,

-- sound is different, no window (or zero) so we need to collect them and
-- force them if not set

local ms, mu, mf = { }, { }, { }

local function delayed(label)
    local a = pdfreserveobject()
    mu[label] = a
    return pdfreference(a)
end

local function insertrenderingwindow(specification)
    local label = specification.label
 -- local openpage = specification.openpage
 -- local closepage = specification.closepage
    if specification.option == v_auto then
        if openpageaction then
            -- \handlereferenceactions{\v!StartRendering{#2}}
        end
        if closepageaction then
            -- \handlereferenceactions{\v!StopRendering {#2}}
        end
    end
    local actions = nil
    if openpage or closepage then
        actions = pdfdictionary {
            PO = (openpage  and lpdfaction(openpage )) or nil,
            PC = (closepage and lpdfaction(closepage)) or nil,
        }
    end
    local page = tonumber(specification.page) or texgetcount("realpageno") -- todo
    local r = mu[label] or pdfreserveobject() -- why the reserve here?
    local a = pdfdictionary {
        S  = pdfconstant("Rendition"),
        R  = mf[label],
        OP = 0,
        AN = pdfreference(r),
    }
    local bs, bc = pdfborder()
    local d = pdfdictionary {
        Subtype = pdfconstant("Screen"),
        P       = pdfreference(pdfpagereference(page)),
        A       = a, -- needed in order to make the annotation clickable (i.e. don't bark)
        Border  = bs,
        C       = bc,
        AA      = actions,
    }
    local width = specification.width or 0
    local height = specification.height or 0
    if height == 0 or width == 0 then
        -- todo: sound needs no window
    end
    write_node(nodeinjections.annotation(width,height,0,d(),r)) -- save ref
    return pdfreference(r)
end

-- some dictionaries can have a MH (must honor) or BE (best effort) capsule

local function insertrendering(specification)
    local label = specification.label
    local option = settings_to_hash(specification.option)
    if not mf[label] then
        local filename = specification.filename
        local isurl    = find(filename,"://",1,true)
        local mimetype = specification.mimetype or specification.mime
     -- local start = pdfdictionary {
     --     Type = pdfconstant("MediaOffset"),
     --     S = pdfconstant("T"), -- time
     --     T = pdfdictionary { -- time
     --         Type = pdfconstant("Timespan"),
     --         S    = pdfconstant("S"),
     --         V    = 3, -- time in seconds
     --     },
     -- }
     -- local start = pdfdictionary {
     --     Type = pdfconstant("MediaOffset"),
     --     S = pdfconstant("F"), -- frame
     --     F = 100 -- framenumber
     -- }
     -- local start = pdfdictionary {
     --     Type = pdfconstant("MediaOffset"),
     --     S = pdfconstant("M"), -- mark
     --     M = "somemark",
     -- }
     -- local parameters = pdfdictionary {
     --     BE = pdfdictionary {
     --          B = start,
     --     }
     -- }
     -- local parameters = pdfdictionary {
     --     Type = pdfconstant(MediaPermissions),
     --     TF   = pdfstring("TEMPALWAYS") }, -- TEMPNEVER TEMPEXTRACT TEMPACCESS TEMPALWAYS
     -- }
        local descriptor = pdfdictionary {
            Type = pdfconstant("Filespec"),
            F    = filename,
        }
        if isurl then
            descriptor.FS = pdfconstant("URL")
        elseif option[v_embed] then
            descriptor.EF = codeinjections.embedfile {
                file     = filename,
                mimetype = mimetype, -- yes or no
                compress = false,
            }
        end
        local clip = pdfdictionary {
            Type = pdfconstant("MediaClip"),
            S    = pdfconstant("MCD"),
            N    = label,
            CT   = mimetype,
            Alt  = pdfarray { "", "file not found" }, -- language id + message
            D    = pdfreference(pdfflushobject(descriptor)),
         -- P    = pdfreference(pdfflushobject(parameters)),
        }
        local rendition = pdfdictionary {
            Type = pdfconstant("Rendition"),
            S    = pdfconstant("MR"),
            N    = label,
            C    = pdfreference(pdfflushobject(clip)),
        }
        mf[label] = pdfreference(pdfflushobject(rendition))
    end
end

local function insertrenderingobject(specification) -- todo
    local label = specification.label
    if not mf[label] then
        report_media("unknown medium, label %a",label)
        local clip = pdfdictionary { -- does  not work that well one level up
            Type = pdfconstant("MediaClip"),
            S    = pdfconstant("MCD"),
            N    = label,
            D    = pdfreference(unknown), -- not label but objectname, hm .. todo?
        }
        local rendition = pdfdictionary {
            Type = pdfconstant("Rendition"),
            S    = pdfconstant("MR"),
            N    = label,
            C    = pdfreference(pdfflushobject(clip)),
        }
        mf[label] = pdfreference(pdfflushobject(rendition))
    end
end

function codeinjections.processrendering(label)
    local specification = interactions.renderings.rendering(label)
    if not specification then
        -- error
    elseif specification.type == "external" then
        insertrendering(specification)
    else
        insertrenderingobject(specification)
    end
end

function codeinjections.insertrenderingwindow(specification)
    local label = specification.label
    codeinjections.processrendering(label)
    ms[label] = insertrenderingwindow(specification)
end

local function set(operation,arguments)
    codeinjections.processrendering(arguments)
    return pdfdictionary {
        S  = pdfconstant("Rendition"),
        OP = operation,
        R  = mf[arguments],
        AN = ms[arguments] or delayed(arguments),
    }
end

function executers.startrendering (arguments) return set(0,arguments) end
function executers.stoprendering  (arguments) return set(1,arguments) end
function executers.pauserendering (arguments) return set(2,arguments) end
function executers.resumerendering(arguments) return set(3,arguments) end
