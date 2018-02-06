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
--         context.step(nil|...)
--         ...
--     end)
--     ...
--     context.step(nil|...)
--     ...
--     context.step(nil|...)
--     ...
-- end)

local context = context

local create  = coroutine.create
local yield   = coroutine.yield
local resume  = coroutine.resume
local status  = coroutine.status

local stepper = nil
local stack   = { } -- will never be deep so no gc needed
local depth   = 0

local function nextstep()
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

local ctx_resume = context.protected.cs.clf_step

local closeinput  = texio.closeinput -- experiment
local closeindeed = true
local stepsindeed = true

directives.register("context.steps.nosteps",function(v) stepsindeed = not v end)
directives.register("context.steps.noclose",function(v) closeindeed = not v end)

if closeinput then

    function context.step(first,...)
        if first ~= nil then
            context(first,...)
        end
if stepper then
        ctx_resume()
        yield()
        if closeindeed then
            closeinput()
        end
end
    end

else

    function context.step(first,...)
        if first ~= nil then
            context(first,...)
        end
if stepper then
        ctx_resume()
        yield()
end
    end

end

function context.stepwise(f)
    if stepsindeed then
        depth = depth + 1
        stack[depth] = stepper
        stepper = create(f)
     -- ctx_resume(stepper)
        ctx_resume()
    else
        f()
    end
end
