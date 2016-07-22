if not modules then modules = { } end modules ['cldf-stp'] = {
    version   = 1.001,
    comment   = "companion to cldf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- limitation: input levels

-- context.stepwise (function()
--     ...
--     context.step(nil|...)
--     ...
--     context.step(nil|...)
--     ...
--     context.stepwise (function()
--         ...
--         context.step(nil|...)
--         ...
--     context.step(nil|...)
--     ...
--     end)
--     ...
--     context.step(nil|...)
--     ...
--     context.step(nil|...)
--     ...
-- end)

local create  = coroutine.create
local yield   = coroutine.yield
local resume  = coroutine.resume
local status  = coroutine.status

local stepper = nil
local stack   = { } -- will never be deep so no gc needed
local depth   = 0

local nextstep = function()
    if status(stepper) == "dead" then
        stepper      = stack[depth]
        depth        = depth - 1
        stack[depth] = false
    end
    resume(stepper)
end

interfaces.implement {
    name    = "step",
    actions = nextstep,
}

local ctx_resume = context.protectedcs.clf_step

function context.step(first,...)
    if first ~= nil then
        context(first,...)
    end
    ctx_resume()
    yield()
end

function context.stepwise(f)
    depth = depth + 1
    stack[depth] = stepper
    stepper = create(f)
    ctx_resume(stepper)
end
