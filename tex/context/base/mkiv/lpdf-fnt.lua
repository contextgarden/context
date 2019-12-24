if not modules then modules = { } end modules ['lpdf-fnt'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is experimental code.

local match, gmatch = string.match, string.gmatch
local tonumber, rawget = tonumber, rawget

local pdfreserveobject = lpdf.reserveobject
local pdfincludechar   = lpdf.includechar
local pdfincludefont   = lpdf.includefont
local pdfreference     = lpdf.reference

local pdfe = lpdf.epdf

local tobemerged   = { }
local trace_merge  = false  trackers.register("graphics.fonts",function(v) trace_merge = v end)
local report_merge = logs.reporter("graphics","fonts")

local function register(usedname,cleanname)
    local cleanname = cleanname or fonts.names.cleanname(usedname)
    local fontid    = fonts.definers.internal { name = cleanname }
    if fontid then
        local objref = pdfreserveobject()
        pdfincludefont(fontid)
        if trace_merge then
            report_merge("registering %a with name %a, id %a and object %a",usedname,cleanname,fontid,objref)
        end
        return {
            id        = fontid,
            reference = objref,
            indices   = { },
            cleanname = cleanname,
        }
    end
    return false
end

function lpdf.registerfont(usedname,cleanname)
    local v = register(usedname,cleanname)
    tobemerged[usedname] = v
    return v
end

table.setmetatableindex(tobemerged,function(t,k)
    return lpdf.registerfont(k)
end)

local function finalizefont(v)
    local indextoslot = fonts.helpers.indextoslot
    if v then
        local id = v.id
        local n  = 0
        for i in next, v.indices do
            local u = indextoslot(id,i)
         -- pdfincludechar(id,u)
            n = n + 1
        end
        v.n = n
    end
end

statistics.register("merged fonts", function()
    if next(tobemerged) then
        local t = { }
        for k, v in table.sortedhash(tobemerged) do
            t[#t+1] = string.formatters["%s (+%i)"](k,v.n)
        end
        return table.concat(t," ")
    end
end)

function lpdf.finalizefonts()
    for k, v in next, tobemerged do
        finalizefont(v)
    end
end

callback.register("font_descriptor_objnum_provider",function(name)
    local m = rawget(tobemerged,name)
    if m then
     -- finalizefont(m)
        local r = m.reference or 0
        if trace_merge then
            report_merge("using object %a for font descriptor of %a",r,name)
        end
        return r
    end
    return 0
end)

local function getunicodes1(str,indices)
    for s in gmatch(str,"beginbfrange%s*(.-)%s*endbfrange") do
        for first, last, offset in gmatch(s,"<([^>]+)>%s+<([^>]+)>%s+<([^>]+)>") do
            for i=tonumber(first,16),tonumber(last,16) do
                indices[i] = true
            end
        end
    end
    for s in gmatch(str,"beginbfchar%s*(.-)%s*endbfchar") do
        for old, new in gmatch(s,"<([^>]+)>%s+<([^>]+)>") do
            indices[tonumber(old,16)] = true
        end
    end
end

local function getunicodes2(widths,indices)
    for i=1,#widths,2 do
        local start =  widths[i]
        local count = #widths[i+1]
        if start and count then
            for i=start,start+count-1 do
                indices[i] = true
            end
        end
    end
end

local function checkedfonts(pdfdoc,xref,copied,page)
    local list = page.Resources.Font
    local done = { }
    for k, somefont in pdfe.expanded(list) do
        if somefont.Subtype == "Type0" and somefont.Encoding == "Identity-H" then
            local descendants = somefont.DescendantFonts
            if descendants then
                for i=1,#descendants do
                    local d = descendants[i]
                    if d then
                        local subtype = d.Subtype
                        if subtype == "CIDFontType0" or subtype == "CIDFontType2" then
                            local basefont = somefont.BaseFont
                            if basefont then
                                local fontname = match(basefont,"^[A-Z]+%+(.+)$")
                                local fontdata = tobemerged[fontname]
                                if fontdata then
                                    local descriptor = d.FontDescriptor
                                    if descriptor then
                                        local okay   = false
                                        local widths = d.W
                                        if widths then
                                            getunicodes2(widths,fontdata.indices)
                                            okay = true
                                        else
                                            local tounicode = somefont.ToUnicode
                                            if tounicode then
                                                getunicodes1(tounicode(),fontdata.indices)
                                                okay = true
                                            end
                                        end
                                        if okay then
                                            local r = xref[descriptor]
                                            done[r] = fontdata.reference
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return next(done) and done
end

if pdfincludefont then

    function lpdf.epdf.plugin(pdfdoc,xref,copied,page)
        local done = checkedfonts(pdfdoc,xref,copied,page)
        if done then
            return {
                FontDescriptor = function(xref,copied,object,key,value,copyobject)
                    local r = value[3]
                    local d = done[r]
                    if d then
                        return pdfreference(d)
                    else
                        return copyobject(xref,copied,object,key,value)
                    end
                end
            }
        end
    end

else

    function lpdf.epdf.plugin() end

end

lpdf.registerdocumentfinalizer(lpdf.finalizefonts)

-- already defined in font-ocl but the context variatn will go here
--
-- function lpdf.vfimage(wd,ht,dp,data,name)
--     return { "image", { filename = name, width = wd, height = ht, depth = dp } }
-- end
