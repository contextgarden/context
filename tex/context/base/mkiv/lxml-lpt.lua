if not modules then modules = { } end modules ['lxml-lpt'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- e.ni is only valid after a filter run
-- todo: B/C/[get first match]

local concat, remove, insert = table.concat, table.remove, table.insert
local type, next, tonumber, tostring, setmetatable, load, select = type, next, tonumber, tostring, setmetatable, load, select
local format, upper, lower, gmatch, gsub, find, rep = string.format, string.upper, string.lower, string.gmatch, string.gsub, string.find, string.rep
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns

local setmetatableindex = table.setmetatableindex
local formatters = string.formatters -- no need (yet) as paths are cached anyway

-- beware, this is not xpath ... e.g. position is different (currently) and
-- we have reverse-sibling as reversed preceding sibling

--[[ldx--
<p>This module can be used stand alone but also inside <l n='mkiv'/> in
which case it hooks into the tracker code. Therefore we provide a few
functions that set the tracers. Here we overload a previously defined
function.</p>
<p>If I can get in the mood I will make a variant that is XSLT compliant
but I wonder if it makes sense.</P>
--ldx]]--

--[[ldx--
<p>Expecially the lpath code is experimental, we will support some of xpath, but
only things that make sense for us; as compensation it is possible to hook in your
own functions. Apart from preprocessing content for <l n='context'/> we also need
this module for process management, like handling <l n='ctx'/> and <l n='rlx'/>
files.</p>

<typing>
a/b/c /*/c
a/b/c/first() a/b/c/last() a/b/c/index(n) a/b/c/index(-n)
a/b/c/text() a/b/c/text(1) a/b/c/text(-1) a/b/c/text(n)
</typing>
--ldx]]--

local trace_lpath    = false
local trace_lparse   = false
local trace_lprofile = false
local report_lpath   = logs.reporter("xml","lpath")

if trackers then
    trackers.register("xml.path", function(v)
        trace_lpath  = v
    end)
    trackers.register("xml.parse", function(v)
        trace_lparse = v
    end)
    trackers.register("xml.profile", function(v)
        trace_lpath    = v
        trace_lparse   = v
        trace_lprofile = v
    end)
end

--[[ldx--
<p>We've now arrived at an interesting part: accessing the tree using a subset
of <l n='xpath'/> and since we're not compatible we call it <l n='lpath'/>. We
will explain more about its usage in other documents.</p>
--ldx]]--

local xml = xml

local lpathcalls  = 0  function xml.lpathcalls () return lpathcalls  end
local lpathcached = 0  function xml.lpathcached() return lpathcached end

xml.functions        = xml.functions or { } -- internal
local functions      = xml.functions

xml.expressions      = xml.expressions or { } -- in expressions
local expressions    = xml.expressions

xml.finalizers       = xml.finalizers or { } -- fast do-with ... (with return value other than collection)
local finalizers     = xml.finalizers

xml.specialhandler   = xml.specialhandler or { }
local specialhandler = xml.specialhandler

lpegpatterns.xml     = lpegpatterns.xml or { }
local xmlpatterns    = lpegpatterns.xml

finalizers.xml = finalizers.xml or { }
finalizers.tex = finalizers.tex or { }

local function fallback (t, name)
    local fn = finalizers[name]
    if fn then
        t[name] = fn
    else
        report_lpath("unknown sub finalizer %a",name)
        fn = function() end
    end
    return fn
end

setmetatableindex(finalizers.xml, fallback)
setmetatableindex(finalizers.tex, fallback)

xml.defaultprotocol = "xml"

-- as xsl does not follow xpath completely here we will also
-- be more liberal especially with regards to the use of | and
-- the rootpath:
--
-- test    : all 'test' under current
-- /test   : 'test' relative to current
-- a|b|c   : set of names
-- (a|b|c) : idem
-- !       : not
--
-- after all, we're not doing transformations but filtering. in
-- addition we provide filter functions (last bit)
--
-- todo: optimizer
--
-- .. : parent
-- *  : all kids
-- /  : anchor here
-- // : /**/
-- ** : all in between
--
-- so far we had (more practical as we don't transform)
--
-- {/test}   : kids 'test' under current node
-- {test}    : any kid with tag 'test'
-- {//test}  : same as above

-- evaluator (needs to be redone, for the moment copied)

-- todo: apply_axis(list,notable) and collection vs single

local apply_axis = { }

apply_axis['root'] = function(list)
    local collected = { }
    for l=1,#list do
        local ll = list[l]
        local rt = ll
        while ll do
            ll = ll.__p__
            if ll then
                rt = ll
            end
        end
        collected[l] = rt
    end
    return collected
end

apply_axis['self'] = function(list)
 -- local collected = { }
 -- for l=1,#list do
 --     collected[l] = list[l]
 -- end
 -- return collected
    return list
end

apply_axis['child'] = function(list)
    local collected = { }
    local c         = 0
    for l=1,#list do
        local ll = list[l]
        local dt = ll.dt
        if dt then -- weird that this is needed
            local n = #dt
            if n == 0 then
                ll.en = 0
            elseif n == 1 then
                local dk = dt[1]
                if dk.tg then
                    c = c + 1
                    collected[c] = dk
                    dk.ni = 1 -- refresh
                    dk.ei = 1
                    ll.en = 1
                end
            else
                local en = 0
                for k=1,#dt do
                    local dk = dt[k]
                    if dk.tg then
                        c = c + 1
                        en = en + 1
                        collected[c] = dk
                        dk.ni = k -- refresh
                        dk.ei = en
                    end
                end
                ll.en = en
            end
        end
    end
    return collected
end

local function collect(list,collected,c)
    local dt = list.dt
    if dt then
        local n = #dt
        if n == 0 then
            list.en = 0
        elseif n == 1 then
            local dk = dt[1]
            if dk.tg then
                c = c + 1
                collected[c] = dk
                dk.ni = 1 -- refresh
                dk.ei = 1
                c = collect(dk,collected,c)
                list.en = 1
            else
                list.en = 0
            end
        else
            local en = 0
            for k=1,n do
                local dk = dt[k]
                if dk.tg then
                    c = c + 1
                    en = en + 1
                    collected[c] = dk
                    dk.ni = k -- refresh
                    dk.ei = en
                    c = collect(dk,collected,c)
                end
            end
            list.en = en
        end
    end
    return c
end

apply_axis['descendant'] = function(list)
    local collected = { }
    local c = 0
    for l=1,#list do
        c = collect(list[l],collected,c)
    end
    return collected
end

local function collect(list,collected,c)
    local dt = list.dt
    if dt then
        local n = #dt
        if n == 0 then
            list.en = 0
        elseif n == 1 then
            local dk = dt[1]
            if dk.tg then
                c = c + 1
                collected[c] = dk
                dk.ni = 1 -- refresh
                dk.ei = 1
                c = collect(dk,collected,c)
                list.en = 1
            end
        else
            local en = 0
            for k=1,#dt do
                local dk = dt[k]
                if dk.tg then
                    c = c + 1
                    en = en + 1
                    collected[c] = dk
                    dk.ni = k -- refresh
                    dk.ei = en
                    c = collect(dk,collected,c)
                end
            end
            list.en = en
        end
    end
    return c
end

apply_axis['descendant-or-self'] = function(list)
    local collected = { }
    local c = 0
    for l=1,#list do
        local ll = list[l]
        if ll.special ~= true then -- catch double root
            c = c + 1
            collected[c] = ll
        end
        c = collect(ll,collected,c)
    end
    return collected
end

apply_axis['ancestor'] = function(list)
    local collected = { }
    local c = 0
    for l=1,#list do
        local ll = list[l]
        while ll do
            ll = ll.__p__
            if ll then
                c = c + 1
                collected[c] = ll
            end
        end
    end
    return collected
end

apply_axis['ancestor-or-self'] = function(list)
    local collected = { }
    local c = 0
    for l=1,#list do
        local ll = list[l]
        c = c + 1
        collected[c] = ll
        while ll do
            ll = ll.__p__
            if ll then
                c = c + 1
                collected[c] = ll
            end
        end
    end
    return collected
end

apply_axis['parent'] = function(list)
    local collected = { }
    local c = 0
    for l=1,#list do
        local pl = list[l].__p__
        if pl then
            c = c + 1
            collected[c] = pl
        end
    end
    return collected
end

apply_axis['attribute'] = function(list)
    return { }
end

apply_axis['namespace'] = function(list)
    return { }
end

apply_axis['following'] = function(list) -- incomplete
 -- local collected, c = { }, 0
 -- for l=1,#list do
 --     local ll = list[l]
 --     local p = ll.__p__
 --     local d = p.dt
 --     for i=ll.ni+1,#d do
 --         local di = d[i]
 --         if type(di) == "table" then
 --             c = c + 1
 --             collected[c] = di
 --             break
 --         end
 --     end
 -- end
 -- return collected
    return { }
end

apply_axis['preceding'] = function(list) -- incomplete
 -- local collected = { }
 -- local c = 0
 -- for l=1,#list do
 --     local ll = list[l]
 --     local p = ll.__p__
 --     local d = p.dt
 --     for i=ll.ni-1,1,-1 do
 --         local di = d[i]
 --         if type(di) == "table" then
 --             c = c + 1
 --             collected[c] = di
 --             break
 --         end
 --     end
 -- end
 -- return collected
    return { }
end

apply_axis['following-sibling'] = function(list)
    local collected = { }
    local c = 0
    for l=1,#list do
        local ll = list[l]
        local p = ll.__p__
        local d = p.dt
        for i=ll.ni+1,#d do
            local di = d[i]
            if type(di) == "table" then
                c = c + 1
                collected[c] = di
            end
        end
    end
    return collected
end

apply_axis['preceding-sibling'] = function(list)
    local collected = { }
    local c = 0
    for l=1,#list do
        local ll = list[l]
        local p = ll.__p__
        local d = p.dt
        for i=1,ll.ni-1 do
            local di = d[i]
            if type(di) == "table" then
                c = c + 1
                collected[c] = di
            end
        end
    end
    return collected
end

apply_axis['reverse-sibling'] = function(list) -- reverse preceding
    local collected = { }
    local c = 0
    for l=1,#list do
        local ll = list[l]
        local p = ll.__p__
        local d = p.dt
        for i=ll.ni-1,1,-1 do
            local di = d[i]
            if type(di) == "table" then
                c = c + 1
                collected[c] = di
            end
        end
    end
    return collected
end

apply_axis['auto-descendant-or-self'] = apply_axis['descendant-or-self']
apply_axis['auto-descendant']         = apply_axis['descendant']
apply_axis['auto-child']              = apply_axis['child']
apply_axis['auto-self']               = apply_axis['self']
apply_axis['initial-child']           = apply_axis['child']

local function apply_nodes(list,directive,nodes)
    -- todo: nodes[1] etc ... negated node name in set ... when needed
    -- ... currently ignored
    local maxn = #nodes
    if maxn == 3 then --optimized loop
        local nns = nodes[2]
        local ntg = nodes[3]
        if not nns and not ntg then -- wildcard
            if directive then
                return list
            else
                return { }
            end
        else
            local collected = { }
            local c = 0
            local m = 0
            local p = nil
            if not nns then -- only check tag
                for l=1,#list do
                    local ll  = list[l]
                    local ltg = ll.tg
                    if ltg then
                        if directive then
                            if ntg == ltg then
                                local llp = ll.__p__ ; if llp ~= p then p = llp ; m = 1 else m = m + 1 end
                                c = c + 1
                                collected[c] = ll
                                ll.mi = m
                            end
                        elseif ntg ~= ltg then
                            local llp = ll.__p__ ; if llp ~= p then p = llp ; m = 1 else m = m + 1 end
                            c = c + 1
                            collected[c] = ll
                            ll.mi = m
                        end
                    end
                end
            elseif not ntg then -- only check namespace
                for l=1,#list do
                    local ll  = list[l]
                    local lns = ll.rn or ll.ns
                    if lns then
                        if directive then
                            if lns == nns then
                                local llp = ll.__p__ ; if llp ~= p then p = llp ; m = 1 else m = m + 1 end
                                c = c + 1
                                collected[c] = ll
                                ll.mi = m
                            end
                        elseif lns ~= nns then
                            local llp = ll.__p__ ; if llp ~= p then p = llp ; m = 1 else m = m + 1 end
                            c = c + 1
                            collected[c] = ll
                            ll.mi = m
                        end
                    end
                end
            else -- check both
                for l=1,#list do
                    local ll = list[l]
                    local ltg = ll.tg
                    if ltg then
                        local lns = ll.rn or ll.ns
                        local ok = ltg == ntg and lns == nns
                        if directive then
                            if ok then
                                local llp = ll.__p__ ; if llp ~= p then p = llp ; m = 1 else m = m + 1 end
                                c = c + 1
                                collected[c] = ll
                                ll.mi = m
                            end
                        elseif not ok then
                            local llp = ll.__p__ ; if llp ~= p then p = llp ; m = 1 else m = m + 1 end
                            c = c + 1
                            collected[c] = ll
                            ll.mi = m
                        end
                    end
                end
            end
            return collected
        end
    else
        local collected = { }
        local c = 0
        local m = 0
        local p = nil
        for l=1,#list do
            local ll  = list[l]
            local ltg = ll.tg
            if ltg then
                local lns = ll.rn or ll.ns
                local ok  = false
                for n=1,maxn,3 do
                    local nns = nodes[n+1]
                    local ntg = nodes[n+2]
                    ok = (not ntg or ltg == ntg) and (not nns or lns == nns)
                    if ok then
                        break
                    end
                end
                if directive then
                    if ok then
                        local llp = ll.__p__ ; if llp ~= p then p = llp ; m = 1 else m = m + 1 end
                        c = c + 1
                        collected[c] = ll
                        ll.mi = m
                    end
                elseif not ok then
                    local llp = ll.__p__ ; if llp ~= p then p = llp ; m = 1 else m = m + 1 end
                    c = c + 1
                    collected[c] = ll
                    ll.mi = m
                end
            end
        end
        return collected
    end
end

local quit_expression = false

local function apply_expression(list,expression,order)
    local collected = { }
    local c = 0
    quit_expression = false
    for l=1,#list do
        local ll = list[l]
        if expression(list,ll,l,order) then -- nasty, order alleen valid als n=1
            c = c + 1
            collected[c] = ll
        end
        if quit_expression then
            break
        end
    end
    return collected
end

local function apply_selector(list,specification)
    if xml.applyselector then
        apply_selector = xml.applyselector
        return apply_selector(list,specification)
    else
        return list
    end
end

-- this one can be made faster but there are not that many conversions so it doesn't
-- really pay of

local P, V, C, Cs, Cc, Ct, R, S, Cg, Cb = lpeg.P, lpeg.V, lpeg.C, lpeg.Cs, lpeg.Cc, lpeg.Ct, lpeg.R, lpeg.S, lpeg.Cg, lpeg.Cb

local spaces     = S(" \n\r\t\f")^0
local lp_space   = S(" \n\r\t\f")
local lp_any     = P(1)
local lp_noequal = P("!=") / "~=" + P("<=") + P(">=") + P("==")
local lp_doequal = P("=")  / "=="
local lp_or      = P("|")  / " or "
local lp_and     = P("&")  / " and "

local builtin = {
    text         = "(ll.dt[1] or '')", -- fragile
    content      = "ll.dt",
    name         = "((ll.ns~='' and ll.ns..':'..ll.tg) or ll.tg)",
    tag          = "ll.tg",
    position     = "l", -- is element in finalizer
    firstindex   = "1",
    firstelement = "1",
    first        = "1",
    lastindex    = "(#ll.__p__.dt or 1)",
    lastelement  = "(ll.__p__.en or 1)",
    last         = "#list",
    list         = "list",
    self         = "ll",
    rootposition = "order",
    order        = "order",
    element      = "(ll.ei or 1)",
    index        = "(ll.ni or 1)",
    match        = "(ll.mi or 1)",
    namespace    = "ll.ns",
    ns           = "ll.ns",

}

local lp_builtin   = lpeg.utfchartabletopattern(builtin)/builtin * ((spaces * P("(") * spaces * P(")"))/"")

-- for the moment we keep namespaces with attributes

local lp_attribute = (P("@") + P("attribute::")) / "" * Cc("(ll.at and ll.at['") * ((R("az","AZ") + S("-_:"))^1) * Cc("'])")

----- lp_fastpos_p = (P("+")^0 * R("09")^1 * P(-1)) / function(s) return "l==" .. s end
----- lp_fastpos_n = (P("-")   * R("09")^1 * P(-1)) / function(s) return "(" .. s .. "<0 and (#list+".. s .. "==l))" end

local lp_fastpos_p = P("+")^0 * R("09")^1 * P(-1) / "l==%0"
local lp_fastpos_n = P("-")   * R("09")^1 * P(-1) / "(%0<0 and (#list+%0==l))"
local lp_fastpos   = lp_fastpos_n + lp_fastpos_p

local lp_reserved  = C("and") + C("or") + C("not") + C("div") + C("mod") + C("true") + C("false")

-- local lp_lua_function = C(R("az","AZ","__")^1 * (P(".") * R("az","AZ","__")^1)^1) * ("(") / function(t) -- todo: better . handling
--     return t .. "("
-- end

-- local lp_lua_function = (R("az","AZ","__")^1 * (P(".") * R("az","AZ","__")^1)^1) * ("(") / "%0("
local lp_lua_function = Cs((R("az","AZ","__")^1 * (P(".") * R("az","AZ","__")^1)^1) * ("(")) / "%0"

local lp_function  = C(R("az","AZ","__")^1) * P("(") / function(t) -- todo: better . handling
    if expressions[t] then
        return "expr." .. t .. "("
    else
        return "expr.error("
    end
end

local lparent  = P("(")
local rparent  = P(")")
local noparent = 1 - (lparent+rparent)
local nested   = P{lparent * (noparent + V(1))^0 * rparent}
local value    = P(lparent * C((noparent + nested)^0) * rparent) -- P{"("*C(((1-S("()"))+V(1))^0)*")"}

local lp_child   = Cc("expr.child(ll,'") * R("az","AZ") * R("az","AZ","--","__")^0 * Cc("')")
local lp_number  = S("+-") * R("09")^1
local lp_string  = Cc("'") * R("az","AZ","--","__")^1 * Cc("'")
local lp_content = (P("'") * (1-P("'"))^0 * P("'") + P('"') * (1-P('"'))^0 * P('"'))

local cleaner

local lp_special = (C(P("name")+P("text")+P("tag")+P("count")+P("child"))) * value / function(t,s)
    if expressions[t] then
        s = s and s ~= "" and lpegmatch(cleaner,s)
        if s and s ~= "" then
            return "expr." .. t .. "(ll," .. s ..")"
        else
            return "expr." .. t .. "(ll)"
        end
    else
        return "expr.error(" .. t .. ")"
    end
end

local content =
    lp_builtin +
    lp_attribute +
    lp_special +
    lp_noequal + lp_doequal +
    lp_or + lp_and +
    lp_reserved +
    lp_lua_function + lp_function +
    lp_content + -- too fragile
    lp_child +
    lp_any

local converter = Cs (
    lp_fastpos + (P { lparent * (V(1))^0 * rparent + content } )^0
)

cleaner = Cs ( (
 -- lp_fastpos +
    lp_reserved +
    lp_number +
    lp_string +
1 )^1 )

local template_e = [[
    local expr = xml.expressions
    return function(list,ll,l,order)
        return %s
    end
]]

local template_f_y = [[
    local finalizer = xml.finalizers['%s']['%s']
    return function(collection)
        return finalizer(collection,%s)
    end
]]

local template_f_n = [[
    return xml.finalizers['%s']['%s']
]]

--

local register_last_match              = { kind = "axis", axis = "last-match"              } -- , apply = apply_axis["self"]               }
local register_self                    = { kind = "axis", axis = "self"                    } -- , apply = apply_axis["self"]               }
local register_parent                  = { kind = "axis", axis = "parent"                  } -- , apply = apply_axis["parent"]             }
local register_descendant              = { kind = "axis", axis = "descendant"              } -- , apply = apply_axis["descendant"]         }
local register_child                   = { kind = "axis", axis = "child"                   } -- , apply = apply_axis["child"]              }
local register_descendant_or_self      = { kind = "axis", axis = "descendant-or-self"      } -- , apply = apply_axis["descendant-or-self"] }
local register_root                    = { kind = "axis", axis = "root"                    } -- , apply = apply_axis["root"]               }
local register_ancestor                = { kind = "axis", axis = "ancestor"                } -- , apply = apply_axis["ancestor"]           }
local register_ancestor_or_self        = { kind = "axis", axis = "ancestor-or-self"        } -- , apply = apply_axis["ancestor-or-self"]   }
local register_attribute               = { kind = "axis", axis = "attribute"               } -- , apply = apply_axis["attribute"]          }
local register_namespace               = { kind = "axis", axis = "namespace"               } -- , apply = apply_axis["namespace"]          }
local register_following               = { kind = "axis", axis = "following"               } -- , apply = apply_axis["following"]          }
local register_following_sibling       = { kind = "axis", axis = "following-sibling"       } -- , apply = apply_axis["following-sibling"]  }
local register_preceding               = { kind = "axis", axis = "preceding"               } -- , apply = apply_axis["preceding"]          }
local register_preceding_sibling       = { kind = "axis", axis = "preceding-sibling"       } -- , apply = apply_axis["preceding-sibling"]  }
local register_reverse_sibling         = { kind = "axis", axis = "reverse-sibling"         } -- , apply = apply_axis["reverse-sibling"]    }

