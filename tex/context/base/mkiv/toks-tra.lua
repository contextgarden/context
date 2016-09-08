if not modules then modules = { } end modules ['toks-ini'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this will become a module

local utfbyte, utfchar, utfvalues = utf.byte, utf.char, utf.values
local format, gsub = string.format, string.gsub
local tostring = tostring

local tokens   = tokens
local token    = token -- the built in one
local tex      = tex
local context  = context
local commands = commands

tokens.collectors     = tokens.collectors or { }
local collectors      = tokens.collectors

collectors.data       = collectors.data or { }
local collectordata   = collectors.data

collectors.registered = collectors.registered or { }
local registered      = collectors.registered

local report          = logs.reporter("tokens","collectors")

-- todo:
--
-- register : macros that will be expanded (only for demo-ing)
-- flush    : print back to tex
-- test     : fancy stuff

local get_next     = token.get_next
local create_token = token.create

function collectors.install(tag,end_cs)
    local data, d = { }, 0
    collectordata[tag] = data
    end_cs = gsub(end_cs,"^\\","")
    while true do
        local t = get_next()
        if t.csname == end_cs then
            context[end_cs]()
            return
        else
            d = d + 1
            data[d] = t
        end
    end
end

local simple = { letter = "letter", other_char = "other" }

function collectors.show(data)
    -- We no longer have methods as we only used (in demos) method a
    -- so there is no need to burden the core with this. We have a
    -- different table anyway.
    if type(data) == "string" then
        data = collectordata[data]
    end
    if not data then
        return
    end
    local ctx_NC       = context.NC
    local ctx_NR       = context.NR
    local ctx_bold     = context.bold
    local ctx_verbatim = context.verbatim
    context.starttabulate { "|Tl|Tc|Tl|" }
    ctx_NC() ctx_bold("cmd")
    ctx_NC() ctx_bold("meaning")
    ctx_NC() ctx_bold("properties")
    ctx_NC() ctx_NR()
    context.HL()
    for i=1,#data do
        local token   = data[i]
        local cmdname = token.cmdname
        local simple  = simple[cmdname]
        ctx_NC()
        ctx_verbatim(simple or cmdname)
        ctx_NC()
        ctx_verbatim(simple and utfchar(token.mode) or token.csname)
        ctx_NC()
        if token.active     then context("active ") end
        if token.expandable then context("expandable ") end
        if token.protected  then context("protected ") end
        ctx_NC()
        ctx_NR()
    end
    context.stoptabulate()
end

local function printlist(data)
    if data and #data > 0 then
        report("not supported (yet): printing back to tex")
    end
end

tokens.printlist = printlist -- will change to another namespace

function collectors.flush(tag)
    printlist(collectordata[tag])
end

function collectors.test(tag,handle)
    report("not supported (yet): testing")
end

function collectors.register(name)
    report("not supported (yet): registering")
end

-- -- old token code
--
--  -- 1 = command, 2 = modifier (char), 3 = controlsequence id
--
--  local create       = token.create
--  local csname_id    = token.csname_id
--  local command_id   = token.command_id
--  local command_name = token.command_name
--  local get_next     = token.get_next
--  local expand       = token.expand
--  local csname_name  = token.csname_name
--
--  local function printlist(data)
--      if data and #data > 0 then
--          callbacks.push('token_filter', function ()
--             callbacks.pop('token_filter') -- tricky but the nil assignment helps
--             return data
--          end)
--      end
--  end
--
--  tokens.printlist = printlist -- will change to another namespace
--
--  function collectors.flush(tag)
--      printlist(collectordata[tag])
--  end
--
--  function collectors.register(name)
--      registered[csname_id(name)] = name
--  end
--
--  local call   = command_id("call")
--  local letter = command_id("letter")
--  local other  = command_id("other_char")
--
--  function collectors.install(tag,end_cs)
--      local data, d = { }, 0
--      collectordata[tag] = data
--      end_cs = gsub(end_cs,"^\\","")
--      local endcs = csname_id(end_cs)
--      while true do
--          local t = get_next()
--          local a, b = t[1], t[3]
--          if b == endcs then
--              context[end_cs]()
--              return
--          elseif a == call and registered[b] then
--              expand()
--          else
--              d = d + 1
--              data[d] = t
--          end
--      end
--  end
--
--  function collectors.show(data)
--      -- We no longer have methods as we only used (in demos) method a
--      -- so there is no need to burden the core with this.
--      if type(data) == "string" then
--          data = collectordata[data]
--      end
--      if not data then
--          return
--      end
--      local ctx_NC       = context.NC
--      local ctx_NR       = context.NR
--      local ctx_bold     = context.bold
--      local ctx_verbatim = context.verbatim
--      context.starttabulate { "|T|Tr|cT|Tr|T|" }
--      ctx_NC() ctx_bold("cmd")
--      ctx_NC() ctx_bold("chr")
--      ctx_NC()
--      ctx_NC() ctx_bold("id")
--      ctx_NC() ctx_bold("name")
--      ctx_NC() ctx_NR()
--      context.HL()
--      for i=1,#data do
--          local token = data[i]
--          local cmd   = token[1]
--          local chr   = token[2]
--          local id    = token[3]
--          local name  = command_name(token)
--          ctx_NC()
--          ctx_verbatim(name)
--          ctx_NC()
--          if tonumber(chr) >= 0 then
--              ctx_verbatim(chr)
--          end
--          ctx_NC()
--          if cmd == letter or cmd == other then
--              ctx_verbatim(utfchar(chr))
--          end
--          ctx_NC()
--          if id > 0 then
--              ctx_verbatim(id)
--          end
--          ctx_NC()
--          if id > 0 then
--              ctx_verbatim(csname_name(token) or "")
--          end
--          ctx_NC() ctx_NR()
--      end
--      context.stoptabulate()
--  end
--
--  function collectors.test(tag,handle)
--      local t, w, tn, wn = { }, { }, 0, 0
--      handle = handle or collectors.defaultwords
--      local tagdata = collectordata[tag]
--      for k=1,#tagdata do
--          local v = tagdata[k]
--          if v[1] == letter then
--              wn = wn + 1
--              w[wn] = v[2]
--          else
--              if wn > 0 then
--                  handle(t,w)
--                  wn = 0
--              end
--              tn = tn + 1
--              t[tn] = v
--          end
--      end
--      if wn > 0 then
--          handle(t,w)
--      end
--      collectordata[tag] = t
--  end

-- Interfacing:

commands.collecttokens = collectors.install
commands.showtokens    = collectors.show
commands.flushtokens   = collectors.flush
commands.testtokens    = collectors.test
commands.registertoken = collectors.register

-- Redundant:

-- function collectors.test(tag)
--     printlist(collectordata[tag])
-- end

-- For old times sake:

collectors.dowithwords = collectors.test

-- This is only used in old articles ... will move to a module:

tokens.vbox   = create_token("vbox")
tokens.hbox   = create_token("hbox")
tokens.vtop   = create_token("vtop")
tokens.bgroup = create_token(utfbyte("{"),1)
tokens.egroup = create_token(utfbyte("}"),2)

tokens.letter = function(chr) return create_token(utfbyte(chr),11) end
tokens.other  = function(chr) return create_token(utfbyte(chr),12) end

tokens.letters = function(str)
    local t, n = { }, 0
    for chr in utfvalues(str) do
        n = n + 1
        t[n] = create_token(chr, 11)
    end
    return t
end

function collectors.defaultwords(t,str)
    if t then
        local n = #t
        n = n + 1 ; t[n] = tokens.bgroup
        n = n + 1 ; t[n] = create_token("red")
        for i=1,#str do
            n = n + 1 ; t[n] = tokens.other('*')
        end
        n = n + 1 ; t[n] = tokens.egroup
    end
end
