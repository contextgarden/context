local info = {
    version   = 1.002,
    comment   = "prototype textadept runner for context/metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- This is an adapted version of the run code by mitchell.att.foicica.corunner. The main
-- reason I started patching is that long lines got broken in the middle so we needed
-- to have a more clever line splitter that saves half of a line for later. Then I
-- decided to come up with a few more variants so in the end ... it's just too tempting
-- make something that exactly suits out needs. In fact, maybe I'll do that some day:
-- take core textadept and make a dedicated variant for the kind of processing that we
-- do and make it suitable for document authors (the manual says that is doable). In that
-- case I can also use a lot of already written helpers.
--
-- The error scanner is not needed. If I need one, it will be using a lexers applied
-- afterwards because working on half lines is not going to work out well anyway.
--
-- Here I removed iconv calls as in context we use utf (less hassle with fonts too). One
-- can always use the original approach.
--
-- The events seems to have hard coded names, Also, the name of the message buffer cannot
-- be changes because otherwise we get a message when the session is restored. I don't
-- care about locales.
--
-- Somehow the process hangs when I refresh the pdf viewer, this doesn't happen in scite so
-- the underlying code is for the moment less reliant.

local match, gsub, find, format, gmatch, rep = string.match, string.gsub, string.find, string.format, string.gmatch, string.rep
local char, lower, upper, sub = string.char, string.lower, string.upper, string.sub
local concat, sort = table.concat, table.sort
local assert, type = assert, type

local original            = textadept.run
local runner              = { }

runner.MARK_WARNING       = original.MARK_WARNING
runner.MARK_ERROR         = original.MARK_ERROR

local specifications      = { }
runner.specifications     = specifications

----- RUNNER_EVENT        = "[Context Runner]"
local OUTPUT_BUFFER       = '[Message Buffer]' -- CONSOLE

----- events.RUNNER_EVENT = RUNNER_EVENT

local currentprocess      = nil
local xbuffer             = nil

local function find_buffer(buffer_type)
    for i=1,#_BUFFERS do
        local buffer = _BUFFERS[i]
        if buffer._type == buffer_type then
            return buffer
        end
    end
end

local function print_output(str)
    local print_buffer = find_buffer(OUTPUT_BUFFER)
    -- some simplified magic copied from the adeptext runner
    if not print_buffer then
        if not ui.tabs then
            view:split()
        end
        print_buffer = buffer.new()
        print_buffer._type = OUTPUT_BUFFER
        events.emit(events.FILE_OPENED)
    else
        for i=1,#_VIEWS do
            local view = _VIEWS[i]
            if view.buffer._type == OUTPUT_BUFFER then
                ui.goto_view(view)
                break
            end
        end
        if view.buffer._type ~= OUTPUT_BUFFER then
            view:goto_buffer(print_buffer)
        end
    end
    print_buffer:append_text(str)
    print_buffer:goto_pos(buffer.length)
    print_buffer:set_save_point()
    return true -- quits
end

local function trace_output(str)
    xbuffer = buffer
    print_output(str)
    if xbuffer then 
        view:goto_buffer(xbuffer)
    end 
end 

local function clear_output()
    xbuffer = buffer
    local print_buffer = find_buffer(OUTPUT_BUFFER)
    if print_buffer then
        print_buffer:clear_all()
    end
end

local function is_output(buffer)
    return buffer._type == OUTPUT_BUFFER
end

-- Instead of events we will have out own interceptors so that we don't have
-- interference. The main problem is that we don't have much control over the
-- order. If we have much actions I can always come up with something. 

-- The textadept console seems a bit slower than the one in scite (which does some 
-- output pane parsing so it could be even faster). Maybe it relates to the way 
-- the program is run. Scite provides some more control over this. It might have
-- to do with the way tex pipes to the console, because from a simple lua run it's 
-- quite fast. Maybe calling cmd is not optimal. Anyhow, it means that for now I 
-- should not use textadept when running performance test that need to compare with 
-- the past. 

local function process(buffer,filename,action)
    if not filename then
        filename = buffer.filename
    end
    if not filename then
        return
    end
    if filename == buffer.filename then
        buffer:annotation_clear_all() -- needed ?
        io.save_file()
    end
    if filename == "" then
        return
    end
    local suffix        = match(filename,'[^/\\.]+$')
    local specification = specifications[suffix]
    if not specification then
        return
    end
    local action = specification[action]
    local quitter = nil
    if type(action) == "table" then
        action  = action.command
        quitter = action.quitter
    end
    if type(action) ~= "string" then
        return
    end
    clear_output()
    local pathpart = ''
    local basename = filename
    if find(filename,'[/\\]') then
        pathpart, basename = match(filename,'^(.+[/\\])([^/\\]+)$')
    end
    -- beter strip one from the end
    local nameonly = match(basename,'^(.+)%.')
    -- more in sync which what we normally do (i'd rather use the ctx template mechanism)
    local command = gsub(action,'%%(.-)%%', {
        filename  = filename,
        pathname  = dirname,
        dirname   = dirname,
        pathpart  = dirname,
        basename  = basename,
        nameonly  = nameonly,
        suffix    = suffix,
        selection = function() return match(buffer.get_sel_text(),"%s*([A-Za-z]+)") end,
    })
    -- for fun i'll add a ansi escape sequence lexer some day
    local function emit_output(output)
        print_output(output) -- events.emit(RUNNER_EVENT,...)
        -- afaik there is no way to check if we're waiting for input (no input callback)
       if quitter then
           local quit, message = quitter(interceptor)
           if quit then
               if message then
                   print_output(format("\n\n> quit: %s\n",message))
               end
               runner.quit()
           end
       end
    end
    local function exit_output(status)
        print_output(format("\n\n> exit: %s, press esc to return to source\n",status)) -- events.emit(RUNNER_EVENT,...)
    end
    print_output(format("> command: %s\n",command)) -- events.emit(RUNNER_EVENT,...)
    currentprocess = assert(os.spawn(command, pathpart, emit_output, emit_output, exit_output))
end

function runner.install(name)
    return function(filename)
        process(buffer,filename,name)
    end
end

runner.check   = runner.install("check")
runner.process = runner.install("process")
runner.preview = runner.install("preview")

function runner.resultof(command) -- from l-os.lua
    local handle = io.popen(command,"r")
    if handle then
        local result = handle:read("*all") or ""
        handle:close()
        return result
    else
        return ""
    end
end

function runner.quit()
    if currentprocess then
        assert(currentprocess:kill())
    end
end

local function char_added(code)
    if code == 10 and currentprocess and currentprocess:status() == 'running' and buffer._type == OUTPUT_BUFFER then
        local line_num = buffer:line_from_position(buffer.current_pos) - 1
        currentprocess:write((buffer:get_line(line_num)))
    end
    return true -- quits
end

function runner.goto_error(line, next)
    -- see original code for how to do it
end

local function key_press(code)
    if xbuffer and keys.KEYSYMS[code] == 'esc' then
        view:goto_buffer(xbuffer)
        return true
    end
end

local function double_click()
    if xbuffer and is_output(buffer) then
        view:goto_buffer(xbuffer)
        return true
    end
end

-- 

local l2 = char(0xC0)
local l3 = char(0xE0)
local l4 = char(0xF0)

local function utflen(str)
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

local function prepare()
    local startposition = buffer.selection_start 
    local endposition   = buffer.selection_end   

    if startposition == endposition then return end

    buffer.current_pos = startposition
    buffer:home()

    buffer.current_pos = endposition
    buffer:line_end_extend()

    local firstposition = buffer.selection_start 
    local lastposition  = buffer.selection_end   

    local firstline     = buffer:line_from_position(startposition)
    local lastline      = buffer:line_from_position(endposition)

    local startcolumn   = startposition - firstposition
    local endcolumn     = lastposition  - endposition   + 1 
    local selection     = buffer:get_sel_text()

 -- trace_output(firstposition .. " " .. startposition .. "\n")
 -- trace_output(endposition   .. " " .. lastposition  .. "\n")

    return startposition, endposition, firstposition, lastposition, startcolumn, endcolumn, firstline, lastline, selection
end 

local function replace(startposition,lastposition,replacement)
    if type(replacement) == "table" then 
        replacement = concat(replacement,"\n")
    end 
 -- trace_output(replacement .. "\n")

    buffer.current_pos = startposition

    buffer:begin_undo_action()
    buffer:set_target_range(startposition,lastposition)
    buffer:replace_target(replacement)
    buffer:end_undo_action()

    buffer.selection_start = startposition
    buffer.selection_end   = startposition
end

-- This is old code, from my early lua days, so not that nice and optimal, but 
-- no one sees it and performance is irrelevant here. 

local magicstring = rep("<ctx-crlf/>", 2)

function runner.wrap()

    local startposition, endposition, firstposition, lastposition, startcolumn, endcolumn, firstline, lastline, selection = prepare()

    if not startposition then 
        return 
    end 

    local wraplength  = buffer.wrap_length
    local length      = tonumber(wraplength) or 80
    local replacement = { }
    local templine    = ""
    local tempsize    = 0
    local indentation = rep(' ',startcolumn)

    selection = gsub(selection,"[\n\r][\n\r]","\n")
    selection = gsub(selection,"\n\n+"," " .. magicstring .. " ")
    selection = gsub(selection,"^%s",'')

    for snippet in gmatch(selection,"%S+") do
        if snippet == magicstring then
            replacement[#replacement+1] = templine
            replacement[#replacement+1] = ""
            templine = ""
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
                templine = templine .. " " .. snippet
                tempsize = tempsize + 1 + snipsize
            end
        end
    end
    
    replacement[#replacement+1] = templine  
    replacement[1] = gsub(replacement[1],"^%s+","")

    if endcolumn == 0 then
        replacement[#replacement+1] = ""
    end

    replace(startposition,lastposition,replacement)

end 

local magicstring = rep("<multiplelines/>", 2)

function runner.unwrap()

    local startposition, endposition, firstposition, lastposition, startcolumn, endcolumn, selection, firstline, lastline = prepare()

    if not startposition then 
        return 
    end 

    startposition = firstposition 
    endposition   = lastposition 

    local selection   = gsub(selection,"[\n\r][\n\r]+", " " .. magicstring .. " ")
    local replacement = { } 

    for snippet in gmatch(selection,"%S+") do
        replacement[#replacement+1] = snippet == magicstring and "" or snippet
    end

    if endcolumn == 0 then
        replacement[#replacement+1] = ""
    end

    replace(startposition,lastposition,replacement)

end 

-- This is real old crappy code which doesn't really pass my current qa standards but 
-- it does the job so ... (hashing the blobs would work ok). 

local function grab(str,delimiter)
    local list = { }
    for snippet in gmatch(str,delimiter) do
        list[#list+1] = snippet
    end
    return list
end

local function alphacmp_yes(a,b)
    return lower(gsub(sub(a,i),"0"," ")) < lower(gsub(sub(b,i),"0"," "))
end

local function alphacmp_nop(a,b)
    return lower(a) < lower(b)
end

local function alphasort(list,i)    
    sort(list,i and i > 0 and alphacmp_yes or alphacmp_nop)
end

function runner.sort()

    local startposition, endposition, firstposition, lastposition, startcolumn, endcolumn, firstline, lastline, selection = prepare()

    if not startposition then 
        return 
    end 

    startposition = firstposition 
    endposition   = lastposition 

    local list = grab(selection,"[^\n\r]+")

    alphasort(list,startcolumn)

    if endcolumn == 0 then
        list[#list+1] = ""
    end

    replace(startposition,lastposition,list)

end 

-- Tricky: we can't reset an event (because we need to know the function which is
-- local. So, a first solution injected a false into the table which will trigger
-- a break and then I found out that returning true has the same effect. Then I
-- found out that we can have our own events and next decided not to use them at
-- all.

-- events.connect(events.RUNNER_EVENT,   print_output, 1)

events.connect(events.CHAR_ADDED,     char_added,   1)
events.connect(events.KEYPRESS,       key_press,    1)
events.connect(events.DOUBLE_CLICK,   double_click, 1)

-- We need to get rid of the crash due to macros.lua event crash in 
-- 
-- -- textadept.menu.menubar[_L['_Tools']][_L['Select Co_mmand']][2],

-- for i=1,#_VIEWS do
--     if _VIEWS[i].buffer._type == "[Message Buffer]" then 
--         ui.goto_view(_VIEWS[i])
--         buffer.current_pos = buffer.current_pos
--         io.close_buffer()
--         break 
--     end
-- end
-- for i = 1, #_BUFFERS do
--     if _BUFFERS[i]._type == "[Message Buffer]" then 
--         view:goto_buffer(_BUFFERS[i]) 
--         buffer.current_pos = buffer.current_pos
--         io.close_buffer()
--         break 
--     end
-- end

-- I don't want the indentation. I also want an extra space which in turn means 
-- a more extensive test. I also don't care about a suffix. Adapted a bit to 
-- match the code above. 

function runner.blockcomment()
    local buffer  = buffer
    local comment = textadept.editing.comment_string[buffer:get_lexer(true)]

    if not comment or comment == "" then 
        return 
    end

    local prefix     = comment:match('^([^|]+)|?([^|]*)$')
    local usedprefix = prefix 

    if not prefix then 
        return     
    end

    if not find(prefix,"%s$") then 
        usedprefix = prefix .. " "
    end

    local n_prefix      = #prefix
    local n_usedprefix  = #usedprefix

    local startposition = buffer.selection_start
    local endposition   = buffer.selection_end
    local firstline     = buffer:line_from_position(startposition)
    local lastline      = buffer:line_from_position(endposition)

    if firstline ~= lastline and endposition == buffer:position_from_line(lastline) then 
        lastline = lastline - 1 
    end 

    startposition = buffer.line_end_position[startposition] - startposition
    endposition   = buffer.length - endposition

    buffer:begin_undo_action()

    for line=firstline,lastline do
        local p = buffer:position_from_line(line)
        if buffer:text_range(p, p + n_usedprefix) == usedprefix then
            buffer:delete_range(p, n_usedprefix)
        elseif buffer:text_range(p, p + n_prefix) == prefix then
            buffer:delete_range(p, n_prefix)
        else
            buffer:insert_text(p, usedprefix)
        end
    end

    buffer:end_undo_action()

    startposition = buffer.line_end_position[firstline] - startposition
    endposition   = buffer.length - endposition

    -- whatever ... 

    local start_pos = buffer:position_from_line(firstline)

    if start_pos > startposition then 
        startposition = start_pos 
    end 
    if start_pos > endposition then 
        endposition = start_pos 
    end 

    if firstline ~= lastline then 
        buffer:set_sel(startposition, endposition) 
    else 
        buffer:goto_pos(endposition) 
    end
end

-- This only works partially as for some reason scite shows proper math symbols while 
-- here we don't see them. I need to look into that. 

local textlists = { -- taken from sort-lan.lua
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
sort(textselector)

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

-- I haven't found out yet how to create a strip as in scite. 

-- local function make_strip()
--     local used     = usedlists[enabled]
--     local lists    = used.lists
--     local alphabet = lists[used.current]
--     local selector = "(hide)(" .. concat(used.selector,")(") .. ")"
--     local alphabet = "(" .. used.current .. ":)(" .. concat(alphabet,")(") .. ")"
-- --     scite.StripShow(selector .. "\n" .. alphabet)
-- end
-- 
-- local function hide_strip()
-- --     scite.StripShow("")
-- end
-- 
-- local function process_strip(control)
-- --     local value = scite.StripValue(control)
-- --     if value == "hide" then
-- --         hide_strip()
-- --         return
-- --     elseif find(value,".+:") then
-- --         return
-- --     end
-- --     local used = usedlists[enabled]
-- --     if used.lists[value] then
-- --         used.current = value
-- --         make_strip()
-- --     else
-- --         editor:insert(editor.CurrentPos,value)
-- --     end
-- end
-- 
-- local function ignore_strip()
-- end

function runner.unicodes(name)
--     enabled = enabled + 1
--     if usedlists[enabled] then
--         make_strip()
--     else
--         enabled = 0
--         hide_strip()
--     end
end
 
return runner

-- The ui.print function is a bit heavy as each flush will parse the whole list of buffers.
-- Also it does some tab magic that we don't need or want. There is the original ui.print for
-- that. FWIW, speed is not an issue. Some optimizations:

-- function _print(buffer_type,one,two,...)
--     ...
--     print_buffer:append_text(one)
--     if two then
--         print_buffer:append_text(two)
--         for i=1, select('#', ...) do
--             print_buffer:append_text((select(i,...)))
--         end
--     end
--     print_buffer:append_text('\n')
--     ...
-- end
--
-- And a better splitter:
--     ...
--     local rest
--     local function emit_output(output)
--         for line, lineend in output:gmatch('([^\r\n]+)([\r\n]?)') do
--             if rest then
--                 line = rest .. line
--                 rest = nil
--             end
--             if lineend and lineend ~= "" then
--                 events.emit(event, line, ext_or_lexer)
--             else
--                 rest = line
--             end
--         end
--     end
--     ...
--         if rest then
--             events.emit(event,rest,ext_or_lexer)
--         end
--         events.emit(event, '> exit status: '..status)
--     ...
