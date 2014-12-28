if not modules then modules = { } end modules ['luat-exe'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not sandbox then require("l-sandbox") require("util-sbx") end -- for testing

local type = type

local executers      = resolvers.executers or { }
resolvers.executers  = executers

local disablerunners = sandbox.disablerunners
local registerbinary = sandbox.registerbinary
local registerroot   = sandbox.registerroot

local lpegmatch      = lpeg.match

local sc_splitter    = lpeg.tsplitat(";")
local cm_splitter    = lpeg.tsplitat(",")

local execution_mode  directives.register("system.executionmode", function(v) execution_mode = v end)
local execution_list  directives.register("system.executionlist", function(v) execution_list = v end)
local root_list       directives.register("system.rootlist",      function(v) root_list      = v end)

sandbox.initializer(function()
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
        -- whatever else we have configured
    end
end)

sandbox.initializer(function()
    if type(root_list) == "string" then
        root_list = lpegmatch(sc_splitter,root_list)
    end
    if type(root_list) == "table" then
        for i=1,#root_list do
            local entry = root_list[i]
            if entry ~= "" then
                registerroot(entry)
            end
        end
    end
end)

sandbox.finalizer(function()
    if execution_mode == "none" then
        disablerunners()
    end
end)

-- Let's prevent abuse of these libraries (built-in support still works).

sandbox.finalizer(function()
    mplib      = nil
    epdf       = nil
    zip        = nil
    fontloader = nil
end)
