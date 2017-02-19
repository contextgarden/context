if not modules then modules = { } end modules ['luat-exe'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not sandbox then require("l-sandbox") require("util-sbx") end -- for testing

-- Ok, as usual, after finishing some code, I rewarded myself with searching youtube for
-- new music ... this time I ran into the swedisch group 'wintergatan' (search for: marble
-- machine) ... mechanical computers are so much more fun than the ones needed for running
-- the code below. Nice videos (and shows) too ...

local type = type

local executers        = resolvers.executers or { }
resolvers.executers    = executers

local disablerunners   = sandbox.disablerunners
local disablelibraries = sandbox.disablelibraries
local registerbinary   = sandbox.registerbinary
local registerlibrary  = sandbox.registerlibrary
local registerroot     = sandbox.registerroot

local lpegmatch        = lpeg.match

local sc_splitter      = lpeg.tsplitat(";")
local cm_splitter      = lpeg.tsplitat(",")

local execution_mode  directives.register("system.executionmode", function(v) execution_mode = v end)
local execution_list  directives.register("system.executionlist", function(v) execution_list = v end)
local root_list       directives.register("system.rootlist",      function(v) root_list      = v end)
local library_mode    directives.register("system.librarymode",   function(v) library_mode   = v end)
local library_list    directives.register("system.librarylist",   function(v) library_list   = v end)

sandbox.initializer {
    category = "binaries",
    action   = function()
        if execution_mode == "none" then
            -- will be done later
        elseif execution_mode == "list" then
            if type(execution_list) == "string" then
                execution_list = lpegmatch(cm_splitter,execution_list)
            end
            if type(execution_list) == "table" then
                for i=1,#execution_list do
                    registerbinary(execution_list[i])
                end
            end
        else
            registerbinary(true) -- all
        end
    end
}

sandbox.finalizer {
    category = "binaries",
    action   = function()
        if execution_mode == "none" then
            disablerunners()
        end
    end
}

sandbox.initializer {
    category = "libraries",
    action   = function()
        if library_mode == "none" then
            -- will be done later
        elseif library_mode == "list" then
            if type(library_list) == "string" then
                library_list = lpegmatch(cm_splitter,library_list)
            end
            if type(library_list) == "table" then
                for i=1,#library_list do
                    registerlibrary(library_list[i])
                end
            end
        else
            registerlibrary(true) -- all
        end
    end
}

sandbox.finalizer {
    category = "libraries",
    action   = function()
        if library_mode == "none" then
            disablelibraries()
        end
    end
}

-- A bit of file system protection.

sandbox.initializer{
    category = "files",
    action   = function ()
        if type(root_list) == "string" then
            root_list = lpegmatch(sc_splitter,root_list)
        end
        if type(root_list) == "table" then
            for i=1,#root_list do
                registerroot(root_list[i])
            end
        end
    end
}

-- Let's prevent abuse of these libraries (built-in support still works).

sandbox.finalizer {
    category = "functions",
    action   = function()
        mplib      = nil
        epdf       = nil
        zip        = nil
        fontloader = nil
    end
}
