if not modules then modules = { } end modules ['node-dir'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Taco Hoekwater and Hans Hagen",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[
<p>In the process of cleaning up the lua variant of the parbuilder
we ran into a couple of functions (translated c macros) that were
somewhat inefficient. More convenient is to use hashes although at
the c-end still macros are used. In the process directions.h was
adapted and now has the mappings as comments. This lua file is
based on that file.
]]--

local allocate = utilities.storage.allocate

local nodes = nodes

nodes.is_mirrored = allocate {
 -- TLT = false,
 -- TRT = false,
 -- LTL = false,
 -- RTT = false,
}

nodes.is_rotated = allocate {
 -- TLT = false,
 -- TRT = false,
 -- LTL = false,
    RTT = true, ["+RTT"] = true,
}

nodes.textdir_is_parallel = allocate {
    TLT = {
        TLT = true, ["+TLT"] = true,
        TRT = true, ["+TRT"] = true,
     -- LTL = false,
     -- RTT = false,
    },
    TRT= {
        TLT = true, ["+TLT"] = true,
        TRT = true, ["+TRT"] = true,
     -- LTL = false,
     -- RTT = false,
    },
    LTL = {
     -- TLT = false,
     -- TRT = false,
        LTL = true, ["+LTL"] = true,
        RTT = true, ["+RTT"] = true,
    },
    RTT = {
     -- TLT = false,
     -- TRT = false,
        LTL = true, ["+LTL"] = true,
        RTT = true, ["+RTT"] = true,
    }
}

nodes.pardir_is_parallel = allocate {
    TLT = {
        TLT = true, ["+TLT"] = true,
        TRT = true, ["+TRT"] = true,
     -- LTL = false,
     -- RTT = false,
    },
    TRT = {
        TLT = true, ["+TLT"] = true,
        TRT = true, ["+TRT"] = true,
     -- LTL = false,
     -- RTT = false,
    },
    LTL = {
     -- TLT = false,
     -- TRT = false,
        LTL = true, ["+LTL"] = true,
        RTT = true, ["+RTT"] = true,
    },
    RTT = {
     -- TLT = false,
     -- TRT = false,
        LTL = true, ["+LTL"] = true,
        RTT = true, ["+RTT"] = true,
    },
}

nodes.pardir_is_opposite = allocate {
    TLT = {
     -- TLT = false,
     -- TRT = false,
     -- LTL = false,
     -- RTT = false,
    },
    TRT = {
     -- TLT = false,
     -- TRT = false,
     -- LTL = false,
     -- RTT = false,
    },
    LTL = {
     -- TLT = false,
     -- TRT = false,
     -- LTL = false,
        RTT = true, ["+RTT"] = true,
    },
    RTT = {
     -- TLT = false,
     -- TRT = false,
        LTL = true, ["+LTL"] = true,
     -- RTT = false,
    },
}

nodes.textdir_is_opposite = allocate {
    TLT = {
     -- TLT = false,
        TRT = true, ["+TRT"] = true,
     -- LTL = false,
     -- RTT = false,
    },
    TRT= {
        TLT = true, ["+TLT"] = true,
     -- TRT = false,
     -- LTL = false,
     -- RTT = false,
    },
    LTL = {
     -- TLT = false,
     -- TRT = false,
     -- LTL = false,
     -- RTT = false,
    },
    RTT = {
     -- TLT = false,
     -- TRT = false,
     -- LTL = false,
     -- RTT = false,
    },
}

nodes.glyphdir_is_opposite = allocate {
    TLT = {
     -- TLT = false,
     -- TRT = false,
     -- LTL = false,
     -- RTT = false,
    },
    TRT= {
     -- TLT = false,
     -- TRT = false,
     -- LTL = false,
     -- RTT = false,
    },
    LTL = {
     -- TLT = false,
     -- TRT = false,
     -- LTL = false,
     -- RTT = false,
    },
    RTT = {
     -- TLT = false,
     -- TRT = false,
     -- LTL = false,
     -- RTT = false,
    },
}

