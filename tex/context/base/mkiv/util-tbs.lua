if not modules then modules = { } end modules ['util-tbs'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber, type, rawget = tonumber, type, rawget

utilities            = utilities or {}
local tablestore     = { }
utilities.tablestore = tablestore

local loaded  = { }
local current = nil

function tablestore.load(namespace,filename)
    local data = loaded[namespace]
    if not data then
        if type(filename) == "table" then
            data = filename
        else
            local fullname = resolvers.findfile(filename)
            if fullname and fullname ~= "" then
                if file.suffix(fullname,"json") and utilities.json then
                    data = io.loaddata(fullname)
                    if data then
                        data = utilities.json.tolua(data)
                    else
                        -- error
                    end
                else
                    data = table.load(fullname)
                end
            end
        end
        if not data then
            data = { }
        end
        loaded[namespace] = data
        if metapost then
            metapost.setparameterset(namespace,data)
        end
    end
    current = data
    return data
end

function tablestore.loaded(namespace)
    return (namespace and loaded[namespace]) or current or { }
end

function tablestore.known(namespace)
    return namespace and rawget(loaded,namespace) or false
end

do

    local find, gmatch, formatters = string.find, string.gmatch, string.formatters

    local P, C, Ct, Cc, R = lpeg.P, lpeg.C, lpeg.Ct, lpeg.Cc, lpeg.R

    local separator = P(".")
    local equal     = P("=")
    local digit     = R("09")
    local lbracket  = P("[")
    local rbracket  = P("]")
    local index     = Ct(Cc("index") * lbracket * (digit^1 / tonumber) * rbracket)
    local test      = Ct(Cc("test")  * lbracket * C((1-equal)^1) * equal * C((1-rbracket)^1) * rbracket)
    local entry     = Ct(Cc("entry") * C((1-lbracket-separator)^1))

    local specifier = Ct ((entry + (separator + index + test))^1)

    local function field(namespace,name,default)
        local data = loaded[namespace] or current
        if data then
    --         if find(name,"%[") then
                local t = lpeg.match(specifier,name)
                for i=1,#t do
                    local ti = t[i]
                    local t1 = ti[1]
                    local k  = ti[2]
                    if t1 == "test" then
                        local v = ti[3]
                        for j=1,#data do
                            local dj = data[j]
                            if dj[k] == v then
                                data = dj
                                goto OKAY
                            end
                        end
                        return
                    else
                        data = data[k]
                        if not data then
                            return
                        end
                    end
                  ::OKAY::
                end
    --         else
    --             for s in gmatch(name,"[^%.]+") do
    --                 data = data[s] or data[tonumber(s) or 0]
    --                 if not data then
    --                     return
    --                 end
    --             end
    --         end
            return data
        end
    end


    function length(namespace,name,default)
        local data = field(namespace,name)
        return type(data) == "table" and #data or 0
    end

    function formatted(namespace,name,fmt)
        local data = field(namespace,name)
        if data then
            return formatters[fmt](data)
        end
    end

    tablestore.field     = field
    tablestore.length    = length
    tablestore.formatted = formatted

end
