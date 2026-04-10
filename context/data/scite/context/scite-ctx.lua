-- version   : 1.0.0 - 07/2005 (2008: lua 5.1)
-- author    : Hans Hagen - PRAGMA ADE - www.pragma-ade.com
-- copyright : public domain or whatever suits
-- remark    : part of the context distribution, my first lua code

-- todo: name space for local functions
-- todo: the spell checking code is for the built-in lexer, the lpeg one uses its own

-- loading: scite-ctx.properties

-- # environment variable
-- #
-- #   CTXSPELLPATH=t:/spell
-- #
-- # auto language detection
-- #
-- #   % version =1.0 language=uk
-- #   <?xml version='1.0' language='uk' ?>

-- ext.lua.startup.script=$(SciteDefaultHome)/scite-ctx.lua
--
-- # extension.$(file.patterns.context)=scite-ctx.lua
-- # extension.$(file.patterns.example)=scite-ctx.lua
--
-- # ext.lua.reset=1
-- # ext.lua.auto.reload=1
-- # ext.lua.startup.script=t:/lua/scite-ctx.lua
--
-- ctx.menulist.default=\
--     wrap=wrap_text|\
--     unwrap=unwrap_text|\
--     sort=sort_text|\
--     document=document_text|\
--     quote=quote_text|\
--     compound=compound_text|\
--     check=check_text\|
--     strip=toggle_strip
--
-- ctx.spellcheck.language=auto
-- ctx.spellcheck.wordsize=4
-- ctx.spellcheck.wordpath=ENV(CTXSPELLPATH)
--
-- ctx.spellcheck.wordfile.all=spell-uk.txt,spell-nl.txt
--
-- ctx.spellcheck.wordfile.uk=spell-uk.txt
-- ctx.spellcheck.wordfile.nl=spell-nl.txt
-- ctx.spellcheck.wordsize.uk=4
-- ctx.spellcheck.wordsize.nl=4
--
-- command.name.21.*=CTX Action List
-- command.subsystem.21.*=3
-- command.21.*=show_menu $(ctx.menulist.default)
-- command.groupundo.21.*=yes
-- command.shortcut.21.*=Shift+F11
--
-- command.name.22.*=CTX Check Text
-- command.subsystem.22.*=3
-- command.22.*=check_text
-- command.groupundo.22.*=yes
-- command.shortcut.22.*=Ctrl+L
--
-- command.name.23.*=CTX Wrap Text
-- command.subsystem.23.*=3
-- command.23.*=wrap_text
-- command.groupundo.23.*=yes
-- command.shortcut.23.*=Ctrl+M
--
-- # command.21.*=check_text
-- # command.21.*=dofile e:\context\lua\scite-ctx.lua

-- generic functions

-- Once lpeg is available I will update the functions below.

os.setlocale("C") -- get rid of the locale: it works bad for comparing as in utflen

local props = props or { }

local byte, char = string.byte, string.char
local lower, upper, format = string.lower, string.upper, string.format
local gsub, sub, find, rep, match, gmatch = string.gsub, string.sub, string.find, string.rep, string.match, string.gmatch
local sort, concat = table.sort, table.concat
local loadstring = loadstring or load

local function check_output_pane()
    editor.StyleClearAll(output)
end

-- helpers : utf

local magicstring = rep("<ctx-crlf/>", 2)

local utflen  = utf8 and utf8.len
local utfchar = utf8 and utf8.char

if not utflen then

    local l2 = char(0xC0)
    local l3 = char(0xE0)
    local l4 = char(0xF0)

    utflen = function(str) -- we could use an lpeg instead
        local n = 0
        local l = 0
        for s in gmatch(str,".") do
            if l > 0 then
                l = l - 1
            else
                n = n + 1
                if s >= l4 then
                    l = 3
                elseif s >= l3 then
                    l = 2
                elseif s >= l2 then
                    l = 1
                end
            end
        end
        return n
    end

end

if not utfchar then

    utfchar = function(u)
        if u <= 0x7F then
            return char(
                u
            )
        elseif u <= 0x7FF then
            return char (
                0xC0 | (u >> 6),
                0x80 | (u & 0x3F)
            )
        elseif u <= 0xFFFF then
            return char (
                0xE0 | (u >> 12),
                0x80 | ((u >> 6) & 0x3F),
                0x80 | (u & 0x3F)
            )
        elseif n < 0x110000 then
            local n = u - 0x10000
            local r = ((n & 0xF0000) >> 16) + 1
            return char (
                0xF0 | (r >> 2),
                0x80 | ((r & 3) << 4) | ((n & 0x0F000) >> 12),
                0x80 | ((n & 0x00FC0) >> 6),
                0x80 | (n & 0x0003F)
            )
        else
            return utfchar(0xFFFD)
        end
    end

end

-- helpers: system

function io.exists(filename)
    local ok, result, message = pcall(io.open,filename)
    if result then
        io.close(result)
        return true
    else
        return false
    end
end

local function resultof(command)
    local handle = io.popen(command,"r") -- already has flush
    if handle then
        local result = handle:read("*all") or ""
        handle:close()
        return result
    else
        return ""
    end
end

function os.envvar(str)
    local s = os.getenv(str)
    if s ~= '' then
        return s
    end
    s = os.getenv(upper(str))
    if s ~= '' then
        return s
    end
    s = os.getenv(lower(str))
    if s ~= '' then
        return s
    end
end

local function loadtable(name)
    local f = io.open(name,"rb")
    if f then
        f:close()
        return dofile(name)
    end
end

-- helpers: reporting

local crlf   = "\n"
local report = nil
local trace  = trace

if trace then
    report = function(fmt,...)
        if fmt then
            trace(format(fmt,...))
        end
        trace(crlf)
        io.flush()
    end
else
    trace  = print
    report = function(fmt,...)
        if fmt then
            trace(format(fmt,...))
        else
            trace("")
        end
        io.flush()
    end
end

-- helpers: whatever (old code, we should use our libs)