local register_auto_descendant_or_self = { kind = "axis", axis = "auto-descendant-or-self" } -- , apply = apply_axis["auto-descendant-or-self"] }
local register_auto_descendant         = { kind = "axis", axis = "auto-descendant"         } -- , apply = apply_axis["auto-descendant"] }
local register_auto_self               = { kind = "axis", axis = "auto-self"               } -- , apply = apply_axis["auto-self"] }
local register_auto_child              = { kind = "axis", axis = "auto-child"              } -- , apply = apply_axis["auto-child"] }

local register_initial_child           = { kind = "axis", axis = "initial-child"           } -- , apply = apply_axis["initial-child"] }

local register_all_nodes               = { kind = "nodes", nodetest = true, nodes = { true, false, false } }

local skip = { }

local function errorrunner_e(str,cnv)
    if not skip[str] then
        report_lpath("error in expression: %s => %s",str,cnv)
        skip[str] = cnv or str
    end
    return false
end

local function errorrunner_f(str,arg)
    report_lpath("error in finalizer: %s(%s)",str,arg or "")
    return false
end

local function register_nodes(nodetest,nodes)
    return { kind = "nodes", nodetest = nodetest, nodes = nodes }
end

local function register_selector(specification)
    return { kind = "selector", specification = specification }
end

