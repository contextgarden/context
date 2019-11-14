if not modules then modules = { } end modules ['luat-fio'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format
local concat = table.concat
local sequenced = table.sequenced

texconfig.kpse_init      = false
texconfig.shell_escape   = 't'
texconfig.max_print_line = 100000
texconfig.max_in_open    = 1000

if not resolvers.initialized() then

    resolvers.reset()

    -- we now load the file database as we might need files other than
    -- tex and lua file on the given path

 -- trackers.enable("resolvers.*")
    resolvers.load()
 -- trackers.disable("resolvers.*")

    local findbinfile, loadbinfile = resolvers.findbinfile, resolvers.loadbinfile
    local findtexfile, opentexfile = resolvers.findtexfile, resolvers.opentexfile

    if callback then

        local register  = callbacks.register

        local addsuffix = file.addsuffix
        local join      = file.join

        local function findpk(font,dpi)
            local dpi  = dpi or 600 -- could take from resolution
            -- <font>.pk
            local name = addsuffix(font,"pk")
            -- <dpi>/name.pk
            local temp = join(dpi,name)
            local okay = findbinfile(temp,"pk")
         -- print(temp,okay)
            if okay and okay ~= "" then
                return okay
            end
            -- <dpi>.dpi/name.pk
            local temp = join(dpi..".dpi",name)
            local okay = findbinfile(temp,"pk")
         -- print(temp,okay)
            if okay and okay ~= "" then
                return okay
            end
            -- <font>.<dpi>pk
            local name = addsuffix(font,dpi.."pk")
            -- name.<dpi>pk
            local temp = name
            local okay = findbinfile(temp,"pk")
         -- print(temp,okay)
            if okay and okay ~= "" then
                return okay
            end
            -- <dpi>.dpi/name.<dpi>pk
            local temp = join(dpi..".dpi",name)
            local okay = findbinfile(temp,"pk")
         -- print(temp,okay)
            return okay or ""
        end

        resolvers.findpk = findpk

     -- register('process_jobname'     , function(name) return name end, true)

        register('find_read_file'      , function(id,name) return findtexfile(name)       end, true)
        register('open_read_file'      , function(   name) return opentexfile(name)       end, true)

        register('find_data_file'      , function(name) return findbinfile(name,"tex")    end, true)
        register('open_data_file'      , function(name) return opentexfile(name)          end, true)

        register('find_enc_file'       , function(name) return findbinfile(name,"enc")    end, true)
        register('find_font_file'      , function(name) return findbinfile(name,"tfm")    end, true)
     -- register('find_format_file'    , function(name) return findbinfile(name,"fmt")    end, true)
        register('find_image_file'     , function(name) return findbinfile(name,"tex")    end, true)
        register('find_map_file'       , function(name) return findbinfile(name,"map")    end, true)
        register('find_opentype_file'  , function(name) return findbinfile(name,"otf")    end, true)
        register('find_output_file'    , function(name) return name                       end, true)
        register('find_pk_file'        , findpk, true)
     -- register('find_sfd_file'       , function(name) return findbinfile(name,"sfd")    end, true)
        register('find_truetype_file'  , function(name) return findbinfile(name,"ttf")    end, true)
        register('find_type1_file'     , function(name) return findbinfile(name,"pfb")    end, true)
        register('find_vf_file'        , function(name) return findbinfile(name,"vf")     end, true)
        register('find_cidmap_file'    , function(name) return findbinfile(name,"cidmap") end, true)

        register('read_data_file'      , function(file) return loadbinfile(file,"tex")    end, true)
        register('read_enc_file'       , function(file) return loadbinfile(file,"enc")    end, true)
        register('read_font_file'      , function(file) return loadbinfile(file,"tfm")    end, true)
     -- format
     -- image
        register('read_map_file'       , function(file) return loadbinfile(file,"map")    end, true)
     -- output
        register('read_pk_file'        , function(file) return loadbinfile(file,"pk")     end, true) -- 600dpi/manfnt.720pk
     -- register('read_sfd_file'       , function(file) return loadbinfile(file,"sfd")    end, true)
        register('read_vf_file'        , function(file) return loadbinfile(file,"vf" )    end, true)

     -- register('find_font_file'      , function(name) return findbinfile(name,"ofm")    end, true)
     -- register('find_vf_file'        , function(name) return findbinfile(name,"ovf")    end, true)

     -- register('read_font_file'      , function(file) return loadbinfile(file,"ofm")    end, true)
     -- register('read_vf_file'        , function(file) return loadbinfile(file,"ovf")    end, true)

     -- register('read_opentype_file'  , function(file) return loadbinfile(file,"otf")    end, true)
     -- register('read_truetype_file'  , function(file) return loadbinfile(file,"ttf")    end, true)
     -- register('read_type1_file'     , function(file) return loadbinfile(file,"pfb")    end, true)
     -- register('read_cidmap_file'    , function(file) return loadbinfile(file,"cidmap") end, true)

        register('find_write_file'     , function(id,name) return name end, true)

        register('find_log_file'       , function(name)    return name end, true)
        register('find_format_file'    , function(name)    return name end, true)

    end

end

statistics.register("resource resolver", function()
    local scandata = resolvers.scandata()
    return format("loadtime %s seconds, %s scans with scantime %s seconds, %s shared scans, %s found files, scanned paths: %s",
        resolvers.loadtime(),
        scandata.n,
        scandata.time,
        scandata.shared,
        #resolvers.foundintrees(),
        #scandata.paths > 0 and concat(scandata.paths," ") or "<none>"
    )
end)
