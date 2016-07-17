if not modules then modules = { } end modules ['lang-cnt'] = {
    version   = 1.001,
    comment   = "companion to lang-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is generated with help from ctx-checkedcombined.lua (an ugly local
-- helper script).

-- We don't really need this as we compose and decompose already. The only
-- exception are the ae etc but these can best be entered in their unicode
-- form anyway. So, even if we can support hjcodes with counts is is not
-- needed in practice. It's anyway debatable if æ should be seen as one
-- character or two. And ﬃ and ĳ and such are not used in patterns anyway.

languages = languages or { }

languages.hjcounts = { -- used: used in registered unicode characters
    --
    [0x000C6] = { category = "letter",    count = 2 }, -- Æ
    [0x000E6] = { category = "letter",    count = 2 }, -- æ
    --
    [0x01E9E] = { category = "letter",    count = 2 }, -- ẞ
    [0x000DF] = { category = "letter",    count = 2 }, -- ß
    --
    [0x00132] = { category = "dubious",   count = 2 }, -- Ĳ
    [0x00133] = { category = "dubious",   count = 2 }, -- ĳ
    --
    [0x00152] = { category = "dubious",   count = 2 }, -- Œ
    [0x00153] = { category = "dubious",   count = 2 }, -- œ
    --
    [0x001C7] = { category = "letter",    count = 2 }, -- Ǉ
    [0x001C8] = { category = "letter",    count = 2 }, -- ǈ
    [0x001C9] = { category = "letter",    count = 2 }, -- ǉ
    --
    [0x001CA] = { category = "letter",    count = 2 }, -- Ǌ
    [0x001CC] = { category = "letter",    count = 2 }, -- ǌ
    -- not in patterns
    [0x0FB01] = { category = "ligature",  count = 2 }, -- ﬁ
    [0x0FB02] = { category = "ligature",  count = 2 }, -- ﬂ
    [0x0FB03] = { category = "ligature",  count = 3 }, -- ﬃ
    [0x0FB04] = { category = "ligature",  count = 3 }, -- ﬄ
    [0x0FB06] = { category = "ligature",  count = 2 }, -- ﬆ
    --
    [0x00300] = { category = "combining", count = 0, used = true  }, -- ̀
    [0x00301] = { category = "combining", count = 0, used = true  }, -- ́
    [0x00302] = { category = "combining", count = 0, used = true  }, -- ̂
    [0x00303] = { category = "combining", count = 0, used = true  }, -- ̃
    [0x00304] = { category = "combining", count = 0, used = true  }, -- ̄
    [0x00305] = { category = "combining", count = 0, used = false }, -- ̅
    [0x00306] = { category = "combining", count = 0, used = true  }, -- ̆
    [0x00307] = { category = "combining", count = 0, used = true  }, -- ̇
    [0x00308] = { category = "combining", count = 0, used = true  }, -- ̈
    [0x00309] = { category = "combining", count = 0, used = true  }, -- ̉
    [0x0030A] = { category = "combining", count = 0, used = true  }, -- ̊
    [0x0030B] = { category = "combining", count = 0, used = true  }, -- ̋
    [0x0030C] = { category = "combining", count = 0, used = true  }, -- ̌
    [0x0030D] = { category = "combining", count = 0, used = false }, -- ̍
    [0x0030E] = { category = "combining", count = 0, used = false }, -- ̎
    [0x0030F] = { category = "combining", count = 0, used = true  }, -- ̏
    [0x00310] = { category = "combining", count = 0, used = false }, -- ̐
    [0x00311] = { category = "combining", count = 0, used = true  }, -- ̑
    [0x00312] = { category = "combining", count = 0, used = false }, -- ̒
    [0x00313] = { category = "combining", count = 0, used = true  }, -- ̓
    [0x00314] = { category = "combining", count = 0, used = true  }, -- ̔
    [0x00315] = { category = "combining", count = 0, used = false }, -- ̕
    [0x00316] = { category = "combining", count = 0, used = false }, -- ̖
    [0x00317] = { category = "combining", count = 0, used = false }, -- ̗
    [0x00318] = { category = "combining", count = 0, used = false }, -- ̘
    [0x00319] = { category = "combining", count = 0, used = false }, -- ̙
    [0x0031A] = { category = "combining", count = 0, used = false }, -- ̚
    [0x0031B] = { category = "combining", count = 0, used = true  }, -- ̛
    [0x0031C] = { category = "combining", count = 0, used = false }, -- ̜
    [0x0031D] = { category = "combining", count = 0, used = false }, -- ̝
    [0x0031E] = { category = "combining", count = 0, used = false }, -- ̞
    [0x0031F] = { category = "combining", count = 0, used = false }, -- ̟
    [0x00320] = { category = "combining", count = 0, used = false }, -- ̠
    [0x00321] = { category = "combining", count = 0, used = false }, -- ̡
    [0x00322] = { category = "combining", count = 0, used = false }, -- ̢
    [0x00323] = { category = "combining", count = 0, used = true  }, -- ̣
    [0x00324] = { category = "combining", count = 0, used = true  }, -- ̤
    [0x00325] = { category = "combining", count = 0, used = true  }, -- ̥
    [0x00326] = { category = "combining", count = 0, used = true  }, -- ̦
    [0x00327] = { category = "combining", count = 0, used = true  }, -- ̧
    [0x00328] = { category = "combining", count = 0, used = true  }, -- ̨
    [0x00329] = { category = "combining", count = 0, used = false }, -- ̩
    [0x0032A] = { category = "combining", count = 0, used = false }, -- ̪
    [0x0032B] = { category = "combining", count = 0, used = false }, -- ̫
    [0x0032C] = { category = "combining", count = 0, used = false }, -- ̬
    [0x0032D] = { category = "combining", count = 0, used = true  }, -- ̭
    [0x0032E] = { category = "combining", count = 0, used = true  }, -- ̮
    [0x0032F] = { category = "combining", count = 0, used = false }, -- ̯
    [0x00330] = { category = "combining", count = 0, used = true  }, -- ̰
    [0x00331] = { category = "combining", count = 0, used = true  }, -- ̱
    [0x00332] = { category = "combining", count = 0, used = false }, -- ̲
    [0x00333] = { category = "combining", count = 0, used = false }, -- ̳
    [0x00334] = { category = "combining", count = 0, used = false }, -- ̴
    [0x00335] = { category = "combining", count = 0, used = false }, -- ̵
    [0x00336] = { category = "combining", count = 0, used = false }, -- ̶
    [0x00337] = { category = "combining", count = 0, used = false }, -- ̷
    [0x00338] = { category = "combining", count = 0, used = false }, -- ̸
    [0x00339] = { category = "combining", count = 0, used = false }, -- ̹
    [0x0033A] = { category = "combining", count = 0, used = false }, -- ̺
    [0x0033B] = { category = "combining", count = 0, used = false }, -- ̻
    [0x0033C] = { category = "combining", count = 0, used = false }, -- ̼
    [0x0033D] = { category = "combining", count = 0, used = false }, -- ̽
    [0x0033E] = { category = "combining", count = 0, used = false }, -- ̾
    [0x0033F] = { category = "combining", count = 0, used = false }, -- ̿
    [0x00340] = { category = "combining", count = 0, used = false }, -- ̀
    [0x00341] = { category = "combining", count = 0, used = false }, -- ́
    [0x00342] = { category = "combining", count = 0, used = true  }, -- ͂
    [0x00343] = { category = "combining", count = 0, used = false }, -- ̓
    [0x00344] = { category = "combining", count = 0, used = false }, -- ̈́
    [0x00345] = { category = "combining", count = 0, used = true  }, -- ͅ
    [0x00346] = { category = "combining", count = 0, used = false }, -- ͆
    [0x00347] = { category = "combining", count = 0, used = false }, -- ͇
    [0x00348] = { category = "combining", count = 0, used = false }, -- ͈
    [0x00349] = { category = "combining", count = 0, used = false }, -- ͉
    [0x0034A] = { category = "combining", count = 0, used = false }, -- ͊
    [0x0034B] = { category = "combining", count = 0, used = false }, -- ͋
    [0x0034C] = { category = "combining", count = 0, used = false }, -- ͌
    [0x0034D] = { category = "combining", count = 0, used = false }, -- ͍
    [0x0034E] = { category = "combining", count = 0, used = false }, -- ͎
    [0x0034F] = { category = "combining", count = 0, used = false }, -- ͏
    [0x00350] = { category = "combining", count = 0, used = false }, -- ͐
    [0x00351] = { category = "combining", count = 0, used = false }, -- ͑
    [0x00352] = { category = "combining", count = 0, used = false }, -- ͒
    [0x00353] = { category = "combining", count = 0, used = false }, -- ͓
    [0x00354] = { category = "combining", count = 0, used = false }, -- ͔
    [0x00355] = { category = "combining", count = 0, used = false }, -- ͕
    [0x00356] = { category = "combining", count = 0, used = false }, -- ͖
    [0x00357] = { category = "combining", count = 0, used = false }, -- ͗
    [0x00358] = { category = "combining", count = 0, used = false }, -- ͘
    [0x00359] = { category = "combining", count = 0, used = false }, -- ͙
    [0x0035A] = { category = "combining", count = 0, used = false }, -- ͚
    [0x0035B] = { category = "combining", count = 0, used = false }, -- ͛
    [0x0035C] = { category = "combining", count = 0, used = false }, -- ͜
    [0x0035D] = { category = "combining", count = 0, used = false }, -- ͝
    [0x0035E] = { category = "combining", count = 0, used = false }, -- ͞
    [0x0035F] = { category = "combining", count = 0, used = false }, -- ͟
    [0x00360] = { category = "combining", count = 0, used = false }, -- ͠
    [0x00361] = { category = "combining", count = 0, used = false }, -- ͡
    [0x00362] = { category = "combining", count = 0, used = false }, -- ͢
    [0x00363] = { category = "combining", count = 0, used = false }, -- ͣ
    [0x00364] = { category = "combining", count = 0, used = false }, -- ͤ
    [0x00365] = { category = "combining", count = 0, used = false }, -- ͥ
    [0x00366] = { category = "combining", count = 0, used = false }, -- ͦ
    [0x00367] = { category = "combining", count = 0, used = false }, -- ͧ
    [0x00368] = { category = "combining", count = 0, used = false }, -- ͨ
    [0x00369] = { category = "combining", count = 0, used = false }, -- ͩ
    [0x0036A] = { category = "combining", count = 0, used = false }, -- ͪ
    [0x0036B] = { category = "combining", count = 0, used = false }, -- ͫ
    [0x0036C] = { category = "combining", count = 0, used = false }, -- ͬ
    [0x0036D] = { category = "combining", count = 0, used = false }, -- ͭ
    [0x0036E] = { category = "combining", count = 0, used = false }, -- ͮ
    [0x0036F] = { category = "combining", count = 0, used = false }, -- ͯ
    [0x00483] = { category = "combining", count = 0, used = false }, -- ҃
    [0x00484] = { category = "combining", count = 0, used = false }, -- ҄
    [0x00485] = { category = "combining", count = 0, used = false }, -- ҅
    [0x00486] = { category = "combining", count = 0, used = false }, -- ҆
    [0x00487] = { category = "combining", count = 0, used = false }, -- ҇
}
