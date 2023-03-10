-- version   = 1.000,
-- comment   = "companion to luametatex",
-- author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
-- copyright = "PRAGMA ADE / ConTeXt Development Team",
-- license   = "see context related readme files"

-- If you copy or link 'luametatex' to 'texlua' and put this script in the same path
-- we have a more pure Lua runner (as with luatex and texlua).

-- todo: error trace
-- todo: protect these locals

local texlua_load     = load
local texlua_loadfile = loadfile
local texlua_type     = type
local texlua_xpcall   = xpcall
local texlua_find     = string.find
local texlua_dump     = string.dump
local texlua_open     = io.open
local texlua_print    = print
local texlua_show     = luac.print

function texlua_inspect(v)
    if texlua_type(v) == "function" then
        local ok, str = texlua_xpcall(texlua_dump,function() end,v)
        if ok then
            v = str
        end
    end
    if type(v) == "string" then
        texlua_show(v,true)
    else
        texlua_print(v)
    end
end

local function main_execute(str,loader)
    if str and str ~= "" then
        local str = loader(str)
        if texlua_type(str) == "function" then
            str()
        end
    end
end

local function main_compile(str,loader,out,strip)
    if str and str ~= "" then
        local str = loader(str)
        if texlua_type(str) == "function" then
            str = texlua_dump(str,strip)
            if type(out) == "string" and out ~= "" then
                local f = texlua_open(out,"wb")
                if f then
                    f:write(str)
                    f:close()
                end
            elseif out == true then
                texlua_inspect(str)
            else
                texlua_print(str)
            end
        end
    end
end

local function main_help()
    texlua_print("LuaMetaTeX in Lua mode:")
    texlua_print("")
    texlua_print("-o  'filename'  output filename")
    texlua_print("-e  'string'    execute loaded string")
    texlua_print("-f  'filename'  execute loaded file")
    texlua_print("-d  'string'    dump bytecode of loaded string")
    texlua_print("-c  'filename'  dump bytecode of loaded file")
    texlua_print("-i  'string'    list bytecode of loaded string")
    texlua_print("-l  'filename'  list bytecode of loaded file")
    texlua_print("-s              strip byte code")
    texlua_print("    'filename'  execute loaded file")
end

local function main()
    local i = 1
    local o = ""
    local s = false
    while true do
        local option = arg[i] or ""
        if option == "" then
            if i == 1 then
                main_help()
            end
            break
        elseif option == "-e" then
            i = i + 1
            main_execute(arg[i],texlua_load)
            o = ""
            s = false
        elseif option == "-f" then
            i = i + 1
            main_execute(arg[i],texlua_loadfile)
            o = ""
            s = false
        elseif option == "-d" then
            i = i + 1
            main_compile(arg[i],texlua_load,o,s)
            o = ""
            s = false
        elseif option == "-c" then
            i = i + 1
            main_compile(arg[i],texlua_loadfile,o,s)
            o = ""
            s = false
        elseif option == "-i" then
            i = i + 1
            main_compile(arg[i],texlua_load,true)
            o = ""
            s = false
        elseif option == "-l" then
            i = i + 1
            main_compile(arg[i],texlua_loadfile,true)
            o = ""
            s = false
        elseif option == "-s" then
            s = true
        elseif option == "-o" then
            i = i + 1
            o = arg[i] or ""
            if texlua_find(o,"^%-") then
                help()
                break
            end
        elseif not texlua_find(option,"^%-") then
            main_execute(option,texlua_loadfile)
            break
        else
            main_help()
            break
        end
        i = i + 1
    end
end

main()