local function register_expression(expression)
    local converted = lpegmatch(converter,expression)
    local wrapped   = format(template_e,converted)
    local runner = load(wrapped)
 -- print(wrapped)
    runner = (runner and runner()) or function() errorrunner_e(expression,converted) end
    return { kind = "expression", expression = expression, converted = converted, evaluator = runner }
end

local function register_finalizer(protocol,name,arguments)
    local runner
    if arguments and arguments ~= "" then
        runner = load(format(template_f_y,protocol or xml.defaultprotocol,name,arguments))
    else
        runner = load(format(template_f_n,protocol or xml.defaultprotocol,name))
    end
    runner = (runner and runner()) or function() errorrunner_f(name,arguments) end
    return { kind = "finalizer", name = name, arguments = arguments, finalizer = runner }
end

local expression = P { "ex",
    ex = "[" * C((V("sq") + V("dq") + (1 - S("[]")) + V("ex"))^0) * "]",
    sq = "'" * (1 - S("'"))^0 * "'",
    dq = '"' * (1 - S('"'))^0 * '"',
}

local arguments = P { "ar",
    ar = "(" * Cs((V("sq") + V("dq") + V("nq") + P(1-P(")")))^0) * ")",
    nq = ((1 - S("),'\""))^1) / function(s) return format("%q",s) end,
    sq = P("'") * (1 - P("'"))^0 * P("'"),
    dq = P('"') * (1 - P('"'))^0 * P('"'),
}

