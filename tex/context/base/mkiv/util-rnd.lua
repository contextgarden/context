if not modules then modules = { } end modules ['util-rnd'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Tamara, Adriana, Tomáš Hála & Hans Hagen",
    copyright = "ConTeXt Development Team", -- umbrella
    license   = "see context related readme files"
}

-- The rounding code is a variant on Tomáš Hála <tomas.hala@mendelu.cz; mendelu@thala.cz>
-- code that is used in the statistical module. We use local variables and a tolerant name
-- resolver that also permits efficient local aliases. With code like this one
-- really have to make sure that locals are used because changing the rounding
-- can influence other code.

local floor, ceil, pow = math.floor, math.ceil, math.pow
local rawget, type = rawget, type
local gsub, lower = string.gsub, string.lower

local rounding = { }

local methods = {
    no = function(num)
        -- no rounding
        return num
    end,
    up = function(num,coef)
        -- ceiling rounding
        coef = coef and pow(10,coef) or 1
        return ceil(num * coef) / coef
    end,
    down = function(num,coef)
        -- floor rounding
        coef = coef and pow(10,coef) or 1
        return floor(num * coef) / coef
    end,
    halfup = function(num,coef)
        -- rounds decimal numbers as usual, numbers with 0.5 up, too (e.g. number -0.5 will be rounded to 0)
        coef = coef and pow(10,coef) or 1
        return floor(num * coef + 0.5) / coef
    end,
    halfdown = function(num,coef)
        -- rounds decimal numbers as usual, numbers with 0.5 down, too (e.g. number 0.5 will be rounded to 0)
        coef = coef and pow(10,coef) or 1
        return ceil(num * coef -0.5) / coef
    end,
    halfabsup = function(num,coef)
        -- rounds deciaml numbers as usual, numbers with 0.5 away from zero, e.g. numbers -0.5 and 0.5 will be rounded to -1 and 1
        coef = coef and pow(10,coef) or 1
        return (num >= 0 and floor(num * coef + 0.5) or ceil(num * coef - 0.5)) / coef
    end,
    halfabsdown = function(num,coef)
        -- rounds deciaml numbers as usual, numbers with 0.5 towards zero, e.g. numbers -0.5 and 0.5 will be rounded both to 0
        coef = coef and pow(10,coef) or 1
        return (num <  0 and floor(num * coef + 0.5) or ceil(num * coef - 0.5)) / coef
    end,
    halfeven = function(num,coef)
       -- rounds deciaml numbers as usual, numbers with 0.5 to the nearest even, e.g. numbers 1.5 and 2.5 will be rounded both to 2
        coef = coef and pow(10,coef) or 1
        num = num*coef
        return floor(num + (((num - floor(num)) ~= 0.5 and 0.5) or ((floor(num) % 2 == 1) and 1) or 0)) / coef
    end,
    halfodd = function(num,coef)
        -- rounds deciaml numbers as usual, numbers with 0.5 to the nearest odd (e.g. numbers 1.5 and 2.5 will be rounded to 1 and 3
        coef = coef and pow(10,coef) or 1
        num = num * coef
        return floor(num + (((num - floor(num)) ~= 0.5 and 0.5) or ((floor(num) % 2 == 1) and 0) or 1)) / coef
    end,
}

methods.default = methods.halfup

rounding.methods = table.setmetatableindex(methods,function(t,k)
    local s = gsub(lower(k),"[^a-z]","")
    local v = rawget(t,s)
    if not v then
        v = t.halfup
    end
    t[k] = v
    return v
end)

-- If needed I can make a high performance one.

local defaultmethod = methods.halfup

rounding.round = function(num,dec,mode)
    if type(dec) == "string" then
        mode = dec
        dec  = 1
    end
    return (mode and methods[mode] or defaultmethods)(num,dec)
end

number.rounding = rounding

-- -- Tomáš' test numbers:

-- local list = { 5.49, 5.5, 5.51, 6.49, 6.5, 6.51, 0.5, 12.45 }
--
-- for method, round in table.sortedhash(number.rounding.methods) do
--     for i=1,#list do
--         local n = list[i]
--         print(n,method,round(n,k),round(n,k,3))
--     end
-- end
--
-- local myround = number.rounding.methods["HALF ABS DOWN"]
--
-- for i=1,#list do
--     local n = list[i]
--     print(n,"Half Abs Down",number.rounding.round(n,1,"Half Abs Down"))
--     print(n,"HALF_ABS_DOWN",number.rounding.round(n,1,"HALF_ABS_DOWN"))
--     print(n,"HALF_ABS_DOWN",myround(n,1))
-- end

return rounding
