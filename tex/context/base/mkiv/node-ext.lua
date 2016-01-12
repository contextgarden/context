if not modules then modules = { } end modules ['node-ext'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Serializing nodes can be handy for tracing. Also, saving and
loading node lists can come in handy as soon we are going to
use external applications to process node lists.</p>
--ldx]]--

function nodes.show(stack)
--  logs.writer(table.serialize(stack))
end

function nodes.save(stack,name) -- *.ltn : luatex node file
--  if name then
--      file.savedata(name,table.serialize(stack))
--  else
--      logs.writer(table.serialize(stack))
--  end
end

function nodes.load(name)
--  return file.loaddata(name)
--  -- todo
end
