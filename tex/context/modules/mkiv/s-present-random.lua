if not modules then modules = { } end modules ['present-random'] = {
    version   = 1.001,
    comment   = "companion to s-present-random.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- For the moment we keep the namespace steps because it can become some
-- shared module some day.

moduledata.steps = moduledata.steps or { }
local steps      = moduledata.steps

local locations = {
    'lefttop',
    'middletop',
    'righttop',
    'middleleft',
    'middle',
    'middleright',
    'leftbottom',
    'middlebottom',
    'rightbottom',
}

local done, current, previous, n

function steps.reset_locations()
    done, current, previous, n = table.tohash(locations,false), 0, 0, 0
end

function steps.next_location(loc)
    previous = current
    n = n + 1
    loc = loc and loc ~= "" and tonumber(loc)
    while true do
        current = loc or math.random(1,#locations)
        if not done[current] then
            done[current] = true
            break
        end
    end
end

function steps.current_location()
    context(locations[current] or "")
end

function steps.previous_location()
    context(locations[previous] or "")
end

function steps.current_n()
    context(current)
end

function steps.previous_n()
    context(previous)
end

function steps.step()
    context(n)
end

steps.reset_locations()