nodes.pardir_is_equal = allocate {
    TLT = {
        TLT = true, ["+TLT"] = true,
        TRT = true, ["+TRT"] = true,
     -- LTL = false,
     -- RTT = false,
        },
    TRT= {
        TLT = true, ["+TLT"] = true,
        TRT = true, ["+TRT"] = true,
     -- LTL = false,
     -- RTT = false,
    },
    LTL= {
     -- TLT = false,
     -- TRT = false,
        LTL = true, ["+LTL"] = true,
     -- RTT = false,
    },
    RTT= {
     -- TLT = false,
     -- TRT = false,
     -- LTL = false,
        RTT = true, ["+RTT"] = true,
    },
}

nodes.textdir_is_equal = allocate {
    TLT = {
        TLT = true, ["+TLT"] = true,
     -- TRT = false,
     -- LTL = false,
     -- RTT = false,
    },
    TRT= {
     -- TLT = false,
        TRT = true, ["+TRT"] = true,
     -- LTL = false,
     -- RTT = false,
    },
    LTL = {
     -- TLT = false,
     -- TRT = false,
        LTL = true, ["+LTL"] = true,
        RTT = true, ["+RTT"] = true,
    },
    RTT = {
     -- TLT = false,
     -- TRT = false,
        LTL = true, ["+LTL"] = true,
        RTT = true, ["+RTT"] = true,
    },
}

nodes.glyphdir_is_equal = allocate {
    TLT = {
        TLT = true, ["+TLT"] = true,
        TRT = true, ["+TRT"] = true,
     -- LTL = false,
        RTT = true, ["+RTT"] = true,
    },
    TRT= {
        TLT = true, ["+TLT"] = true,
        TRT = true, ["+TRT"] = true,
     -- LTL = false,
        RTT = true, ["+RTT"] = true,
    },
    LTL = {
     -- TLT = false,
     -- TRT = false,
        LTL = true, ["+LTL"] = true,
     -- RTT = false,
    },
    RTT = {
        TLT = true, ["+TLT"] = true,
        TRT = true, ["+TRT"] = true,
     -- LTL = false,
        RTT = true, ["+RTT"] = true,
    },
}

nodes.partextdir_is_equal = allocate {
    TLT = {
     -- TLT = false,
     -- TRT = false,
        LTL = true, ["+LTL"] = true,
        RTT = true, ["+RTT"] = true,
    },
    TRT= {
     -- TLT = false,
     -- TRT = false,
        LTL = true, ["+LTL"] = true,
        RTT = true, ["+RTT"] = true,
    },
    LTL = {
        TLT = true, ["+TLT"] = true,
     -- TRT = false,
     -- LTL = false,
     -- RTT = false,
    },
    RTT = {
     -- TLT = false,
        TRT = true, ["+TRT"] = true,
     -- LTL = false,
     -- RTT = false,
    },
}

nodes.textdir_is_is = allocate {
    TLT = true, ["+TLT"] = true,
 -- TRT = false,
 -- LTL = false,
 -- RTT = false,
}

nodes.glyphdir_is_orthogonal = allocate {
    TLT = true, ["+TLT"] = true,
    TRT = true, ["+TRT"] = true,
    LTL = true, ["+LTL"] = true,
 -- RTT = false
}

nodes.dir_is_pop = allocate {
    ["-TRT"] = true,
    ["-TLT"] = true,
    ["-LTL"] = true,
    ["-RTT"] = true,
}

nodes.dir_negation = allocate {
    ["-TRT"] = "+TRT",
    ["-TLT"] = "+TLT",
    ["-LTL"] = "+LTL",
    ["-RTT"] = "+RTT",
    ["+TRT"] = "-TRT",
    ["+TLT"] = "-TLT",
    ["+LTL"] = "-LTL",
    ["+RTT"] = "-RTT",
}
