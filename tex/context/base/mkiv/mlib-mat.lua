if not modules then modules = { } end modules ['mlib-mat'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local scanners       = mp.scan
local registerscript = metapost.registerscript

local scannumeric    = scanners.numeric
local scanpair       = scanners.pair
local scancolor      = scanners.color

local mppair         = mp.pair

local m = xmath
local c = xcomplex

local m_acos      = m.acos      registerscript("m_acos",      function() return m_acos     (scannumeric()) end)
local m_acosh     = m.acosh     registerscript("m_acosh",     function() return m_acosh    (scannumeric()) end)
local m_asin      = m.asin      registerscript("m_asin",      function() return m_asin     (scannumeric()) end)
local m_asinh     = m.asinh     registerscript("m_asinh",     function() return m_asinh    (scannumeric()) end)
local m_atan      = m.atan      registerscript("m_atan",      function() return m_atan     (scannumeric()) end)
local m_atan2     = m.atan2     registerscript("m_atan2",     function() return m_atan2    (scanpair   ()) end)
local m_atanh     = m.atanh     registerscript("m_atanh",     function() return m_atanh    (scannumeric()) end)
local m_cbrt      = m.cbrt      registerscript("m_cbrt",      function() return m_cbrt     (scannumeric()) end)
local m_ceil      = m.ceil      registerscript("m_ceil",      function() return m_ceil     (scannumeric()) end)
local m_copysign  = m.copysign  registerscript("m_copysign",  function() return m_copysign (scanpair   ()) end)
local m_cos       = m.cos       registerscript("m_cos",       function() return m_cos      (scannumeric()) end)
local m_cosh      = m.cosh      registerscript("m_cosh",      function() return m_cosh     (scannumeric()) end)
local m_deg       = m.deg       registerscript("m_deg",       function() return m_deg      (scannumeric()) end)
local m_erf       = m.erf       registerscript("m_erf",       function() return m_erf      (scannumeric()) end)
local m_erfc      = m.erfc      registerscript("m_erfc",      function() return m_erfc     (scannumeric()) end)
local m_exp       = m.exp       registerscript("m_exp",       function() return m_exp      (scannumeric()) end)
local m_exp2      = m.exp2      registerscript("m_exp2",      function() return m_exp2     (scannumeric()) end)
local m_expm1     = m.expm1     registerscript("m_expm1",     function() return m_expm1    (scannumeric()) end)
local m_fabs      = m.fabs      registerscript("m_fabs",      function() return m_fabs     (scannumeric()) end)
local m_fdim      = m.fdim      registerscript("m_fdim",      function() return m_fdim     (scanpair   ()) end)
local m_floor     = m.floor     registerscript("m_floor",     function() return m_floor    (scannumeric()) end)
local m_fma       = m.fma       registerscript("m_fma",       function() return m_fma      (scancolor  ()) end)
local m_fmax      = m.fmax      registerscript("m_fmax",      function() return m_fmax     (scannumeric()) end)
local m_fmin      = m.fmin      registerscript("m_fmin",      function() return m_fmin     (scannumeric()) end)
local m_fmod      = m.fmod      registerscript("m_fmod",      function() return m_fmod     (scanpair   ()) end)
local m_frexp     = m.frexp     registerscript("m_frexp",     function() return m_frexp    (scannumeric()) end)
local m_gamma     = m.gamma     registerscript("m_gamma",     function() return m_gamma    (scannumeric()) end)
local m_hypot     = m.hypot     registerscript("m_hypot",     function() return m_hypot    (scanpair   ()) end)
local m_isfinite  = m.isfinite  registerscript("m_isfinite",  function() return m_isfinite (scannumeric()) end)
local m_isinf     = m.isinf     registerscript("m_isinf",     function() return m_isinf    (scannumeric()) end)
local m_isnan     = m.isnan     registerscript("m_isnan",     function() return m_isnan    (scannumeric()) end)
local m_isnormal  = m.isnormal  registerscript("m_isnormal",  function() return m_isnormal (scannumeric()) end)
local m_j0        = m.j0        registerscript("m_j0",        function() return m_j0       (scannumeric()) end)
local m_j1        = m.j1        registerscript("m_j1",        function() return m_j1       (scannumeric()) end)
local m_jn        = m.jn        registerscript("m_jn",        function() return m_jn       (scanpair   ()) end)
local m_ldexp     = m.ldexp     registerscript("m_ldexp",     function() return m_ldexp    (scanpair   ()) end)
local m_lgamma    = m.lgamma    registerscript("m_lgamma",    function() return m_lgamma   (scannumeric()) end)
local m_log       = m.log       registerscript("m_log",       function() return m_log      (scannumeric()) end)
local m_log10     = m.log10     registerscript("m_log10",     function() return m_log10    (scannumeric()) end)
local m_log1p     = m.log1p     registerscript("m_log1p",     function() return m_log1p    (scannumeric()) end)
local m_log2      = m.log2      registerscript("m_log2",      function() return m_log2     (scannumeric()) end)
local m_logb      = m.logb      registerscript("m_logb",      function() return m_logb     (scannumeric()) end)
local m_modf      = m.modf      registerscript("m_modf",      function() return m_modf     (scannumeric()) end)
local m_nearbyint = m.nearbyint registerscript("m_nearbyint", function() return m_nearbyint(scannumeric()) end)
local m_nextafter = m.nextafter registerscript("m_nextafter", function() return m_nextafter(scanpair   ()) end)
local m_pow       = m.pow       registerscript("m_pow",       function() return m_pow      (scanpair   ()) end)
local m_rad       = m.rad       registerscript("m_rad",       function() return m_rad      (scannumeric()) end)
local m_remainder = m.remainder registerscript("m_remainder", function() return m_remainder(scanpair   ()) end)
local m_remquo    = m.remquo    registerscript("m_remquo",    function() return m_remquo   (scannumeric()) end)
local m_round     = m.round     registerscript("m_round",     function() return m_round    (scannumeric()) end)
local m_scalbn    = m.scalbn    registerscript("m_scalbn",    function() return m_scalbn   (scanpair   ()) end)
local m_sin       = m.sin       registerscript("m_sin",       function() return m_sin      (scannumeric()) end)
local m_sinh      = m.sinh      registerscript("m_sinh",      function() return m_sinh     (scannumeric()) end)
local m_sqrt      = m.sqrt      registerscript("m_sqrt",      function() return m_sqrt     (scannumeric()) end)
local m_tan       = m.tan       registerscript("m_tan",       function() return m_tan      (scannumeric()) end)
local m_tanh      = m.tanh      registerscript("m_tanh",      function() return m_tanh     (scannumeric()) end)
local m_tgamma    = m.tgamma    registerscript("m_tgamma",    function() return m_tgamma   (scannumeric()) end)
local m_trunc     = m.trunc     registerscript("m_trunc",     function() return m_trunc    (scannumeric()) end)
local m_y0        = m.y0        registerscript("m_y0",        function() return m_y0       (scannumeric()) end)
local m_y1        = m.y1        registerscript("m_y1",        function() return m_y1       (scannumeric()) end)
local m_yn        = m.yn        registerscript("m_yn",        function() return m_yn       (scanpair   ()) end)

if not (c and c.sin) then
    return
end

local c_topair = c.topair
local c_new    = c.new

local c_sin    = c.sin    registerscript("c_sin",    function() return mppair(c_topair(c_sin   (c_new(scanpair())))) end)
local c_cos    = c.cos    registerscript("c_cos",    function() return mppair(c_topair(c_cos   (c_new(scanpair())))) end)
local c_tan    = c.tan    registerscript("c_tan",    function() return mppair(c_topair(c_tan   (c_new(scanpair())))) end)
local c_sinh   = c.sinh   registerscript("c_sinh",   function() return mppair(c_topair(c_sinh  (c_new(scanpair())))) end)
local c_cosh   = c.cosh   registerscript("c_cosh",   function() return mppair(c_topair(c_cosh  (c_new(scanpair())))) end)
local c_tanh   = c.tanh   registerscript("c_tanh",   function() return mppair(c_topair(c_tanh  (c_new(scanpair())))) end)

local c_asin   = c.asin   registerscript("c_asin",   function() return mppair(c_topair(c_sin   (c_new(scanpair())))) end)
local c_acos   = c.acos   registerscript("c_acos",   function() return mppair(c_topair(c_cos   (c_new(scanpair())))) end)
local c_atan   = c.atan   registerscript("c_atan",   function() return mppair(c_topair(c_tan   (c_new(scanpair())))) end)
local c_asinh  = c.asinh  registerscript("c_asinh",  function() return mppair(c_topair(c_sinh  (c_new(scanpair())))) end)
local c_acosh  = c.acosh  registerscript("c_acosh",  function() return mppair(c_topair(c_cosh  (c_new(scanpair())))) end)
local c_atanh  = c.atanh  registerscript("c_atanh",  function() return mppair(c_topair(c_tanh  (c_new(scanpair())))) end)

local c_sqrt   = c.sqrt   registerscript("c_sqrt",   function() return mppair(c_topair(c_sqrt  (c_new(scanpair())))) end)
local c_abs    = c.abs    registerscript("c_abs",    function() return        c_topair(c_abs   (c_new(scanpair())))  end)
local c_arg    = c.arg    registerscript("c_arg",    function() return        c_topair(c_arg   (c_new(scanpair())))  end)
local c_conj   = c.conj   registerscript("c_conj",   function() return mppair(c_topair(c_conj  (c_new(scanpair())))) end)
local c_exp    = c.exp    registerscript("c_exp",    function() return mppair(c_topair(c_exp   (c_new(scanpair())))) end)
local c_log    = c.log    registerscript("c_log",    function() return mppair(c_topair(c_log   (c_new(scanpair())))) end)
local c_proj   = c.proj   registerscript("c_proj",   function() return mppair(c_topair(c_proj  (c_new(scanpair())))) end)

local c_erf    = c.erf    registerscript("c_erf",    function() return mppair(c_topair(c_erf   (c_new(scanpair())))) end)
local c_erfc   = c.erfc   registerscript("c_erfc",   function() return mppair(c_topair(c_erfc  (c_new(scanpair())))) end)
local c_erfcx  = c.erfcx  registerscript("c_erfcx",  function() return mppair(c_topair(c_erfcx (c_new(scanpair())))) end)
local c_erfi   = c.erfi   registerscript("c_erfi",   function() return mppair(c_topair(c_erfi  (c_new(scanpair())))) end)
local c_dawson = c.dawson registerscript("c_dawson", function() return mppair(c_topair(c_dawson(c_new(scanpair())))) end)

local c_voigt       = c.voigt
local c_voigt_hwhm  = c.voigt_hwhm

registerscript("c_voigt", function()
    return mppair(c_topair(c_voigt(c_new(scanpair()),c_new(scanpair()),c_new(scanpair()))))
end)

registerscript("c_voigt_hwhm", function()
    return mppair(c_topair(c_voigt_hwhm(c_new(scanpair()),c_new(scanpair()))))
end)

local c_pow = c.pow registerscript("c_pow", function() return mppair(c_topair(c_pow(c_new(scanpair()),c_new(scanpair())))) end)
local c_add = c.add registerscript("c_add", function() return mppair(c_topair(c_add(c_new(scanpair()),c_new(scanpair())))) end)
local c_sub = c.sub registerscript("c_sub", function() return mppair(c_topair(c_sub(c_new(scanpair()),c_new(scanpair())))) end)
local c_mul = c.mul registerscript("c_mul", function() return mppair(c_topair(c_mul(c_new(scanpair()),c_new(scanpair())))) end)
local c_div = c.div registerscript("c_div", function() return mppair(c_topair(c_div(c_new(scanpair()),c_new(scanpair())))) end)

local c_imag = c.imag registerscript("c_imag", function() return c_topair(c_imag(c_new(scanpair()))) end)
local c_real = c.real registerscript("c_real", function() return c_topair(c_real(c_new(scanpair()))) end)
local c_neg  = c.neg  registerscript("c_new",  function() return c_topair(c_neg (c_new(scanpair()))) end)