local function grab(str,delimiter)
    local list = { }
    for snippet in gmatch(str,delimiter) do
        list[#list+1] = snippet
    end
    return list
end

local function expand(str)
    return (gsub(str,"ENV%((%w+)%)", os.envvar))
end

local function strip(str)
    return (gsub(str,"^%s*(.-)%s*$", "%1"))
end

local function alphasort(list,i)
    if i and i > 0 then
        local function alphacmp(a,b)
            return lower(gsub(sub(a,i),'0',' ')) < lower(gsub(sub(b,i),'0',' '))
        end
        sort(list,alphacmp)
    else
        local function alphacmp(a,b)
            return lower(a) < lower(b)
        end
        sort(list,alphacmp)
    end
end

-- helpers: editor

-- local function column_of_position(position)
--     local line = editor:LineFromPosition(position)
--     local oldposition = editor.CurrentPos
--     local column = 0
--     editor:GotoPos(position)
--     while editor.CurrentPos ~= 0 and line == editor:LineFromPosition(editor.CurrentPos) do
--         editor:CharLeft()
--         column = column + 1
--     end
--     editor:GotoPos(oldposition)
--     if line > 0 then
--         return column -1
--     else
--         return column
--     end
-- end

-- local function line_of_position(position)
--     return editor:LineFromPosition(position)
-- end

local function extend_to_start()
    local selectionstart = editor.SelectionStart
    local selectionend = editor.SelectionEnd
    local line = editor:LineFromPosition(selectionstart)
    if line > 0 then
        while line == editor:LineFromPosition(selectionstart-1) do
            selectionstart = selectionstart - 1
            editor:SetSel(selectionstart,selectionend)
        end
    else
        selectionstart = 0
    end
    editor:SetSel(selectionstart,selectionend)
    return selectionstart
end

local function extend_to_end() -- editor:LineEndExtend() does not work
    local selectionstart = editor.SelectionStart
    local selectionend = editor.SelectionEnd
    local line = editor:LineFromPosition(selectionend)
    while line == editor:LineFromPosition(selectionend+1) do
        selectionend = selectionend + 1
        editor:SetSel(selectionstart,selectionend)
        if selectionend ~= editor.SelectionEnd then
            break -- no progress
        end
    end
    editor:SetSel(selectionstart,selectionend)
    return selectionend
end

local function getfiletype()
    local language = gsub(props.Language or "","script_","")
    if language ~= "" then
        return language
    else
        local firstline = editor:GetLine(0) or ""
        if find(firstline,"^%%") then
            return 'tex'
        elseif find(firstline,"^<%?xml") then
            return 'xml'
        else
            return 'unknown'
        end
    end
end

-- inspired by LuaExt's scite_Files

-- local function get_dir_list(mask)
--     local f
--     if props['PLAT_GTK'] and props['PLAT_GTK'] ~= "" then
--         f = io.popen('ls -1 ' .. mask)
--     else
--         mask = gsub(mask,'/','\\')
--         local tmpfile = 'scite-ctx.tmp'
--         local cmd = 'dir /b "' .. mask .. '" > ' .. tmpfile
--         os.execute(cmd)
--         f = io.open(tmpfile)
--     end
--     local files = { }
--     if not f then -- path check added
--         return files
--     end
--     for line in f:lines() do
--         files[#files+1] = line
--     end
--     f:close()
--     return files
-- end

--helpers : utf from editor

local cat -- has to be set to editor.CharAt

local function toutfcode(pos) -- if needed we can cache
    local c1 = cat[pos]
    if c1 < 0 then
        c1 = 256 + c1
    end
    if c1 < 128 then
        return c1, 1
    end
    if c1 < 224 then
        local c2 = cat[pos+1]
        if c2 < 0 then
            c2 = 256 + c2
        end
        return c1 * 64 + c2 - 12416, 2
    end
    if c1 < 240 then
        local c2 = cat[pos+1]
        local c3 = cat[pos+2]
        if c2 < 0 then
            c2 = 256 + c2
        end
        if c3 < 0 then
            c3 = 256 + c3
        end
        return (c1 * 64 + c2) * 64 + c3 - 925824, 3
    end
    if c1 < 245 then
        local c2 = cat[pos+1]
        local c3 = cat[pos+2]
        local c4 = cat[pos+3]
        if c2 < 0 then
            c2 = 256 + c2
        end
        if c3 < 0 then
            c3 = 256 + c3
        end
        if c4 < 0 then
            c4 = 256 + c4
        end
        return ((c1 * 64 + c2) * 64 + c3) * 64 + c4 - 63447168, 4
    end
end

-- banner

do

    check_output_pane()

    print("Some CTX extensions:")

    local wraplength = props['ctx.wraptext.length']

    if wraplength and wraplength ~= "" then
        print("\n-  ctx.wraptext.length is set to " .. wraplength)
    else
        print("\n-  ctx.wraptext.length is not set")
    end

    local helpinfo = props['ctx.helpinfo']

    if helpinfo and helpinfo ~= "" then
        print("\n-  key bindings:\n")
        print((gsub(strip(helpinfo),"%s*|%s*","\n")))
    else
        print("\n-  no extra key bindings")
    end

    print("\n-  recognized first lines:\n")
    print("xml   <?xml version='1.0' language='..'")
    print("tex   % language=..")
    print(" ")
    print("(lexing is currently being upgraded / improved / made more native to scite)")
    print(" ")

end

-- text functions

-- written while listening to Talk Talk

function wrap_text()

    -- We always go to the end of a line, so in fact some of
    -- the variables set next are not needed.

    local length = props["ctx.wraptext.length"]

    if length == '' then length = 80 else length = tonumber(length) end

    local startposition = editor.SelectionStart
    local endposition   = editor.SelectionEnd

    if startposition == endposition then return end

    editor:LineEndExtend()

    startposition = editor.SelectionStart
    endposition   = editor.SelectionEnd

    -- local startline   = line_of_position(startposition)
    -- local endline     = line_of_position(endposition)
    -- local startcolumn = column_of_position(startposition)
    -- local endcolumn   = column_of_position(endposition)
    --
    -- editor:SetSel(startposition,endposition)

    local startline   = props['SelectionStartLine']
    local endline     = props['SelectionEndLine']
    local startcolumn = props['SelectionStartColumn'] - 1
    local endcolumn   = props['SelectionEndColumn'] - 1

    local replacement = { }
    local templine    = ''
    local tempsize    = 0
    local indentation = rep(' ',startcolumn)
    local selection   = editor:GetSelText()

    selection = gsub(selection,"[\n\r][\n\r]","\n")
    selection = gsub(selection,"\n\n+",' ' .. magicstring .. ' ')
    selection = gsub(selection,"^%s",'')

    for snippet in gmatch(selection,"%S+") do
        if snippet == magicstring then
            replacement[#replacement+1] = templine
            replacement[#replacement+1] = ""
            templine = ''
            tempsize = 0
        else
            local snipsize = utflen(snippet)
            if tempsize + snipsize > length then
                replacement[#replacement+1] = templine
                templine = indentation .. snippet
                tempsize = startcolumn + snipsize
            elseif tempsize == 0 then
                templine = indentation .. snippet
                tempsize = tempsize + startcolumn + snipsize
            else
                templine = templine .. ' ' .. snippet
                tempsize = tempsize + 1 + snipsize
            end
        end
    end

    replacement[#replacement+1] = templine
    replacement[1] = gsub(replacement[1],"^%s+",'')

    if endcolumn == 0 then
        replacement[#replacement+1] = ""
    end

    editor:ReplaceSel(concat(replacement,"\n"))

end

function unwrap_text()

    local startposition = editor.SelectionStart
    local endposition   = editor.SelectionEnd

    if startposition == endposition then return end

    editor:HomeExtend()
    editor:LineEndExtend()

    startposition = editor.SelectionStart
    endposition   = editor.SelectionEnd

    local magicstring = rep("<multiplelines/>", 2)
    local selection   = gsub(editor:GetSelText(),"[\n\r][\n\r]+", ' ' .. magicstring .. ' ')
    local replacement = ''

    for snippet in gmatch(selection,"%S+") do
        if snippet == magicstring then
            replacement = replacement .. "\n"
        else
            replacement = replacement .. snippet .. "\n"
        end
    end

    if endcolumn == 0 then replacement = replacement .. "\n" end

    editor:ReplaceSel(replacement)

end

function sort_text()

    local startposition = editor.SelectionStart
    local endposition   = editor.SelectionEnd

    if startposition == endposition then return end

    -- local startcolumn = column_of_position(startposition)
    -- local endcolumn   = column_of_position(endposition)
    --
    -- editor:SetSel(startposition,endposition)

    local startline   = props['SelectionStartLine']
    local endline     = props['SelectionEndLine']
    local startcolumn = props['SelectionStartColumn'] - 1
    local endcolumn   = props['SelectionEndColumn']   - 1

    startposition = extend_to_start()
    endposition   = extend_to_end()

    local selection = gsub(editor:GetSelText(), "%s*$", '')
    local list = grab(selection,"[^\n\r]+")
    alphasort(list, startcolumn)
    local replacement = concat(list, "\n")

    editor:GotoPos(startposition)
    editor:SetSel(startposition,endposition)

    if endcolumn == 0 then replacement = replacement .. "\n" end

    editor:ReplaceSel(replacement)

end

do

    local data = {
        xml = {
            pattern = "%<%!%-%-.-%-%-%>"
        },
        tex = {
            pattern = "%%.-[\r\n]"
        },
    }

    function remove_comment()
        local filetype  = getfiletype()
        local filedata  = data[filetype]
        local selection = editor:GetSelText()
        if filedata and selection ~= "" then
            local startposition = editor.SelectionStart
            local endposition   = editor.SelectionEnd
            selection = gsub(selection,filedata.pattern,"")
            selection = gsub(selection,"%s+","")
            editor:ReplaceSel(selection)
        end
    end

end

do

    -- I really needed we can do version numbers but no one uses them.

    local patterns = {
        "(%d+)%s+(%d+)%s+obj",
        "(%d+)%s+(%d+)%s+R",
    }

    local function show_pdf_object(n)
        local name = props.FilePath
        local data = resultof("mtxrun --script pdf --object=" .. n .. " " .. name)
        print(format("file: %s, object number: %s, object data:\n",name,n))
        print(data)
    end

    function filter_pdf_object()
        local filetype  = getfiletype()
        local selection = editor:GetSelText()
        if filetype == "pdf" and selection ~= 0 then
            local n, m
            for i=1,#patterns do
                n, m = match(selection,patterns[i])
                if n and m then
                    break
                end
            end
            n = tonumber(n)
            m = tonumber(m)
            if n and m then
                show_pdf_object(n)
            end
        end
    end

    function search_pdf_object()
        local filetype  = getfiletype()
        local selection = editor:GetSelText()
        if filetype == "pdf" and selection ~= 0 then
            local onstrip = OnStrip
            function OnStrip(control,change)
                if control == 2 then
                    local n = tonumber(scite.StripValue(1))
                    if n then
                        show_pdf_object(n)
                    end
                    OnStrip = onstrip
                    scite.StripShow("")
                end
            end
            scite.StripShow("!'Object Number:'{}(&Search)\n")
        end
    end

end

do

    local valid = {
        xml = true,
        tex = true,
    }

    function document_text()
        local filetype = getfiletype()
        if valid[filetype or ""] then
            local startposition = editor.SelectionStart
            local endposition   = editor.SelectionEnd
            if startposition ~= endposition then
                startposition = extend_to_start()
                endposition   = extend_to_end()
                editor:SetSel(startposition,endposition)
                local replacement = ''
                for i = editor:LineFromPosition(startposition), editor:LineFromPosition(endposition) do
                    local str = editor:GetLine(i)
                    if filetype == 'xml' then
                        if find(str,"^<%!%-%- .* %-%->%s*$") then
                            replacement = replacement .. gsub(str,"^<%!%-%- (.*) %-%->(%s*)$","%1\n")
                        elseif find(str,"%S") then
                            replacement = replacement .. '<!-- ' .. gsub(str,"(%s*)$",'') .. " -->\n"
                        else
                            replacement = replacement .. str
                        end
                    else
                        if find(str,"^%%D%s+$") then
                            replacement = replacement .. "\n"
                        elseif find(str,"^%%D ") then
                            replacement = replacement .. gsub(str,"^%%D ",'')
                        else
                            replacement = replacement .. '%D ' .. str
                        end
                    end
                end
                replacement = gsub(replacement,"[\n\r]$",'')
                editor:ReplaceSel(replacement)
            end
        end
    end

end

do

    local data = {
        xml = {
            quote = {
                left  = "<quote>",
                right = "</quote>",
            },
            quotation = {
                left  = "<quotation>",
                right = "</quotation>",
            },
        },
        tex = {
            quote = {
                left  = "\\quote {",
                right = "}",
            },
            quotation = {
                left  = "\\quotation {",
                right = "}",
            },
        },
    }

    function quote_text()
        local filetype  = getfiletype()
        local filedata  = data[filetype]
        local selection = editor:GetSelText()
        if filedata and selection ~= "" then
            selection = gsub(selection,[["(.-)"]], filedata.quotation.left .. "%1" .. filedata.quotation.right)
            selection = gsub(selection,[['(.-)']], filedata.quote    .left .. "%1" .. filedata.quote    .right)
            editor:ReplaceSel(selection)
        end
    end

    function quote_text_s()
        local filetype  = getfiletype()
        local filedata  = data[filetype]
        local selection = editor:GetSelText()
        if filedata and selection ~= "" then
            selection = filedata.quote.left .. selection .. filedata.quote.right
            editor:ReplaceSel(selection)
        end
    end

    function quote_text_d()
        local filetype  = getfiletype()
        local filedata  = data[filetype]
        local selection = editor:GetSelText()
        if filedata and selection ~= "" then
            selection = filedata.quotation.left .. selection .. filedata.quotation.right
            editor:ReplaceSel(selection)
        end
    end

    local function wrap(left,right)
        local selection = editor:GetSelText()
        if selection ~= "" then
            selection = left .. selection .. right
            editor:ReplaceSel(selection)
        end
    end

    function wrap_curly_braces   () wrap("{","}") end
    function wrap_square_brackets() wrap("[","]") end
    function wrap_parentheses    () wrap("(",")") end
    function wrap_angle_brackets () wrap("<",">") end

end

do

    local data = {
        xml = {
            pattern     = [[(>[^<%-][^<%-]+)([-/])(%w%w+)]],
            replacement = [[%1<compound token="%2"/>%3]],
        },
        tex = {
            pattern     = [[([^|])([-/]+)([^|])]],
            replacement = [[%1|%2|%3]],
        },
    }

    function compound_text()

        local filetype  = getfiletype()
        local filedata  = data[filetype]
        local selection = editor:GetSelText()
        if filedata and selection ~= "" then
            selection = gsub(selection,filedata.pattern,filedata.replacement)
            editor:ReplaceSel(selection)
        end

    end

end

-- There used to be some spell checking code here usign regular Scite
-- mechanisms but that has been moved to the lexer code already a while
-- ago so I removed the (pre 2005) code here. (See archive.)

do

    function add_text()

        local startposition = editor.SelectionStart
        local endposition   = editor.SelectionEnd

        if startposition == endposition then return end

        local selection = gsub(editor:GetSelText(), "%s*$", '')

        local n, sum = 0, 0
        for s in gmatch(selection,"[%-%+]?[%d%.%,]+") do -- todo: proper lpeg
            local s = gsub(s,",",".")
            local m = tonumber(s)
            if m then
                n = n + 1
                sum = sum + m
                report("%4i : %s",n,m)
            end
        end
        if n > 0 then
            report()
            report("sum  : %s",sum)
        else
            report("no numbers selected")
        end

    end

end

local dirty = { } do

    local bidi = nil

    local mapping = {
        l   = 0, -- "Left-to-Right",
        lre = 7, -- "Left-to-Right Embedding",
        lro = 7, -- "Left-to-Right Override",
        r   = 2, -- "Right-to-Left",
        al  = 3, -- "Right-to-Left Arabic",
        rle = 7, -- "Right-to-Left Embedding",
        rlo = 7, -- "Right-to-Left Override",
        pdf = 7, -- "Pop Directional Format",
        en  = 4, -- "European Number",
        es  = 4, -- "European Number Separator",
        et  = 4, -- "European Number Terminator",
        an  = 5, -- "Arabic Number",
        cs  = 6, -- "Common Number Separator",
        nsm = 6, -- "Non-Spacing Mark",
        bn  = 7, -- "Boundary Neutral",
        b   = 0, -- "Paragraph Separator",
        s   = 7, -- "Segment Separator",
        ws  = 0, -- "Whitespace",
        on  = 7, -- "Other Neutrals",
    }

    -- todo: take from scite-context-theme.lua

    local colors = { -- b g r
        [0] = 0x000000, -- black
        [1] = 0x00007F, -- red
        [2] = 0x007F00, -- green
        [3] = 0x7F0000, -- blue
        [4] = 0x7F7F00, -- cyan
        [5] = 0x7F007F, -- magenta
        [6] = 0x007F7F, -- yellow
        [7] = 0x007FB0, -- orange
        [8] = 0x4F4F4F, -- dark
    }

    -- in principle, when we could inject some funny symbol that is not part of the
    -- stream and/or use a different extra styling for each snippet then selection
    -- would work and rendering would look better too ... one problem is that a font
    -- rendering can collapse characters due to font features

    function show_bidi()

        cat = editor.CharAt

        editor.CodePage = SC_CP_UTF8

        for i=1,#colors do -- 0,#colors
           editor.StyleFore[i] = colors[i] -- crashes
        end

        if not bidi then
            bidi = require("context.scite-ctx-bidi")
        end

        local len = editor.TextLength
        local str = editor:textrange(0,len-1)

        local t = { }
        local a = { }
        local n = 0
        local i = 0

        local v
        while i < len do
            n = n + 1
            v, s = toutfcode(i)
            t[n] = v
            a[n] = s
            i = i + s
        end

        local t = bidi.process(t)

        editor:StartStyling(0,31)

        local defaultcolor = mapping.l
        local mirrorcolor  = 1

        if false then
            for i=1,n do
                local direction = t[i].direction
                local color     = direction and (mapping[direction] or 0) or defaultcolor
                editor:SetStyling(a[i],color)
            end
        else
            local lastcolor = -1
            local runlength = 0
            for i=1,n do
                local ti = t[i]
                local direction = ti.direction
                local mirror    = t[i].mirror
                local color     = (mirror and mirrorcolor) or (direction and mapping[direction]) or defaultcolor
                if color == lastcolor then
                    runlength = runlength + a[i]
                else
                    if runlength > 0 then
                        editor:SetStyling(runlength,lastcolor)
                    end
                    lastcolor = color
                    runlength = a[i]
                end
            end
            if runlength > 0 then
                editor:SetStyling(runlength,lastcolor)
            end
        end

        editor:SetStyling(2,31)

        dirty[props.FileNameExt] = true

    end

end

-- menu

local menuactions   = { }
local menufunctions = { }
local menuentries   = { }

function UserListShow(menutrigger, menulist)
    if type(menulist) == "string" then
        menuentries = { }
        menuactions = { }
        for item in gmatch(menulist,"[^%|]+") do
            if item ~= "" then
                -- why not just a split
                for key, value in gmatch(item,"%s*(.+)=(.+)%s*") do
                    menuentries[#menuentries+1] = key
                    menuactions[key] = value
                end
            end
        end
    else
        menuentries = menulist
        menuactions = false
    end
    local menustring = concat(menuentries,'|')
    if menustring == "" then
        report("there are no (further) options defined for this file type")
    else
        editor.AutoCSeparator = byte('|')
        editor:UserListShow(menutrigger,menustring)
        editor.AutoCSeparator = byte(' ')
    end
end

function OnUserListSelection(trigger,choice)
    if menufunctions[trigger] then
        return menufunctions[trigger](menuactions and menuactions[choice] or choice)
    else
        return false
    end
end

-- main menu

do

    local menutrigger = 12

    function show_menu(menulist)
        UserListShow(menutrigger, menulist)
    end

    function process_menu(action)
        if not find(action,"%(%)$") then
            assert(load(action .. "()"))()
        else
            assert(load(action))()
        end
    end

    menufunctions[12] = process_menu

end

-- The template code is old but used so we cannot drop it. I will cook up a better
-- system some day, using Lua tables instead.

do

    -- <?context-directive job ctxtemplate demotemplate.lua ?>

    local templatetrigger = 13

    local ctx_template_file = "scite-ctx-templates.lua"
    local ctx_template_list = { }
    local ctx_template_menu = { }

 -- function ctx_list_loaded(path)
 --     return ctx_path_list[path] and #ctx_path_list[path] > 0
 -- end

    local patterns = {
        xml = "<%?context%-directive job ctxtemplate (.-) %?>"
    }

    local function loadtemplate(name)
        local temp = gsub(name,"\\","/")
        local okay = loadtable(temp)
        if okay then
            print("template loaded: " .. name)
        end
        return okay
    end

    local function loadtemplatefrompaths(path,name)
        return loadtemplate(path ..       "/" .. name) or
               loadtemplate(path ..    "/../" .. name) or
               loadtemplate(path .. "/../../" .. name)
    end

    function insert_template(templatelist)
        local path   = props["FileDir"]
        local suffix = props["FileExt"]
        local list   = ctx_template_list[path]
        if list == nil then
            local pattern = patterns[suffix]
            local okay    = false
            if pattern then
                for i=0,9 do
                    local line = editor:GetLine(i) or ""
                    local name = match(line,pattern)
                    if name then
                        okay = loadtemplatefrompaths(path,name)
                        if not okay then
                            name = resultof("mtxrun --find-file " .. name)
                            if name then
                                name = gsub(name,"\n","")
                                okay = loadtemplate(name)
                            end
                        end
                        break
                    end
                end
            end
            if not okay then
                okay = loadtemplatefrompaths(path,ctx_template_file)
            end
            if not okay then
                okay = loadtemplate(props["SciteDefaultHome"] .. "/context/" .. ctx_template_file)
            end
            if okay then
                list = okay
            else
                list = false
                print("no template file found")
            end
            ctx_template_list[path] = list
        end
        ctx_template_menu = { }
        if list then
            local okay = list[suffix]
            if okay then
                local menu = { }
                for i=1,#okay do
                    local o = okay[i]
                    local n = o.name
                    menu[#menu+1] = n
                    ctx_template_menu[n] = o
                end
                UserListShow(templatetrigger, menu, true)
            end
        end
    end

    function inject_template(action)
        if ctx_template_menu then
            local a = ctx_template_menu[action]
            if a then
                local template = a.template
                local nature   = a.nature
                if template then
                    local margin = props['SelectionStartColumn'] - 1
                 -- template = gsub(template,"\\n","\n")
                    template = gsub(template,"%?%?","_____")
                    local pos = find(template,"%?")
                    template = gsub(template,"%?","")
                    template = gsub(template,"_____","?")
                    if nature == "display" then
                        local spaces = rep(" ",margin)
                        if not find(template,"\n$") then
                            template = template .. "\n"
                        end
                        template = gsub(template,"\n",function(s)
                            return "\n" .. spaces
                        end)
                        pos = pos + margin -- todo: check for first line
                    end
                    editor:insert(editor.CurrentPos,template)
                    if pos then
                        editor.CurrentPos = editor.CurrentPos + pos - 1
                        editor.SelectionStart = editor.CurrentPos
                        editor.SelectionEnd = editor.CurrentPos
                        editor:GotoPos(editor.CurrentPos)
                    end
                end
            end
        end
    end

    menufunctions[13] = inject_template

end

do

    -- These will become external and taken from sort-lan.lua in the
    -- ConTeXt distribution.

    local textlists = {
        en = {
            "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
            "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
            "u", "v", "w", "x", "y", "z",

            "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
            "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
            "U", "V", "W", "X", "Y", "Z",
        },
        nl = {
            "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
            "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
            "u", "v", "w", "x", "y", "z",

            "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
            "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
            "U", "V", "W", "X", "Y", "Z",
        },
        fr = {
            "a", "æ", "b", "c", "ç", "d", "e", "è", "é", "ê",
            "f", "g", "h", "i", "j", "k", "l", "m", "n", "o",
            "p", "q", "r", "s", "t", "u", "v", "w", "x", "y",
            "z",

            "A", "Æ", "B", "C", "Ç", "D", "E", "È", "É", "Ê",
            "F", "G", "H", "I", "J", "K", "L", "M", "N", "O",
            "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y",
            "Z",

        },
        de = {
            "a", "ä", "b", "c", "d", "e", "f", "g", "h", "i",
            "j", "k", "l", "m", "n", "o", "ö", "p", "q", "r",
            "s", "ß", "t", "u", "ü", "v", "w", "x", "y", "z",

            "A", "Ä", "B", "C", "D", "E", "F", "G", "H", "I",
            "J", "K", "L", "M", "N", "O", "Ö", "P", "Q", "R",
            "S", "SS", "T", "U", "Ü", "V", "W", "X", "Y", "Z",
        },
        fi = { -- finish
            "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
            "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
            "u", "v", "w", "x", "y", "z", "å", "ä", "ö",

            "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
            "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
            "U", "V", "W", "X", "Y", "Z", "Å", "Ä", "Ö",
        },
        sl = { -- slovenian
            "a", "b", "c", "č", "ć", "d", "đ", "e", "f", "g", "h", "i",
            "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "š", "t",
            "u", "v", "w", "x", "y", "z", "ž",

            "A", "B", "C", "Č", "Ć", "D", "Đ", "E", "F", "G", "H", "I",
            "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "Š", "T",
            "U", "V", "W", "X", "Y", "Z", "Ž",
        },
        ru = { -- rusian
            "а", "б", "в", "г", "д", "е", "ё", "ж", "з", "и",
            "і", "й", "к", "л", "м", "н", "о", "п", "р", "с",
            "т", "у", "ф", "х", "ц", "ч", "ш", "щ", "ъ", "ы",
            "ь", "ѣ", "э", "ю", "я", "ѳ", "ѵ",

            "А", "Б", "В", "Г", "Д", "Е", "Ё", "Ж", "З", "И",
            "І", "Й", "К", "Л", "М", "Н", "О", "П", "Р", "С",
            "Т", "У", "Ф", "Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ы",
            "Ь", "Ѣ", "Э", "Ю", "Я", "Ѳ", "Ѵ",
        },
        uk = { -- ukraninuan
            "а", "б", "в", "г", "ґ", "д", "е", "є", "ж", "з", "и", "і",
            "ї", "й", "к", "л", "м", "н", "о", "п", "р", "с", "т", "у",
            "ф", "х", "ц", "ч", "ш", "щ", "ь", "ю", "я",

            "А", "Б", "В", "Г", "Ґ", "Д", "Е", "Є", "Ж", "З", "И", "І",
            "Ї", "Й", "К", "Л", "М", "Н", "О", "П", "Р", "С", "Т", "У",
            "Ф", "Х", "Ц", "Ч", "Ш", "Щ", "Ь", "Ю", "Я",
        },
        be = { -- belarusia
            "а", "б", "в", "г", "д", "е", "ё", "ж", "з", "і",
            "й", "к", "л", "м", "н", "о", "п", "р", "с", "т",
            "у", "ў", "ф", "х", "ц", "ч", "ш", "ы", "ь", "э",
            "ю", "я",

            "А", "Б", "В", "Г", "Д", "Е", "Ё", "Ж", "З", "І",
            "Й", "К", "Л", "М", "Н", "О", "П", "Р", "С", "Т",
            "У", "Ў", "Ф", "Х", "Ц", "Ч", "Ш", "Ы", "Ь", "Э",
            "Ю", "Я",
        },
        bg = { -- bulgarian
            "а", "б", "в", "г", "д", "е", "ж", "з","и", "й",
            "к", "a", "л", "a", "м", "н", "о", "п", "р", "с",
            "т", "у", "ф", "х", "ц", "ч", "ш", "щ", "ъ", "ь",
            "ю", "я",

            "А", "Б", "В", "Г", "Д", "Е", "Ж", "З","И", "Й",
            "К", "A", "Л", "A", "М", "Н", "О", "П", "Р", "С",
            "Т", "У", "Ф", "Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ь",
            "Ю", "Я",
        },
        pl = { -- polish
            "a", "ą", "b", "c", "ć", "d", "e", "ę", "f", "g",
            "h", "i", "j", "k", "l", "ł", "m", "n", "ń", "o",
            "ó", "p", "q", "r", "s", "ś", "t", "u", "v", "w",
            "x", "y", "z", "ź", "ż",

            "A", "Ą", "B", "C", "Ć", "D", "E", "Ę", "F", "G",
            "H", "I", "J", "K", "L", "Ł", "M", "N", "Ń", "O",
            "Ó", "P", "Q", "R", "S", "Ś", "T", "U", "V", "W",
            "X", "Y", "Z", "Ź", "Ż",
        },
        cz = { -- czech
            "a", "á", "b", "c", "č", "d", "ď", "e", "é", "ě",
            "f", "g", "h", "i", "í", "j", "k", "l", "m",
            "n", "ň", "o", "ó", "p", "q", "r", "ř", "s", "š",
            "t", "ť", "u", "ú",  "ů", "v", "w", "x",  "y", "ý",
            "z", "ž",

            "A", "Á", "B", "C", "Č", "D", "Ď", "E", "É", "Ě",
            "F", "G", "H", "I", "Í", "J", "K", "L", "M",
            "N", "Ň", "O", "Ó", "P", "Q", "R", "Ř", "S", "Š",
            "T", "Ť", "U", "Ú",  "Ů", "V", "W", "X",  "Y", "Ý",
            "Z", "Ž",
        },
        sk = { -- slovak
            "a", "á", "ä", "b", "c", "č", "d", "ď",
            "e", "é", "f", "g", "h", ch,  "i", "í", "j", "k",
            "l", "ĺ", "ľ", "m", "n", "ň", "o", "ó", "ô", "p",
            "q", "r", "ŕ", "s", "š", "t", "ť", "u", "ú", "v",
            "w", "x", "y", "ý", "z", "ž",

            "A", "Á", "Ä", "B", "C", "Č", "D", "Ď",
            "E", "É", "F", "G", "H", "I", "Í", "J", "K",
            "L", "Ĺ", "Ľ", "M", "N", "Ň", "O", "Ó", "Ô", "P",
            "Q", "R", "Ŕ", "S", "Š", "T", "Ť", "U", "Ú", "V",
            "W", "X", "Y", "Ý", "Z", "Ž",
        },
        hr = { -- croatian
            "a", "b", "c", "č", "ć", "d", "đ", "e", "f",
            "g", "h", "i", "j", "k", "l", "m", "n",
            "o", "p", "r", "s", "š", "t", "u", "v", "z", "ž",

            "A", "B", "C", "Č", "Ć", "D", "Đ", "E", "F",
            "G", "H", "I", "J", "K", "L", "M", "N",
            "O", "P", "R", "S", "Š", "T", "U", "V", "Z", "Ž",
        },
        sr = { -- serbian
            "а", "б", "в", "г", "д", "ђ", "е", "ж", "з", "и",
            "ј", "к", "л", "љ", "м", "н", "њ", "о", "п", "р",
            "с", "т", "ћ", "у", "ф", "х", "ц", "ч", "џ", "ш",

            "А", "Б", "В", "Г", "Д", "Ђ", "Е", "Ж", "З", "И",
            "Ј", "К", "Л", "Љ", "М", "Н", "Њ", "О", "П", "Р",
            "С", "Т", "Ћ", "У", "Ф", "Х", "Ц", "Ч", "Џ", "Ш",
        },
        no = { -- norwegian
            "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
            "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
            "u", "v", "w", "x", "y", "z", "æ", "ø", "å",

            "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
            "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
            "U", "V", "W", "X", "Y", "Z", "Æ", "Ø", "Å",
        },
        da = { --danish
            "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
            "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
            "u", "v", "w", "x", "y", "z", "æ", "ø", "å",

            "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
            "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
            "U", "V", "W", "X", "Y", "Z", "Æ", "Ø", "Å",
        },
        sv = { -- swedish
            "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
            "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
            "u", "v", "w", "x", "y", "z", "å", "ä", "ö",

            "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
            "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
            "U", "V", "W", "X", "Y", "Z", "Å", "Ä", "Ö",
        },
        is = { -- islandic
            "a", "á", "b", "d", "ð", "e", "é", "f", "g", "h",
            "i", "í", "j", "k", "l", "m", "n", "o", "ó", "p",
            "r", "s", "t", "u", "ú", "v", "x", "y", "ý", "þ",
            "æ", "ö",

            "A", "Á", "B", "D", "Ð", "E", "É", "F", "G", "H",
            "I", "Í", "J", "K", "L", "M", "N", "O", "Ó", "P",
            "R", "S", "T", "U", "Ú", "V", "X", "Y", "Ý", "Þ",
            "Æ", "Ö",
        },
     -- gr = { -- greek
     --     "α", "ά", "ὰ", "ᾶ", "ᾳ", "ἀ", "ἁ", "ἄ", "ἂ", "ἆ",
     --     "ἁ", "ἅ", "ἃ", "ἇ", "ᾁ", "ᾴ", "ᾲ", "ᾷ", "ᾄ", "ᾂ",
     --     "ᾅ", "ᾃ", "ᾆ", "ᾇ", "β", "γ", "δ", "ε", "έ", "ὲ",
     --     "ἐ", "ἔ", "ἒ", "ἑ", "ἕ", "ἓ", "ζ", "η", "η", "ή",
     --     "ὴ", "ῆ", "ῃ", "ἠ", "ἤ", "ἢ", "ἦ", "ᾐ", "ἡ", "ἥ",
     --     "ἣ", "ἧ", "ᾑ", "ῄ", "ῂ", "ῇ", "ᾔ", "ᾒ", "ᾕ", "ᾓ",
     --     "ᾖ", "ᾗ", "θ", "ι", "ί", "ὶ", "ῖ", "ἰ", "ἴ", "ἲ",
     --     "ἶ", "ἱ", "ἵ", "ἳ", "ἷ", "ϊ", "ΐ", "ῒ", "ῗ", "κ",
     --     "λ", "μ", "ν", "ξ", "ο", "ό", "ὸ", "ὀ", "ὄ", "ὂ",
     --     "ὁ", "ὅ", "ὃ", "π", "ρ", "ῤ", "ῥ", "σ", "ς", "τ",
     --     "υ", "ύ", "ὺ", "ῦ", "ὐ", "ὔ", "ὒ", "ὖ", "ὑ", "ὕ",
     --     "ὓ", "ὗ", "ϋ", "ΰ", "ῢ", "ῧ", "φ", "χ", "ψ", "ω",
     --     "ώ", "ὼ", "ῶ", "ῳ", "ὠ", "ὤ", "ὢ", "ὦ", "ᾠ", "ὡ",
     --     "ὥ", "ὣ", "ὧ", "ᾡ", "ῴ", "ῲ", "ῷ", "ᾤ", "ᾢ", "ᾥ",
     --     "ᾣ", "ᾦ", "ᾧ",
     --
     --     "Α", "Ά", "Ὰ", "Α͂", "Ἀ", "Ἁ", "Ἄ", "Ἂ", "Ἆ",
     --     "Ἁ", "Ἅ", "Ἃ", "Ἇ",
     --     "Β", "Γ", "Δ", "Ε", "Έ", "Ὲ",
     --     "Ἐ", "Ἔ", "Ἒ", "Ἑ", "Ἕ", "Ἓ", "Ζ", "Η", "Η", "Ή",
     --     "Ὴ", "Η͂", "Ἠ", "Ἤ", "Ἢ", "Ἦ", "Ἡ", "Ἥ",
     --     "Ἣ", "Ἧ",
     --     "Θ", "Ι", "Ί", "Ὶ", "Ι͂", "Ἰ", "Ἴ", "Ἲ",
     --     "Ἶ", "Ἱ", "Ἵ", "Ἳ", "Ἷ", "Ϊ", "Ϊ́", "Ϊ̀", "Ϊ͂", "Κ",
     --     "Λ", "Μ", "Ν", "Ξ", "Ο", "Ό", "Ὸ", "Ὀ", "Ὄ", "Ὂ",
     --     "Ὁ", "Ὅ", "Ὃ", "Π", "Ρ", "Ρ̓", "Ῥ", "Σ", "Σ", "Τ",
     --     "Υ", "Ύ", "Ὺ", "Υ͂", "Υ̓", "Υ̓́", "Υ̓̀", "Υ̓͂", "Ὑ", "Ὕ",
     --     "Ὓ", "Ὗ", "Ϋ", "Ϋ́", "Ϋ̀", "Ϋ͂", "Φ", "Χ", "Ψ", "Ω",
     --     "Ώ", "Ὼ", "Ω͂", "Ὠ", "Ὤ", "Ὢ", "Ὦ", "Ὡ",
     --     "Ὥ", "Ὣ", "Ὧ",
     --     },
        gr = { -- greek
            "α", "β", "γ", "δ", "ε", "ζ", "η", "θ", "ι", "κ",
            "λ", "μ", "ν", "ξ", "ο", "π", "ρ", "ς", "τ", "υ",
            "φ", "χ", "ψ", "ω",

            "Α", "Β", "Γ", "Δ", "Ε", "Ζ", "Η", "Θ", "Ι", "Κ",
            "Λ", "Μ", "Ν", "Ξ", "Ο", "Π", "Ρ", "Σ", "Τ", "Υ",
            "Χ", "Ψ", "Ω",
            },
        la = { -- latin
            "a", "ā", "ă", "b", "c", "d", "e", "ē", "ĕ", "f",
            "g", "h", "i", "ī", "ĭ", "j", "k", "l", "m", "n",
            "o", "ō", "ŏ", "p", "q", "r", "s", "t", "u", "ū",
            "ŭ", "v", "w", "x", "y", "ȳ", "y̆", "z", "æ",

            "A", "Ā", "Ă", "B", "C", "D", "E", "Ē", "Ĕ", "F",
            "G", "H", "I", "Ī", "Ĭ", "J", "K", "L", "M", "N",
            "O", "Ō", "Ŏ", "P", "Q", "R", "S", "T", "U", "Ū",
            "Ŭ", "V", "W", "X", "Y", "Ȳ", "Y̆", "Z", "Æ",
        },
        it = { -- italian
            "a", "á", "b", "c", "d", "e", "é", "è", "f", "g",
            "h", "i", "í", "ì", "j", "k", "l", "m", "n", "o",
            "ó", "ò", "p", "q", "r", "s", "t", "u", "ú", "ù",
            "v", "w", "x", "y", "z",

            "A", "Á", "B", "C", "D", "E", "É", "È", "F", "G",
            "H", "I", "Í", "Ì", "J", "K", "L", "M", "N", "O",
            "Ó", "Ò", "P", "Q", "R", "S", "T", "U", "Ú", "Ù",
            "V", "W", "X", "Y", "Z",
        },
        ro = { -- romanian
            "a", "ă", "â", "b", "c", "d", "e", "f", "g", "h",
            "i", "î", "j", "k", "l", "m", "n", "o", "p", "q",
            "r", "s", "ș", "t", "ț", "u", "v", "w", "x", "y",
            "z",

            "A", "Ă", "Â", "B", "C", "D", "E", "F", "G", "H",
            "I", "Î", "J", "K", "L", "M", "N", "O", "P", "Q",
            "R", "S", "Ș", "T", "Ț", "U", "V", "W", "X", "Y",
            "Z",
        },
        es = { -- spanish
            "a", "á", "b", "c", "d", "e", "é", "f", "g", "h",
            "i", "í", "j", "k", "l", "m", "n", "ñ", "o", "ó",
            "p", "q", "r", "s", "t", "u", "ú", "ü", "v", "w",
            "x", "y", "z",

            "A", "Á", "B", "C", "D", "E", "É", "F", "G", "H",
            "I", "Í", "J", "K", "L", "M", "N", "Ñ", "O", "Ó",
            "P", "Q", "R", "S", "T", "U", "Ú", "Ü", "V", "W",
            "X", "Y", "Z",
        },
        pt = { -- portuguese
            "a", "á", "â", "ã", "à", "b", "c", "ç", "d", "e",
            "é", "ê", "f", "g", "h", "i", "í", "j", "k", "l",
            "m", "n", "o", "ó", "ô", "õ", "p", "q", "r", "s",
            "t", "u", "ú", "ü", "v", "w", "x", "y", "z",

            "A", "Á", "Â", "Ã", "À", "B", "C", "Ç", "D", "E",
            "É", "Ê", "F", "G", "H", "I", "Í", "J", "K", "L",
            "M", "N", "O", "Ó", "Ô", "Õ", "P", "Q", "R", "S",
            "T", "U", "Ú", "Ü", "V", "W", "X", "Y", "Z",
        },
        lt = { -- lithuanian
            "a", "ą", "b", "c", "ch",  "č", "d", "e", "ę", "ė",
            "f", "g", "h", "i", "į", "y", "j", "k", "l", "m",
            "n", "o", "p", "r", "s", "š", "t", "u", "ų", "ū",
            "v", "z", "ž",

            "A", "Ą", "B", "C", "CH",  "Č", "D", "E", "Ę", "Ė",
            "F", "G", "H", "I", "Į", "Y", "J", "K", "L", "M",
            "N", "O", "P", "R", "S", "Š", "T", "U", "Ų", "Ū",
            "V", "Z", "Ž",
        },
        lv = { -- latvian
            "a", "ā", "b", "c", "č", "d", "e", "ē", "f", "g",
            "ģ", "h", "i", "ī", "j", "k", "ķ", "l", "ļ", "m",
            "n", "ņ", "o", "ō", "p", "r", "ŗ", "s", "š", "t",
            "u", "ū", "v", "z", "ž",

            "A", "Ā", "B", "C", "Č", "D", "E", "Ē", "F", "G",
            "Ģ", "H", "I", "Ī", "J", "K", "Ķ", "L", "Ļ", "M",
            "N", "Ņ", "O", "Ō", "P", "R", "Ŗ", "S", "Š", "T",
            "U", "Ū", "V", "Z", "Ž",
        },
        hu = { -- hungarian
            "a", "á", "b", "c", "d", "e", "é",
            "f", "g", "h", "i", "í", "j", "k", "l",
            "m", "n", "o", "ó", "ö", "ő", "p", "q", "r",
            "s",  "t", "u", "ú", "ü", "ű", "v", "w",
            "x", "y", "z",

            "A", "Á", "B", "C", "D", "E", "É",
            "F", "G", "H", "I", "Í", "J", "K", "L",
            "M", "N", "O", "Ó", "Ö", "Ő", "P", "Q", "R",
            "S",  "T", "U", "Ú", "Ü", "Ű", "V", "W",
            "X", "Y", "Z",
        },
        et = { -- estonian
            "a", "b", "d", "e", "f", "g", "h", "i", "j", "k",
            "l", "m", "n", "o", "p", "r", "s", "š", "z", "ž",
            "t", "u", "v", "w", "õ", "ä", "ö", "ü", "x", "y",

            "A", "B", "D", "E", "F", "G", "H", "I", "J", "K",
            "L", "M", "N", "O", "P", "R", "S", "Š", "Z", "Ž",
            "T", "U", "V", "W", "Õ", "Ä", "Ö", "Ü", "X", "Y",
        },
     -- jp = { -- japanese
     --     "あ", "い", "う", "え", "お", "か", "き", "く", "け", "こ",
     --     "さ", "し", "す", "せ", "そ", "た", "ち", "つ", "て", "と",
     --     "な", "に", "ぬ", "ね", "の", "は", "ひ", "ふ", "へ", "ほ",
     --     "ま", "み", "む", "め", "も", "や", "ゆ", "よ",
     --     "ら", "り", "る", "れ", "ろ", "わ", "ゐ", "ゑ", "を", "ん",
     -- },
    }

    local textselector = { }
    for k, v in next, textlists do
        textselector[#textselector+1] = k
    end
    table.sort(textselector)

    -- We can populate these with the utf converter but it looks nicer here to
    -- see what we actually get. And it also tests how SciTE displays these
    -- special characters.

    local mathsets = {
        { "tf", {
            "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
            "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
            "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"
        }, },
        { "bf", {
            "𝐛", "𝐜", "𝐝", "𝐞", "𝐟", "𝐠", "𝐡", "𝐢", "𝐣", "𝐤", "𝐥", "𝐦", "𝐧", "𝐨", "𝐩", "𝐪", "𝐫", "𝐬", "𝐭", "𝐮", "𝐯", "𝐰", "𝐱", "𝐲", "𝐳",
            "𝐀", "𝐁", "𝐂", "𝐃", "𝐄", "𝐅", "𝐆", "𝐇", "𝐈", "𝐉", "𝐊", "𝐋", "𝐌", "𝐍", "𝐎", "𝐏", "𝐐", "𝐑", "𝐒", "𝐓", "𝐔", "𝐕", "𝐖", "𝐗", "𝐘", "𝐙", "𝐚",
            "𝟎", "𝟏", "𝟐", "𝟑", "𝟒", "𝟓", "𝟔", "𝟕", "𝟖", "𝟗"
        }, },
        { "it",           {
            "𝑎", "𝑏", "𝑐", "𝑑", "𝑒", "𝑓", "𝑔", "ℎ", "𝑖", "𝑗", "𝑘", "𝑙", "𝑚", "𝑛", "𝑜", "𝑝", "𝑞", "𝑟", "𝑠", "𝑡", "𝑢", "𝑣", "𝑤", "𝑥", "𝑦", "𝑧",
            "𝐴", "𝐵", "𝐶", "𝐷", "𝐸", "𝐹", "𝐺", "𝐻", "𝐼", "𝐽", "𝐾", "𝐿", "𝑀", "𝑁", "𝑂", "𝑃", "𝑄", "𝑅", "𝑆", "𝑇", "𝑈", "𝑉", "𝑊", "𝑋", "𝑌", "𝑍",
        }, },
        { "bi",           {
            "𝒂", "𝒃", "𝒄", "𝒅", "𝒆", "𝒇", "𝒈", "𝒉", "𝒊", "𝒋", "𝒌", "𝒍", "𝒎", "𝒏", "𝒐", "𝒑", "𝒒", "𝒓", "𝒔", "𝒕", "𝒖", "𝒗", "𝒘", "𝒙", "𝒚", "𝒛",
            "𝑨", "𝑩", "𝑪", "𝑫", "𝑬", "𝑭", "𝑮", "𝑯", "𝑰", "𝑱", "𝑲", "𝑳", "𝑴", "𝑵", "𝑶", "𝑷", "𝑸", "𝑹", "𝑺", "𝑻", "𝑼", "𝑽", "𝑾", "𝑿", "𝒀", "𝒁",
        }, },
        { "sc",       {
            "𝒵", "𝒶", "𝒷", "𝒸", "𝒹", "ℯ", "𝒻", "ℊ", "𝒽", "𝒾", "𝒿", "𝓀", "𝓁", "𝓂", "𝓃", "ℴ", "𝓅", "𝓆", "𝓇", "𝓈", "𝓉", "𝓊", "𝓋", "𝓌", "𝓍", "𝓎", "𝓏",
            "𝒜", "ℬ", "𝒞", "𝒟", "ℰ", "ℱ", "𝒢", "ℋ", "ℐ", "𝒥", "𝒦", "ℒ", "ℳ", "𝒩", "𝒪", "𝒫", "𝒬", "ℛ", "𝒮", "𝒯", "𝒰", "𝒱", "𝒲", "𝒳", "𝒴",
        }, },
        { "sc bf",   {
            "𝓪", "𝓫", "𝓬", "𝓭", "𝓮", "𝓯", "𝓰", "𝓱", "𝓲", "𝓳", "𝓴", "𝓵", "𝓶", "𝓷", "𝓸", "𝓹", "𝓺", "𝓻", "𝓼", "𝓽", "𝓾", "𝓿", "𝔀", "𝔁", "𝔂", "𝔃",
            "𝓐", "𝓑", "𝓒", "𝓓", "𝓔", "𝓕", "𝓖", "𝓗", "𝓘", "𝓙", "𝓚", "𝓛", "𝓜", "𝓝", "𝓞", "𝓟", "𝓠", "𝓡", "𝓢", "𝓣", "𝓤", "𝓥", "𝓦", "𝓧", "𝓨", "𝓩",
        }, },
        { "fr",      {
            "𝔞", "𝔟", "𝔠", "𝔡", "𝔢", "𝔣", "𝔤", "𝔥", "𝔦", "𝔧", "𝔨", "𝔩", "𝔪", "𝔫", "𝔬", "𝔭", "𝔮", "𝔯", "𝔰", "𝔱", "𝔲", "𝔳", "𝔴", "𝔵", "𝔶", "𝔷",
            "𝔄", "𝔅", "ℭ", "𝔇", "𝔈", "𝔉", "𝔊", "ℌ", "ℑ", "𝔍", "𝔎", "𝔏", "𝔐", "𝔑", "𝔒", "𝔓", "𝔔", "ℜ", "𝔖", "𝔗", "𝔘", "𝔙", "𝔚", "𝔛", "𝔜", "ℨ",
        }, },
        { "ds", {
            "𝕓", "𝕔", "𝕕", "𝕖", "𝕗", "𝕘", "𝕙", "𝕚", "𝕛", "𝕜", "𝕝", "𝕞", "𝕟", "𝕠", "𝕡", "𝕢", "𝕣", "𝕤", "𝕥", "𝕦", "𝕧", "𝕨", "𝕩", "𝕪", "𝕫",
            "𝔸", "𝔹", "ℂ", "𝔻", "𝔼", "𝔽", "𝔾", "ℍ", "𝕀", "𝕁", "𝕂", "𝕃", "𝕄", "ℕ", "𝕆", "ℙ", "ℚ", "ℝ", "𝕊", "𝕋", "𝕌", "𝕍", "𝕎", "𝕏", "𝕐", "ℤ", "𝕒",
            "𝟘", "𝟙", "𝟚", "𝟛", "𝟜", "𝟝", "𝟞", "𝟟", "𝟠", "𝟡"
        }, },
        { "fr bf",  {
            "𝕬", "𝕭", "𝕮", "𝕯", "𝕰", "𝕱", "𝕲", "𝕳", "𝕴", "𝕵", "𝕶", "𝕷", "𝕸", "𝕹", "𝕺", "𝕻", "𝕼", "𝕽", "𝕾", "𝕿", "𝖀", "𝖁", "𝖂", "𝖃",
            "𝖄", "𝖅", "𝖆", "𝖇", "𝖈", "𝖉", "𝖊", "𝖋", "𝖌", "𝖍", "𝖎", "𝖏", "𝖐", "𝖑", "𝖒", "𝖓", "𝖔", "𝖕", "𝖖", "𝖗", "𝖘", "𝖙", "𝖚", "𝖛", "𝖜", "𝖝", "𝖞", "𝖟"
        }, },
        { "ss tf",        {
            "𝖺", "𝖻", "𝖼", "𝖽", "𝖾", "𝖿", "𝗀", "𝗁", "𝗂", "𝗃", "𝗄", "𝗅", "𝗆", "𝗇", "𝗈", "𝗉", "𝗊", "𝗋", "𝗌", "𝗍", "𝗎", "𝗏", "𝗐", "𝗑", "𝗒", "𝗓",
            "𝖠", "𝖡", "𝖢", "𝖣", "𝖤", "𝖥", "𝖦", "𝖧", "𝖨", "𝖩", "𝖪", "𝖫", "𝖬", "𝖭", "𝖮", "𝖯", "𝖰", "𝖱", "𝖲", "𝖳", "𝖴", "𝖵", "𝖶", "𝖷", "𝖸", "𝖹",
            "𝟢", "𝟣", "𝟤", "𝟥", "𝟦", "𝟧", "𝟨", "𝟩", "𝟪", "𝟫"
        }, },
        { "ss bf",        {
            "𝗮", "𝗯", "𝗰", "𝗱", "𝗲", "𝗳", "𝗴", "𝗵", "𝗶", "𝗷", "𝗸", "𝗹", "𝗺", "𝗻", "𝗼", "𝗽", "𝗾", "𝗿", "𝘀", "𝘁", "𝘂", "𝘃", "𝘄", "𝘅", "𝘆", "𝘇",
            "𝗔", "𝗕", "𝗖", "𝗗", "𝗘", "𝗙", "𝗚", "𝗛", "𝗜", "𝗝", "𝗞", "𝗟", "𝗠", "𝗡", "𝗢", "𝗣", "𝗤", "𝗥", "𝗦", "𝗧", "𝗨", "𝗩", "𝗪", "𝗫", "𝗬", "𝗭",
            "𝟬", "𝟭", "𝟮", "𝟯", "𝟰", "𝟱", "𝟲", "𝟳", "𝟴", "𝟵",
        }, },
        { "ss it",        {
            "𝘢", "𝘣", "𝘤", "𝘥", "𝘦", "𝘧", "𝘨", "𝘩", "𝘪", "𝘫", "𝘬", "𝘭", "𝘮", "𝘯", "𝘰", "𝘱", "𝘲", "𝘳", "𝘴", "𝘵", "𝘶", "𝘷", "𝘸", "𝘹", "𝘺", "𝘻",
            "𝘈", "𝘉", "𝘊", "𝘋", "𝘌", "𝘍", "𝘎", "𝘏", "𝘐", "𝘑", "𝘒", "𝘓", "𝘔", "𝘕", "𝘖", "𝘗", "𝘘", "𝘙", "𝘚", "𝘛", "𝘜", "𝘝", "𝘞", "𝘟", "𝘠", "𝘡",
        }, },
        { "ss bi",        {
            "𝙖", "𝙗", "𝙘", "𝙙", "𝙚", "𝙛", "𝙜", "𝙝", "𝙞", "𝙟", "𝙠", "𝙡", "𝙢", "𝙣", "𝙤", "𝙥", "𝙦", "𝙧", "𝙨", "𝙩", "𝙪", "𝙫", "𝙬", "𝙭", "𝙮", "𝙯",
            "𝘼", "𝘽", "𝘾", "𝘿", "𝙀", "𝙁", "𝙂", "𝙃", "𝙄", "𝙅", "𝙆", "𝙇", "𝙈", "𝙉", "𝙊", "𝙋", "𝙌", "𝙍", "𝙎", "𝙏", "𝙐", "𝙑", "𝙒", "𝙓", "𝙔", "𝙕",
        }, },
        { "tt",           {
            "𝚊", "𝚋", "𝚌", "𝚍", "𝚎", "𝚏", "𝚐", "𝚑", "𝚒", "𝚓", "𝚔", "𝚕", "𝚖", "𝚗", "𝚘", "𝚙", "𝚚", "𝚛", "𝚜", "𝚝", "𝚞", "𝚟", "𝚠", "𝚡", "𝚢", "𝚣",
            "𝙰", "𝙱", "𝙲", "𝙳", "𝙴", "𝙵", "𝙶", "𝙷", "𝙸", "𝙹", "𝙺", "𝙻", "𝙼", "𝙽", "𝙾", "𝙿", "𝚀", "𝚁", "𝚂", "𝚃", "𝚄", "𝚅", "𝚆", "𝚇", "𝚈", "𝚉",
            "𝟶", "𝟷", "𝟸", "𝟹", "𝟺", "𝟻", "𝟼", "𝟽", "𝟾", "𝟿"
        }, },
        { "gr tf",        {
            "α", "β", "γ", "δ", "ε", "ζ", "η", "θ", "ι", "κ", "λ", "μ", "ν", "ξ", "ο", "π", "ρ", "ς", "σ", "τ", "υ", "φ", "χ", "ψ", "ω",
            "Α", "Β", "Γ", "Δ", "Ε", "Ζ", "Η", "Θ", "Ι", "Κ", "Λ", "Μ", "Ν", "Ξ", "Ο", "Π", "Ρ", "΢", "Σ", "Τ", "Υ", "Φ", "Χ", "Ψ", "Ω",
        }, },
        { "gr bf",        {
            "𝛂", "𝛃", "𝛄", "𝛅", "𝛆", "𝛇", "𝛈", "𝛉", "𝛊", "𝛋", "𝛌", "𝛍", "𝛎", "𝛏", "𝛐", "𝛑", "𝛒", "𝛓", "𝛔", "𝛕", "𝛖", "𝛗", "𝛘", "𝛙", "𝛚",
            "𝚨", "𝚩", "𝚪", "𝚫", "𝚬", "𝚭", "𝚮", "𝚯", "𝚰", "𝚱", "𝚲", "𝚳", "𝚴", "𝚵", "𝚶", "𝚷", "𝚸", "𝚹", "𝚺", "𝚻", "𝚼", "𝚽", "𝚾", "𝚿", "𝛀",
        }, },
        { "gr it",        {
            "𝛼", "𝛽", "𝛾", "𝛿", "𝜀", "𝜁", "𝜂", "𝜃", "𝜄", "𝜅", "𝜆", "𝜇", "𝜈", "𝜉", "𝜊", "𝜋", "𝜌", "𝜍", "𝜎", "𝜏", "𝜐", "𝜑", "𝜒", "𝜓", "𝜔",
            "𝛢", "𝛣", "𝛤", "𝛥", "𝛦", "𝛧", "𝛨", "𝛩", "𝛪", "𝛫", "𝛬", "𝛭", "𝛮", "𝛯", "𝛰", "𝛱", "𝛲", "𝛳", "𝛴", "𝛵", "𝛶", "𝛷", "𝛸", "𝛹", "𝛺",
        }, },
        { "gr bi",        {
            "𝜶", "𝜷", "𝜸", "𝜹", "𝜺", "𝜻", "𝜼", "𝜽", "𝜾", "𝜿", "𝝀", "𝝁", "𝝂", "𝝃", "𝝄", "𝝅", "𝝆", "𝝇", "𝝈", "𝝉", "𝝊", "𝝋", "𝝌", "𝝍", "𝝎",
            "𝜜", "𝜝", "𝜞", "𝜟", "𝜠", "𝜡", "𝜢", "𝜣", "𝜤", "𝜥", "𝜦", "𝜧", "𝜨", "𝜩", "𝜪", "𝜫", "𝜬", "𝜭", "𝜮", "𝜯", "𝜰", "𝜱", "𝜲", "𝜳", "𝜴",
        }, },
        { "gr ss bf",     {
            "𝝰", "𝝱", "𝝲", "𝝳", "𝝴", "𝝵", "𝝶", "𝝷", "𝝸", "𝝹", "𝝺", "𝝻", "𝝼", "𝝽", "𝝾", "𝝿", "𝞀", "𝞁", "𝞂", "𝞃", "𝞄", "𝞅", "𝞆", "𝞇", "𝞈",
            "𝝖", "𝝗", "𝝘", "𝝙", "𝝚", "𝝛", "𝝜", "𝝝", "𝝞", "𝝟", "𝝠", "𝝡", "𝝢", "𝝣", "𝝤", "𝝥", "𝝦", "𝝧", "𝝨", "𝝩", "𝝪", "𝝫", "𝝬", "𝝭", "𝝮",
        }, },
        { "gr ss bi",  {
            "𝞪", "𝞫", "𝞬", "𝞭", "𝞮", "𝞯", "𝞰", "𝞱", "𝞲", "𝞳", "𝞴", "𝞵", "𝞶", "𝞷", "𝞸", "𝞹", "𝞺", "𝞻", "𝞼", "𝞽", "𝞾", "𝞿", "𝟀", "𝟁", "𝟂",
            "𝞐", "𝞑", "𝞒", "𝞓", "𝞔", "𝞕", "𝞖", "𝞗", "𝞘", "𝞙", "𝞚", "𝞛", "𝞜", "𝞝", "𝞞", "𝞟", "𝞠", "𝞡", "𝞢", "𝞣", "𝞤", "𝞥", "𝞦", "𝞧", "𝞨",
        }, },
        { "op", {
        }, },
        { "sy a", {
        }, },
        { "sy b", {
        }, },
        { "sy c", {
        }, },
    }

    local mathlists    = { }
    local mathselector = { }

    for i=1,#mathsets do
        local mathset = mathsets[i]
        mathselector[#mathselector+1] = mathset[1]
        mathlists[mathset[1]] = mathset[2]
    end

    local enabled   = 0
    local usedlists = {
        { name = "text", current = "en", lists = textlists, selector = textselector },
        { name = "math", current = "tf", lists = mathlists, selector = mathselector },
    }

    local function make_strip()
        local used     = usedlists[enabled]
        local lists    = used.lists
        local alphabet = lists[used.current]
        local selector = "(hide)(" .. concat(used.selector,")(") .. ")"
        local alphabet = "(" .. used.current .. ":)(" .. concat(alphabet,")(") .. ")"
        scite.StripShow(selector .. "\n" .. alphabet)
    end

    local function hide_strip()
        scite.StripShow("")
    end

    local function process_strip(control)
        local value = scite.StripValue(control)
        if value == "hide" then
            hide_strip()
            return
        elseif find(value,".+:") then
            return
        end
        local used = usedlists[enabled]
        if used.lists[value] then
            used.current = value
            make_strip()
        else
            editor:insert(editor.CurrentPos,value)
        end
    end

    local function ignore_strip()
    end

    function toggle_strip(name)
        enabled = enabled + 1
        if usedlists[enabled] then
            make_strip()
            OnStrip = process_strip
        else
            enabled = 0
            hide_strip()
            OnStrip = ignore_strip
        end
    end

end

-- Last time I checked the source the output pane errorlist lexer was still
-- hardcoded and could not be turned off ... alas.

-- output.Lexer = 0

-- SCI_SETBIDIRECTIONAL = SC_BIDIRECTIONAL_R2L

-- Because SCITE messes around with package.loaded a regular require doesn't work, so
-- we overload it. We also add some paths.

do

    package.path = props.SciteDefaultHome .. "/context/lexers/?.lua;"        .. package.path
    package.path = props.SciteDefaultHome .. "/context/lexers/themes/?.lua;" .. package.path
    package.path = props.SciteDefaultHome .. "/context/lexers/data/?.lua;"   .. package.path

    local required = require
    local loaded   = { }

    require = function(name)
        local data = loaded[name]
        if not data then
            data = required(name)
            loaded[name] = data
        end
        return data
    end

end

-- It makes not much sense to trace back over whitespace and start lexing because in
-- our use case we can have nested lexers that themselve need a trace back. Also, in
-- large documents we seldom add at the end and therefore can as well parse the
-- whole document. Lua 5.4 is faster anyway.
--
-- The 'editor' object is not useable because (1) it is null terminating which is
-- bad for the PDF lexer. The 'styler' on the other hand is utf based and does not
-- work well for the byte based LPEG lexers. And, because 'OnStyle' creates a large
-- userdata blob anyway, we added a few methods to it.
--
-- Because this file will be reloaded after a change, and in the process messes with
-- some global properties (like package.loaded) we have some require hackery in the
-- lexer files.

-- function OnStyle(styler)
--     local S_DEFAULT = 0
--     local S_IDENTIFIER = 1
--     local S_KEYWORD = 2
--     local S_UNICODECOMMENT = 3
--     local identifierCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
--     styler:StartStyling(styler.startPos, styler.lengthDoc, styler.initStyle)
--     while styler:More() do
--         if styler:State() == S_IDENTIFIER then
--             if not identifierCharacters:find(styler:Current(), 1, true) then
--                 local identifier = styler:Token()
--                 if identifier == "if" or identifier == "end" then
--                         styler:ChangeState(S_KEYWORD)
--                 end
--                 styler:SetState(S_DEFAULT)
--             end
--         elseif styler:State() == S_UNICODECOMMENT then
--             if styler:Match("»") then
--                 styler:ForwardSetState(S_DEFAULT)
--             end
--         end
--         if styler:State() == S_DEFAULT then
--             if styler:Match("«") then
--                 styler:SetState(S_UNICODECOMMENT)
--             elseif identifierCharacters:find(styler:Current(), 1, true) then
--                 styler:SetState(S_IDENTIFIER)
--             end
--         end
--         styler:Forward()
--     end
--     styler:EndStyling()
-- end

-- function OnStyle(styler)
--     local lineStart = editor:LineFromPosition(styler.startPos)
--     local lineEnd = editor:LineFromPosition(styler.startPos + styler.lengthDoc)
--     editor:StartStyling(styler.startPos, 31)
--     for line=lineStart,lineEnd,1 do
--         local lengthLine = editor:PositionFromLine(line+1) - editor:PositionFromLine(line)
--         local lineText = editor:GetLine(line)
--         local first = string.sub(lineText,1,1)
--         local style = 0
--         if first == "+" then
--                 style = 1
--         elseif first == " " or first == "\t" then
--                 style = 2
--         end
--         editor:SetStyling(lengthLine, style)
--     end
-- end

do

    local lexers     = nil
    local properties = props
    local partial    = false
    local partial    = true
    local trace      = false
--     local trace      = true

    local loadedlexers = setmetatable ( { }, {
        __index = function(t,k)
                local language = match(k,"^script_(.*)$") or k
                if not lexers then
                    lexers = require("scite-context-lexer")
                    lexers.loadtheme(require("scite-context-theme"))
                end
                local name = "scite-context-lexer-" .. language
                local v = lexers.load(name)
                if v then
                    lexers.registertheme(properties,language)
                else
                    v = false
                end
                t[name]     = v
                t[k]        = v
                t[language] = v
                return v
            end
        } )

    local function update(language,size,start,stop)
        if language then
            local syntax = loadedlexers[language]
            if syntax then
                lexers.scite_onstyle(syntax,editor,partial,language,props.FileNameExt,size,start,stop,trace)
            end
        end
    end

    function Initialise()
        check_output_pane()
    end

    function OnStyle(styler)
        -- for the moment here: editor.StyleClearAll(output) -- we have no way to nil the output lexer
        update(styler.language,editor.TextLength,styler.startPos,styler.lengthDoc)
    end

    function OnOpen(filename)
        if trace then
            report("opening '%s' of %i bytes, language '%s'",filename,editor.TextLength,props.Language)
        end
        update(props.Language,editor.TextLength,0,editor.TextLength)
        check_output_pane()
    end

    function OnSwitchFile(filename)
        if dirty[props.FileNameExt] then
            if trace then
                report("switching '%s' of %i bytes, language '%s'",filename,editor.TextLength,props.Language)
            end
            update(props.Language,editor.TextLength,0,editor.TextLength)
            dirty[props.FileNameExt] = false
        end
        check_output_pane()
    end

    function OnChar()
        if not editor:AutoCActive() then
            local syntax = loadedlexers[props.Language]
            if syntax and syntax.completion then
                local stop   = editor.CurrentPos
                local start  = editor:WordStartPosition(stop,true)
                local length = stop - start
                if length >= 2 then
                    local snippet = editor:textrange(start,stop)
                    local list    = syntax.completion(snippet)
                    if list then
                        editor.AutoCMaxHeight = 30
                        editor.AutoCSeparator = 32
                        editor:AutoCShow(length,list)
                    end
                end
            end
        end
    end

end

-- function OnKey(a,b,c)
--     print("key",a,b,c)
-- end