-- todo: better arg parser

local function register_error(str)
    return { kind = "error", error = format("unparsed: %s",str) }
end

-- there is a difference in * and /*/ and so we need to catch a few special cases

local special_1 = P("*")  * Cc(register_auto_descendant) * Cc(register_all_nodes) -- last one not needed
local special_2 = P("/")  * Cc(register_auto_self)
local special_3 = P("")   * Cc(register_auto_self)

local no_nextcolon   = P(-1) + #(1-P(":")) -- newer lpeg needs the P(-1)
local no_nextlparent = P(-1) + #(1-P("(")) -- newer lpeg needs the P(-1)

local pathparser = Ct { "patterns", -- can be made a bit faster by moving some patterns outside

    patterns             = spaces * V("protocol") * spaces * (
                              ( V("special") * spaces * P(-1)                                                         ) +
                              ( V("initial") * spaces * V("step") * spaces * (P("/") * spaces * V("step") * spaces)^0 )
                           ),

    protocol             = Cg(V("letters"),"protocol") * P("://") + Cg(Cc(nil),"protocol"),

 -- the / is needed for // as descendant or self is somewhat special
 --
 -- step                 = (V("shortcuts") + V("axis") * spaces * V("nodes")^0 + V("error")) * spaces * V("expressions")^0 * spaces * V("finalizer")^0,
    step                 = ((V("shortcuts") + V("selector") + P("/") + V("axis")) * spaces * V("nodes")^0 + V("error")) * spaces * V("expressions")^0 * spaces * V("finalizer")^0,

    axis                 = V("last_match")
                         + V("descendant")
                         + V("child")
                         + V("parent")
                         + V("self")
                         + V("root")
                         + V("ancestor")
                         + V("descendant_or_self")
                         + V("following_sibling")
                         + V("following")
                         + V("reverse_sibling")
                         + V("preceding_sibling")
                         + V("preceding")
                         + V("ancestor_or_self")
                         + #(1-P(-1)) * Cc(register_auto_child),

    special              = special_1
                         + special_2
                         + special_3,

    initial              = (P("/") * spaces * Cc(register_initial_child))^-1,

    error                = (P(1)^1) / register_error,

    shortcuts_a          = V("s_descendant_or_self")
                         + V("s_descendant")
                         + V("s_child")
                         + V("s_parent")
                         + V("s_self")
                         + V("s_root")
                         + V("s_ancestor")
                         + V("s_lastmatch"),

    shortcuts            = V("shortcuts_a") * (spaces * "/" * spaces * V("shortcuts_a"))^0,

    s_descendant_or_self = (P("***/") + P("/"))  * Cc(register_descendant_or_self), --- *** is a bonus
    s_descendant         = P("**")               * Cc(register_descendant),
    s_child              = P("*") * no_nextcolon * Cc(register_child),
    s_parent             = P("..")               * Cc(register_parent),
    s_self               = P("." )               * Cc(register_self),
    s_root               = P("^^")               * Cc(register_root),
    s_ancestor           = P("^")                * Cc(register_ancestor),
    s_lastmatch          = P("=")                * Cc(register_last_match),

    -- we can speed this up when needed but we cache anyway so ...

    descendant           = P("descendant::")         * Cc(register_descendant),
    child                = P("child::")              * Cc(register_child),
    parent               = P("parent::")             * Cc(register_parent),
    self                 = P("self::")               * Cc(register_self),
    root                 = P('root::')               * Cc(register_root),
    ancestor             = P('ancestor::')           * Cc(register_ancestor),
    descendant_or_self   = P('descendant-or-self::') * Cc(register_descendant_or_self),
    ancestor_or_self     = P('ancestor-or-self::')   * Cc(register_ancestor_or_self),
 -- attribute            = P('attribute::')          * Cc(register_attribute),
 -- namespace            = P('namespace::')          * Cc(register_namespace),
    following            = P('following::')          * Cc(register_following),
    following_sibling    = P('following-sibling::')  * Cc(register_following_sibling),
    preceding            = P('preceding::')          * Cc(register_preceding),
    preceding_sibling    = P('preceding-sibling::')  * Cc(register_preceding_sibling),
    reverse_sibling      = P('reverse-sibling::')    * Cc(register_reverse_sibling),
    last_match           = P('last-match::')         * Cc(register_last_match),

    selector             = P("{") * C((1-P("}"))^1) * P("}") / register_selector,

    nodes                = (V("nodefunction") * spaces * P("(") * V("nodeset") * P(")") + V("nodetest") * V("nodeset")) / register_nodes,

    expressions          = expression / register_expression,

    letters              = R("az")^1,
    name                 = (1-S("/[]()|:*!"))^1, -- make inline
    negate               = P("!") * Cc(false),

    nodefunction         = V("negate") + P("not") * Cc(false) + Cc(true),
    nodetest             = V("negate") + Cc(true),
    nodename             = (V("negate") + Cc(true)) * spaces * ((V("wildnodename") * P(":") * V("wildnodename")) + (Cc(false) * V("wildnodename"))),
    wildnodename         = (C(V("name")) + P("*") * Cc(false)) * no_nextlparent,
    nodeset              = spaces * Ct(V("nodename") * (spaces * P("|") * spaces * V("nodename"))^0) * spaces,

    finalizer            = (Cb("protocol") * P("/")^-1 * C(V("name")) * arguments * P(-1)) / register_finalizer,

}

