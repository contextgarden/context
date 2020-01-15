if not modules then modules = { } end modules ['lpdf-swf'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The following code is based on tests by Luigi Scarso. His prototype
-- was using tex code. This is the official implementation.

local format, gsub = string.format, string.gsub
local concat = table.concat
local formatters = string.formatters

local backends        = backends
local lpdf            = lpdf
local context         = context

local pdfconstant     = lpdf.constant
local pdfstring       = lpdf.string
local pdfdictionary   = lpdf.dictionary
local pdfarray        = lpdf.array
local pdfreference    = lpdf.reference
local pdfflushobject  = lpdf.flushobject
local pdfsharedobject = lpdf.shareobjectreference

local checkedkey      = lpdf.checkedkey

local codeinjections = backends.pdf.codeinjections
local nodeinjections = backends.pdf.nodeinjections

local trace_swf = false  trackers.register("backend.swf", function(v) trace_swf = v end)

local report_swf = logs.reporter("backend","swf")

--------------------------------------------------------------------------------------

local createimage = images.create
local embedimage  = images.embed

local basepoints  = number.dimenfactors.bp

local f_image     = formatters["%.6N 0 0 %.6N 0 0 cm /%s Do"]

local function package(image) -- see lpdf-u3d **
    local boundingbox = image.bbox
    local imagetag    = "Im" .. image.index -- this is not ok
    local resources   = pdfdictionary {
        ProcSet   = lpdf.procset(),
        Resources = pdfdictionary {
            XObject = pdfdictionary {
                [imagetag] = pdfreference(image.objnum)
            }
        }
    }
    local width  = boundingbox[3]
    local height = boundingbox[4]
    local xform = createimage {
        attr   = resources(),
        stream = f_image(width,height,imagetag),
        bbox   = { 0, 0, width/basepoints, height/basepoints },
    }
    embedimage(xform)
    return xform
end

--------------------------------------------------------------------------------------

local activations = {
    click = "XA",
    page  = "PO",
    focus = "PV",
}

local deactivations = {
    click = "XD",
    page  = "PI",
    focus = "PC",
}

table.setmetatableindex(activations,  function() return activations  .click end)
table.setmetatableindex(deactivations,function() return deactivations.focus end)

local function insertswf(spec)
    local width     = spec.width
    local height    = spec.height
    local filename  = spec.foundname
    local resources = spec.resources
    local display   = spec.display
    local controls  = spec.controls
    local arguments = spec.arguments

    local resources = resources and parametersets[resources]
    local display   = display   and parametersets[display]
    local controls  = controls  and parametersets[controls]  -- not yet used
    local arguments = arguments and parametersets[arguments] -- not yet used

    local preview   = checkedkey(display,"preview","string")
    local toolbar   = checkedkey(display,"toolbar","boolean")

    local embeddedreference = codeinjections.embedfile {
        file     = filename,
        compress = false,
    }

    local flash = pdfdictionary {
        Subtype   = pdfconstant("RichMediaConfiguration"),
        Instances = pdfarray {
            pdfdictionary {
                Type    = pdfconstant("RichMediaInstance"),
                Asset   = embeddedreference,
                Subtype = pdfconstant("Flash"), -- 3D Sound Video ... somehow still Flash too
                Params  = pdfsharedobject(pdfdictionary {
                    Binding   = pdfconstant("Background"), -- Foreground makes swf behave erratic
                    FlashVars = arguments and pdfstring(table.sequenced(arguments,"&")) or nil,
                }),
            },
        },
    }

    local flashreference = pdfreference(pdfflushobject(flash))

    local configuration = pdfdictionary {
        Configurations = pdfarray { flashreference },
        Assets         = pdfdictionary {
            Names = pdfarray {
                pdfstring(filename),
                embeddedreference,
            }
        },
    }

    -- todo: check op subpath figuur (relatief)

    -- filename : ./test.swf (graphic)
    -- root     : .
    -- prefix   : ^%./
    -- fullname : ./assets/whatever.xml
    -- usedname : assets/whatever.xml
    -- filename : assets/whatever.xml

    local root          = file.dirname(filename)
    local relativepaths = nil
    local paths         = nil
    if resources then
        local names = configuration.Assets.Names
        local prefix = false
        if root ~= "" and root ~= "." then
            prefix = format("^%s/",string.topattern(root))
        end
        if prefix and trace_swf then
            report_swf("using strip pattern %a",prefix)
        end
        local function add(fullname,strip)
            local filename = gsub(fullname,"^%./","")
            local usedname = strip and prefix and gsub(filename,prefix,"") or filename
            local embeddedreference = codeinjections.embedfile {
                file     = fullname,
                usedname = usedname,
                keepdir  = true,
                compress = false,
            }
            names[#names+1] = pdfstring(filename)
            names[#names+1] = embeddedreference
            if trace_swf then
                report_swf("embedding file %a as %a",fullname,usedname)
            end
        end
        relativepaths = resources.relativepaths
        if relativepaths then
            if trace_swf then
                report_swf("checking %s relative paths",#relativepaths)
            end
            for i=1,#relativepaths do
                local relativepath = relativepaths[i]
                if trace_swf then
                    report_swf("checking path %a relative to %a",relativepath,root)
                end
                local path = file.join(root == "" and "." or root,relativepath)
                local files = dir.glob(path .. "/**")
                for i=1,#files do
                    add(files[i],true)
                end
            end
        end
        paths = resources.paths
        if paths then
            if trace_swf then
                report_swf("checking absolute %s paths",#paths)
            end
            for i=1,#paths do
                local path = paths[i]
                if trace_swf then
                    report_swf("checking path %a",path)
                end
                local files = dir.glob(path .. "/**")
                for i=1,#files do
                    add(files[i],false)
                end
            end
        end
        local relativefiles = resources.relativefiles
        if relativefiles then
            if trace_swf then
                report_swf("checking %s relative files",#relativefiles)
            end
            for i=1,#relativefiles do
                add(relativefiles[i],true)
            end
        end
        local files = resources.files
        if files then
            if trace_swf then
                report_swf("checking absolute %s files",#files)
            end
            for i=1,#files do
                add(files[i],false)
            end
        end
    end

    local opendisplay  = display and display.open  or false
    local closedisplay = display and display.close or false

    local configurationreference = pdfreference(pdfflushobject(configuration))

    local activation = pdfdictionary {
        Type          = pdfconstant("RichMediaActivation"),
        Condition     = pdfconstant(activations[opendisplay]),
        Configuration = flashreference,
        Animation     = pdfdictionary {
            Subtype   = pdfconstant("Linear"),
            Speed     = 1,
            Playcount = 1,
        },
        Presentation  = pdfdictionary {
         -- PassContextClick = false,
            PassContextClick = true,
            Style            = pdfconstant("Embedded"),
            Toolbar          = toolbar,
            NavigationPane   = false,
            Transparent      = true,
            Window           = pdfdictionary {
                Type     = pdfconstant("RichMediaWindow"),
                Width    = pdfdictionary {
                    Default = 100,
                    Min     = 100,
                    Max     = 100,
                },
                Height   = pdfdictionary {
                    Default = 100,
                    Min     = 100,
                    Max     = 100,
                },
                Position = pdfdictionary {
                    Type    = pdfconstant("RichMediaPosition"),
                    HAlign  = pdfconstant("Near"),
                    VAlign  = pdfconstant("Near"),
                    HOffset = 0,
                    VOffset = 0,
                }
            }
        },
     -- View
     -- Scripts
    }

    local deactivation = pdfdictionary {
        Type      = pdfconstant("RichMediaDeactivation"),
        Condition = pdfconstant(deactivations[closedisplay]),
    }

    local richmediasettings = pdfdictionary {
        Type         = pdfconstant("RichMediaSettings"),
        Activation   = activation,
        Deactivation = deactivation,
    }

    local settingsreference = pdfreference(pdfflushobject(richmediasettings))

    local appearance

    if preview then
        preview = gsub(preview,"%*",file.nameonly(filename))
        local figure = codeinjections.getpreviewfigure { name = preview, width = width, height = height }
        if relativepaths and not figure then
            for i=1,#relativepaths do
                local path = file.join(root == "" and "." or root,relativepaths[i])
                if trace_swf then
                    report_swf("checking preview on relative path %s",path)
                end
                local p = file.join(path,preview)
                figure = codeinjections.getpreviewfigure { name = p, width = width, height = height }
                if figure then
                    preview = p
                    break
                end
            end
        end
        if paths and not figure then
            for i=1,#paths do
                local path = paths[i]
                if trace_swf then
                    report_swf("checking preview on absolute path %s",path)
                end
                local p = file.join(path,preview)
                figure = codeinjections.getpreviewfigure { name = p, width = width, height = height }
                if figure then
                    preview = p
                    break
                end
            end
        end
        if figure then
            local image = package(figure.status.private)
            appearance = pdfdictionary { N = pdfreference(image.objnum) }
            if trace_swf then
                report_swf("using preview %s",preview)
            end
        end
    end

    local annotation = pdfdictionary {
        Subtype           = pdfconstant("RichMedia"),
        RichMediaContent  = configurationreference,
        RichMediaSettings = settingsreference,
        AP                = appearance,
    }

    return annotation, nil, nil

end

function backends.pdf.nodeinjections.insertswf(spec)
    local annotation, preview, ref = insertswf {
        foundname = spec.foundname,
        width     = spec.width,
        height    = spec.height,
        display   = spec.display,
        controls  = spec.controls,
        resources = spec.resources,
        arguments = spec.arguments,
     -- factor    = spec.factor,
     -- label     = spec.label,
    }
    context(nodeinjections.annotation(spec.width,spec.height,0,annotation())) -- the context wrap is probably also needed elsewhere
end
