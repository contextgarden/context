if not modules then modules = { } end modules ['lpdf-eng'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Here we plug in the regular luatex image handler. The low level module itself
-- is hidden from the user.

local codeinjections = backends.pdf.codeinjections
local imgnew         = img.new

function codeinjections.newimage(specification)
    if type(specification) == "table" then
        specification.kind = nil
    end
    return imgnew(specification)
end

codeinjections.copyimage  = img.copy
codeinjections.scanimage  = img.scan
codeinjections.embedimage = img.immediatewrite
codeinjections.wrapimage  = img.node

-- We cannot nil the img table because the backend code explicitly accesses the
-- new field when dealing with virtual characters. I should patch luatex for that
-- and maybe I will. So no:
--
-- img = nil
--
-- We keep the low level img.new function but make the rest kind of unseen. At some
-- point the other ones will be gone and one has to use the images.* wrappers.

local unpack = unpack
local sortedkeys = table.sortedkeys
local context = context

img = table.setmetatableindex (
    {
        new                  = images.create,
    },
    {
     -- new                  = images.create,
        scan                 = images.scan,
        copy                 = images.copy,
        node                 = images.wrap,
        write                = function(specification) context(images.wrap(specification)) end,
        immediatewrite       = images.embed,
        immediatewriteobject = function() end, -- not upported, experimental anyway
        boxes                = function() return sortedkeys(images.sizes) end,
        fields               = function() return images.keys end,
        types                = function() return { unpack(images.types,0,#images.types) } end,
    }
)

--

do

    local function prepare(driver)
        if not environment.initex then
            -- install new functions in pdf namespace
            updaters.apply("backend.update.pdf")
            -- install new functions in lpdf namespace
            updaters.apply("backend.update.lpdf")
            -- adapt existing shortcuts to lpdf namespace
            updaters.apply("backend.update.tex")
            -- adapt existing shortcuts to tex namespace
            updaters.apply("backend.update")
            --
        end
    end

    local function outputfilename(driver)
        if not filename then
            filename = addsuffix(tex.jobname,"pdf")
        end
        return filename
    end

    drivers.install {
        name     = "pdf",
        flushers = {
            -- nothing here
        },
        actions  = {
            convert        = drivers.converters.engine,
            outputfilename = outputfilename,
            prepare        = prepare,
        },
    }

end

