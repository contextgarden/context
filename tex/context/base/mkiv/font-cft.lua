if not modules then modules = { } end modules ['font-cft'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- context font tables
--
-- todo: extra:
--
-- extra_space       => space.extra
-- space             => space.width
-- space_stretch     => space.stretch
-- space_shrink      => space.shrink
--
-- We do keep the x-height, extra_space, space_shrink and space_stretch
-- around as these are low level official names.
--
-- Needs to be checked and updated.

local type, tonumber = type, tonumber

local fonts  = fonts or { }
local tables = fonts.tables or { }
fonts.tables = tables

local data   = utilities.storage.allocate()
tables.data  = data

do

    local t_units     = "<units>"
    local t_unicode   = "<unicode>"
    local t_unispec   = "<unispec>"      -- t_unicode | { t_unicode }
    local t_index     = "<index>"
    local t_cardinal  = "<cardinal>"
    local t_integer   = "<integer>"
    local t_float     = "<float>"
    local t_boolean   = "<boolean>"
    local t_string    = "<string>"
    local t_array     = "<array>"
    local t_hash      = "<hash>"
    local t_scaled    = "<scaled>"
    local t_keyword   = "<keyword>"
    local t_scale     = "<scale>"       -- 1000 based tex scale
    local t_value     = "<value>"       -- number, string, boolean
    local t_function  = "<function>"

    data.types = {
        ["units"]     = "<units>",
        ["unicode"]   = "<unicode>",
        ["unispec"]   = "<unispec>" ,     -- t_unicode | { t_unicode }
        ["index"]     = "<index>",
        ["cardinal"]  = "<cardinal>",
        ["integer"]   = "<integer>",
        ["float"]     = "<float>",
        ["boolean"]   = "<boolean>",
        ["string"]    = "<string>",
        ["array"]     = "<array>",
        ["hash"]      = "<hash>",
        ["scaled"]    = "<scaled>",
        ["keyword"]   = "<keyword>",
        ["scale"]     = "<scale>",       -- 1000 based tex scale
        ["value"]     = "<value>",       -- number, string, boolean
        ["function"]  = "<function>",
    }

    local boundingbox = {
        t_units,
        t_units,
        t_units,
        t_units
    }

    local mathvariants = {
        t_array
    }

    local mathparts = {
        {
            advance  = t_units,
            ["end"]  = t_units,
            extender = t_units,
            glyph    = t_unicode,
            start    = t_units,
        }
    }

    local mathkerns = {
        {
            height = t_units,
            kern   = t_units,
        },
    }

    local mathparts = {
        {
            advance  = t_scaled,
            ["end"]  = t_scaled,
            extender = t_scaled,
            glyph    = t_unicode,
            start    = t_scaled,
        }
    }

    local mathkerns = {
        {
            height = t_scaled,
            kern   = t_scaled,
        },
    }

    local vfcommands = {
        { t_keyword, t_value },
    }

    local description = {
        width       = t_units,
        height      = t_units,
        depth       = t_units,
        italic      = t_units,
        index       = t_index,
        boundingbox = boundingbox,
        unicode     = t_unispec,
        math        = {
            accent    = t_units,
            hvariants = mathvariants,
            vvariants = mathvariants,
            hparts    = mathparts,
            vparts    = mathparts,
            kerns     = {
                bottomright = mathkerns,
                bottomleft  = mathkerns,
                topright    = mathkerns,
                topleft     = mathkerns,
            }
        },
    }

    local character = {
        width            = t_scaled,
        height           = t_scaled,
        depth            = t_scaled,
        italic           = t_scaled,
        index            = t_index,
        expansion_factor = t_scaled,
        left_protruding  = t_scaled,
        right_protruding = t_scaled,
        tounicode        = t_string,
        unicode          = t_unispec,
        commands         = vfcommands,
        accent           = t_scaled,
        hvariants        = mathvariants,
        vvariants        = mathvariants,
        hparts           = math_parts,
        vparts           = math_parts,
        kerns            = {
            bottomright = math_kerns,
            bottomleft  = math_kerns,
            topright    = math_kerns,
            topleft     = math_kerns,
        },
        ligatures        = t_hash,
        kerns            = t_hash,
        next             = t_array,
    }

    data.original = {
        cache_uuid     =  t_string,
        cache_version  =  t_float,
        compacted      =  t_boolean,
        creator        =  t_string,
        descriptions   =  { description },
        format         =  t_string,
        goodies        =  t_hash,
        metadata       =  {
            ascender      = t_units,
            averagewidth  = t_units,
            capheight     = t_units,
            descender     = t_units,
            family        = t_string,
            familyname    = t_string,
            fontname      = t_string,
            fullname      = t_string,
            italicangle   = t_float,
            monospaced    = t_boolean,
            panoseweight  = t_string,
            panosewidth   = t_string,
            pfmweight     = t_units,
            pfmwidth      = t_units,
            subfamily     = t_string,
            subfamilyname = t_string,
            subfontindex  = t_index,
            units         = t_cardinal,
            version       = t_string,
            weight        = t_string,
            width         = t_string,
            xheight       = t_units,
        },
        private        = t_unicode,
        properties     = {
            hascolor      = t_boolean,
            hasitalics    = t_boolean,
            hasspacekerns = t_boolean,
        },
        resources      = {
            duplicates    = t_hash,
            features      = {
                gpos = t_hash,
                gsub = t_hash,
            },
            filename      = t_string,
            markclasses   = t_hash,
            marks         = t_hash,
            marksets      = t_hash,
            mathconstants = t_hash,
            private       = t_cardinal,
            sequences     = t_array,
         -- unicodes      = t_hash,
            version       = t_string,
        },
        size         = t_cardinal,
     -- tables       = t_array,
        tableversion = t_float,
        time         = t_cardinal,
    }

    data.scaled = {
        properties = {
            encodingbytes    = t_cardinal,
            embedding        = t_cardinal, -- ?
            cidinfo          = t_hash,
            format           = t_string,
            fontname         = t_string,
            fullname         = t_string,
            filename         = t_string,
            psname           = t_string,
            name             = t_string,
            virtualized      = t_boolean,
            hasitalics       = t_boolean,
            autoitalicamount = t_float,
            nostackmath      = t_boolean,
            mode             = t_string,
            hasmath          = t_boolean,
            mathitalics      = t_boolean,
            textitalics      = t_boolean,
            finalized        = t_boolean,
            effect = {
                effect  = t_cardinal,
                width   = t_float,
                factor  = t_float,
                hfactor = t_float,
                vfactor = t_float,
                wdelta  = t_float,
                hdelta  = t_float,
                ddelta  = t_float,
            }
        },
        parameters = {
            mathsize               = t_cardinal,
            scriptpercentage       = t_float,
            scriptscriptpercentage = t_float,
            units                  = t_cardinal,
            designsize             = t_scaled,
            expansion              = {
                stretch = t_scale,
                shrink  = t_scale,
                step    = t_scale,
                auto    = t_boolean,
            },
            protrusion             = {
                auto = t_boolean,
            },
            slantfactor   = t_float,
            extendfactor  = t_float,
            mode          = t_cardinal,
            width         = t_scale,
            factor        = t_float,
            hfactor       = t_float,
            vfactor       = t_float,
            size          = t_scaled,
            units         = t_scaled,
            scaledpoints  = t_scaled,
            slantperpoint = t_scaled,
            xheight       = t_scaled,
            quad          = t_scaled,
            ascender      = t_scaled,
            descender     = t_scaled,
            spacing       = {
                width   = t_scaled,
                stretch = t_scaled,
                shrink  = t_scaled,
                extra   = t_scaled,
            },
         -- synonyms      = {
         --     space         = "spacing.width",
         --     spacestretch  = "spacing.stretch",
         --     spaceshrink   = "spacing.shrink",
         --     extraspace    = "spacing.extra",
         --     x_height      = "xheight",
         --     space_stretch = "spacing.stretch",
         --     space_shrink  = "spacing.shrink",
         --     extra_space   = "spacing.extra",
         --     em            = "quad",
         --     ex            = "xheight",
         --     slant         = "slantperpoint",
         -- },
        },
        descriptions   =  { description },
        characters     =  { character },
    }

    data.goodies = {
        -- preamble
        name      = t_string,
        version   = t_string,
        comment   = t_string,
        author    = t_string,
        copyright = t_string,
        --
        remapping = {
            tounicode = t_boolean,
            unicodes = {
                [t_string] = t_index,
            },
        },
        mathematics = {
            mapfiles = {
                t_string,
            },
            virtuals = {
                [t_string] = {
                    {
                        name       = t_string,
                        features   = t_hash,
                        main       = t_boolean,
                        extension  = t_boolean,
                        vector     = t_string,
                        skewchar   = t_unicode,
                        parameters = t_boolean,
                    },
                },
            },
            italics = {
                [t_string] = {
                    defaultfactor = t_float,
                    disableengine = t_boolean,
                    corrections   = {
                        [t_unicode] = t_float,
                    }
                },
            },
            kerns = {
                [t_unicode] = {
                    bottomright = math_kerns,
                    topright    = math_kerns,
                    bottomleft  = math_kerns,
                    topleft     = math_kerns,
                },
            },
            alternates = {
                [t_string] = {
                    feature = t_hash,
                    value   = t_float,
                    comment = t_string,
                },
            },
            variables = {
                [t_string] = t_value,
            },
            parameters = {
                [t_string] = t_value,
                [t_string] = t_function,
            },
            dimensions = {
                [t_string] = {
                    [t_unicode] = {
                        width   = t_units,
                        height  = t_units,
                        depth   = t_units,
                        xoffset = t_units,
                        yoffset = t_units,
                    },
                },
            },
        },
        filenames = {
            [t_string] = {
                t_string,
            },
        },
        compositions = {
            [t_string] = {
                dy          = t_unit,
                dx          = t_unit,
                [t_unicode] = {
                    dy = t_unit
                },
                [t_unicode] = {
                    anchors = {
                        top = {
                            x = t_unit,
                            y = t_unit,
                        },
                        bottom = {
                            x = t_unit,
                            y = t_unit,
                        },
                    },
                },
            },
        },
        postprocessors = {
            [t_string] = t_function,
        },
        designsizes = {
            [t_string] = {
                [t_string] = t_string,
                default    = t_string
            },
        },
        featuresets = {
            [t_string] = {
                t_string,
                [t_keyword] = t_value
            },
        },
        solutions = {
            experimental = {
                less = { t_string },
                more = { t_string },
            },
        },
        stylistics = {
            [t_string] = t_string,
            [t_string] = t_string,
        },
        colorschemes = {
            default = {
                [1] = { t_string },
            }
        },
        files = {
            name = t_string,
            list = {
                [t_string] = {
                    name   = t_string,
                    weight = t_string,
                    style  = t_string,
                    width  = t_string,
                },
            },
        },
        typefaces = {
            [t_string] = {
                shortcut     = t_string,
                shape        = t_string,
                fontname     = t_string,
                normalweight = t_string,
                boldweight   = t_string,
                width        = t_string,
                size         = t_string,
                features     = t_string,
            },
        },
    }

end

-- compatibility (for now)

if fonts.constructors then
    fonts.constructors.keys = data.scaled
end

-- handy helpers

local report = logs.reporter("fonts")

function tables.savefont(specification)
    local method   = specification.method
    local filename = specification.filename
    local fontname = specification.fontname
    if not method or method ~= "original" then
        method = "scaled"
    end
    if not filename or filename == "" then
        filename = "temp-font-" .. method .. ".lua"
    else
        filename = file.addsuffix(filename,"lua")
    end
    if not fontname or fontname == "" then
        fontname = true
    end
    if fontname == true then
        report("saving current font in %a",filename)
    elseif tonumber(fontname) then
        report("saving font id %a in %a",fontname,filename)
        fontname = tonumber(fontname)
    else
        report("saving font %a in %a",fontname,filename)
        tfmdata = fonts.definers.define {
            name = fontname
        }
    end
    if tfmdata then
        tfmdata = fonts.hashes.identifiers[tfmdata]
    end
    if not tfmdata then
        -- bad news
    elseif method == "original" then
        tfmdata = tfmdata.shared and tfmdata.shared.rawdata
    else
        tfmdata = {
            characters    = tfmdata.characters,
            parameters    = tfmdata.parameters,
            properties    = tfmdata.properties,
            specification = tfmdata.specification,
        }
    end
    if tfmdata then
        table.save(filename,tfmdata)
    else
     -- os.remove(filename)
        report("saving font failed")
    end
end

function tables.saveoriginal(filename,specification)
    local tfmdata = get(specification)
    if tfmdata then
        local rawdata = tfmdata.shared and tfmdata.shared.rawdata
        if rawdata then
            table.save(filename,rawdata)
        end
    end
end

if context then

    interfaces.implement {
        name      = "savefont",
        actions   = tables.savefont,
        arguments = {
            {
                { "filename" },
                { "fontname" },
                { "method" },
            }
        },
    }

end

