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

local match, gsub, find, format = string.match, string.gsub, string.find, string.format
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
    --
    return true -- quits
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
-- interference. The main problem is that we don't hav emuch control over the
-- order. If we have much actions I can always come up with something.

local function process(buffer,filename,action)
    if not filename then
        filename = buffer.filename
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
    currentprocess = assert(spawn(command, pathpart, emit_output, emit_output, exit_output))
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

-- Tricky: we can't reset an event (because we need to know the function which is
-- local. So, a first solution injected a false into the table which will trigger
-- a break and then I found out that returning true has the same effect. Then I
-- found out that we can have our own events and next decided not to use them at
-- all.

-- events.connect(events.RUNNER_EVENT,   print_output, 1)

events.connect(events.CHAR_ADDED,     char_added,   1)
events.connect(events.KEYPRESS,       key_press,    1)
events.connect(events.DOUBLE_CLICK,   double_click, 1)

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
