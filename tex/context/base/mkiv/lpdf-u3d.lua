if not modules then modules = { } end modules ['lpdf-u3d'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The following code is based on a working prototype provided
-- by Michael Vidiassov. It is rewritten using the lpdf library
-- and different checking is used. The macro calls are adapted
-- (and will eventually be removed). The user interface needs
-- an overhaul. There are some messy leftovers that will be
-- removed in future versions.

-- For some reason no one really tested this code so at some
-- point we will end up with a reimplementation. For instance
-- it makes sense to add the same activation code as with swf.

local tonumber = tonumber
local formatters, find = string.formatters, string.find
local cos, sin, sqrt, pi, atan2, abs = math.cos, math.sin, math.sqrt, math.pi, math.atan2, math.abs

local backends, lpdf = backends, lpdf

local nodeinjections           = backends.pdf.nodeinjections

local pdfconstant              = lpdf.constant
local pdfboolean               = lpdf.boolean
local pdfunicode               = lpdf.unicode
local pdfdictionary            = lpdf.dictionary
local pdfarray                 = lpdf.array
local pdfnull                  = lpdf.null
local pdfreference             = lpdf.reference
local pdfflushstreamobject     = lpdf.flushstreamobject
local pdfflushstreamfileobject = lpdf.flushstreamfileobject

local checkedkey               = lpdf.checkedkey
local limited                  = lpdf.limited

local embedimage               = images.embed

local schemes = table.tohash {
    "Artwork", "None", "White", "Day", "Night", "Hard",
    "Primary", "Blue", "Red", "Cube", "CAD", "Headlamp",
}

local modes = table.tohash {
    "Solid", "SolidWireframe", "Transparent", "TransparentWireframe", "BoundingBox",
    "TransparentBoundingBox", "TransparentBoundingBoxOutline", "Wireframe",
    "ShadedWireframe", "HiddenWireframe", "Vertices", "ShadedVertices", "Illustration",
    "SolidOutline", "ShadedIllustration",
}

local function normalize(x, y, z)
    local modulo = sqrt(x*x + y*y + z*z);
    if modulo ~= 0 then
        return x/modulo, y/modulo, z/modulo
    else
        return x, y, z
    end
end

local function rotate(vect_x,vect_y,vect_z, tet, axis_x,axis_y,axis_z)
    -- rotate vect by tet about axis counterclockwise
    local c, s = cos(tet*pi/180), sin(tet*pi/180)
    local r = 1 - c
    local n = sqrt(axis_x*axis_x+axis_y*axis_y+axis_z*axis_z)
    axis_x, axis_y, axis_z = axis_x/n, axis_y/n, axis_z/n
    return
        (axis_x*axis_x*r+c       )*vect_x + (axis_x*axis_y*r-axis_z*s)*vect_y + (axis_x*axis_z*r+axis_y*s)*vect_z,
        (axis_x*axis_y*r+axis_z*s)*vect_x + (axis_y*axis_y*r+c       )*vect_y + (axis_y*axis_z*r-axis_x*s)*vect_z,
        (axis_x*axis_z*r-axis_y*s)*vect_x + (axis_y*axis_z*r+axis_x*s)*vect_y + (axis_z*axis_z*r+c       )*vect_z
end

local function make3dview(view)

    local name = view.name
    local name = pdfunicode(name ~= "" and name or "unknown view")

    local viewdict = pdfdictionary {
        Type = pdfconstant("3DView"),
        XN   = name,
        IN   = name,
        NR   = true,
    }

    local bg = checkedkey(view,"bg","table")
    if bg then
        viewdict.BG = pdfdictionary {
            Type = pdfconstant("3DBG"),
            C    = pdfarray { limited(bg[1],1,1,1), limited(bg[2],1,1,1), limited(bg[3],1,1,1) },
        }
    end

    local lights = checkedkey(view,"lights","string")
    if lights and schemes[lights] then
        viewdict.LS =  pdfdictionary {
            Type    = pdfconstant("3DLightingScheme"),
            Subtype = pdfconstant(lights),
        }
    end

    -- camera position is taken from 3d model

    local u3dview = checkedkey(view, "u3dview", "string")
    if u3dview then
        viewdict.MS      = pdfconstant("U3D")
        viewdict.U3DPath = u3dview
    end

    -- position the camera as given

    local c2c      = checkedkey(view, "c2c", "table")
    local coo      = checkedkey(view, "coo", "table")
    local roo      = checkedkey(view, "roo", "number")
    local azimuth  = checkedkey(view, "azimuth", "number")
    local altitude = checkedkey(view, "altitude", "number")

    if c2c or coo or roo or azimuth or altitude then

        local pos  = checkedkey(view, "pos", "table")
        local dir  = checkedkey(view, "dir", "table")
        local upv  = checkedkey(view, "upv", "table")
        local roll = checkedkey(view, "roll", "table")

        local coo_x, coo_y, coo_z       = 0, 0, 0
        local dir_x, dir_y, dir_z       = 0, 0, 0
        local trans_x, trans_y, trans_z = 0, 0, 0
        local left_x, left_y, left_z    = 0, 0, 0
        local up_x, up_y, up_z          = 0, 0, 0

        -- point camera is aimed at

        if coo then
            coo_x, coo_y, coo_z = tonumber(coo[1]) or 0, tonumber(coo[2]) or 0, tonumber(coo[3]) or 0
        end

        -- distance from camera to target

        if roo then
           roo = abs(roo)
        end
        if not roo or roo == 0 then
            roo = 0.000000000000000001
        end

        -- set it via camera position

        if pos then
            dir_x = coo_x - (tonumber(pos[1]) or 0)
            dir_y = coo_y - (tonumber(pos[2]) or 0)
            dir_z = coo_z - (tonumber(pos[3]) or 0)
            if not roo then
                roo = sqrt(dir_x*dir_x + dir_y*dir_y + dir_z*dir_z)
            end
            if dir_x == 0 and dir_y == 0 and dir_z == 0 then dir_y = 1 end
            dir_x, dir_y, dir_z = normalize(dir_x,dir_y,dir_z)
        end

        -- set it directly

        if dir then
            dir_x, dir_y, dir_z = tonumber(dir[1] or 0), tonumber(dir[2] or 0), tonumber(dir[3] or 0)
            if dir_x == 0 and dir_y == 0 and dir_z == 0 then dir_y = 1 end
            dir_x, dir_y, dir_z = normalize(dir_x,dir_y,dir_z)
        end

        -- set it movie15 style with vector from target to camera

        if c2c then
            dir_x, dir_y, dir_z = - tonumber(c2c[1] or 0), - tonumber(c2c[2] or 0), - tonumber(c2c[3] or 0)
            if dir_x == 0 and dir_y == 0 and dir_z == 0 then dir_y = 1 end
            dir_x, dir_y, dir_z = normalize(dir_x,dir_y,dir_z)
        end

        -- set it with azimuth and altitutde

        if altitude or azimuth then
            dir_x, dir_y, dir_z = -1, 0, 0
            if altitude then  dir_x, dir_y, dir_z = rotate(dir_x,dir_y,dir_z, -altitude, 0,1,0) end
            if azimuth  then  dir_x, dir_y, dir_z = rotate(dir_x,dir_y,dir_z,  azimuth,  0,0,1) end
        end

        -- set it with rotation like in MathGL

        if rot then
            if dir_x == 0 and dir_y == 0 and dir_z == 0 then dir_z = -1 end
            dir_x,dir_y,dir_z = rotate(dir_x,dir_y,dir_z, tonumber(rot[1]) or 0, 1,0,0)
            dir_x,dir_y,dir_z = rotate(dir_x,dir_y,dir_z, tonumber(rot[2]) or 0, 0,1,0)
            dir_x,dir_y,dir_z = rotate(dir_x,dir_y,dir_z, tonumber(rot[3]) or 0, 0,0,1)
        end

        -- set it with default movie15 orientation looking up y axis

        if dir_x == 0 and dir_y == 0 and dir_z == 0 then dir_y = 1 end

        -- left-vector
        -- up-vector

        if upv then
            up_x, up_y, up_z = tonumber(upv[1]) or 0, tonumber(upv[2]) or 0, tonumber(upv[3]) or 0
        else
            -- set default up-vector
            if abs(dir_x) == 0 and abs(dir_y) == 0 then
                if dir_z < 0 then
                    up_y =  1 -- top view
                else
                    up_y = -1 -- bottom view
                end
            else
                -- other camera positions than top and bottom, up-vector = up_world - (up_world dot dir) dir
                up_x, up_y, up_z = - dir_z*dir_x, - dir_z*dir_y, - dir_z*dir_z + 1
            end
        end

        -- normalize up-vector

        up_x, up_y, up_z = normalize(up_x,up_y,up_z)

        -- left vector = up x dir

        left_x, left_y, left_z = dir_z*up_y - dir_y*up_z, dir_x*up_z - dir_z*up_x, dir_y*up_x - dir_x*up_y

        -- normalize left vector

        left_x, left_y, left_z = normalize(left_x,left_y,left_z)

        -- apply camera roll

        if roll then
            local sinroll = sin((roll/180.0)*pi)
            local cosroll = cos((roll/180.0)*pi)
            left_x = left_x*cosroll + up_x*sinroll
            left_y = left_y*cosroll + up_y*sinroll
            left_z = left_z*cosroll + up_z*sinroll
            up_x = up_x*cosroll + left_x*sinroll
            up_y = up_y*cosroll + left_y*sinroll
            up_z = up_z*cosroll + left_z*sinroll
        end

        -- translation vector

        trans_x, trans_y, trans_z = coo_x - roo*dir_x, coo_y - roo*dir_y, coo_z - roo*dir_z

        viewdict.MS  = pdfconstant("M")
        viewdict.CO  = roo
        viewdict.C2W = pdfarray {
             left_x, left_y, left_z,
             up_x, up_y, up_z,
             dir_x, dir_y,  dir_z,
             trans_x, trans_y, trans_z,
        }

    end

    local aac = tonumber(view.aac) -- perspective projection
    local mag = tonumber(view.mag) -- ortho projection

    if aac and aac > 0 and aac < 180 then
        viewdict.P = pdfdictionary {
            Subtype = pdfconstant("P"),
            PS      = pdfconstant("Min"),
            FOV     = aac,
        }
    elseif mag and mag > 0 then
        viewdict.P = pdfdictionary {
            Subtype = pdfconstant("O"),
            OS      = mag,
        }
    end

    local mode = modes[view.rendermode]
    if mode then
        pdfdictionary {
            Type    = pdfconstant("3DRenderMode"),
            Subtype = pdfconstant(mode),
        }
    end

    -- crosssection

    local crosssection = checkedkey(view,"crosssection","table")
    if crosssection then
        local crossdict = pdfdictionary {
            Type = pdfconstant("3DCrossSection")
        }

        local c = checkedkey(crosssection,"point","table") or checkedkey(crosssection,"center","table")
        if c then
            crossdict.C = pdfarray { tonumber(c[1]) or 0, tonumber(c[2]) or 0, tonumber(c[3]) or 0 }
        end

        local normal = checkedkey(crosssection,"normal","table")
        if normal then
            local x, y, z = tonumber(normal[1] or 0), tonumber(normal[2] or 0), tonumber(normal[3] or 0)
            if sqrt(x*x + y*y + z*z) == 0 then
                x, y, z = 1, 0, 0
            end
            crossdict.O = pdfarray {
                pdfnull,
                atan2(-z,sqrt(x*x + y*y))*180/pi,
                atan2(y,x)*180/pi,
            }
        end

        local orient = checkedkey(crosssection,"orient","table")
        if orient then
            crossdict.O = pdfarray {
                tonumber(orient[1]) or 1,
                tonumber(orient[2]) or 0,
                tonumber(orient[3]) or 0,
            }
        end

        crossdict.IV = cross.intersection or false
        crossdict.ST = cross.transparent or false

        viewdict.SA = next(crossdict) and pdfarray { crossdict } -- maybe test if # > 1
    end

    local nodes = checkedkey(view,"nodes","table")
    if nodes then
        local nodelist = pdfarray()
        for i=1,#nodes do
            local node = checkedkey(nodes,i,"table")
            if node then
                local position = checkedkey(node,"position","table")
                nodelist[#nodelist+1] = pdfdictionary {
                    Type = pdfconstant("3DNode"),
                    N    = node.name or ("node_" .. i), -- pdfunicode ?
                    M    = position and #position == 12 and pdfarray(position),
                    V    = node.visible or true,
                    O    = node.opacity or 0,
                    RM   = pdfdictionary {
                        Type    = pdfconstant("3DRenderMode"),
                        Subtype = pdfconstant(node.rendermode or "Solid"),
                    },
                }
            end
      end
      viewdict.NA = nodelist
    end

   return viewdict

end

local stored_js, stored_3d, stored_pr, streams = { }, { }, { }, { }

local f_image = formatters["q /GS gs %.6N 0 0 %.6N 0 0 cm /IM Do Q"]

local function insert3d(spec) -- width, height, factor, display, controls, label, foundname

    local width, height, factor = spec.width, spec.height, spec.factor or number.dimenfactors.bp
    local display, controls, label, foundname = spec.display, spec.controls, spec.label, spec.foundname

    local param       = (display  and parametersets[display])  or { }
    local streamparam = (controls and parametersets[controls]) or { }
    local name        = "3D Artwork " .. (param.name or label or "Unknown")

    local activationdict = pdfdictionary {
       TB = pdfboolean(param.toolbar,true),
       NP = pdfboolean(param.tree,false),
    }

    local stream = streams[label]
    if not stream then

        local subtype, subdata = "U3D", io.loaddata(foundname) or ""
        if find(subdata,"^PRC") then
            subtype = "PRC"
        elseif find(subdata,"^U3D") then
            subtype = "U3D"
        elseif file.suffix(foundname) == "prc" then
            subtype = "PRC"
        end

        local attr = pdfdictionary {
            Type    = pdfconstant("3D"),
            Subtype = pdfconstant(subtype),
        }
        local streamviews = checkedkey(streamparam, "views", "table")
        if streamviews then
            local list = pdfarray()
            for i=1,#streamviews do
                local v = checkedkey(streamviews, i, "table")
                if v then
                    list[#list+1] = make3dview(v)
                end
            end
            attr.VA = list
        end
        if checkedkey(streamparam, "view", "table") then
            attr.DV = make3dview(streamparam.view)
        elseif checkedkey(streamparam, "view", "string") then
            attr.DV = streamparam.view
        end
        local js = checkedkey(streamparam, "js", "string")
        if js then
            local jsref = stored_js[js]
            if not jsref then
                jsref = pdfflushstreamfileobject(js)
                stored_js[js] = jsref
            end
            attr.OnInstantiate = pdfreference(jsref)
        end
        stored_3d[label] = pdfflushstreamfileobject(foundname,attr)
        stream = 1
    else
       stream = stream + 1
    end
    streams[label] = stream

    local name = pdfunicode(name)

    local annot  = pdfdictionary {
        Subtype  = pdfconstant("3D"),
        T        = name,
        Contents = name,
        NM       = name,
        ["3DD"]  = pdfreference(stored_3d[label]),
        ["3DA"]  = activationdict,
    }
    if checkedkey(param,"view","table") then
        annot["3DV"] = make3dview(param.view)
    elseif checkedkey(param,"view","string") then
        annot["3DV"] = param.view
    end

    local preview = checkedkey(param,"preview","string")
    if preview then
        activationdict.A = pdfconstant("XA")
        local tag = formatters["%s:%s:%s"](label,stream,preview)
        local ref = stored_pr[tag]
        if not ref then
            local figure = embedimage {
                filename = preview,
                width    = width,
                height   = height
            }
            ref = figure.objnum
            stored_pr[tag] = ref
        end
        if ref then -- see back-pdf ** .. here we have a local /IM !
            local pw   = pdfdictionary {
                Type      = pdfconstant("XObject"),
                Subtype   = pdfconstant("Form"),
                FormType  = 1,
                BBox      = pdfarray { 0, 0, pdfnumber(factor*width), pdfnumber(factor*height) },
                Matrix    = pdfarray { 1, 0, 0, 1, 0, 0 },
                ProcSet   = lpdf.procset(),
                Resources = pdfdictionary {
                                XObject = pdfdictionary {
                                    IM = pdfreference(ref)
                                }
                            },
                ExtGState = pdfdictionary {
                                GS = pdfdictionary {
                                    Type = pdfconstant("ExtGState"),
                                    CA   = 1,
                                    ca   = 1,
                                }
                            },
            }
            local pwd = pdfflushstreamobject(f_image(factor*width,factor*height),pw)
            annot.AP = pdfdictionary {
                N = pdfreference(pwd)
            }
        end
        return annot, figure, ref
    else
        activationdict.A = pdfconstant("PV")
        return annot, nil, nil
    end
end

function nodeinjections.insertu3d(spec)
    local annotation, preview, ref = insert3d { -- just spec
        foundname = spec.foundname,
        width     = spec.width,
        height    = spec.height,
        factor    = spec.factor,
        display   = spec.display,
        controls  = spec.controls,
        label     = spec.label,
    }
    node.write(nodeinjections.annotation(spec.width,spec.height,0,annotation()))
end
