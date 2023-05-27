-- The data is taken from:
--
--   https://github.com/anyascii/anyascii/blob/master/table.tsv
--
-- by Hunter WB under the ISC License (2020-2023).
--
-- Updating:
--
-- -- copy table.tsv to lang-imp-simpleascii-data.tsv
-- -- mtxrun --script lang-imp-simpleascii
-- -- copy lang-imp-simpleascii-data.lgz over old file
--
-- Usage:
--
-- \usetransliteration[simpleascii]
--
-- \definetransliteration
--     [simpleascii]
--     [color=blue,
--      vector={simple ascii}]
--
-- \settransliteration[simpleascii]
--
-- \starttext
--
-- \startchapter[title={深圳 ଗଜପତି Blöße}]
--     深圳 ଗଜପତି Blöße\par
--     深圳 ଗଜପତି Blöße\par
--     深圳 ଗଜପତି Blöße\par
--     深圳 ଗଜପତି Blöße\par
-- \stopchapter
--
-- \stoptext

local textfile = "lang-imp-simpleascii-data.tsv"  -- a copy of table.tsv
local datafile = "lang-imp-simpleascii-data.lua"  -- for tracing
local compfile = "lang-imp-simpleascii-data.lgz"  -- idem in distribution

local verbose = false -- when true, saved uncompressed file for tracing
local report  = logs.reporter("simpleascii")

if not context and lfs.isfile(textfile) then

    -- We save it in the local path so we need to move it explicitly into
    -- the tree which prevents errors.

    local data = io.loaddata(textfile)
    if data and data ~= "" then
        local mapping = { }
        for k, v in string.gmatch(data,"(%S+)[\t]*([^\n\r]-)[\n\r]") do
            if k ~= "" and v ~= "" and k ~= v then
                mapping[k] = v
            end
        end
        if verbose then
            table.save(datafile,mapping)
        else
            mapping  = gzip.compress(table.fastserialize(mapping)) -- zlib.compress(d,9)
            datafile = compfile
            io.savedata(compfile,mapping)
        end
        report("data from %a saved in %a",textfile,datafile)
    else
        report("no data file %a",textfile)
    end

else

    local mapping  = false

    if not verbose then
        mapping = io.loaddata(resolvers.findfile(compfile) or "")
        if mapping then
            mapping  = table.deserialize(gzip.decompress(mapping)) -- zlib.decompress(d)
            if mapping then
                datafile = compfile
            else
                report("data file %a is corrupt",compfile)
            end
        end
    end
    if not mapping then
        mapping = table.load(resolvers.findfile(datafile) or "")
    end

    if mapping then

        report("data file %a loaded",datafile)

     -- for i = 0, 127 do
     --     mapping[utfchar(i)] = utfchar(i) -- not needed
     -- end

        return {

            name      = "simple ascii",
            version   = "1.00",
            comment   = "Unicode to ASCII transliteration",
            author    = "Jairo A. del Rio & Hans Hagen",
            copyright = "ConTeXt development team & whoever made this list",

            transliterations = {
                ["simple ascii"] = {
                    mapping = mapping
                },
            }

        }

    else
        report("no data file %a",datafile)
    end

end
