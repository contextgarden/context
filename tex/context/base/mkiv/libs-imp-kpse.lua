if not modules then modules = { } end modules ['libs-imp-kpse'] = {
    version   = 1.001,
    comment   = "companion to luat-imp-kpse.mkxl",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is an experiment. It might make sense to have this available in case I want
-- more runners to use LuaMetaTeX in which case (as with mtxrun using LuaTeX) we
-- need to load kpse.

local libname = "kpse"
local libfile = (os.platform == "win64" and "kpathsea*w64")
             or (os.platform == "win32" and "kpathsea*w32")
             or "libkpathsea"
local libkpse = resolvers.libraries.validoptional(libname)

if package.loaded[libname] then
    return package.loaded[libname]
end

-- This is a variant that loaded directly:

-- kpse = libkpse -- the library will issue warnings anyway
--
-- resolvers.libraries.optionalloaded(libname,libfile) -- no need to chedk if true

-- This variant delays loading and has a bit more protection:

local function okay()
    if libkpse and resolvers.libraries.optionalloaded(libname,libfile) then
        okay = function() return true end
    else
        okay = function() return false end
    end
    return okay()
end

local kpse = { }

for k, v in next, libkpse do
    kpse[k] = function(...) if okay() then return v(...) end end
end

-- We properly register the module:

package.loaded[libname] = kpse

optional.loaded.kpse = kpse

-- A simple test:

-- kpse.set_program_name("pdftex")
-- print("find file:",kpse.find_file("oeps.tex"))
-- print("find file:",kpse.find_file("context.mkii"))

return kpse