xmlpatterns.pathparser = pathparser

local cache = { }

local function nodesettostring(set,nodetest)
    local t = { }
    for i=1,#set,3 do
        local directive, ns, tg = set[i], set[i+1], set[i+2]
        if not ns or ns == "" then ns = "*" end
        if not tg or tg == "" then tg = "*" end
        tg = (tg == "@rt@" and "[root]") or format("%s:%s",ns,tg)
        t[#t+1] = (directive and tg) or format("not(%s)",tg)
    end
    if nodetest == false then
        return format("not(%s)",concat(t,"|"))
    else
        return concat(t,"|")
    end
end

local function tagstostring(list)
    if #list == 0 then
        return "no elements"
    else
        local t = { }
        for i=1, #list do
            local li = list[i]
            local ns = li.ns
            local tg = li.tg
            if not ns or ns == "" then ns = "*" end
            if not tg or tg == "" then tg = "*" end
            t[i] = (tg == "@rt@" and "[root]") or format("%s:%s",ns,tg)
        end
        return concat(t," ")
    end
end

xml.nodesettostring = nodesettostring

local lpath -- we have a harmless kind of circular reference

local function lshow(parsed)
    if type(parsed) == "string" then
        parsed = lpath(parsed)
    end
    report_lpath("%s://%s => %s",parsed.protocol or xml.defaultprotocol,parsed.pattern,
        table.serialize(parsed,false))
end

xml.lshow = lshow

local function add_comment(p,str)
    local pc = p.comment
    if not pc then
        p.comment = { str }
    else
        pc[#pc+1] = str
    end
end

lpath = function (pattern) -- the gain of caching is rather minimal
    lpathcalls = lpathcalls + 1
    if type(pattern) == "table" then
        return pattern
    else
        local parsed = cache[pattern]
        if parsed then
            lpathcached = lpathcached + 1
        else
            parsed = lpegmatch(pathparser,pattern)
            if parsed then
                parsed.pattern = pattern
                local np = #parsed
                if np == 0 then
                    parsed = { pattern = pattern, register_self, state = "parsing error" }
                    report_lpath("parsing error in pattern: %s",pattern)
                    lshow(parsed)
                else
                    -- we could have done this with a more complex parser but this
                    -- is cleaner
                    local pi = parsed[1]
                    if pi.axis == "auto-child" then
                        if false then
                            add_comment(parsed, "auto-child replaced by auto-descendant-or-self")
                            parsed[1] = register_auto_descendant_or_self
                        else
                            add_comment(parsed, "auto-child replaced by auto-descendant")
                            parsed[1] = register_auto_descendant
                        end
                    elseif pi.axis == "initial-child" and np > 1 and parsed[2].axis then
                        add_comment(parsed, "initial-child removed") -- we could also make it a auto-self
                        remove(parsed,1)
                    end
                    local np = #parsed -- can have changed
                    if np > 1 then
                        local pnp = parsed[np]
                        if pnp.kind == "nodes" and pnp.nodetest == true then
                            local nodes = pnp.nodes
                            if nodes[1] == true and nodes[2] == false and nodes[3] == false then
                                add_comment(parsed, "redundant final wildcard filter removed")
                                remove(parsed,np)
                            end
                        end
                    end
                end
            else
                parsed = { pattern = pattern }
            end
            cache[pattern] = parsed
            if trace_lparse and not trace_lprofile then
                lshow(parsed)
            end
        end
        return parsed
    end
end

xml.lpath = lpath

-- we can move all calls inline and then merge the trace back
-- technically we can combine axis and the next nodes which is
-- what we did before but this a bit cleaner (but slower too)
-- but interesting is that it's not that much faster when we
-- go inline
--
-- beware: we need to return a collection even when we filter
-- else the (simple) cache gets messed up

-- caching found lookups saves not that much (max .1 sec on a 8 sec run)
-- and it also messes up finalizers

-- watch out: when there is a finalizer, it's always called as there
-- can be cases that a finalizer returns (or does) something in case
-- there is no match; an example of this is count()

do

    local profiled  = { }
    xml.profiled    = profiled
    local lastmatch = nil  -- we remember the last one .. drawback: no collection till new collect
    local keepmatch = nil  -- we remember the last one .. drawback: no collection till new collect

    if directives then
        directives.register("xml.path.keeplastmatch",function(v)
            keepmatch = v
            lastmatch = nil
        end)
    end

    apply_axis["last-match"] = function()
        return lastmatch or { }
    end

    local function profiled_apply(list,parsed,nofparsed,order)
        local p = profiled[parsed.pattern]
        if p then
            p.tested = p.tested + 1
        else
            p = { tested = 1, matched = 0, finalized = 0 }
            profiled[parsed.pattern] = p
        end
        local collected = list
        for i=1,nofparsed do
            local pi = parsed[i]
            local kind = pi.kind
            if kind == "axis" then
                collected = apply_axis[pi.axis](collected)
            elseif kind == "nodes" then
                collected = apply_nodes(collected,pi.nodetest,pi.nodes)
            elseif kind == "expression" then
                collected = apply_expression(collected,pi.evaluator,order)
            elseif kind == "selector" then
                collected = apply_selector(collected,pi.specification)
            elseif kind == "finalizer" then
                collected = pi.finalizer(collected) -- no check on # here
                p.matched = p.matched + 1
                p.finalized = p.finalized + 1
                return collected
            end
            if not collected or #collected == 0 then
                local pn = i < nofparsed and parsed[nofparsed]
                if pn and pn.kind == "finalizer" then
                    collected = pn.finalizer(collected) -- collected can be nil
                    p.finalized = p.finalized + 1
                    return collected
                end
                return nil
            end
        end
        if collected then
            p.matched = p.matched + 1
        end
        return collected
    end

    local function traced_apply(list,parsed,nofparsed,order)
        if trace_lparse then
            lshow(parsed)
        end
        report_lpath("collecting: %s",parsed.pattern)
        report_lpath("root tags : %s",tagstostring(list))
        report_lpath("order     : %s",order or "unset")
        local collected = list
        for i=1,nofparsed do
            local pi = parsed[i]
            local kind = pi.kind
            if kind == "axis" then
                collected = apply_axis[pi.axis](collected)
                report_lpath("% 10i : ax : %s",(collected and #collected) or 0,pi.axis)
            elseif kind == "nodes" then
                collected = apply_nodes(collected,pi.nodetest,pi.nodes)
                report_lpath("% 10i : ns : %s",(collected and #collected) or 0,nodesettostring(pi.nodes,pi.nodetest))
            elseif kind == "expression" then
                collected = apply_expression(collected,pi.evaluator,order)
                report_lpath("% 10i : ex : %s -> %s",(collected and #collected) or 0,pi.expression,pi.converted)
            elseif kind == "selector" then
                collected = apply_selector(collected,pi.specification)
                report_lpath("% 10i : se : %s ",(collected and #collected) or 0,pi.specification)
            elseif kind == "finalizer" then
                collected = pi.finalizer(collected)
                report_lpath("% 10i : fi : %s : %s(%s)",(type(collected) == "table" and #collected) or 0,parsed.protocol or xml.defaultprotocol,pi.name,pi.arguments or "")
                return collected
            end
            if not collected or #collected == 0 then
                local pn = i < nofparsed and parsed[nofparsed]
                if pn and pn.kind == "finalizer" then
                    collected = pn.finalizer(collected)
                    report_lpath("% 10i : fi : %s : %s(%s)",(type(collected) == "table" and #collected) or 0,parsed.protocol or xml.defaultprotocol,pn.name,pn.arguments or "")
                    return collected
                end
                return nil
            end
        end
        return collected
    end

    local function normal_apply(list,parsed,nofparsed,order)
        local collected = list
        for i=1,nofparsed do
            local pi = parsed[i]
            local kind = pi.kind
            if kind == "axis" then
                local axis = pi.axis
                if axis ~= "self" then
                    collected = apply_axis[axis](collected)
                end
            elseif kind == "nodes" then
                collected = apply_nodes(collected,pi.nodetest,pi.nodes)
            elseif kind == "expression" then
                collected = apply_expression(collected,pi.evaluator,order)
            elseif kind == "selector" then
                collected = apply_selector(collected,pi.specification)
            elseif kind == "finalizer" then
                return pi.finalizer(collected)
            end
            if not collected or #collected == 0 then
                local pf = i < nofparsed and parsed[nofparsed].finalizer
                if pf then
                    return pf(collected) -- can be anything
                end
                return nil
            end
        end
        return collected
    end

    local apply = normal_apply

    if trackers then
     -- local function check()
     --     if trace_lprofile or then
     --         apply = profiled_apply
     --     elseif trace_lpath then
     --         apply = traced_apply
     --     else
     --         apply = normal_apply
     --     end
     -- end
     -- trackers.register("xml.path",   check) -- can be "xml.path,xml.parse,xml.profile
     -- trackers.register("xml.parse",  check)
     -- trackers.register("xml.profile",check)

        trackers.register("xml.path,xml.parse,xml.profile",function()
            if trace_lprofile then
                apply = profiled_apply
            elseif trace_lpath then
                apply = traced_apply
            else
                apply = normal_apply
            end
        end)
    end


    function xml.applylpath(list,pattern)
        if not list then
            lastmatch = nil
            return
        end
        local parsed = cache[pattern]
        if parsed then
            lpathcalls  = lpathcalls + 1
            lpathcached = lpathcached + 1
        elseif type(pattern) == "table" then
            lpathcalls = lpathcalls + 1
            parsed = pattern
        else
            parsed = lpath(pattern) or pattern
        end
        if not parsed then
            lastmatch = nil
            return
        end
        local nofparsed = #parsed
        if nofparsed == 0 then
            lastmatch = nil
            return -- something is wrong
        end
        local collected = apply({ list },parsed,nofparsed,list.mi)
        lastmatch = keepmatch and collected or nil
        return collected
    end

    function xml.lastmatch()
        return lastmatch
    end

    local stack  = { }

    function xml.pushmatch()
        insert(stack,lastmatch)
    end

    function xml.popmatch()
        lastmatch = remove(stack)
    end

end

local applylpath = xml.applylpath
--[[ldx--
<p>This is the main filter function. It returns whatever is asked for.</p>
--ldx]]--

function xml.filter(root,pattern) -- no longer funny attribute handling here
    return applylpath(root,pattern)
end

-- internal (parsed)

expressions.child = function(e,pattern)
    return applylpath(e,pattern) -- todo: cache
end

expressions.count = function(e,pattern) -- what if pattern == empty or nil
    local collected = applylpath(e,pattern) -- todo: cache
    return pattern and (collected and #collected) or 0
end

expressions.attribute = function(e,name,value)
    if type(e) == "table" and name then
        local a = e.at
        if a then
            local v = a[name]
            if value then
                return v == value
            else
                return v
            end
        end
    end
    return nil
end

-- external

-- expressions.oneof = function(s,...)
--     local t = {...}
--     for i=1,#t do
--         if s == t[i] then
--             return true
--         end
--     end
--     return false
-- end

expressions.oneof = function(s,...)
    for i=1,select("#",...) do
        if s == select(i,...) then
            return true
        end
    end
    return false
end

expressions.error = function(str)
    xml.errorhandler(format("unknown function in lpath expression: %s",tostring(str or "?")))
    return false
end

expressions.undefined = function(s)
    return s == nil
end

expressions.quit = function(s)
    if s or s == nil then
        quit_expression = true
    end
    return true
end

expressions.print = function(...)
    print(...)
    return true
end

expressions.find      = find
expressions.upper     = upper
expressions.lower     = lower
expressions.number    = tonumber
expressions.boolean   = toboolean

function expressions.contains(str,pattern)
    local t = type(str)
    if t == "string" then
        if find(str,pattern) then
            return true
        end
    elseif t == "table" then
        for i=1,#str do
            local d = str[i]
            if type(d) == "string" and find(d,pattern) then
                return true
            end
        end
    end
    return false
end

function expressions.idstring(str)
    return type(str) == "string" and gsub(str,"^#","") or ""
end

-- user interface

local function traverse(root,pattern,handle)
 -- report_lpath("use 'xml.selection' instead for pattern: %s",pattern)
    local collected = applylpath(root,pattern)
    if collected then
        for c=1,#collected do
            local e = collected[c]
            local r = e.__p__
            handle(r,r.dt,e.ni)
        end
    end
end

local function selection(root,pattern,handle)
    local collected = applylpath(root,pattern)
    if collected then
        if handle then
            for c=1,#collected do
                handle(collected[c])
            end
        else
            return collected
        end
    end
end

xml.traverse      = traverse           -- old method, r, d, k
xml.selection     = selection          -- new method, simple handle

--~ function xml.cachedpatterns()
--~     return cache
--~ end

-- generic function finalizer (independant namespace)

local function dofunction(collected,fnc,...)
    if collected then
        local f = functions[fnc]
        if f then
            for c=1,#collected do
                f(collected[c],...)
            end
        else
            report_lpath("unknown function %a",fnc)
        end
    end
end

finalizers.xml["function"] = dofunction
finalizers.tex["function"] = dofunction

-- functions

expressions.text = function(e,n)
    local rdt = e.__p__.dt
    return rdt and rdt[n] or ""
end

expressions.name = function(e,n) -- ns + tg
    local found = false
    n = tonumber(n) or 0
    if n == 0 then
        found = type(e) == "table" and e
    elseif n < 0 then
        local d = e.__p__.dt
        local k = e.ni
        for i=k-1,1,-1 do
            local di = d[i]
            if type(di) == "table" then
                if n == -1 then
                    found = di
                    break
                else
                    n = n + 1
                end
            end
        end
    else
        local d = e.__p__.dt
        local k = e.ni
        for i=k+1,#d,1 do
            local di = d[i]
            if type(di) == "table" then
                if n == 1 then
                    found = di
                    break
                else
                    n = n - 1
                end
            end
        end
    end
    if found then
        local ns = found.rn or found.ns or ""
        local tg = found.tg
        if ns ~= "" then
            return ns .. ":" .. tg
        else
            return tg
        end
    else
        return ""
    end
end

expressions.tag = function(e,n) -- only tg
    if not e then
        return ""
    else
        local found = false
        n = tonumber(n) or 0
        if n == 0 then
            found = (type(e) == "table") and e -- seems to fail
        elseif n < 0 then
            local d = e.__p__.dt
            local k = e.ni
            for i=k-1,1,-1 do
                local di = d[i]
                if type(di) == "table" then
                    if n == -1 then
                        found = di
                        break
                    else
                        n = n + 1
                    end
                end
            end
        else
            local d = e.__p__.dt
            local k = e.ni
            for i=k+1,#d,1 do
                local di = d[i]
                if type(di) == "table" then
                    if n == 1 then
                        found = di
                        break
                    else
                        n = n - 1
                    end
                end
            end
        end
        return (found and found.tg) or ""
    end
end

--[[ldx--
<p>Often using an iterators looks nicer in the code than passing handler
functions. The <l n='lua'/> book describes how to use coroutines for that
purpose (<url href='http://www.lua.org/pil/9.3.html'/>). This permits
code like:</p>

<typing>
for r, d, k in xml.elements(xml.load('text.xml'),"title") do
    print(d[k]) -- old method
end
for e in xml.collected(xml.load('text.xml'),"title") do
    print(e) -- new one
end
</typing>
--ldx]]--

-- local wrap, yield = coroutine.wrap, coroutine.yield
-- local dummy = function() end
--
-- function xml.elements(root,pattern,reverse) -- r, d, k
--     local collected = applylpath(root,pattern)
--     if collected then
--         if reverse then
--             return wrap(function() for c=#collected,1,-1 do
--                 local e = collected[c] local r = e.__p__ yield(r,r.dt,e.ni)
--             end end)
--         else
--             return wrap(function() for c=1,#collected    do
--                 local e = collected[c] local r = e.__p__ yield(r,r.dt,e.ni)
--             end end)
--         end
--     end
--     return wrap(dummy)
-- end
--
-- function xml.collected(root,pattern,reverse) -- e
--     local collected = applylpath(root,pattern)
--     if collected then
--         if reverse then
--             return wrap(function() for c=#collected,1,-1 do yield(collected[c]) end end)
--         else
--             return wrap(function() for c=1,#collected    do yield(collected[c]) end end)
--         end
--     end
--     return wrap(dummy)
-- end

-- faster:

local dummy = function() end

function xml.elements(root,pattern,reverse) -- r, d, k
    local collected = applylpath(root,pattern)
    if not collected then
        return dummy
    end
    local n = #collected
    if n == 0 then
        return dummy
    end
    if reverse then
        local c = n + 1
        return function()
            if c > 1 then
                c = c - 1
                local e = collected[c]
                local r = e.__p__
                return r, r.dt, e.ni
            end
        end
    else
        local c = 0
        return function()
            if c < n then
                c = c + 1
                local e = collected[c]
                local r = e.__p__
                return r, r.dt, e.ni
            end
        end
    end
end

function xml.collected(root,pattern,reverse) -- e
    local collected = applylpath(root,pattern)
    if not collected then
        return dummy
    end
    local n = #collected
    if n == 0 then
        return dummy
    end
    if reverse then
        local c = n + 1
        return function()
            if c > 1 then
                c = c - 1
                return collected[c]
            end
        end
    else
        local c = 0
        return function()
            if c < n then
                c = c + 1
                return collected[c]
            end
        end
    end
end

-- handy

function xml.inspect(collection,pattern)
    pattern = pattern or "."
    for e in xml.collected(collection,pattern or ".") do
        report_lpath("pattern: %s\n\n%s\n",pattern,xml.tostring(e))
    end
end

-- texy (see xfdf):

local function split(e) -- todo: use helpers / lpeg
    local dt = e.dt
    if dt then
        for i=1,#dt do
            local dti = dt[i]
            if type(dti) == "string" then
                dti = gsub(dti,"^[\n\r]*(.-)[\n\r]*","%1")
                dti = gsub(dti,"[\n\r]+","\n\n")
                dt[i] = dti
            else
                split(dti)
            end
        end
    end
    return e
end

function xml.finalizers.paragraphs(c)
    for i=1,#c do
        split(c[i])
    end
    return c
end

-- local lpegmatch = lpeg.match
-- local w = lpeg.patterns.whitespace
-- local p = w^0 * lpeg.Cf(lpeg.Ct("") * lpeg.Cg(lpeg.C((1-w)^1) * lpeg.Cc(true) * w^0)^1,rawset)

-- function xml.functions.classes(e,class) -- cache
--     class = class and e.at[class] or e.at.class
--     if class then
--         return lpegmatch(p,class)
--     else
--         return { }
--     end
-- end

-- local gmatch = string.gmatch

-- function xml.functions.hasclass(e,c,class)
--     class = class and e.at[class] or e.at.class
--     if class and class ~= "" then
--         if class == c then
--             return true
--         else
--             for s in gmatch(class,"%S+") do
--                 if s == c then
--                     return true
--                 end
--             end
--         end
--     end
--     return false
-- end
