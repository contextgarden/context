if not modules then modules = { } end modules ['lpdf-lmt'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The code below was originally in back-lpd.lua but it makes more sense in
-- this namespace. I will rename variables.
--
-- There is no way that a lua based backend can compete with the original one
-- for relative simple text runs. And we're talking seconds here on say 500
-- pages with paragraphs alternativng between three fonts and colors. But such
-- documents are rare so in practice we are quite okay, especially because in
-- ConTeXt we can gain quite a bit elsewhere. So, when we loose 30% on such
-- simple documents, we break even on for instance the manual, and gain 30% on
-- Thomas's turture test (also for other reasons). But .. who knows what magic
-- I can cook up in due time.

-- If you consider this complex, watch:
--
-- https://www.youtube.com/watch?v=6H-cAzfB2qo
--
-- or in distractionmode:
--
-- https://www.youtube.com/watch?v=TYuTE_1jvvE
-- https://www.youtube.com/watch?v=nnicGKX3lvM
--
-- For the moment we have to support the built in backend as well as the alternative. So
-- the next interface is suboptimal and will change at some time. At that moment I will
-- also optimize and extend.

local type, next, unpack, tonumber = type, next, unpack, tonumber
local char, rep, find = string.char, string.rep, string.find
local formatters, splitupstring = string.formatters, string.splitup
local band, extract = bit32.band, bit32.extract
local concat, sortedhash = table.concat, table.sortedhash
local setmetatableindex = table.setmetatableindex
local loaddata = io.loaddata

local bpfactor     <const> = number.dimenfactors.bp

local md5HEX               = md5.HEX
local osuuid               = os.uuid
local zlibcompress         = (xzip or zlib).compress

local nuts                 = nodes.nuts
local tonut                = nodes.tonut

local getdata              = nuts.getdata
local getsubtype           = nuts.getsubtype
local getwhd               = nuts.getwhd
local flushlist            = nuts.flush_list

local pdfincludeimage      = lpdf.includeimage
local pdfgetfontname       = lpdf.getfontname
local pdfgetfontobjnumber  = lpdf.getfontobjnumber

local pdfreserveobject     = lpdf.reserveobject
local pdfpagereference     = lpdf.pagereference
local pdfflushobject       = lpdf.flushobject
local pdfreference         = lpdf.reference
local pdfdictionary        = lpdf.dictionary
local pdfarray             = lpdf.array
local pdfconstant          = lpdf.constant
local pdfflushstreamobject = lpdf.flushstreamobject
local pdfliteral           = lpdf.literal -- not to be confused with a whatsit!

local pdf_pages            = pdfconstant("Pages")
local pdf_page             = pdfconstant("Page")
local pdf_xobject          = pdfconstant("XObject")
local pdf_form             = pdfconstant("Form")

local fonthashes           = fonts.hashes
local characters           = fonthashes.characters
local parameters           = fonthashes.parameters
local properties           = fonthashes.properties

local report               = logs.reporter("backend")

-- used variables

local pdf_h, pdf_v
local need_tm, need_tf, cur_tmrx, cur_factor, cur_f, cur_e
local need_width, need_mode, done_width, done_mode
local mode
local f_pdf_cur, f_pdf, fs_cur, fs, f_cur
local tj_delta, cw
local usedfonts, usedxforms, usedximages, usedxgroups
local getxformname, getximagename
local boundingbox, shippingmode, objectnumber
local tmrx, tmry, tmsx, tmsy, tmtx, tmty
local cmrx, cmry, cmsx, cmsy, cmtx, cmty

local function usefont(t,k) -- a bit redundant hash
    local v = pdfgetfontname(k)
    t[k] = v
    return v
end

local function reset_variables(specification)
    pdf_h, pdf_v  = 0, 0
    cmrx, cmry    = 1, 1
    cmsx, cmsy    = 0, 0
    cmtx, cmty    = 0, 0
    tmrx, tmry    = 1, 1
    tmsx, tmsy    = 0, 0
    tmtx, tmty    = 0, 0
    need_tm       = false
    need_tf       = false
    need_width    = 0
    need_mode     = 0
    done_width    = false
    done_mode     = false
    mode          = "page"
    shippingmode  = specification.shippingmode
    objectnumber  = specification.objectnumber
    cur_tmrx      = 0
    f_cur         = 0
    f_pdf_cur     = 0 -- nullfont
    f_pdf         = 0 -- nullfont
    fs_cur        = 0
    fs            = 0
    tj_delta      = 0
    cur_factor    = 0
    cur_f         = false
    cur_e         = false
    cw            = 0
    usedfonts     = setmetatableindex(usefont)
    usedxforms    = { }
    usedximages   = { }
 -- usedxgroups   = { }
    boundingbox   = specification.boundingbox
end

-- buffer

local buffer = { }
local b      = 0

local function reset_buffer()
    b = 0
end

-- fonts

local fontcharacters
local fontparameters
local fontproperties
local usedcharacters = setmetatableindex("table")
local pdfcharacters

local horizontalmode   = true
----- widefontmode     = true
local scalefactor      = 1
local threshold        = 655360
local tjfactor <const> = 100 / 65536

lpdf.usedcharacters = usedcharacters

local function updatefontstate(font)
    fontcharacters   = characters[font]
    fontparameters   = parameters[font]
    fontproperties   = properties[font]
    local size       = fontparameters.size -- or bad news
    local designsize = fontparameters.designsize or size
    pdfcharacters    = usedcharacters[font]
    horizontalmode   = fontparameters.writingmode ~= "vertical"
 -- widefontmode     = fontproperties.encodingbytes == 2
    scalefactor      = (designsize/size) * tjfactor
    local fthreshold = fontproperties.threshold
    threshold = (fthreshold and (size * fthreshold / 100)) or 655360
end

-- helpers

local f_cm = formatters["%.6N %.6N %.6N %.6N %.6N %.6N cm"]
local f_tm = formatters["%.6N %.6N %.6N %.6N %.6N %.6N Tm"]

local saved_text_pos_v = 0
local saved_text_pos_h = 0

local function begin_text()
    saved_text_pos_h = pdf_h
    saved_text_pos_v = pdf_v
    b = b + 1 ; buffer[b] = "BT"
    need_tf    = true
    need_width = 0
    need_mode  = 0
    mode       = "text"
end

local function end_text()
    if done_width then
        b = b + 1 ; buffer[b] = "0 w"
        done_width = false
    end
    if done_mode then
        b = b + 1 ; buffer[b] = "0 Tr"
        done_mode = false
    end
    b = b + 1 ; buffer[b] = "ET"
    pdf_h = saved_text_pos_h
    pdf_v = saved_text_pos_v
    mode  = "page"
end

local saved_chararray_pos_h
local saved_chararray_pos_v

local saved_b = 0

local function begin_chararray()
    saved_chararray_pos_h = pdf_h
    saved_chararray_pos_v = pdf_v
    cw = horizontalmode and saved_chararray_pos_h or - saved_chararray_pos_v
    tj_delta = 0
    saved_b = b
    b = b + 1 ; buffer[b] = " ["
    mode = "chararray"
end

local function end_chararray()
    b = b + 1 ; buffer[b] = "] TJ"
    buffer[saved_b] = concat(buffer,"",saved_b,b)
    b = saved_b
    pdf_h = saved_chararray_pos_h
    pdf_v = saved_chararray_pos_v
    mode  = "text"
end

local function begin_charmode()
    b = b + 1 ; buffer[b] = "<"
    mode = "char"
end

local function end_charmode()
    b = b + 1 ; buffer[b] = ">"
    mode = "chararray"
end

local function calc_pdfpos(h,v)
    -- mostly char
    if mode == "page" then
        cmtx = h - pdf_h
        cmty = v - pdf_v
        return h ~= pdf_h or v ~= pdf_v
    elseif mode == "text" then
        tmtx = h - saved_text_pos_h
        tmty = v - saved_text_pos_v
        return h ~= pdf_h or v ~= pdf_v
    elseif horizontalmode then
        tmty = v - saved_text_pos_v
        tj_delta = cw - h
        return tj_delta ~= 0 or v ~= pdf_v
    else
        tmtx = h - saved_text_pos_h
        tj_delta = cw + v
        return tj_delta ~= 0 or h ~= pdf_h
    end
end

local function pdf_set_pos(h,v)
    local move = calc_pdfpos(h,v)
    if move then
        b = b + 1 ; buffer[b] = f_cm(cmrx, cmsx, cmsy, cmry, cmtx*bpfactor, cmty*bpfactor)
        pdf_h = pdf_h + cmtx
        pdf_v = pdf_v + cmty
    end
end

local function pdf_reset_pos()
    if mode == "page" then
        cmtx = - pdf_h
        cmty = - pdf_v
        if pdf_h == 0 and pdf_v == 0 then
            return
        end
    elseif mode == "text" then
        tmtx = - saved_text_pos_h
        tmty = - saved_text_pos_v
        if pdf_h == 0 and pdf_v == 0 then
            return
        end
    elseif horizontalmode then
        tmty = - saved_text_pos_v
        tj_delta = cw
        if tj_delta == 0 and pdf_v == 0 then
            return
        end
    else
        tmtx = - saved_text_pos_h
        tj_delta = cw
        if tj_delta == 0 and pdf_h == 0 then
            return
        end
    end
    b = b + 1 ; buffer[b] = f_cm(cmrx, cmsx, cmsy, cmry, cmtx*bpfactor, cmty*bpfactor)
    pdf_h = pdf_h + cmtx
    pdf_v = pdf_v + cmty
end

local function pdf_set_pos_temp(h,v)
    local move = calc_pdfpos(h,v)
    if move then
        b = b + 1 ; buffer[b] = f_cm(cmrx, cmsx, cmsy, cmry, cmtx*bpfactor, cmty*bpfactor)
    end
end

-- these dummy returns makes using them a bit faster

local function pdf_end_string_nl()
    if mode == "char" then
        end_charmode()
        return end_chararray()
    elseif mode == "chararray" then
        return end_chararray()
    end
end

local function pdf_goto_textmode()
    if mode == "page" then
        pdf_reset_pos()
        return begin_text()
    elseif mode ~= "text" then
        if mode == "char" then
            end_charmode()
            return end_chararray()
        else -- if mode == "chararray" then
            return end_chararray()
        end
    end
end

local function pdf_goto_pagemode()
    if mode ~= "page" then
        if mode == "char" then
            end_charmode()
            end_chararray()
            return end_text()
        elseif mode == "chararray" then
            end_chararray()
            return end_text()
        elseif mode == "text" then
            return end_text()
        end
    end
end

local function pdf_goto_fontmode()
    if mode == "char" then
        end_charmode()
        end_chararray()
        end_text()
    elseif mode == "chararray" then
        end_chararray()
        end_text()
    elseif mode == "text" then
        end_text()
    end
    pdf_reset_pos()
    mode = "page"
end

-- characters

local flushcharacter  do

    local round = math.round

    -- across pages ... todo: clean up because we don't need to pass the font
    -- as fontparameters already has checked / set it we can also have a variable
    -- for it so

    local function setup_fontparameters(font,factor,f,e)
        local slant   = fontparameters.slantfactor   or 0
        local extend  = fontparameters.extendfactor  or 1
        local squeeze = fontparameters.squeezefactor or 1
        local expand  = 1 + factor / 1000000
        local format  = fontproperties.format
        if e then
            extend = extend * e
        end
        tmrx       = expand * extend
        tmsy       = slant
        tmry       = squeeze
        need_width = fontparameters.width or 0
        need_mode  = fontparameters.mode or 0
        f_cur      = font
        f_pdf      = usedfonts[font] -- cache
        cur_factor = factor
        cur_f      = f
        cur_e      = e
        tj_delta   = 0
        fs         = fontparameters.size * bpfactor
        if f then
            fs = fs * f
        end
        -- kind of special:
        if format == "opentype" or format == "type1" then
            fs = fs * 1000 / fontparameters.units -- can we avoid this ?
        end
    end

    -- This only saves a little on hz because there we switch a lot of
    -- instances.

 -- local lastslant, lastextend, lastsqueeze, lastformat, lastsize, lastwidth, lastmode, lastused, lastfont

 -- local function setup_fontparameters(font,factor,f,e)
 --     if font ~= lastfont then
 --         lastslant   = fontparameters.slantfactor   or 0
 --         lastextend  = fontparameters.extendfactor  or 1
 --         lastsqueeze = fontparameters.squeezefactor or 1
 --         lastformat  = fontproperties.format
 --         lastsize    = fontparameters.size * bpfactor
 --         if format == "opentype" or format == "type1" then
 --             lastsize = lastsize * 1000 / fontparameters.units -- can we avoid this ?
 --         end
 --         lastwidth = fontparameters.width
 --         lastmode  = fontparameters.mode
 --         lastused  = usedfonts[font] -- cache
 --         lastfont  = font
 --     end
 --     local expand = 1 + factor / 1000000
 --     if e then
 --         tmrx = expand * lastextend * e
 --     else
 --         tmrx = expand * lastextend
 --     end
 --     tmsy       = lastslant
 --     tmry       = lastsqueeze
 --     need_width = lastwidth
 --     need_mode  = lastmode
 --     f_cur      = lastfont
 --     f_pdf      = lastused
 --     cur_factor = factor
 --     cur_f      = f
 --     cur_e      = e
 --     tj_delta   = 0
 --     if f then
 --         fs = lastsize * f
 --     else
 --         fs = lastsize
 --     end
 -- end

    local f_width = formatters["%.6N w"]
    local f_mode  = formatters["%i Tr"]        -- can be hash
    local f_font  = formatters["/F%i %.6N Tf"] -- can be hash

    local s_width <const> = "0 w"
    local s_mode  <const> = "0 Tr"

    local function set_font()
     -- if need_width and need_width ~= 0 then
        if need_width ~= 0 then
            b = b + 1 ; buffer[b] = f_width(bpfactor * need_width / 1000)
            done_width = true
        elseif done_width then
            b = b + 1 ; buffer[b] = s_width
            done_width = false
        end
     -- if need_mode and need_mode ~= 0 then
        if need_mode ~= 0 then
            b = b + 1 ; buffer[b] = f_mode(need_mode)
            done_mode = true
        elseif done_mode then
            b = b + 1 ; buffer[b] = s_mode
            done_mode = false
        end
        b = b + 1 ; buffer[b] = f_font(f_pdf,fs)
        f_pdf_cur = f_pdf
        fs_cur    = fs
        need_tf   = false
        need_tm   = true
    end

    local function set_textmatrix(h,v)
       local move = calc_pdfpos(h,v)
       if need_tm or move then
            b = b + 1 ; buffer[b] = f_tm(tmrx, tmsx, tmsy, tmry, tmtx*bpfactor, tmty*bpfactor)
            pdf_h = saved_text_pos_h + tmtx
            pdf_v = saved_text_pos_v + tmty
            need_tm = false
        end
        cur_tmrx = tmrx
    end

    local f_hex_4 = formatters["%04X"]
    local f_hex_2 = formatters["%02X"]

    local h_hex_4 = setmetatableindex(function(t,k) -- we already have this somewhere
        if k < 256 then -- maybe 512
            -- not sparse in this range
            for i=0,255 do
                t[i] = f_hex_4(i)
            end
            return t[k]
        else
            local v = f_hex_4(k)
            t[k] = v
            return v
        end
    end)
    local h_hex_2 = setmetatableindex(function(t,k) -- we already have this somewhere
        local v = k < 256 and f_hex_2(k) or "00"
        t[k] = v
        return v
    end)

    local trace_threshold = false  trackers.register("backends.pdf.threshold", function(v) trace_threshold = v end)

    flushcharacter = function(current,pos_h,pos_v,pos_r,font,char,data,naturalwidth,factor,width,f,e)
        if need_tf or font ~= f_cur or f_pdf ~= f_pdf_cur or fs ~= fs_cur or mode == "page" then
            pdf_goto_textmode()
            setup_fontparameters(font,factor,f,e)
            set_font()
        elseif cur_tmrx ~= tmrx or cur_factor ~= factor or cur_f ~= f or cur_e ~= e then
            setup_fontparameters(font,factor,f,e)
            need_tm = true
        end
        local move = calc_pdfpos(pos_h,pos_v)

        if trace_threshold then
            report(
                "font %i, char %C, factor %i, width %p, naturalwidth %p, move %l, tm %l, hpos %p, delta %p, threshold %p, cw %p",
                font,char,factor,width,naturalwidth,move,need_tm,pos_h,tj_delta,threshold,cw
            )
        end

        if move or need_tm then
            if not need_tm then
                if horizontalmode then
                    if (saved_text_pos_v + tmty) ~= pdf_v then
                        need_tm = true
                    elseif tj_delta >= threshold or tj_delta <= -threshold then
                        need_tm = true
                    end
                else
                    if (saved_text_pos_h + tmtx) ~= pdf_h then
                        need_tm = true
                    elseif tj_delta >= threshold or tj_delta <= -threshold then
                        need_tm = true
                    end
                end
            end
            if need_tm then
                pdf_goto_textmode()
                set_textmatrix(pos_h,pos_v)
                begin_chararray()
                move = calc_pdfpos(pos_h,pos_v)
            end
            if move then
                local d = tj_delta * scalefactor
                if d <= -0.5 or d >= 0.5 then
                    if mode == "char" then
                        end_charmode()
                    end
                    b = b + 1 ; buffer[b] = round(d) -- or f_skip(d)
                end
                cw = cw - tj_delta
            end
        end

        if mode == "chararray" then
            begin_charmode()
        end

    --  cw = cw + naturalwidth
        cw = cw + width

        local index = data.index or char

        b = b + 1 ; buffer[b] = font > 0 and h_hex_4[index] or h_hex_2[index]

        if not pdfcharacters[index] then
            pdfcharacters[index] = true
        end

    end

    flushfontchar = function(font,char,data)
        local dummy = usedfonts[font]
        local index = data.index or char
        if not pdfcharacters[index] then
            pdfcharacters[index] = true
        end
        return dummy
    end

end

-- literals

local flushliteral  do

    local nodeproperties      <const> = nodes.properties.data
    local literalvalues       <const> = nodes.literalvalues

    local originliteral_code  <const> = literalvalues.origin
    local pageliteral_code    <const> = literalvalues.page
    local alwaysliteral_code  <const> = literalvalues.always
    local rawliteral_code     <const> = literalvalues.raw
    local textliteral_code    <const> = literalvalues.text
    local fontliteral_code    <const> = literalvalues.font

    flushliteral = function(current,pos_h,pos_v,mode,str)
        if mode then
            if not str then
                mode, str = originliteral_code, mode
            elseif mode == "mode" then
                mode = literalvalues[str]
                if mode == originliteral_code then
                    pdf_goto_pagemode()
                    pdf_set_pos(pos_h,pos_v)
                elseif mode == pageliteral_code then
                    pdf_goto_pagemode()
                elseif mode == textliteral_code then
                    pdf_goto_textmode()
                elseif mode == fontliteral_code then
                    pdf_goto_fontmode()
                elseif mode == alwaysliteral_code then
                    pdf_end_string_nl()
                    need_tm = true
                elseif mode == rawliteral_code then
                    pdf_end_string_nl()
                end
                return
            else
                mode = literalvalues[mode]
            end
        else
            local p = nodeproperties[current]
            if p then
                str  = p.data
                mode = p.mode
            else
                str, mode = getdata(current)
            end
        end
        if str and str ~= "" then
            if mode == originliteral_code then
                pdf_goto_pagemode()
                pdf_set_pos(pos_h,pos_v)
            elseif mode == pageliteral_code then
                pdf_goto_pagemode()
            elseif mode == textliteral_code then
                pdf_goto_textmode()
            elseif mode == fontliteral_code then
                pdf_goto_fontmode()
            elseif mode == alwaysliteral_code then
                pdf_end_string_nl()
                need_tm = true
            elseif mode == rawliteral_code then
                pdf_end_string_nl()
            else
                report("check literal")
                pdf_goto_pagemode()
                pdf_set_pos(pos_h,pos_v)
            end
            b = b + 1 ; buffer[b] = str
        end
    end

    updaters.register("backend.update.pdf",function()
        function pdf.print(mode,str)
            if str then
                mode = literalvalues[mode]
            else
                mode, str = originliteral_code, mode
            end
            if str and str ~= "" then
                if mode == originliteral_code then
                    pdf_goto_pagemode()
                 -- pdf_set_pos(pdf_h,pdf_v)
                elseif mode == pageliteral_code then
                    pdf_goto_pagemode()
                elseif mode == textliteral_code then
                    pdf_goto_textmode()
                elseif mode == fontliteral_code then
                    pdf_goto_fontmode()
                elseif mode == alwaysliteral_code then
                    pdf_end_string_nl()
                    need_tm = true
                elseif mode == rawliteral_code then
                    pdf_end_string_nl()
                else
                    pdf_goto_pagemode()
                 -- pdf_set_pos(pdf_h,pdf_v)
                end
                b = b + 1 ; buffer[b] = str
            end
        end
    end)

end

-- grouping & orientation

local flushsave, flushrestore, flushsetmatrix  do

    local matrices     = { }
    local positions    = { }
    local nofpositions = 0
    local nofmatrices  = 0

    local f_matrix = formatters["%s 0 0 cm"]

    flushsave = function(current,pos_h,pos_v)
        nofpositions = nofpositions + 1
        positions[nofpositions] = { pos_h, pos_v, nofmatrices }
        pdf_goto_pagemode()
        pdf_set_pos(pos_h,pos_v)
        b = b + 1 ; buffer[b] = "q"
    end

    flushrestore = function(current,pos_h,pos_v)
        if nofpositions < 1 then
            return
        end
        local t = positions[nofpositions]
     -- local h = pos_h - t[1]
     -- local v = pos_v - t[2]
        if shippingmode == "page" then
            nofmatrices = t[3]
        end
        pdf_goto_pagemode()
        pdf_set_pos(pos_h,pos_v)
        b = b + 1 ; buffer[b] = "Q"
        nofpositions = nofpositions - 1
    end

    local function pdf_set_matrix(str,pos_h,pos_v)
        if shippingmode == "page" then
            local rx, sx, sy, ry = splitupstring(str," ")
            if rx and ry and sx and ry then
                rx, sx, sy, ry = tonumber(rx), tonumber(sx), tonumber(sy), tonumber(ry)
                local tx = pos_h * (1 - rx) - pos_v * sy
                local ty = pos_v * (1 - ry) - pos_h * sx
                if nofmatrices > 1 then
                    local t = matrices[nofmatrices]
                    local r_x, s_x, s_y, r_y, te, tf = t[1], t[2], t[3], t[4], t[5], t[6]
                    rx, sx = rx * r_x + sx * s_y, rx * s_x + sx * r_y
                    sy, ry = sy * r_x + ry * s_y, sy * s_x + ry * r_y
                    tx, ty = tx * r_x + ty * s_y, tx * s_x + ty * r_y
                end
                nofmatrices = nofmatrices + 1
                matrices[nofmatrices] = { rx, sx, sy, ry, tx, ty }
            end
        end
    end

    local nodeproperties = nodes.properties.data

    flushsetmatrix = function(current,pos_h,pos_v)
        local str
        if type(current) == "string" then
            str = current
        else
            local p = nodeproperties[current]
            if p then
                str = p.matrix
            else
                str = getdata(current) -- for the moment
            end
        end
        if str and str ~= "" then
            pdf_set_matrix(str,pos_h,pos_v)
            pdf_goto_pagemode()
            pdf_set_pos(pos_h,pos_v)
            b = b + 1 ; buffer[b] = f_matrix(str)
        end
    end

    do

        local function hasmatrix()
            return nofmatrices > 0
        end

        local function getmatrix()
            if nofmatrices > 0 then
                return unpack(matrices[nofmatrices])
            else
                return 1, 0, 0, 1, 0, 0
            end
        end

        updaters.register("backend.update.pdf",function()
            pdf.hasmatrix = hasmatrix
            pdf.getmatrix = getmatrix
        end)

    end

    pushorientation = function(orientation,pos_h,pos_v,pos_r)
        pdf_goto_pagemode()
        pdf_set_pos(pos_h,pos_v)
        b = b + 1 ; buffer[b] = "q"
        if orientation == 1 then
            b = b + 1 ; buffer[b] = "0 -1 1 0 0 0 cm"  --  90
        elseif orientation == 2 then
            b = b + 1 ; buffer[b] = "-1 0 0 -1 0 0 cm" -- 180
        elseif orientation == 3 then
            b = b + 1 ; buffer[b] = "0 1 -1 0 0 0 cm"  -- 270
        end
    end

    poporientation = function(orientation,pos_h,pos_v,pos_r)
        pdf_goto_pagemode()
        pdf_set_pos(pos_h,pos_v)
        b = b + 1 ; buffer[b] = "Q"
    end

 -- pushorientation = function(orientation,pos_h,pos_v,pos_r)
 --     flushsave(false,pos_h,pos_v)
 --     if orientation == 1 then
 --         flushsetmatrix("0 -1 1 0",pos_h,pos_v)
 --     elseif orientation == 2 then
 --         flushsetmatrix("-1 0 0 -1",pos_h,pos_v)
 --     elseif orientation == 3 then
 --         flushsetmatrix("0 1 -1 0",pos_h,pos_v)
 --     end
 -- end

 -- poporientation = function(orientation,pos_h,pos_v,pos_r)
 --     flushrestore(false,pos_h,pos_v)
 -- end

end

-- rules

local flushedxforms  = { } -- actually box resources but can also be direct
local localconverter = nil -- will be set

local flushrule, flushsimplerule, flushimage, flushgroup  do

    local rulecodes = nodes.rulecodes
    local newrule   = nodes.pool.rule

    local setprop   = nuts.setprop
    local getprop   = nuts.getprop

    local normalrule_code   <const> = rulecodes.normal
    local boxrule_code      <const> = rulecodes.box
    local imagerule_code    <const> = rulecodes.image
    local emptyrule_code    <const> = rulecodes.empty
    local userrule_code     <const> = rulecodes.user
    local overrule_code     <const> = rulecodes.over
    local underrule_code    <const> = rulecodes.under
    local fractionrule_code <const> = rulecodes.fraction
    local radicalrule_code  <const> = rulecodes.radical
    local outlinerule_code  <const> = rulecodes.outline

    local rule_callback = callbacks.functions.process_rule

    local f_fm = formatters["/Fm%d Do"]
    local f_im = formatters["/Im%d Do"]
    local f_gr = formatters["/Gp%d Do"]

    local s_b <const> = "q"
    local s_e <const> = "Q"

    local f_v = formatters["[] 0 d 0 J %.6N w 0 0 m %.6N 0 l S"]
    local f_h = formatters["[] 0 d 0 J %.6N w 0 0 m 0 %.6N l S"]

    local f_f = formatters["0 0 %.6N %.6N re f"]
    local f_o = formatters["[] 0 d 0 J 0 0 %.6N %.6N re S"]
    local f_w = formatters["[] 0 d 0 J %.6N w 0 0 %.6N %.6N re S"]

    -- Historically the index is an object which is kind of bad.

    local boxresources, n = { }, 0

    getxformname = function(index)
        local l = boxresources[index]
        if l then
            return l.name
        else
            report("no box resource %S",index)
        end
    end

    updaters.register("backend.update.pdf",function()
        pdf.getxformname = getxformname
    end)

    local function saveboxresource(box,attributes,resources,immediate,kind,margin)
        n = n + 1
        local immediate = true
        local margin    = margin or 0 -- or dimension
        local objnum    = pdfreserveobject()
        local list      = tonut(type(box) == "number" and tex.takebox(box) or box)
        --
        local width, height, depth = getwhd(list)
        --
        local l = {
            width      = width,
            height     = height,
            depth      = depth,
            margin     = margin,
            attributes = attributes,
            resources  = resources,
            list       = nil,
            type       = kind,
            name       = n,
            index      = objnum,
            objnum     = objnum,
        }
        boxresources[objnum] = l
        if immediate then
            localconverter(list,"xform",objnum,l)
            flushedxforms[objnum] = { true , objnum }
            flushlist(list)
        else
            l.list = list
        end
        return objnum
    end

    local function useboxresource(index,wd,ht,dp)
        local l = boxresources[index]
        if l then
            if wd or ht or dp then
                wd, ht, dp = wd or 0, ht or 0, dp or 0
            else
                wd, ht, dp = l.width, l.height, l.depth
            end
            local rule   = newrule(wd,ht,dp) -- newboxrule
            rule.subtype = boxrule_code
            setprop(tonut(rule),"index",index)
            return rule, wd, ht, dp
        else
            report("no box resource %S",index)
        end
    end

    local function getboxresourcedimensions(index)
        local l = boxresources[index]
        if l then
            return l.width, l.height, l.depth, l.margin
        else
            report("no box resource %S",index)
        end
    end

    local function getboxresourcebox(index)
        local l = boxresources[index]
        if l then
            return l.list
        end
    end

    updaters.register("backend.update.tex",function()
        tex.saveboxresource          = saveboxresource
        tex.useboxresource           = useboxresource
        tex.getboxresourcedimensions = getboxresourcedimensions
        tex.getboxresourcebox        = getboxresourcebox
    end)

    -- a bit of a mess: index is now objnum but that has to change to a proper index
    -- ... an engine inheritance

    local function flushpdfxform(current,pos_h,pos_v,pos_r,size_h,size_v)
        -- object properties
        local objnum = getprop(current,"index")
        local name   = getxformname(objnum)
        local info   = flushedxforms[objnum]
        local r      = boxresources[objnum]
        if not info then
            info = { false , objnum }
            flushedxforms[objnum] = info
        end
        local wd, ht, dp = getboxresourcedimensions(objnum)
     -- or:   wd, ht, dp = r.width, r.height, r.depth
        -- sanity check
        local htdp = ht + dp
        if wd == 0 or size_h == 0 or htdp == 0 or size_v == 0 then
            return
        end
        -- calculate scale
        local rx, ry = 1, 1
        if wd ~= size_h or htdp ~= size_v then
            rx = size_h / wd
            ry = size_v / htdp
        end
        -- flush the reference
        usedxforms[objnum] = true
        pdf_goto_pagemode()
        calc_pdfpos(pos_h,pos_v)
        tx = cmtx * bpfactor
        ty = cmty * bpfactor
        b = b + 1 ; buffer[b] = s_b
        b = b + 1 ; buffer[b] = f_cm(rx,0,0,ry,tx,ty)
        b = b + 1 ; buffer[b] = f_fm(name)
        b = b + 1 ; buffer[b] = s_e
    end

    -- place image also used in vf but we can use a different one if we need it

    local imagetypes     = images.types -- pdf png jpg jp2 jbig2 stream memstream
    local img_none       = imagetypes.none
    local img_pdf        = imagetypes.pdf
    local img_stream     = imagetypes.stream
    local img_memstream  = imagetypes.memstream

    local one_bp <const> = 65536 * bpfactor

    local imageresources, n = { }, 0

    getximagename = function(index)
        local l = imageresources[index]
        if l then
            return l.name
        else
            report("no image resource %S",index)
        end
    end

    updaters.register("backend.update.pdf",function()
        pdf.getximagename = getximagename
    end)

    -- Groups are flushed immediately but we can decide to make them into a
    -- specific whatsit ... but not now. We could hash them if needed when
    -- we use lot sof them in mp ... but not now.

          usedxgroups = { }
    local groups      = 0
    local group       = nil

    flushgroup = function(content,bbox)
        if not group then
            group = pdfdictionary {
                Type = pdfconstant("Group"),
                S    = pdfconstant("Transparency"),
            }
        end
        local wrapper = pdfdictionary {
            Type      = pdf_xobject,
            Subtype   = pdf_form,
            FormType  = 1,
            Group     = group,
            BBox      = pdfarray(bbox),
            Resources = lpdf.collectedresources { serialize = false },
        }
        local objnum = pdfflushstreamobject(content,wrapper,false)
        groups = groups + 1
        usedxgroups[groups] = objnum
        return f_gr(groups)
    end

    lpdf.flushgroup = flushgroup -- todo: access via driver in mlib-pps

    -- end of experiment

    local function flushpdfximage(current,pos_h,pos_v,pos_r,size_h,size_v)

        local width,
              height,
              depth     = getwhd(current)
        local total     = height + depth
        local transform = getprop(current,"transform") or 0  -- we never set it ... so just use rotation then
        local index     = getprop(current,"index") or 0
        local kind,
              xorigin,
              yorigin,
              xsize,
              ysize,
              rotation, -- transform / orientation / rotation : it's a mess (i need to redo this)
              objnum,
              groupref  = pdfincludeimage(index)  -- needs to be sorted out, bad name (no longer mixed anyway)

        if not kind then
            report("invalid image %S",index)
            return
        end

        local rx, sx, sy, ry, tx, ty = 1, 0, 0, 1, 0, 0

        -- tricky: xsize and ysize swapped

        if kind == img_pdf or kind == img_stream or kind == img_memstream then
            rx, ry, tx, ty = 1/xsize, 1/ysize, xorigin/xsize, yorigin/ysize
        else
         -- if kind == img_png then
         --  -- if groupref > 0 and img_page_group_val == 0 then
         --  --     img_page_group_val = groupref
         --  -- end
         -- end
            rx, ry = bpfactor, bpfactor
        end

        if band(transform,7) > 3 then
            -- mirror
            rx, tx = -rx, -tx
        end
        local t = band(transform + rotation,3)
        if t == 0 then
            -- nothing
        elseif t == 1 then
            -- rotation over 90 degrees (counterclockwise)
            rx, sx, sy, ry, tx, ty = 0, rx, -ry, 0, -ty, tx
        elseif t == 2 then
            -- rotation over 180 degrees (counterclockwise)
            rx, ry, tx, ty = -rx, -ry, -tx, -ty
        elseif t == 3 then
            -- rotation over 270 degrees (counterclockwise)
            rx, sx, sy, ry, tx, ty = 0, -rx, ry, 0, ty, -tx
        end

        rx = rx * width
        sx = sx * total
        sy = sy * width
        ry = ry * total
        tx = pos_h - tx * width
        ty = pos_v - ty * total

        local t = transform + rotation

        if band(transform,7) > 3 then
            t = t + 1
        end

        t = band(t,3)

        if t == 0 then
            -- no transform
        elseif t == 1 then
            -- rotation over 90 degrees (counterclockwise)
            tx = tx + width
        elseif t == 2 then
            -- rotation over 180 degrees (counterclockwise)
            tx = tx + width
            ty = ty + total
        elseif t == 3 then
            -- rotation over 270 degrees (counterclockwise)
            ty = ty + total
        end

     -- a flaw in original, can go:
     --
     -- if img_page_group_val == 0 then
     --     img_page_group_val = group_ref
     -- end

        usedximages[index] = objnum -- hm

        pdf_goto_pagemode()

        calc_pdfpos(tx,ty)

        tx = cmtx * bpfactor
        ty = cmty * bpfactor

        b = b + 1 ; buffer[b] = s_b
        b = b + 1 ; buffer[b] = f_cm(rx,sx,sy,ry,tx,ty)
        b = b + 1 ; buffer[b] = f_im(index)
        b = b + 1 ; buffer[b] = s_e
    end

    flushimage = function(index,width,height,depth,pos_h,pos_v)

        -- used in vf characters

        local total = height + depth
        local kind,
              xorigin, yorigin,
              xsize, ysize,
              rotation,
              objnum,
              groupref = pdfincludeimage(index)

        local rx = width / xsize
        local sx = 0
        local sy = 0
        local ry = total / ysize
        local tx = pos_h
        -- to be sorted out
     -- local ty = pos_v - depth
        local ty = pos_v -- we assume that depth is dealt with in the caller (for now)

        usedximages[index] = objnum

        pdf_goto_pagemode()

        calc_pdfpos(tx,ty)

        tx = cmtx * bpfactor
        ty = cmty * bpfactor

        b = b + 1 ; buffer[b] = s_b
        b = b + 1 ; buffer[b] = f_cm(rx,sx,sy,ry,tx,ty)
        b = b + 1 ; buffer[b] = f_im(index)
        b = b + 1 ; buffer[b] = s_e
    end

    -- For the moment we need this hack because the engine checks the 'image'
    -- command in virtual fonts (so we use lua instead).

    flushrule = function(current,pos_h,pos_v,pos_r,size_h,size_v,subtype)

        if subtype == emptyrule_code then
            return
        elseif subtype == boxrule_code then
            return flushpdfxform(current,pos_h,pos_v,pos_r,size_h,size_v)
        elseif subtype == imagerule_code then
            return flushpdfximage(current,pos_h,pos_v,pos_r,size_h,size_v)
        end
        if subtype == userrule_code or subtype >= overrule_code and subtype <= radicalrule_code then
            pdf_goto_pagemode()
            b = b + 1 ; buffer[b] = s_b
            pdf_set_pos_temp(pos_h,pos_v)
            rule_callback(current,size_h,size_v,pos_r) -- so we pass direction
            b = b + 1 ; buffer[b] = s_e
            return
        end

        pdf_goto_pagemode()

     -- local saved_b = b

        b = b + 1 ; buffer[b] = s_b

        local dim_h = size_h * bpfactor
        local dim_v = size_v * bpfactor
        local rule

        if dim_v <= one_bp then
            pdf_set_pos_temp(pos_h,pos_v + 0.5 * size_v)
            rule = f_v(dim_v,dim_h)
        elseif dim_h <= one_bp then
            pdf_set_pos_temp(pos_h + 0.5 * size_h,pos_v)
            rule = f_h(dim_h,dim_v)
        else
            pdf_set_pos_temp(pos_h,pos_v)
            if subtype == outlinerule_code then
                local linewidth = getdata(current)
                if linewidth > 0 then
                    rule = f_w(linewidth * bpfactor,dim_h,dim_v)
                else
                    rule = f_o(dim_h,dim_v)
                end
            else
                rule = f_f(dim_h,dim_v)
            end
        end

        b = b + 1 ; buffer[b] = rule
        b = b + 1 ; buffer[b] = s_e

     -- buffer[saved_b] = concat(buffer," ",saved_b,b)
     -- b = saved_b

    end

    flushsimplerule = function(pos_h,pos_v,pos_r,size_h,size_v)
        pdf_goto_pagemode()

        b = b + 1 ; buffer[b] = s_b

        local dim_h = size_h * bpfactor
        local dim_v = size_v * bpfactor
        local rule

        if dim_v <= one_bp then
            pdf_set_pos_temp(pos_h,pos_v + 0.5 * size_v)
            rule = f_v(dim_v,dim_h)
        elseif dim_h <= one_bp then
            pdf_set_pos_temp(pos_h + 0.5 * size_h,pos_v)
            rule = f_h(dim_h,dim_v)
        else
            pdf_set_pos_temp(pos_h,pos_v)
            rule = f_f(dim_h,dim_v)
        end

        b = b + 1 ; buffer[b] = rule
        b = b + 1 ; buffer[b] = s_e
    end

end

--- basics

local wrapup, registerpage  do

    local pages    = { }
    local maxkids  = 10
    local nofpages = 0
    local pagetag  = "unset"

    registerpage = function(object)
        nofpages = nofpages + 1
        local objnum = pdfpagereference(nofpages)
        pages[nofpages] = {
            page   = nofpages, -- original number, only for diagnostics
            objnum = objnum,
            object = object,
            tag    = pagetag,
        }
    end

    function lpdf.setpagetag(tag)
        pagetag = tag or "unset"
    end

    function lpdf.getnofpages()
        return nofpages
    end

    function lpdf.getpagetags()
        local list = { }
        for i=1,nofpages do
            list[i] = pages[i].tag
        end
        return list
    end

    function lpdf.setpageorder(mapping)
        -- mapping can be a hash so:
        local list = table.sortedkeys(mapping)
        local n    = #list
        if n == nofpages then
            local done = { }
            local hash = { }
            for i=1,n do
                local order = mapping[list[i]]
                if hash[order] then
                    report("invalid page order, duplicate entry %i",order)
                    return
                elseif order < 1 or order > nofpages then
                    report("invalid page order, no page %i",order)
                    return
                else
                    done[i]     = pages[order]
                    hash[order] = true
                end
            end
            pages = done
        else
            report("invalid page order, %i entries expected",nofpages)
        end
    end

    -- We can have this, but then via codeinjections etc. Later.

 -- function structures.pages.swapthem()
 --     local n = lpdf.getnofpages()
 --     local t = { }
 --     for i=1,n do
 --         t[i] = i
 --     end
 --     for i=2,math.odd(n) and n or (n-1),2 do
 --         t[i]   = i+1
 --         t[i+1] = i
 --     end
 --     lpdf.setpageorder(t)
 -- end

    wrapup = function(driver)

        -- hook (to reshuffle pages)
        local pagetree = { }
        local parent   = nil
        local minimum  = 0
        local maximum  = 0
        local current  = 0
        if #pages > 1.5 * maxkids then
            repeat
                local plist, pnode
                if current == 0 then
                    plist, minimum = pages, 1
                elseif current == 1 then
                    plist, minimum = pagetree, 1
                else
                    plist, minimum = pagetree, maximum + 1
                end
                maximum = #plist
                if maximum > minimum then
                    local kids
                    for i=minimum,maximum do
                        local p = plist[i]
                        if not pnode or #kids == maxkids then
                            kids   = pdfarray()
                            parent = pdfreserveobject()
                            pnode  = pdfdictionary {
                                objnum = parent,
                                Type   = pdf_pages,
                                Kids   = kids,
                                Count  = 0,
                            }
                            pagetree[#pagetree+1] = pnode
                        end
                        kids[#kids+1] = pdfreference(p.objnum)
                        pnode.Count = pnode.Count + (p.Count or 1)
                        p.Parent = pdfreference(parent)
                    end
                end
                current = current + 1
            until maximum == minimum
            -- flush page tree
            for i=1,#pagetree do
                local entry  = pagetree[i]
                local objnum = entry.objnum
                entry.objnum = nil
                pdfflushobject(objnum,entry)
            end
        else
            -- ugly
            local kids = pdfarray()
            local list = pdfdictionary {
                Type  = pdf_pages,
                Kids  = kids,
                Count = nofpages,
            }
            parent = pdfreserveobject()
            for i=1,nofpages do
                local page = pages[i]
                kids[#kids+1] = pdfreference(page.objnum)
                page.Parent = pdfreference(parent)
            end
            pdfflushobject(parent,list)
        end
        for i=1,nofpages do
            local page   = pages[i]
            local object = page.object
            object.Parent = page.Parent
            pdfflushobject(page.objnum,object)
        end
        lpdf.addtocatalog("Pages",pdfreference(parent))

    end

end

pdf_h, pdf_v  = 0, 0

local function initialize(driver,details)
    reset_variables(details)
    reset_buffer()
end

-- This will all move and be merged and become less messy.

-- todo: more clever resource management: a bit tricky as we can inject
-- stuff in the page stream

local compact = false

do

    -- This is more a convenience feature and it might even be not entirely robust.
    -- It removes redundant color directives which makes the page stream look a bit
    -- nicer (also when figuring out issues). I might add more here but there is
    -- some additional overhead involved so runtime can be impacted.

    local P, R, S, Cs, lpegmatch = lpeg.P, lpeg.R, lpeg.S, lpeg.Cs, lpeg.match

    local p_ds    = (R("09") + S(" ."))^1
    ----- p_nl    = S("\n\r")^1
    local p_nl    = S("\n")^1
    local p_eg    = P("Q")

    local p_cl    = p_ds * (P("rg") + P("g") + P("k")) * p_ds * (P("RG") + P("G") + P("K"))
    ----- p_cl    = (p_ds * (P("rg") + P("g") + P("k") + P("RG") + P("G") + P("K")))^1
    local p_tr    = P("/Tr") * p_ds * P("gs")

    local p_no_cl = (p_cl * p_nl) / ""
    local p_no_tr = (p_tr * p_nl) / ""
    local p_no_nl = 1 - p_nl

    local p_do_cl = p_cl * p_nl
    local p_do_tr = p_tr * p_nl

    local p_do_eg = p_eg * p_nl

    local pattern = Cs( (
        (p_no_cl + p_no_tr)^0 * p_do_eg           -- transparencies and colors before Q
      +  p_no_tr * p_no_cl    * p_do_tr * p_do_cl -- transparencies and colors before others
      +  p_no_cl              * p_do_cl           -- successive colors
      +  p_no_tr              * p_do_tr           -- successive transparencies
      +  p_no_nl^1
      +  1
    )^1 )

    local oldsize = 0
    local newsize = 0

    directives.register("pdf.compact", function(v)
        compact = v and function(s)
            oldsize = oldsize + #s
            s = lpegmatch(pattern,s) or s
            newsize = newsize + #s
            return s
        end
    end)

    statistics.register("pdf pagestream",function()
        if oldsize ~= newsize then
            return string.format("old size: %i, new size %i",oldsize,newsize)
        end
    end)


end

local flushdeferred -- defined later

local level = 0

local finalize  do

    local f_font  = formatters["F%d"]

    local f_form  = formatters["Fm%d"]
    local f_group = formatters["Gp%d"]
    local f_image = formatters["Im%d"]

    finalize = function(driver,details)

        level = level + 1

        pdf_goto_pagemode() -- for now

        local objnum        = details.objnum
        local specification = details.specification

        local content = concat(buffer,"\n",1,b)

        if compact then
            content = compact(content)
        end

        local fonts   = nil
        local xforms  = nil

        if next(usedfonts) then
            fonts = pdfdictionary { }
            for k, v in next, usedfonts do
                fonts[f_font(v)] = pdfreference(pdfgetfontobjnumber(k)) -- we can overload for testing
            end
        end

        -- messy: use real indexes for both ... so we need to change some in the
        -- full luatex part

        if next(usedxforms) or next(usedximages) or next(usedxgroups) then
            xforms = pdfdictionary { }
            for k in sortedhash(usedxforms) do
             -- xforms[f_form(k)] = pdfreference(k)
                xforms[f_form(getxformname(k))] = pdfreference(k)
            end
            for k, v in sortedhash(usedximages) do
                xforms[f_image(k)] = pdfreference(v)
            end
            for k, v in sortedhash(usedxgroups) do
                xforms[f_group(k)] = pdfreference(v)
            end
        end

        reset_buffer()

     -- finish_pdfpage_callback(shippingmode == "page")

        if shippingmode == "page" then

            local pageproperties  = lpdf.getpageproperties()

            local pageresources   = pageproperties.pageresources
            local pageattributes  = pageproperties.pageattributes
            local pagesattributes = pageproperties.pagesattributes

            pageresources.Font    = fonts
            pageresources.XObject = xforms
            pageresources.ProcSet = lpdf.procset()

            local xorigin, yorigin, relocated = backends.codeinjections.getpageorigin() -- for now here

            local bbox = pdfarray {
                (boundingbox[1] + xorigin) * bpfactor,
                (boundingbox[2] + yorigin) * bpfactor,
                (boundingbox[3] + xorigin) * bpfactor,
                (boundingbox[4] + yorigin) * bpfactor,
            }

            if relocated then
                content = formatters["1 0 0 1 %.6N %.6N cm\n%s"](bbox[1],bbox[2],content)
            end

            local contentsobj = pdfflushstreamobject(content,false,false)

            pageattributes.Type      = pdf_page
            pageattributes.Contents  = pdfreference(contentsobj)
            pageattributes.Resources = pageresources
         -- pageattributes.Resources = pdfreference(pdfflushobject(pageresources))
            pageattributes.MediaBox  = bbox
            pageattributes.Parent    = nil -- precalculate
            pageattributes.Group     = nil -- todo

            -- resources can be indirect

            registerpage(pageattributes)

            lpdf.finalizepage(true)

            if relocated then
                if pageattributes.TrimBox  then pageattributes.TrimBox  = box end
                if pageattributes.CropBox  then pageattributes.CropBox  = box end
                if pageattributes.BleedBox then pageattributes.BleedBox = box end
            end

        else

            local xformtype  = specification.type or 0
            local margin     = specification.margin or 0
            local attributes = specification.attributes or ""
            local resources  = specification.resources or ""

            local wrapper    = nil

            if xformtype == 0 then
                wrapper = pdfdictionary {
                    Type      = pdf_xobject,
                    Subtype   = pdf_form,
                    FormType  = 1,
                    BBox      = nil,
                    Matrix    = nil,
                    Resources = nil,
                }
            else
                wrapper = pdfdictionary {
                    BBox      = nil,
                    Matrix    = nil,
                    Resources = nil,
                }
            end
            if xformtype == 0 or xformtype == 1 or xformtype == 3 then
                wrapper.BBox = pdfarray {
                    -margin * bpfactor,
                    -margin * bpfactor,
                    (boundingbox[3] + margin) * bpfactor,
                    (boundingbox[4] + margin) * bpfactor,
                }
            end
            if xformtype == 0 or xformtype == 2 or xformtype == 3 then
                wrapper.Matrix = pdfarray { 1, 0, 0, 1, 0, 0 }
            end

            -- todo: additional = resources

            local boxresources   = lpdf.collectedresources { serialize = false }
            boxresources.Font    = fonts
            boxresources.XObject = xforms

         -- todo: maybe share them
         -- wrapper.Resources = pdfreference(pdfflushobject(boxresources))

            if resources ~= "" then
                 boxresources = boxresources + resources
            end
            if attributes ~= "" then
                wrapper = wrapper + attributes
            end

            wrapper.Resources = next(boxresources) and boxresources or nil
            wrapper.ProcSet   = lpdf.procset()

         -- pdfflushstreamobject(content,wrapper,false,objectnumber)
            pdfflushstreamobject(content,wrapper,false,specification.objnum)

        end

        for objnum in sortedhash(usedxforms) do
            local f = flushedxforms[objnum]
            if f[1] == false then
                f[1] = true
                local objnum        = f[2] -- specification.objnum
                local specification = boxresources[objnum]
                local list          = specification.list
                localconverter(list,"xform",f[2],specification)
            end
        end

        pdf_h, pdf_v  = 0, 0

        if level == 1 then
            flushdeferred()
        end
        level = level - 1

    end

end

updaters.register("backend.update.pdf",function()
    job.positions.registerhandlers {
        getpos  = drivers.getpos,
        getrpos = drivers.getrpos,
        gethpos = drivers.gethpos,
        getvpos = drivers.getvpos,
    }
end)

updaters.register("backend.update",function()
    local saveboxresource = tex.boxresources.save
    --
    -- also in lpdf-res .. brrr .. needs fixing
    --
    backends.codeinjections.registerboxresource = function(n,offset)
        local r = saveboxresource(n,nil,nil,false,0,offset or 0)
        return r
    end
end)

-- now comes the pdf file handling

local objects       = { }
local streams       = { } -- maybe just parallel to objects (no holes)
local nofobjects    = 0
local offset        = 0
local f             = false
local flush         = false
local threshold     = 40 -- also #("/Filter /FlateDecode") (compression threshold)
local objectstream  = true
local compress      = true
local cache         = false
local info          = ""
local catalog       = ""
local lastdeferred  = false
local majorversion  = 1
local minorversion  = 7
local trailerid     = true

directives.register("backend.pdf.threshold",function(v)
    if v then
        threshold = tonumber(v) or 40
    else
        threshold = -1000
    end
end)

local f_object       = formatters["%i 0 obj\010%s\010endobj\010"]
local f_stream_n_u   = formatters["%i 0 obj\010<< /Length %i >>\010stream\010%s\010endstream\010endobj\010"]
local f_stream_n_c   = formatters["%i 0 obj\010<< /Filter /FlateDecode /Length %i >>\010stream\010%s\010endstream\010endobj\010"]
local f_stream_d_u   = formatters["%i 0 obj\010<< %s /Length %i >>\010stream\010%s\010endstream\010endobj\010"]
local f_stream_d_c   = formatters["%i 0 obj\010<< %s /Filter /FlateDecode /Length %i >>\010stream\010%s\010endstream\010endobj\010"]
local f_stream_d_r   = formatters["%i 0 obj\010<< %s >>\010stream\010%s\010endstream\010endobj\010"]

----- f_object_b     = formatters["%i 0 obj\010"]
local f_stream_b_n_u = formatters["%i 0 obj\010<< /Length %i >>\010stream\010"]
local f_stream_b_n_c = formatters["%i 0 obj\010<< /Filter /FlateDecode /Length %i >>\010stream\010"]
local f_stream_b_d_u = formatters["%i 0 obj\010<< %s /Length %i >>\010stream\010"]
local f_stream_b_d_c = formatters["%i 0 obj\010<< %s /Filter /FlateDecode /Length %i >>\010stream\010"]
local f_stream_b_d_r = formatters["%i 0 obj\010<< %s >>\010stream\010"]

----- s_object_e <const> = "\010endobj\010"
local s_stream_e <const> = "\010endstream\010endobj\010"

do

    local function setinfo()    end -- we get it
    local function setcatalog() end -- we get it

    local function settrailerid(v)
        trailerid = v or false
    end

    local function setmajorversion(v) majorversion = tonumber(v) or majorversion end
    local function setminorversion(v) minorversion = tonumber(v) or minorversion end

    local function getmajorversion(v) return majorversion end
    local function getminorversion(v) return minorversion end

    local function setcompresslevel   (v) compress     = v and v ~= 0 and true or false end
    local function setobjcompresslevel(v) objectstream = v and v ~= 0 and true or false end

    local function getcompresslevel   (v) return compress     and 3 or 0 end
    local function getobjcompresslevel(v) return objectstream and 1 or 0 end

    local function setpageresources  () end -- needs to be sorted out
    local function setpageattributes () end
    local function setpagesattributes() end

    updaters.register("backend.update.pdf",function()
        pdf.setinfo             = setinfo
        pdf.setcatalog          = setcatalog
        pdf.settrailerid        = settrailerid
        pdf.setmajorversion     = setmajorversion
        pdf.setminorversion     = setminorversion
        pdf.getmajorversion     = getmajorversion
        pdf.getminorversion     = getminorversion
        pdf.setcompresslevel    = setcompresslevel
        pdf.setobjcompresslevel = setobjcompresslevel
        pdf.getcompresslevel    = getcompresslevel
        pdf.getobjcompresslevel = getobjcompresslevel
        pdf.setpageresources    = setpageresources
        pdf.setpageattributes   = setpageattributes
        pdf.setpagesattributes  = setpagesattributes
    end)

end

local addtocache, flushcache, cache do

    local data, d  = { }, 0
    local list, l  = { }, 0
    local coffset  = 0
    local indices  = { }

    local maxsize  <const> = 32 * 1024 -- uncompressed
    local maxcount <const> = 0xFF

    addtocache = function(n,str)
        local size = #str
        if size == 0 then
            -- todo: message
            return
        end
        if coffset + size > maxsize or d == maxcount then
            flushcache()
        end
        if d == 0 then
            nofobjects = nofobjects + 1
            objects[nofobjects] = false
            streams[nofobjects] = indices
            cache = nofobjects
        end
        objects[n] = - cache
        indices[n] = d
        d = d + 1
        -- can have a comment n 0 obj as in luatex
        data[d] = str
        l = l + 1 ; list[l] = n
        l = l + 1 ; list[l] = coffset
        coffset = coffset + size + 1
    end

    local p_ObjStm = pdfconstant("ObjStm")

    flushcache = function() -- references cannot be stored
        if l > 0 then
            list = concat(list," ")
            data[0] = list
            data = concat(data,"\010",0,d)
            local strobj = pdfdictionary {
                Type  = p_ObjStm,
                N     = d,
                First = #list + 1,
            }
            objects[cache] = offset
            local b = nil
            local e = s_stream_e
            if compress then
                local comp = zlibcompress(data,3)
                if comp and #comp < #data then
                    data = comp
                    b = f_stream_b_d_c(cache,strobj(),#data)
                else
                    b = f_stream_b_d_u(cache,strobj(),#data)
                end
            else
                b = f_stream_b_d_u(cache,strobj(),#data)
            end
            flush(f,b)
            flush(f,data)
            flush(f,e)
            offset = offset + #b + #data + #e
            data, d = { }, 0
            list, l = { }, 0
            coffset = 0
            indices = { }
        end
    end

end

local function pdfreserveobj()
    nofobjects = nofobjects + 1
    objects[nofobjects] = false
    return nofobjects
end

local pages = table.setmetatableindex(function(t,k)
    local v = pdfreserveobj()
    t[k] = v
    return v
end)

local function getpageref(n)
    return pages[n]
end

local function refobj()
    -- not needed, as we have auto-delay
end

local function flushnormalobj(data,n)
    if not n then
        nofobjects = nofobjects + 1
        n = nofobjects
    end
    data = f_object(n,data)
    if level == 0 then
        objects[n] = offset
        offset = offset + #data
        flush(f,data)
    else
        if not lastdeferred then
            lastdeferred = n
        elseif n < lastdeferred then
            lastdeferred = n
        end
        objects[n] = data
    end
    return n
end

local function flushstreamobj(data,n,dict,comp,nolength)
    if not data then
        report("no data for %S",dict)
        return
    end
    if not n then
        nofobjects = nofobjects + 1
        n = nofobjects
    end
    local size = #data
    if level == 0 then
        local b = nil
        local e = s_stream_e
        if nolength then
            b = f_stream_b_d_r(n,dict)
        elseif comp ~= false and compress and size > threshold then
            local compdata = zlibcompress(data,3)
            if compdata then
                local compsize = #compdata
                if compsize > size - threshold then
                    b = dict and f_stream_b_d_u(n,dict,size) or f_stream_b_n_u(n,size)
                else
                    data = compdata
                    b = dict and f_stream_b_d_c(n,dict,compsize) or f_stream_b_n_c(n,compsize)
                end
            else
                b = dict and f_stream_b_d_u(n,dict,size) or f_stream_b_n_u(n,size)
            end
        else
            b = dict and f_stream_b_d_u(n,dict,size) or f_stream_b_n_u(n,size)
        end
        flush(f,b)
        flush(f,data)
        flush(f,e)
        objects[n] = offset
        offset = offset + #b + #data + #e
    else
        if nolength then
            data = f_stream_d_r(n,dict,data)
        elseif comp ~= false and compress and size > threshold then
            local compdata = zlibcompress(data,3)
            if compdata then
                local compsize = #compdata
                if compsize > size - threshold then
                    data = dict and f_stream_d_u(n,dict,size,data) or f_stream_n_u(n,size,data)
                else
                    data = dict and f_stream_d_c(n,dict,compsize,compdata) or f_stream_n_c(n,compsize,compdata)
                end
            else
                data = dict and f_stream_d_u(n,dict,size,data) or f_stream_n_u(n,size,data)
            end
        else
            data = dict and f_stream_d_u(n,dict,size,data) or f_stream_n_u(n,size,data)
        end
        if not lastdeferred then
            lastdeferred = n
        elseif n < lastdeferred then
            lastdeferred = n
        end
        objects[n] = data
    end
    return n
end

flushdeferred = function() -- was forward defined
    if lastdeferred then
        for n=lastdeferred,nofobjects do
            local o = objects[n]
            if type(o) == "string" then
                objects[n] = offset
                offset = offset + #o
                flush(f,o)
            end
        end
        lastdeferred = false
    end
end

-- n = pdf.obj([n,]               objtext)
-- n = pdf.obj([n,] "file",       filename)
-- n = pdf.obj([n,] "stream",     streamtext [, attrtext])
-- n = pdf.obj([n,] "streamfile", filename   [, attrtext])
--
-- n = pdf.obj {
--     type           = <string>,  -- raw|stream
--     immediate      = <boolean>,
--     objnum         = <number>,
--     attr           = <string>,
--     compresslevel  = <number>,
--     objcompression = <boolean>,
--     file           = <string>,
--     string         = <string>,
--     nolength       = <boolean>,
-- }

local function obj(a,b,c,d)
    local kind --, immediate
    local objnum, data, attr, filename
    local compresslevel, objcompression, nolength
    local argtype = type(a)
    if argtype == "table" then
        kind           = a.type          -- raw | stream
     -- immediate      = a.immediate
        objnum         = a.objnum
        attr           = a.attr
        compresslevel  = a.compresslevel
        objcompression = a.objcompression
        filename       = a.file
        data           = a.string or a.stream or ""
        nolength       = a.nolength
        if kind == "stream" then
            if filename then
                data = loaddata(filename) or ""
            end
        elseif kind == "raw"then
            if filename then
                data = loaddata(filename) or ""
            end
        elseif kind == "file"then
            kind = "raw"
            data = filename and loaddata(filename) or ""
        elseif kind == "streamfile" then
            kind = "stream"
            data = filename and loaddata(filename) or ""
        end
    else
        if argtype == "number" then
            objnum = a
            a, b, c = b, c, d
        else
            nofobjects = nofobjects + 1
            objnum = nofobjects
        end
        if b then
            if a == "stream" then
                kind = "stream"
                data = b
            elseif a == "file" then
             -- kind = "raw"
                data = loaddata(b)
            elseif a == "streamfile" then
                kind = "stream"
                data = loaddata(b)
            else
                data = "" -- invalid object
            end
            attr = c
        else
         -- kind = "raw"
            data = a
        end
    end
    if not objnum then
        nofobjects = nofobjects + 1
        objnum = nofobjects
    end
    -- todo: immediate
    if kind == "stream" then
        flushstreamobj(data,objnum,attr,compresslevel and compresslevel > 0 or nil,nolength)
    elseif objectstream and objcompression ~= false then
        addtocache(objnum,data)
    else
        flushnormalobj(data,objnum)
    end
    return objnum
end

updaters.register("backend.update.pdf",function()
    pdf.reserveobj     = pdfreserveobj
    pdf.getpageref     = getpageref
    pdf.refobj         = refobj
    pdf.flushstreamobj = flushstreamobj
    pdf.flushnormalobj = flushnormalobj
    pdf.obj            = obj
    pdf.immediateobj   = obj
end)

-- In lua 5.4 the methods are now moved one metalevel deeper so we need to get them
-- from mt.__index instead. (I did get that at first.) It makes for a slightly (imo)
-- nicer interface but no real gain in speed as we don't flush that often.

local openfile, closefile  do

    -- I used to do <space><lf> but then figured out that when I open and save a file in a mode
    -- that removes trailing spaces, the xref becomes invalid. The problem was then that a
    -- reconstruction of the file by a viewer gives weird effects probably because percent symbols
    -- gets interpreted then. Thanks to Ross Moore for noticing this side effect!

    local f_used       = formatters["%010i 00000 n\013\010"]
    local f_link       = formatters["%010i 00000 f\013\010"]
    local f_first      = formatters["%010i 65535 f\013\010"]

    local f_pdf        = formatters["%%PDF-%i.%i\010"]
    local f_xref       = formatters["xref\0100 %i\010"]
    local f_trailer_id = formatters["trailer\010<< %s /ID [ <%s> <%s> ] >>\010startxref\010%i\010%%%%EOF"]
    local f_trailer_no = formatters["trailer\010<< %s >>\010startxref\010%i\010%%%%EOF"]
    local f_startxref  = formatters["startxref\010%i\010%%%%EOF"]

    local inmemory = false
    local close    = false

    openfile = function(filename)
        if inmemory then
            local n = 0
            f = { }
            flush = function(f,s)
                n = n + 1 f[n] = s
            end
            close = function(f)
                f = concat(f)
                io.savedata(filename,f)
                f = false
            end
         -- local n = 0
         -- f = {
         --     write = function(self,s)
         --         n = n + 1 f[n] = s
         --     end,
         --     close = function(self)
         --         f = concat(f)
         --         io.savedata(filename,f)
         --         f = false
         --     end,
         -- }
         else
            f = io.open(filename,"wb")
            if not f then
                -- message
                os.exit()
            end
         -- f:setvbuf("full",64*1024)
            local m = getmetatable(f)
            flush = m.write or m.__index.write
            close = m.close or m.__index.close
        end
        local v = f_pdf(majorversion,minorversion)
     -- local b = "%\xCC\xD5\xC1\xD4\xC5\xD8\xD0\xC4\xC6\010"     -- LUATEXPDF  (+128)
        local b = "%\xC3\xCF\xCE\xD4\xC5\xD8\xD4\xD0\xC4\xC6\010" -- CONTEXTPDF (+128)
        flush(f,v)
        flush(f,b)
        offset = #v + #b
    end

    closefile = function(abort)
        if abort then
            f:close()
            f = io.open(abort,"wb")
            if f then
                local name = resolvers.findfile("context-lmtx-error.pdf")
                if name then
                    local data = io.loaddata(name)
                    if data then
                        f:write(data)
                        f:close()
                        return
                    end
                end
                f:close()
                removefile(abort)
            end
        else
            local xrefoffset = offset
            local lastfree   = 0
            local noffree    = 0
            local catalog    = lpdf.getcatalog()
            local info       = lpdf.getinfo()
                if trailerid == true then
                trailerid = md5HEX(osuuid())
            elseif trailerid and #trailerid > 32 then
                trailerid = md5HEX(trailerid)
            else
                trailerid = false
            end
            if objectstream then
                flushdeferred()
                flushcache()
                --
                xrefoffset = offset
                --
                nofobjects = nofobjects + 1
                objects[nofobjects] = offset -- + 1
                --
                -- combine these three in one doesn't really give less code so
                -- we go for the efficient ones
                --
                local nofbytes  = 4
                local c1, c2, c3, c4
                if offset <= 0xFFFF then
                    nofbytes = 2
                    for i=1,nofobjects do
                        local o = objects[i]
                        if not o then
                            noffree = noffree + 1
                        else
                            local strm = o < 0
                            if strm then
                                o = -o
                            end
                            c1 = extract(o,8,8)
                            c2 = extract(o,0,8)
                            if strm then
                                objects[i] = char(2,c1,c2,streams[o][i])
                            else
                                objects[i] = char(1,c1,c2,0)
                            end
                        end
                    end
                    if noffree > 0 then
                        for i=nofobjects,1,-1 do
                            local o = objects[i]
                            if not o then
                                local f1 = extract(lastfree,8,8)
                                local f2 = extract(lastfree,0,8)
                                objects[i] = char(0,f1,f2,0)
                                lastfree   = i
                            end
                        end
                    end
                elseif offset <= 0xFFFFFF then
                    nofbytes = 3
                    for i=1,nofobjects do
                        local o = objects[i]
                        if not o then
                            noffree = noffree + 1
                        else
                            local strm = o < 0
                            if strm then
                                o = -o
                            end
                            c1 = extract(o,16,8)
                            c2 = extract(o, 8,8)
                            c3 = extract(o, 0,8)
                            if strm then
                                objects[i] = char(2,c1,c2,c3,streams[o][i])
                            else
                                objects[i] = char(1,c1,c2,c3,0)
                            end
                        end
                    end
                    if noffree > 0 then
                        for i=nofobjects,1,-1 do
                            local o = objects[i]
                            if not o then
                                local f1 = extract(lastfree,16,8)
                                local f2 = extract(lastfree, 8,8)
                                local f3 = extract(lastfree, 0,8)
                                objects[i] = char(0,f1,f2,f3,0)
                                lastfree   = i
                            end
                        end
                    end
                else
                    nofbytes = 4
                    for i=1,nofobjects do
                        local o = objects[i]
                        if not o then
                            noffree = noffree + 1
                        else
                            local strm = o < 0
                            if strm then
                                o = -o
                            end
                            c1 = extract(o,24,8)
                            c2 = extract(o,16,8)
                            c3 = extract(o, 8,8)
                            c4 = extract(o, 0,8)
                            if strm then
                                objects[i] = char(2,c1,c2,c3,c4,streams[o][i])
                            else
                                objects[i] = char(1,c1,c2,c3,c4,0)
                            end
                        end
                    end
                    if noffree > 0 then
                        for i=nofobjects,1,-1 do
                            local o = objects[i]
                            if not o then
                                local f1 = extract(lastfree,24,8)
                                local f2 = extract(lastfree,16,8)
                                local f3 = extract(lastfree, 8,8)
                                local f4 = extract(lastfree, 0,8)
                                objects[i] = char(0,f1,f2,f3,f4,0)
                                lastfree   = i
                            end
                        end
                    end
                end
                objects[0] = rep("\0",1+nofbytes+1)
                local data = concat(objects,"",0,nofobjects)
                local xref = pdfdictionary {
                    Type  = pdfconstant("XRef"),
                    Size  = nofobjects + 1,
                    W     = pdfarray { 1, nofbytes, 1 },
                    Root  = catalog,
                    Info  = info,
                    ID    = trailerid and pdfarray { pdfliteral(trailerid,true), pdfliteral(trailerid,true) } or nil,
                }
                if compress then
                    local comp = zlibcompress(data,3)
                    if comp then
                        data = comp
                        flush(f,f_stream_b_d_c(nofobjects,xref(),#data))
                    else
                        flush(f,f_stream_b_d_u(nofobjects,xref(),#data))
                    end
                else
                    flush(f,f_stream_b_d_u(nofobjects,xref(),#data))
                end
                flush(f,data)
                flush(f,s_stream_e)
                flush(f,f_startxref(xrefoffset))
            else
                flushdeferred()
                xrefoffset = offset
                flush(f,f_xref(nofobjects+1))
                local trailer = pdfdictionary {
                    Size = nofobjects+1,
                    Root = catalog,
                    Info = info,
                }
                for i=1,nofobjects do
                    local o = objects[i]
                    if o then
                        objects[i] = f_used(o)
                    end
                end
                for i=nofobjects,1,-1 do
                    local o = objects[i]
                    if not o then
                        objects[i] = f_link(lastfree)
                        lastfree   = i
                    end
                end
                objects[0] = f_first(lastfree)
                flush(f,concat(objects,"",0,nofobjects))
                trailer.Size = nofobjects + 1
                if trailerid then
                    flush(f,f_trailer_id(trailer(),trailerid,trailerid,xrefoffset))
                else
                    flush(f,f_trailer_no(trailer(),xrefoffset))
                end
            end
            f:close()
        end
        io.flush()
        closefile = function() end
    end

end

-- For the moment we overload it here, although back-fil.lua eventually will
-- be merged with back-pdf as it's pdf specific, or maybe back-imp-pdf or so.

updaters.register("backend.update.pdf",function()

    -- We overload img but at some point it will even go away, so we just
    -- reimplement what we need in context. This will change completely i.e.
    -- we will drop the low level interface!

    local codeinjections = backends.pdf.codeinjections

    local imagetypes     = images.types -- pdf png jpg jp2 jbig2 stream memstream
    local img_none       = imagetypes.none

    local rulecodes      = nodes.rulecodes

    local setprop        = nodes.nuts.setprop

    local report_images  = logs.reporter("backend","images")

    local lastindex      = 0
    local indices        = { }

    local bpfactor       <const> = number.dimenfactors.bp
    local imagerule_code <const> = rulecodes.image

    function codeinjections.newimage(specification)
        return specification
    end

    function codeinjections.copyimage(original)
        return setmetatableindex(original)
    end

    function codeinjections.scanimgage(specification)
        return specification
    end

    local function embedimage(specification)
        lastindex = lastindex + 1
        index     = lastindex
        specification.index = index
        local xobject = pdfdictionary { }
        if not specification.notype then
            xobject.Type     = pdf_xobject
            xobject.Subtype  = pdf_form
            xobject.FormType = 1
        end
        local bbox = specification.bbox
        if bbox and not specification.nobbox then
            xobject.BBox = pdfarray {
                bbox[1] * bpfactor,
                bbox[2] * bpfactor,
                bbox[3] * bpfactor,
                bbox[4] * bpfactor,
            }
        end
        xobject = xobject + specification.attr
        if bbox and not specification.width then
            specification.width = bbox[3]
        end
        if bbox and not specification.height then
            specification.height = bbox[4]
        end
        local dict = xobject()
        --
        nofobjects     = nofobjects + 1
        local objnum   = nofobjects
        local nolength = specification.nolength
        local stream   = specification.stream or specification.string
        --
        -- We cannot set type in native img so we need this hack or
        -- otherwise we need to patch too much. Better that i write
        -- a wrapper then. Anyway, it has to be done better: a key that
        -- tells either or not to scale by xsize/ysize when flushing.
        --
        if not specification.type then
            local kind = specification.kind
            if kind then
                -- take that one
            elseif attr and find(attr,"BBox") then
                kind = img_stream
            else
                -- hack: a bitmap
                kind = img_none
            end
            specification.type = kind
            specification.kind = kind
        end
        local compress = compresslevel and compresslevel > 0 or nil
        flushstreamobj(stream,objnum,dict,compress,nolength)
        specification.objnum      = objnum
        specification.rotation    = specification.rotation or 0
        specification.orientation = specification.orientation or 0
        specification.transform   = specification.transform or 0
        specification.stream      = nil
        specification.attr        = nil
        specification.type        = specification.kind or specification.type or img_none
        indices[index]            = specification -- better create a real specification
        return specification
    end

    codeinjections.embedimage = embedimage

    function codeinjections.wrapimage(specification)
        --
        local index = specification.index
        if not index then
            embedimage(specification)
        end
        --
        local width  = specification.width  or 0
        local height = specification.height or 0
        local depth  = specification.depth  or 0
        -- newimagerule
        local n      = nodes.pool.rule(width,height,depth)
        n.subtype    = imagerule_code
        setprop(tonut(n),"index",specification.index)
        return n
    end

    function pdf.includeimage(index)
        local specification = indices[index]
        if specification then
            local bbox      = specification.bbox
            local xorigin   = bbox[1]
            local yorigin   = bbox[2]
            local xsize     = bbox[3] - xorigin -- we need the original ones, not the 'rotated' ones
            local ysize     = bbox[4] - yorigin -- we need the original ones, not the 'rotated' ones
            local transform = specification.transform or 0
            local objnum    = specification.objnum or pdfreserveobj()
            local groupref  = nil
            local kind      = specification.kind or specification.type or img_none -- determines scaling type
            return
                kind,
                xorigin, yorigin,
                xsize, ysize,
                transform,
                objnum,
                groupref
        end
    end

end)

updaters.register("backend.update.lpdf",function()

    -- todo: an md5 or sha2 hash can save space
    -- todo: make a type 3 font instead
    -- todo: move to lpdf namespace

    local pdfimage   = lpdf.epdf.image
    local newpdf     = pdfimage.new
    local openpdf    = pdfimage.open
    local closepdf   = pdfimage.close
    local copypage   = pdfimage.copy

    local embedimage = images.embed

    local nofstreams = 0
    local topdf      = { }
    local toidx      = { }

    local function storedata_s(pdf)
        local idx = toidx[pdf]
        if not idx then
            nofstreams = nofstreams + 1
            idx = nofstreams
            toidx[pdf] = nofstreams
            topdf[idx] = pdf
        end
        return idx
    end

    local function vfimage_s(id,wd,ht,dp,pos_h,pos_v)
        local index = topdf[id]
        if type(index) == "string" then
            local pdfdoc  = newpdf(index,#index)
            local image   = copypage(pdfdoc)
            local bbox    = image.bbox
            image.width   = bbox[3] - bbox[1]
            image.height  = bbox[4] - bbox[2]
            embedimage(image)
            index = image.index
            topdf[id] = index
        end
        -- pdf.print or pdf.literal
        flushimage(index,wd,ht,dp,pos_h,pos_v)
    end

    local function storedata_n(name,page)
        local idx = toidx[pdf]
        if not idx then
            nofstreams = nofstreams + 1
            idx = nofstreams
            toidx[pdf] = nofstreams
            topdf[idx] = pdf
        end
        return idx
    end

    -- We need to have a way to close such a pdf ... esp for fonts.

    local pdfdocs = { }

    local function vfimage_n(name,page,wd,ht,dp,pos_h,pos_v)
        local d = pdfdocs[name]
        if not d then
            d = { doc = openpdf(name), pages = { } }
            pdfdocs[name] = d
        end
        local index = d.pages[page]
        if not index then
            local image  = copypage(d.doc,page)
            local bbox   = image.bbox
            image.width  = bbox[3] - bbox[1]
            image.height = bbox[4] - bbox[2]
            embedimage(image)
            index = image.index
            d.pages[page] = index
        end
        flushimage(index,wd,ht,dp,pos_h,pos_v)
    end

    local function pdfvfimage(wd,ht,dp,data,name)
        if type(data) == "number" then
            return { "lua", function(font,char,pos_h,pos_v)
                vfimage_n(name,data,wd,ht,dp,pos_h,pos_v)
            end }
        else
            return { "lua", function(font,char,pos_h,pos_v)
                local id = storedata_s(data)
                vfimage_s(id,wd,ht,dp,pos_h,pos_v)
            end }
        end
    end

    lpdf.vfimage = pdfvfimage

end)

-- The driver.

do

    local isfile     = lfs.isfile
    local removefile = os.remove
    local renamefile = os.rename
 -- local copyfile   = file.copy
 -- local addsuffix  = file.addsuffix
    local texgetbox  = tex.getbox

    local pdfname    = nil
    local converter  = nil
    local useddriver = nil -- a bit of a hack

    local function outputfilename(driver)
        return pdfname
    end

    -- todo: prevent twice

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
         -- if rawget(pdf,"setforcefile") then
         --     pdf.setforcefile(false) -- default anyway
         -- end
            --
            pdfname = file.addsuffix(tex.jobname,"pdf")
            openfile(pdfname)
            --
            luatex.registerstopactions(1,function()
                if pdfname then
                    lpdf.finalizedocument()
                    closefile()
                end
            end)
            --
            luatex.registerpageactions(1,function()
                if pdfname then
                    lpdf.finalizepage(true)
                end
            end)
            --            --
            lpdf.registerdocumentfinalizer(wrapup,nil,"wrapping up")
            --
        end
        --
        environment.lmtxmode = CONTEXTLMTXMODE
        --
        converter  = drivers.converters.lmtx
        useddriver = driver
    end

    local function wrapup(driver)
        if pdfname then
            closefile()
            pdfname = nil
        end
    end

    local function cleanup(driver)
        if pdfname then
            closefile(pdfname)
            pdfname = nil
        end
    end

    local function convert(driver,boxnumber)
        converter(driver,texgetbox(boxnumber),"page")
    end

    localconverter = function(...)
        converter(useddriver,...)
    end

    drivers.install {
        name     = "pdf",
        flushers = {
            character       = flushcharacter,
            fontchar        = flushfontchar,
            rule            = flushrule,
            simplerule      = flushsimplerule,
            pushorientation = pushorientation,
            poporientation  = poporientation,
            --
            literal         = flushliteral,
            setmatrix       = flushsetmatrix,
            save            = flushsave,
            restore         = flushrestore,
            image           = flushimage,
            group           = flushgroup,
            --
            updatefontstate = updatefontstate,
        },
        actions  = {
            prepare         = prepare,
            wrapup          = wrapup,
            cleanup         = cleanup,
            --
            initialize      = initialize,
            convert         = convert,
            finalize        = finalize,
            --
            outputfilename  = outputfilename,
        },
    }

end
