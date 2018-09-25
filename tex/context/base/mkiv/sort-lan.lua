if not modules then modules = { } end modules ['sort-lan'] = {
    version   = 1.001,
    comment   = "companion to sort-lan.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
    dataonly  = true,
}

-- todo: look into uts#10 (2012) ... some experiments ... something
-- to finish in winter.
-- todo: U+1E9E (german SS)

-- Many vectors were supplied by Wolfgang Schuster and Philipp
-- Gesang. However this is a quite adapted and reformatted variant
-- so it needs some checking. Other users provides tables and
-- corrections as well.

local utfchar, utfbyte  = utf.char, utf.byte
local sorters           = sorters
local definitions       = sorters.definitions
local replacementoffset = sorters.constants.replacementoffset
local variables         = interfaces.variables

definitions["default"] = {
    method  = variables.before,
    replacements = {
        -- no replacements
    },
    entries = {
        ["a"] = "a", ["b"] = "b", ["c"] = "c", ["d"] = "d", ["e"] = "e",
        ["f"] = "f", ["g"] = "g", ["h"] = "h", ["i"] = "i", ["j"] = "j",
        ["k"] = "k", ["l"] = "l", ["m"] = "m", ["n"] = "n", ["o"] = "o",
        ["p"] = "p", ["q"] = "q", ["r"] = "r", ["s"] = "s", ["t"] = "t",
        ["u"] = "u", ["v"] = "v", ["w"] = "w", ["x"] = "x", ["y"] = "y",
        ["z"] = "z",
    },
    orders = {
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
        "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
        "u", "v", "w", "x", "y", "z",
    },
    lower = {
        -- no replacements
    },
    upper = {
        -- no replacements
    }
}

sorters.setlanguage("default")

-- english

definitions["en"] = { parent = "default" }

-- dutch

definitions['nl'] = {
    parent = 'default',
    replacements = {
     -- { "ij", 'y' }, { "IJ", 'Y' }, -- no longer, or will be option
    },
}

-- French

definitions['fr'] = { parent = 'default' }

-- German (by Wolfgang Schuster)

-- DIN 5007-1

definitions['DIN 5007-1'] = {
    parent       = 'default',
    replacements = {
        { "ß", "ss" },
    },
}

-- DIN 5007-2

definitions['DIN 5007-2'] = {
    parent       = 'default',
    replacements = {
        { "ä", "ae" }, { "Ä", "Ae" },
        { "ö", "oe" }, { "Ö", "Oe" },
        { "ü", "ue" }, { "Ü", "Ue" },
        { "ß", "ss" },
    },
}

-- Duden

definitions['Duden'] = {
    parent       = 'default',
    replacements = {
        { "ß", "s" },
    },
}

-- definitions['de'] = { parent = 'default' } -- new german

definitions['de']    = {
    parent = 'default',
    replacements = {
        { "ä", 'ae' }, { "Ä", 'Ae' },
        { "ö", 'oe' }, { "Ö", 'Oe' },
        { "ü", 'ue' }, { "Ü", 'Ue' },
        { "ß", 's'  },
    },
}

definitions['deo']   = { parent = 'de' } -- old german

definitions['de-DE'] = { parent = 'de' } -- german - Germany
definitions['de-CH'] = { parent = 'de' } -- german - Swiss

-- german - Austria

definitions['de-AT'] = {
    entries = {
        ["a"] = "a", ["ä"] = "ä", ["b"] = "b", ["c"] = "c", ["d"] = "d",
        ["e"] = "e", ["f"] = "f", ["g"] = "g", ["h"] = "h", ["i"] = "i",
        ["j"] = "j", ["k"] = "k", ["l"] = "l", ["m"] = "m", ["n"] = "n",
        ["o"] = "o", ["ö"] = "ö", ["p"] = "p", ["q"] = "q", ["r"] = "r",
        ["s"] = "s", ["t"] = "t", ["u"] = "u", ["ü"] = "ü", ["v"] = "v",
        ["w"] = "w", ["x"] = "x", ["y"] = "y", ["z"] = "z",
    },
    orders = {
        "a", "ä", "b", "c", "d", "e", "f", "g", "h", "i",
        "j", "k", "l", "m", "n", "o", "ö", "p", "q", "r",
        "s", "t", "u", "ü", "v", "w", "x", "y", "z",
    },
}

-- finnish (by Wolfgang Schuster)

definitions['fi'] = {
    entries = {
        ["a"] = "a", ["b"] = "b", ["c"] = "c", ["d"] = "d", ["e"] = "e",
        ["f"] = "f", ["g"] = "g", ["h"] = "h", ["i"] = "i", ["j"] = "j",
        ["k"] = "k", ["l"] = "l", ["m"] = "m", ["n"] = "n", ["o"] = "o",
        ["p"] = "p", ["q"] = "q", ["r"] = "r", ["s"] = "s", ["t"] = "t",
        ["u"] = "u", ["v"] = "v", ["w"] = "w", ["x"] = "x", ["y"] = "y",
        ["z"] = "z", ["å"] = "å", ["ä"] = "ä", ["ö"] = "ö",
    },
    orders = {
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
        "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
        "u", "v", "w", "x", "y", "z", "å", "ä", "ö",
    }
}

-- slovenian by MM: this will change since we need to add accented vowels

definitions['sl'] = {
    entries = {
        ["a"] = "a", ["b"] = "b", ["c"] = "c", ["č"] = "č", ["ć"] = "ć", ["d"] = "d",
        ["đ"] = "đ", ["e"] = "e", ["f"] = "f", ["g"] = "g", ["h"] = "h", ["i"] = "i",
        ["j"] = "j", ["k"] = "k", ["l"] = "l", ["m"] = "m", ["n"] = "n", ["o"] = "o",
        ["p"] = "p", ["q"] = "q", ["r"] = "r", ["s"] = "s", ["š"] = "š", ["t"] = "t",
        ["u"] = "u", ["v"] = "v", ["w"] = "w", ["x"] = "x", ["y"] = "y", ["z"] = "z",
        ["ž"] = "ž",
    },
    orders = {
        "a", "b", "c", "č", "ć", "d", "đ", "e", "f", "g", "h", "i",
        "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "š", "t",
        "u", "v", "w", "x", "y", "z", "ž",
    }
}

-- The following data was provided by Philipp Gesang.

definitions["ru"] = {
    entries = {
        ["а"] = "а", ["б"] = "б", ["в"] = "в", ["г"] = "г", ["д"] = "д",
        ["е"] = "е", ["ё"] = "е", ["ж"] = "ж", ["з"] = "з", ["и"] = "и",
        ["і"] = "и", ["й"] = "й", ["к"] = "к", ["л"] = "л", ["м"] = "м",
        ["н"] = "н", ["о"] = "о", ["п"] = "п", ["р"] = "р", ["с"] = "с",
        ["т"] = "т", ["у"] = "у", ["ф"] = "ф", ["х"] = "х", ["ц"] = "ц",
        ["ч"] = "ч", ["ш"] = "ш", ["щ"] = "щ", ["ъ"] = "ъ", ["ы"] = "ы",
        ["ь"] = "ь", ["ѣ"] = "ѣ", ["э"] = "э", ["ю"] = "ю", ["я"] = "я",
        ["ѳ"] = "ѳ", ["ѵ"] = "ѵ",
    },
    orders = {
        "а", "б", "в", "г", "д", "е", "ё", "ж", "з", "и",
        "і", "й", "к", "л", "м", "н", "о", "п", "р", "с",
        "т", "у", "ф", "х", "ц", "ч", "ш", "щ", "ъ", "ы",
        "ь", "ѣ", "э", "ю", "я", "ѳ", "ѵ",
    }
}

--- Basic Ukrainian

definitions["uk"] = {
    entries = {
        ["а"] = "а", ["б"] = "б", ["в"] = "в", ["г"] = "г", ["ґ"] = "ґ",
        ["д"] = "д", ["е"] = "е", ["є"] = "є", ["ж"] = "ж", ["з"] = "з",
        ["и"] = "и", ["і"] = "і", ["ї"] = "ї", ["й"] = "й", ["к"] = "к",
        ["л"] = "л", ["м"] = "м", ["н"] = "н", ["о"] = "о", ["п"] = "п",
        ["р"] = "р", ["с"] = "с", ["т"] = "т", ["у"] = "у", ["ф"] = "ф",
        ["х"] = "х", ["ц"] = "ц", ["ч"] = "ч", ["ш"] = "ш", ["щ"] = "щ",
        ["ь"] = "ь", ["ю"] = "ю", ["я"] = "я",
    },
    orders = {
        "а", "б", "в", "г", "ґ", "д", "е", "є", "ж", "з", "и", "і",
        "ї", "й", "к", "л", "м", "н", "о", "п", "р", "с", "т", "у",
        "ф", "х", "ц", "ч", "ш", "щ", "ь", "ю", "я",
    }
}

--- Belarusian

definitions["be"] = {
    entries = {
        ["а"] = "а", ["б"] = "б", ["в"] = "в", ["г"] = "г", ["д"] = "д",
        ["е"] = "е", ["ё"] = "е", ["ж"] = "ж", ["з"] = "з", ["і"] = "і",
        ["й"] = "й", ["к"] = "к", ["л"] = "л", ["м"] = "м", ["н"] = "н",
        ["о"] = "о", ["п"] = "п", ["р"] = "р", ["с"] = "с", ["т"] = "т",
        ["у"] = "у", ["ў"] = "ў", ["ф"] = "ф", ["х"] = "х", ["ц"] = "ц",
        ["ч"] = "ч", ["ш"] = "ш", ["ы"] = "ы", ["ь"] = "ь", ["э"] = "э",
        ["ю"] = "ю", ["я"] = "я",
    },
    orders = {
        "а", "б", "в", "г", "д", "е", "ё", "ж", "з", "і",
        "й", "к", "л", "м", "н", "о", "п", "р", "с", "т",
        "у", "ў", "ф", "х", "ц", "ч", "ш", "ы", "ь", "э",
        "ю", "я",
    }
}

--- Bulgarian

definitions["bg"] = {
    entries = {
        ["а"] = "а", ["б"] = "б", ["в"] = "в", ["г"] = "г", ["д"] = "д",
        ["е"] = "е", ["ж"] = "ж", ["з"] = "з", ["и"] = "и", ["й"] = "й",
        ["к"] = "к", ["a"] = "a", ["л"] = "л", ["a"] = "a", ["м"] = "м",
        ["н"] = "н", ["о"] = "о", ["п"] = "п", ["р"] = "р", ["с"] = "с",
        ["т"] = "т", ["у"] = "у", ["ф"] = "ф", ["х"] = "х", ["ц"] = "ц",
        ["ч"] = "ч", ["ш"] = "ш", ["щ"] = "щ", ["ъ"] = "ъ", ["ь"] = "ь",
        ["ю"] = "ю", ["я"] = "я",
    },
    orders = {
        "а", "б", "в", "г", "д", "е", "ж", "з","и", "й",
        "к", "a", "л", "a", "м", "н", "о", "п", "р", "с",
        "т", "у", "ф", "х", "ц", "ч", "ш", "щ", "ъ", "ь",
        "ю", "я",
    }
}

--- Old Church Slavonic

-- The language symbol “cu” is taken from the Wikipedia subdomain
-- cu.wikipedia.org.

local uk, UK  = utfchar(replacementoffset + 1), utfchar(replacementoffset + 11)

definitions["cu"] = {
    replacements = {
        { "оу", uk }, { "ОУ", UK },
    },
    entries = {
        ["а"] = "а", ["б"] = "б", ["в"] = "в", ["г"] = "г", ["д"] = "д",
        ["є"] = "є", ["ж"] = "ж", ["ѕ"] = "ѕ", ["ꙃ"] = "ѕ", ["з"] = "з",
        ["ꙁ"] = "з", ["и"] = "и", ["і"] = "и", ["ї"] = "и", ["ћ"] = "ћ",
        ["к"] = "к", ["л"] = "л", ["м"] = "м", ["н"] = "н", ["о"] = "о",
        ["п"] = "п", ["р"] = "р", ["с"] = "с", ["т"] = "т", ["у"] = "у",
        ["ѹ"] = "у", ["ꙋ"] = "у", [uk]  = "у", ["ф"] = "ф", ["х"] = "х",
        ["ѡ"] = "ѡ", ["ѿ"] = "ѡ", ["ѽ"] = "ѡ", ["ꙍ"] = "ѡ", ["ц"] = "ц",
        ["ч"] = "ч", ["ш"] = "ш", ["щ"] = "щ", ["ъ"] = "ъ", ["ы"] = "ы",
        ["ꙑ"] = "ы", ["ь"] = "ь", ["ѣ"] = "ѣ", ["ю"] = "ю", ["ꙗ"] = "ꙗ",
        ["ѥ"] = "ѥ", ["ѧ"] = "ѧ", ["ѩ"] = "ѩ", ["ѫ"] = "ѫ", ["ѭ"] = "ѭ",
        ["ѯ"] = "ѯ", ["ѱ"] = "ѱ", ["ѳ"] = "ѳ", ["ѵ"] = "ѵ", ["ѷ"] = "ѵ",
    },
    orders = {
        "а", "б", "в", "г", "д", "є", "ж", "ѕ", "ꙃ", "з", -- Dzělo, U+0292, alternative: ǳ U+01f3
        "ꙁ", "и", "і", "ї", "ћ", "к", "л", "м", "н", "о", -- Zemlja
        "п", "р", "с", "т", "у", "ѹ", "ꙋ", uk,  "ф", "х", -- U+0478 uk, horizontal ligature, U+0479 uk, vertical ligature
        "ѡ", "ѿ", "ѽ", "ꙍ", "ц", "ч", "ш", "щ", "ъ", "ы", -- "ō", U+047f \, U+047d  > Omega variants,  U+064D  /
        "ꙑ", "ь", "ѣ", "ю", "ꙗ", "ѥ", "ѧ", "ѩ", "ѫ", "ѭ", -- Old jery (U+a651) as used e.g. by the OCS Wikipedia. IOTIFIED A
        "ѯ", "ѱ", "ѳ", "ѵ", "ѷ",
    },
    upper = {
        uk = UK,
    },
    lower = {
        UK = uk,
    }
}

--- Polish (including the letters q, v, x) Cf. ftp://ftp.gust.org.pl/pub/GUST/bulletin/03/02-bl.pdf.

definitions["pl"] = {
    entries = {
        ["a"] = "a", ["ą"] = "ą", ["b"] = "b", ["c"] = "c", ["ć"] = "ć",
        ["d"] = "d", ["e"] = "e", ["ę"] = "ę", ["f"] = "f", ["g"] = "g",
        ["h"] = "h", ["i"] = "i", ["j"] = "j", ["k"] = "k", ["l"] = "l",
        ["ł"] = "ł", ["m"] = "m", ["n"] = "n", ["ń"] = "ń", ["o"] = "o",
        ["ó"] = "ó", ["p"] = "p", ["q"] = "q", ["r"] = "r", ["s"] = "s",
        ["ś"] = "ś", ["t"] = "t", ["u"] = "u", ["v"] = "v", ["w"] = "w",
        ["x"] = "x", ["y"] = "y", ["z"] = "z", ["ź"] = "ź", ["ż"] = "ż",
    },
    orders = {
        "a", "ą", "b", "c", "ć", "d", "e", "ę", "f", "g",
        "h", "i", "j", "k", "l", "ł", "m", "n", "ń", "o",
        "ó", "p", "q", "r", "s", "ś", "t", "u", "v", "w",
        "x", "y", "z", "ź", "ż",
    },
}

-- Czech, modified to treat quantities and other secondary characteristics indifferently. Cf.
-- http://racek.vlada.cz/usneseni/usneseni_webtest.nsf/WebGovRes/0AD8FEF4CC04B7A4C12571B6006D69D0?OpenDocument
-- (2.4.3; via <http://cs.wikipedia.org/wiki/Abecední_řazení#.C4.8Ce.C5.A1tina>)

local ch, CH = utfchar(replacementoffset + 1), utfchar(replacementoffset + 11)

definitions["cz"] = {
    replacements = {
        { "ch", ch }, { "Ch", ch }, { "CH", ch }
    },
    entries = {
        ["a"] = "a", ["á"] = "a", ["b"] = "b", ["c"] = "c",  ["č"] = "č",
        ["d"] = "d", ["ď"] = "d", ["e"] = "e", ["é"] = "e",  ["ě"] = "e",
        ["f"] = "f", ["g"] = "g", ["h"] = "h", [ch]  = "ch", ["i"] = "i",
        ["í"] = "i", ["j"] = "j", ["k"] = "k", ["l"] = "l",  ["m"] = "m",
        ["n"] = "n", ["ň"] = "n", ["o"] = "o", ["ó"] = "o",  ["p"] = "p",
        ["q"] = "q", ["r"] = "r", ["ř"] = "ř", ["s"] = "s",  ["š"] = "š",
        ["t"] = "t", ["ť"] = "t", ["u"] = "u", ["ú"] = "u",  ["ů"] = "u",
        ["v"] = "v", ["w"] = "w", ["x"] = "x", ["y"] = "y",  ["ý"] = "y",
        ["z"] = "z", ["ž"] = "ž",
    },
    orders = {
        "a", "á", "b", "c", "č", "d", "ď", "e", "é", "ě",
        "f", "g", "h", ch,  "i", "í", "j", "k", "l", "m",
        "n", "ň", "o", "ó", "p", "q", "r", "ř", "s", "š",
        "t", "ť", "u", "ú",  "ů", "v", "w", "x",  "y", "ý",
        "z", "ž",
    },
    upper = {
        ch = CH,
    },
    lower = {
        CH = ch,
    }
}

definitions["cs"] = { parent = "cz" }

--- Slovak.

-- Vowel and consonant quantities, "ď", "ľ", "ň", "ť", "ô", and "ä" are treated
-- indifferently as their base character, as in my dictionary. If you prefer them
-- to affect collation order, then use the values given in the comments. We could
-- define an additional vector for that.

local dz,  DZ  = utfchar(replacementoffset + 1), utfchar(replacementoffset + 11)
local dzh, DZH = utfchar(replacementoffset + 2), utfchar(replacementoffset + 12)
local ch,  CH  = utfchar(replacementoffset + 3), utfchar(replacementoffset + 13)

definitions["sk"] = {
    replacements = {
        { "dz", dz  }, { "dz", DZ  },
        { "dž", dzh }, { "dž", DZH },
        { "ch", ch  }, { "ch", CH  },
    },
    entries = {
        ["a"] = "a",  ["á"] = "a", ["ä"] = "a", ["b"] = "b",  ["c"] = "c",
        ["č"] = "č",  ["d"] = "d", ["ď"] = "d", [dz]  = "dz", [dzh] = "dž",
        ["e"] = "e",  ["é"] = "e", ["f"] = "f", ["g"] = "g",  ["h"] = "h",
        [ch]  = "ch", ["i"] = "i", ["í"] = "i", ["j"] = "j",  ["k"] = "k",
        ["l"] = "l",  ["ĺ"] = "l", ["ľ"] = "l", ["m"] = "m",  ["n"] = "n",
        ["ň"] = "n",  ["o"] = "o", ["ó"] = "o", ["ô"] = "o",  ["p"] = "p",
        ["q"] = "q",  ["r"] = "r", ["ŕ"] = "r", ["s"] = "s",  ["š"] = "š",
        ["t"] = "t",  ["ť"] = "t", ["u"] = "u", ["ú"] = "u",  ["v"] = "v",
        ["w"] = "w",  ["x"] = "x", ["y"] = "y", ["ý"] = "y",  ["z"] = "z",
        ["ž"] = "ž",
    },
    orders = {
        "a", "á", "ä", "b", "c", "č", "d", "ď", dz,  dzh,
        "e", "é", "f", "g", "h", ch,  "i", "í", "j", "k",
        "l", "ĺ", "ľ", "m", "n", "ň", "o", "ó", "ô", "p",
        "q", "r", "ŕ", "s", "š", "t", "ť", "u", "ú", "v",
        "w", "x", "y", "ý", "z", "ž",
    },
    upper = {
        dz  = DZ, dzh = DZH, ch  = CH,
    },
    lower = {
        DZ  = dz, DZH = dzh, CH  = ch,
    }
}

--- Croatian

local dzh, DZH = utfchar(replacementoffset + 1), utfchar(replacementoffset + 11)
local lj,  LJ  = utfchar(replacementoffset + 2), utfchar(replacementoffset + 12)
local nj,  NJ  = utfchar(replacementoffset + 3), utfchar(replacementoffset + 13)

definitions["hr"] = {
    replacements = {
        { "dž", dzh }, { "DŽ", DZH },
        { "lj", lj  }, { "LJ", LJ  },
        { "nj", nj  }, { "NJ", NJ  },
    },
    entries = {
        ["a"] = "a", ["b"] =  "b", ["c"] = "c", ["č"] = "č", ["ć"] =  "ć",
        ["d"] = "d", [dzh] = "dž", ["đ"] = "đ", ["e"] = "e", ["f"] =  "f",
        ["g"] = "g", ["h"] =  "h", ["i"] = "i", ["j"] = "j", ["k"] =  "k",
        ["l"] = "l", [lj]  = "lj", ["m"] = "m", ["n"] = "n", [nj]  = "nj",
        ["o"] = "o", ["p"] =  "p", ["r"] = "r", ["s"] = "s", ["š"] =  "š",
        ["t"] = "t", ["u"] =  "u", ["v"] = "v", ["z"] = "z", ["ž"] =  "ž",
    },
    orders = {
        "a", "b", "c", "č", "ć", "d", dzh, "đ", "e", "f",
        "g", "h", "i", "j", "k", "l", lj,  "m", "n", nj,
        "o", "p", "r", "s", "š", "t", "u", "v", "z", "ž",
    },
    upper = {
        dzh = DZH, lj  = LJ, nj  = NJ,
    },
    lower = {
        DZH = dzh, LJ  = lj, NJ  = nj,
    }
}


--- Serbian

definitions["sr"] = {
    entries = {
        ["а"]   = "а", ["б"]   = "б", ["в"]   = "в", ["г"]   = "г", ["д"]   = "д",
        ["ђ"]   = "ђ", ["е"]   = "е", ["ж"]   = "ж", ["з"]   = "з", ["и"]   = "и",
        ["ј"]   = "ј", ["к"]   = "к", ["л"]   = "л", ["љ"]   = "љ", ["м"]   = "м",
        ["н"]   = "н", ["њ"]   = "њ", ["о"]   = "о", ["п"]   = "п", ["р"]   = "р",
        ["с"]   = "с", ["т"]   = "т", ["ћ"]   = "ћ", ["у"]   = "у", ["ф"]   = "ф",
        ["х"]   = "х", ["ц"]   = "ц", ["ч"]   = "ч", ["џ"]   = "џ",
        ["ш"]   = "ш",
    },
    orders = {
        "а", "б", "в", "г", "д", "ђ", "е", "ж", "з", "и",
        "ј", "к", "л", "љ", "м", "н", "њ", "о", "п", "р",
        "с", "т", "ћ", "у", "ф", "х", "ц", "ч", "џ", "ш",
    }
}

--- Transliteration: Russian|ISO9-1995

-- Keeping the same collation order as Russian (v.s.).
-- Matches the tables from:
-- http://bitbucket.org/phg/transliterator/src/tip/tex/context/third/transliterator/trans_tables_iso9.lua

local yer = utfchar(replacementoffset + 1)

definitions["ru-iso9"] = {
    replacements = {
        { "''", yer  },
    },
    entries = {
        ["a"] = "a", ["b"] = "b", ["v"] = "v", ["g"] = "g", ["d"] = "d",
        ["e"] = "e", ["ë"] = "ë", ["ž"] = "ž", ["z"] = "z", ["i"] = "i",
        ["ì"] = "ì", ["j"] = "j", ["k"] = "k", ["l"] = "l", ["m"] = "m",
        ["n"] = "n", ["o"] = "o", ["p"] = "p", ["r"] = "r", ["s"] = "s",
        ["t"] = "t", ["u"] = "u", ["f"] = "f", ["h"] = "h", ["c"] = "c",
        ["č"] = "č", ["š"] = "š", ["ŝ"] = "ŝ", ["ʺ"] = "ʺ",  [yer] = "ʺ",
        ["y"] = "y", ["ʹ"] = "ʹ", ["'"] = "ʹ", ["ě"] = "ě", ["è"] = "è",
        ["û"] = "û", ["â"] = "â", ["û"] = "û", ["â"] = "â",
    },
    orders = {
        "a", "b", "v", "g", "d", "e", "ë", "ž", "z", "i",
        "ì", "j", "k", "l", "m", "n", "o", "p", "r", "s",
        "t", "u", "f", "h", "c", "č", "š", "ŝ", "ʺ", yer,
        "y", "ʹ", "'", "ě", "è", "û", "â", "û", "â",
    }
}

--- Transliteration: Old Slavonic|scientific

-- Matches the tables from:
-- http://bitbucket.org/phg/transliterator/src/tip/tex/context/third/transliterator/trans_tables_scntfc.lua

local uk,      UK      = utfchar(replacementoffset +  1), utfchar(replacementoffset + 21)
local tshe,    TSHE    = utfchar(replacementoffset +  2), utfchar(replacementoffset + 22)
local sht,     SHT     = utfchar(replacementoffset +  3), utfchar(replacementoffset + 23)
local ju,      JU      = utfchar(replacementoffset +  4), utfchar(replacementoffset + 24)
local ja,      JA      = utfchar(replacementoffset +  5), utfchar(replacementoffset + 25)
local je,      JE      = utfchar(replacementoffset +  6), utfchar(replacementoffset + 26)
local ijus,    IJUS    = utfchar(replacementoffset +  7), utfchar(replacementoffset + 27)
local ibigjus, IBIGJUS = utfchar(replacementoffset +  8), utfchar(replacementoffset + 28)
local xi,      XI      = utfchar(replacementoffset +  9), utfchar(replacementoffset + 29)
local psi,     PSI     = utfchar(replacementoffset + 10), utfchar(replacementoffset + 30)
local theta,   THETA   = utfchar(replacementoffset + 11), utfchar(replacementoffset + 31)
local shch,    SHCH    = utfchar(replacementoffset + 12), utfchar(replacementoffset + 32)

definitions["ocs-scn"] = {
    replacements = {
        { "ou", uk      }, { "OU", UK      },
        { "g’", tshe    }, { "G’", TSHE    },
        { "št", sht     }, { "ŠT", SHT     },
        { "ju", ju      }, { "JU", JU      },
        { "ja", ja      }, { "JA", JA      },
        { "je", je      }, { "JE", JE      },
        { "ję", ijus    }, { "JĘ", IJUS    },
        { "jǫ", ibigjus }, { "JǪ", IBIGJUS },
        { "ks", xi      }, { "KS", XI      },
        { "ps", psi     }, { "PS", PSI     },
        { "th", theta   }, { "TH", THETA   },
        { "šč", shch    }, { "ŠČ", SHCH    },
    },
    entries = {
        ["a"]  =  "a", ["b"]     =  "b", ["v"]  =  "v", ["g"]  =  "g", ["d"]   =  "d",
        ["e"]  =  "e", ["ž"]     =  "ž", ["ʒ"]  =  "ʒ", ["z"]  =  "z", ["i"]   =  "i",
        ["ï"]  =  "ï", [tshe]    = "g’", ["k"]  =  "k", ["l"]  =  "l", ["m"]   =  "m",
        ["n"]  =  "n", ["o"]     =  "o", ["p"]  =  "p", ["r"]  =  "r", ["s"]   =  "s",
        ["t"]  =  "t", ["u"]     =  "u", ["f"]  =  "f", ["x"]  =  "x", ["o"]   =  "o",
        ["c"]  =  "c", ["č"]     =  "č", ["š"]  =  "š", [sht]  = "št", [shch]  = "šč",
        ["ъ"]  =  "ъ", ["y"]     =  "y", [uk]   =  "y", ["ь"]  =  "ь", ["ě"]   =  "ě",
        [ju]   = "ju", [ja]      = "ja", [je]   = "je", ["ę"]  =  "ę", [ijus]  = "ję",
        ["ǫ"]  =  "ǫ", [ibigjus] = "jǫ", [xi]   = "ks", [psi]  = "ps", [theta] = "th",
        ["ü"]  =  "ü",
    },
    orders = {
        "a",   "b", "v", "g", "d", "e", "ž",  "ʒ",  "z",     "i", "ï",
        tshe,  "k", "l", "m", "n", "o", "p",  "r",  "s",     "t", "u",
        "f",   "x", "o", "c", "č", "š", sht,  shch, "ъ",     "y", uk,
        "ь",   "ě", ju,  ja,  je,  "ę", ijus, "ǫ",  ibigjus, xi,  psi,
        theta, "ü",
    },
    upper = {
        uk = UK, tshe = TSHE, sht = SHT, ju = JU, ja = JA, je = JE, ijus = IJUS, ibigjus = IBIGJUS, xi = XI, psi = PSI, theta = THETA, shch = SHCH,
    },
    lower = {
        UK = uk, TSHE = tshe, SHT = sht, JU = ju, JA = ja, JE = je, IJUS = ijus, IBIGJUS = ibigjus, XI = xi, PSI = psi, THETA = theta, SHCH = shch,
    },
}


--- Norwegian (bokmål).

definitions["no"] = {
    entries = {
        ["a"] = "a", ["b"] = "b", ["c"] = "c", ["d"] = "d", ["e"] = "e",
        ["f"] = "f", ["g"] = "g", ["h"] = "h", ["i"] = "i", ["j"] = "j",
        ["k"] = "k", ["l"] = "l", ["m"] = "m", ["n"] = "n", ["o"] = "o",
        ["p"] = "p", ["q"] = "q", ["r"] = "r", ["s"] = "s", ["t"] = "t",
        ["u"] = "u", ["v"] = "v", ["w"] = "w", ["x"] = "x", ["y"] = "y",
        ["z"] = "z", ["æ"] = "æ", ["ø"] = "ø", ["å"] = "å",
    },
    orders = {
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
        "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
        "u", "v", "w", "x", "y", "z", "æ", "ø", "å",
    }
}

--- Danish (-> Norwegian).

definitions["da"] = { parent = "no" }

--- Swedish

definitions["sv"] = {
    entries = {
        ["a"] = "a", ["b"] = "b", ["c"] = "c", ["d"] = "d", ["e"] = "e",
        ["f"] = "f", ["g"] = "g", ["h"] = "h", ["i"] = "i", ["j"] = "j",
        ["k"] = "k", ["l"] = "l", ["m"] = "m", ["n"] = "n", ["o"] = "o",
        ["p"] = "p", ["q"] = "q", ["r"] = "r", ["s"] = "s", ["t"] = "t",
        ["u"] = "u", ["v"] = "v", ["w"] = "w", ["x"] = "x", ["y"] = "y",
        ["z"] = "z", ["å"] = "å", ["ä"] = "ä", ["ö"] = "ö",
    },
    orders = {
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
        "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
        "u", "v", "w", "x", "y", "z", "å", "ä", "ö",
    }
}

--- Icelandic

-- Treating quantities as allographs.

definitions["is"] = {
    entries = {
        ["a"] = "a", ["á"] = "a", ["b"] = "b", ["d"] = "d", ["ð"] = "ð",
        ["e"] = "e", ["é"] = "e", ["f"] = "f", ["g"] = "g", ["h"] = "h",
        ["i"] = "i", ["í"] = "i", ["j"] = "j", ["k"] = "k", ["l"] = "l",
        ["m"] = "m", ["n"] = "n", ["o"] = "o", ["ó"] = "o", ["p"] = "p",
        ["r"] = "r", ["s"] = "s", ["t"] = "t", ["u"] = "u", ["ú"] = "u",
        ["v"] = "v", ["x"] = "x", ["y"] = "y", ["ý"] = "y", ["þ"] = "þ",
        ["æ"] = "æ", ["ö"] = "ö",
    },
    orders = {
        "a", "á", "b", "d", "ð", "e", "é", "f", "g", "h",
        "i", "í", "j", "k", "l", "m", "n", "o", "ó", "p",
        "r", "s", "t", "u", "ú", "v", "x", "y", "ý", "þ",
        "æ", "ö",
    },
}

--- Greek

definitions["gr"] = {
    replacements = {
        { "α", "αa" }, { "ά", "αb" }, { "ὰ", "αc" }, { "ὰ", "αd" }, { "ᾳ", "αe" },
        { "ἀ", "αf" }, { "ἁ", "αg" }, { "ἄ", "αh" }, { "ἂ", "αi" }, { "ἆ", "αj" },
        { "ἁ", "αk" }, { "ἅ", "αl" }, { "ἃ", "αm" }, { "ἇ", "αn" }, { "ᾁ", "αo" },
        { "ᾴ", "αp" }, { "ᾲ", "αq" }, { "ᾷ", "αr" }, { "ᾄ", "αs" }, { "ὰ", "αt" },
        { "ᾅ", "αu" }, { "ᾃ", "αv" }, { "ᾆ", "αw" }, { "ᾇ", "αx" },
        { "ε", "εa" }, { "έ", "εb" }, { "ὲ", "εc" }, { "ἐ", "εd" }, { "ἔ", "εe" },
        { "ἒ", "εf" }, { "ἑ", "εg" }, { "ἕ", "εh" }, { "ἓ", "εi" },
        { "η", "ηa" }, { "η", "ηb" }, { "ή", "ηc" }, { "ὴ", "ηd" }, { "ῆ", "ηe" },
        { "ῃ", "ηf" }, { "ἠ", "ηg" }, { "ἤ", "ηh" }, { "ἢ", "ηi" }, { "ἦ", "ηj" },
        { "ᾐ", "ηk" }, { "ἡ", "ηl" }, { "ἥ", "ηm" }, { "ἣ", "ηn" }, { "ἧ", "ηo" },
        { "ᾑ", "ηp" }, { "ῄ", "ηq" }, { "ῂ", "ηr" }, { "ῇ", "ηs" }, { "ᾔ", "ηt" },
        { "ᾒ", "ηu" }, { "ᾕ", "ηv" }, { "ᾓ", "ηw" }, { "ᾖ", "ηx" }, { "ᾗ", "ηy" },
        { "ι", "ιa" }, { "ί", "ιb" }, { "ὶ", "ιc" }, { "ῖ", "ιd" }, { "ἰ", "ιe" },
        { "ἴ", "ιf" }, { "ἲ", "ιg" }, { "ἶ", "ιh" }, { "ἱ", "ιi" }, { "ἵ", "ιj" },
        { "ἳ", "ιk" }, { "ἷ", "ιl" }, { "ϊ", "ιm" }, { "ΐ", "ιn" }, { "ῒ", "ιo" },
        { "ῗ", "ιp" },
        { "ο", "οa" }, { "ό", "οb" }, { "ὸ", "οc" }, { "ὀ", "οd" }, { "ὄ", "οe" },
        { "ὂ", "οf" }, { "ὁ", "οg" }, { "ὅ", "οh" }, { "ὃ", "οi" },
        { "ρ", "ρa" }, { "ῤ", "ῤb" }, { "ῥ", "ῥc" },
        { "υ", "υa" }, { "ύ", "υb" }, { "ὺ", "υc" }, { "ῦ", "υd" }, { "ὐ", "υe" },
        { "ὔ", "υf" }, { "ὒ", "υg" }, { "ὖ", "υh" }, { "ὑ", "υi" }, { "ὕ", "υj" },
        { "ὓ", "υk" }, { "ὗ", "υl" }, { "ϋ", "υm" }, { "ΰ", "υn" }, { "ῢ", "υo" },
        { "ω", "ωa" }, { "ώ", "ωb" }, { "ὼ", "ωc" }, { "ῶ", "ωd" }, { "ῳ", "ωe" },
        { "ὠ", "ωf" }, { "ὤ", "ωg" }, { "ὢ", "ωh" }, { "ὦ", "ωi" }, { "ᾠ", "ωj" },
        { "ὡ", "ωk" }, { "ὥ", "ωl" }, { "ὣ", "ωm" }, { "ὧ", "ωn" }, { "ᾡ", "ωo" },
        { "ῴ", "ωp" }, { "ῲ", "ωq" }, { "ῷ", "ωr" }, { "ᾤ", "ωs" }, { "ᾢ", "ωt" },
        { "ᾥ", "ωu" }, { "ᾣ", "ωv" }, { "ᾦ", "ωw" }, { "ᾧ", "ωx" },
    },
    entries = {
        ["α"] = "α", ["ά"] = "α", ["ὰ"] = "α", ["ᾶ"] = "α", ["ᾳ"] = "α",
        ["ἀ"] = "α", ["ἁ"] = "α", ["ἄ"] = "α", ["ἂ"] = "α", ["ἆ"] = "α",
        ["ἁ"] = "α", ["ἅ"] = "α", ["ἃ"] = "α", ["ἇ"] = "α", ["ᾁ"] = "α",
        ["ᾴ"] = "α", ["ᾲ"] = "α", ["ᾷ"] = "α", ["ᾄ"] = "α", ["ᾂ"] = "α",
        ["ᾅ"] = "α", ["ᾃ"] = "α", ["ᾆ"] = "α", ["ᾇ"] = "α", ["β"] = "β",
        ["γ"] = "γ", ["δ"] = "δ", ["ε"] = "ε", ["έ"] = "ε", ["ὲ"] = "ε",
        ["ἐ"] = "ε", ["ἔ"] = "ε", ["ἒ"] = "ε", ["ἑ"] = "ε", ["ἕ"] = "ε",
        ["ἓ"] = "ε", ["ζ"] = "ζ", ["η"] = "η", ["η"] = "η", ["ή"] = "η",
        ["ὴ"] = "η", ["ῆ"] = "η", ["ῃ"] = "η", ["ἠ"] = "η", ["ἤ"] = "η",
        ["ἢ"] = "η", ["ἦ"] = "η", ["ᾐ"] = "η", ["ἡ"] = "η", ["ἥ"] = "η",
        ["ἣ"] = "η", ["ἧ"] = "η", ["ᾑ"] = "η", ["ῄ"] = "η", ["ῂ"] = "η",
        ["ῇ"] = "η", ["ᾔ"] = "η", ["ᾒ"] = "η", ["ᾕ"] = "η", ["ᾓ"] = "η",
        ["ᾖ"] = "η", ["ᾗ"] = "η", ["θ"] = "θ", ["ι"] = "ι", ["ί"] = "ι",
        ["ὶ"] = "ι", ["ῖ"] = "ι", ["ἰ"] = "ι", ["ἴ"] = "ι", ["ἲ"] = "ι",
        ["ἶ"] = "ι", ["ἱ"] = "ι", ["ἵ"] = "ι", ["ἳ"] = "ι", ["ἷ"] = "ι",
        ["ϊ"] = "ι", ["ΐ"] = "ι", ["ῒ"] = "ι", ["ῗ"] = "ι", ["κ"] = "κ",
        ["λ"] = "λ", ["μ"] = "μ", ["ν"] = "ν", ["ξ"] = "ξ", ["ο"] = "ο",
        ["ό"] = "ο", ["ὸ"] = "ο", ["ὀ"] = "ο", ["ὄ"] = "ο", ["ὂ"] = "ο",
        ["ὁ"] = "ο", ["ὅ"] = "ο", ["ὃ"] = "ο", ["π"] = "π", ["ρ"] = "ρ",
        ["ῤ"] = "ῤ", ["ῥ"] = "ῥ", ["σ"] = "σ", ["ς"] = "ς", ["τ"] = "τ",
        ["υ"] = "υ", ["ύ"] = "υ", ["ὺ"] = "υ", ["ῦ"] = "υ", ["ὐ"] = "υ",
        ["ὔ"] = "υ", ["ὒ"] = "υ", ["ὖ"] = "υ", ["ὑ"] = "υ", ["ὕ"] = "υ",
        ["ὓ"] = "υ", ["ὗ"] = "υ", ["ϋ"] = "υ", ["ΰ"] = "υ", ["ῢ"] = "υ",
        ["ῧ"] = "υ", ["φ"] = "φ", ["χ"] = "χ", ["ψ"] = "ψ", ["ω"] = "ω",
        ["ώ"] = "ω", ["ὼ"] = "ω", ["ῶ"] = "ω", ["ῳ"] = "ω", ["ὠ"] = "ω",
        ["ὤ"] = "ω", ["ὢ"] = "ω", ["ὦ"] = "ω", ["ᾠ"] = "ω", ["ὡ"] = "ω",
        ["ὥ"] = "ω", ["ὣ"] = "ω", ["ὧ"] = "ω", ["ᾡ"] = "ω", ["ῴ"] = "ω",
        ["ῲ"] = "ω", ["ῷ"] = "ω", ["ᾤ"] = "ω", ["ᾢ"] = "ω", ["ᾥ"] = "ω",
        ["ᾣ"] = "ω", ["ᾦ"] = "ω", ["ᾧ"] = "ω",
    },
 -- orders = {
 --     "α", "ά", "ὰ", "ᾶ", "ᾳ", "ἀ", "ἁ", "ἄ", "ἂ", "ἆ",
 --     "ἁ", "ἅ", "ἃ", "ἇ", "ᾁ", "ᾴ", "ᾲ", "ᾷ", "ᾄ", "ᾂ",
 --     "ᾅ", "ᾃ", "ᾆ", "ᾇ", "β", "γ", "δ", "ε", "έ", "ὲ",
 --     "ἐ", "ἔ", "ἒ", "ἑ", "ἕ", "ἓ", "ζ", "η", "η", "ή",
 --     "ὴ", "ῆ", "ῃ", "ἠ", "ἤ", "ἢ", "ἦ", "ᾐ", "ἡ", "ἥ",
 --     "ἣ", "ἧ", "ᾑ", "ῄ", "ῂ", "ῇ", "ᾔ", "ᾒ", "ᾕ", "ᾓ",
 --     "ᾖ", "ᾗ", "θ", "ι", "ί", "ὶ", "ῖ", "ἰ", "ἴ", "ἲ",
 --     "ἶ", "ἱ", "ἵ", "ἳ", "ἷ", "ϊ", "ΐ", "ῒ", "ῗ", "κ",
 --     "λ", "μ", "ν", "ξ", "ο", "ό", "ὸ", "ὀ", "ὄ", "ὂ",
 --     "ὁ", "ὅ", "ὃ", "π", "ρ", "ῤ", "ῥ", "σ", "ς", "τ",
 --     "υ", "ύ", "ὺ", "ῦ", "ὐ", "ὔ", "ὒ", "ὖ", "ὑ", "ὕ",
 --     "ὓ", "ὗ", "ϋ", "ΰ", "ῢ", "ῧ", "φ", "χ", "ψ", "ω",
 --     "ώ", "ὼ", "ῶ", "ῳ", "ὠ", "ὤ", "ὢ", "ὦ", "ᾠ", "ὡ",
 --     "ὥ", "ὣ", "ὧ", "ᾡ", "ῴ", "ῲ", "ῷ", "ᾤ", "ᾢ", "ᾥ",
 --     "ᾣ", "ᾦ", "ᾧ",
 -- },
    orders = {
        "α", "β", "γ", "δ", "ε", "ζ", "η", "θ", "ι", "κ",
        "λ", "μ", "ν", "ξ", "ο", "π", "ρ", "σ", "ς", "τ",
        "υ", "φ", "χ", "ψ", "ω",
    },
}

--- Latin

-- Treating the post-classical fricatives “j” and “v” as “i” and “u”
-- respectively.

definitions["la"] = {
    replacements = {
        { "æ", "ae" }, { "Æ", "AE" },
    },
    entries = {
        ["a"] = "a", ["ā"] = "a", ["ă"] = "a", ["b"] = "b", ["c"] = "c",
        ["d"] = "d", ["e"] = "e", ["ē"] = "e", ["ĕ"] = "e", ["f"] = "f",
        ["g"] = "g", ["h"] = "h", ["i"] = "i", ["ī"] = "i", ["ĭ"] = "i",
        ["j"] = "i", ["k"] = "k", ["l"] = "l", ["m"] = "m", ["n"] = "n",
        ["o"] = "o", ["ō"] = "o", ["ŏ"] = "o", ["p"] = "p", ["q"] = "q",
        ["r"] = "r", ["s"] = "s", ["t"] = "t", ["u"] = "u", ["ū"] = "u",
        ["ŭ"] = "u", ["v"] = "u", ["w"] = "w", ["x"] = "x", ["y"] = "y",
        ["ȳ"] = "y", ["y̆"] = "y", ["z"] = "z",
    },
    orders = {
        "a", "ā", "ă", "b", "c", "d", "e", "ē", "ĕ", "f",
        "g", "h", "i", "ī", "ĭ", "j", "k", "l", "m", "n",
        "o", "ō", "ŏ", "p", "q", "r", "s", "t", "u", "ū",
        "ŭ", "v", "w", "x", "y", "ȳ", "y̆", "z",
    }
}

--- Italian

definitions["it"] = {
    entries = {
        ["a"] = "a", ["á"] = "a", ["b"] = "b", ["c"] = "c", ["d"] = "d",
        ["e"] = "e", ["é"] = "e", ["è"] = "e", ["f"] = "f", ["g"] = "g",
        ["h"] = "h", ["i"] = "i", ["í"] = "i", ["ì"] = "i", ["j"] = "j",
        ["k"] = "k", ["l"] = "l", ["m"] = "m", ["n"] = "n", ["o"] = "o",
        ["ó"] = "o", ["ò"] = "o", ["p"] = "p", ["q"] = "q", ["r"] = "r",
        ["s"] = "s", ["t"] = "t", ["u"] = "u", ["ú"] = "u", ["ù"] = "u",
        ["v"] = "v", ["w"] = "w", ["x"] = "x", ["y"] = "y", ["z"] = "z",
    },
    orders = {
        "a", "á", "b", "c", "d", "e", "é", "è", "f", "g",
        "h", "i", "í", "ì", "j", "k", "l", "m", "n", "o",
        "ó", "ò", "p", "q", "r", "s", "t", "u", "ú", "ù",
        "v", "w", "x", "y", "z",
    }
}

--- Romanian

definitions["ro"] = {
    entries = {
        ["a"] = "a", ["ă"] = "ă", ["â"] = "â", ["b"] = "b", ["c"] = "c",
        ["d"] = "d", ["e"] = "e", ["f"] = "f", ["g"] = "g", ["h"] = "h",
        ["i"] = "i", ["î"] = "î", ["j"] = "j", ["k"] = "k", ["l"] = "l",
        ["m"] = "m", ["n"] = "n", ["o"] = "o", ["p"] = "p", ["q"] = "q",
        ["r"] = "r", ["s"] = "s", ["ș"] = "ș", ["t"] = "t", ["ț"] = "ț",
        ["u"] = "u", ["v"] = "v", ["w"] = "w", ["x"] = "x", ["y"] = "y",
        ["z"] = "z",
    },
    orders = {
        "a", "ă", "â", "b", "c", "d", "e", "f", "g", "h",
        "i", "î", "j", "k", "l", "m", "n", "o", "p", "q",
        "r", "s", "ș", "t", "ț", "u", "v", "w", "x", "y",
        "z",
    }
}

--- Spanish

definitions["es"] = {
    entries = {
        ["a"] = "a", ["á"] = "a", ["b"] = "b", ["c"] = "c", ["d"] = "d",
        ["e"] = "e", ["é"] = "e", ["f"] = "f", ["g"] = "g", ["h"] = "h",
        ["i"] = "i", ["í"] = "i", ["j"] = "j", ["k"] = "k", ["l"] = "l",
        ["m"] = "m", ["n"] = "n", ["ñ"] = "ñ", ["o"] = "o", ["ó"] = "o",
        ["p"] = "p", ["q"] = "q", ["r"] = "r", ["s"] = "s", ["t"] = "t",
        ["u"] = "u", ["ú"] = "u", ["ü"] = "u", ["v"] = "v", ["w"] = "w",
        ["x"] = "x", ["y"] = "y", ["z"] = "z",
    },
 -- orders = {
 --     "a", "á", "b", "c", "d", "e", "é", "f", "g", "h",
 --     "i", "í", "j", "k", "l", "m", "n", "ñ", "o", "ó",
 --     "p", "q", "r", "s", "t", "u", "ú", "ü", "v", "w",
 --     "x", "y", "z",
 -- },
    orders = {
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
        "k", "l", "m", "n", "ñ", "o", "p", "q", "r", "s",
        "t", "u", "v", "w", "x", "y", "z",
    },
}

--- Portuguese

definitions["pt"] = {
    entries = {
        ["a"] = "a", ["á"] = "a", ["â"] = "a", ["ã"] = "a", ["à"] = "a",
        ["b"] = "b", ["c"] = "c", ["ç"] = "c", ["d"] = "d", ["e"] = "e",
        ["é"] = "e", ["ê"] = "e", ["f"] = "f", ["g"] = "g", ["h"] = "h",
        ["i"] = "i", ["í"] = "i", ["j"] = "j", ["k"] = "k", ["l"] = "l",
        ["m"] = "m", ["n"] = "n", ["o"] = "o", ["ó"] = "o", ["ô"] = "o",
        ["õ"] = "o", ["p"] = "p", ["q"] = "q", ["r"] = "r", ["s"] = "s",
        ["t"] = "t", ["u"] = "u", ["ú"] = "u", ["ü"] = "u", ["v"] = "v",
        ["w"] = "w", ["x"] = "x", ["y"] = "y", ["z"] = "z",
    },
    orders = {
        "a", "á", "â", "ã", "à", "b", "c", "ç", "d", "e",
        "é", "ê", "f", "g", "h", "i", "í", "j", "k", "l",
        "m", "n", "o", "ó", "ô", "õ", "p", "q", "r", "s",
        "t", "u", "ú", "ü", "v", "w", "x", "y", "z",
    }
}

--- Lithuanian

local ch, CH = utfchar(replacementoffset + 1), utfchar(replacementoffset + 11)

definitions["lt"] = {
    replacements = {
        { "ch", ch }, { "CH", CH}
    },
    entries = {
        ["a"] = "a", ["ą"] = "a", ["b"] = "b", ["c"] = "c", [ch ] = "c",
        ["č"] = "č", ["d"] = "d", ["e"] = "e", ["ę"] = "e", ["ė"] = "e",
        ["f"] = "f", ["g"] = "g", ["h"] = "h", ["i"] = "i", ["į"] = "i",
        ["y"] = "i", ["j"] = "j", ["k"] = "k", ["l"] = "l", ["m"] = "m",
        ["n"] = "n", ["o"] = "o", ["p"] = "p", ["r"] = "r", ["s"] = "s",
        ["š"] = "š", ["t"] = "t", ["u"] = "u", ["ų"] = "u", ["ū"] = "u",
        ["v"] = "v", ["z"] = "z", ["ž"] = "ž",
    },
    orders = {
        "a", "ą", "b", "c", ch,  "č", "d", "e", "ę", "ė",
        "f", "g", "h", "i", "į", "y", "j", "k", "l", "m",
        "n", "o", "p", "r", "s", "š", "t", "u", "ų", "ū",
        "v", "z", "ž",
    },
    lower = {
        ch = CH,
    },
    upper = {
        CH = ch,
    },
}

--- Latvian

definitions["lv"] = {
    entries = {
        ["a"] = "a", ["ā"] = "a", ["b"] = "b", ["c"] = "c", ["č"] = "č",
        ["d"] = "d", ["e"] = "e", ["ē"] = "e", ["f"] = "f", ["g"] = "g",
        ["ģ"] = "ģ", ["h"] = "h", ["i"] = "i", ["ī"] = "i", ["j"] = "j",
        ["k"] = "k", ["ķ"] = "ķ", ["l"] = "l", ["ļ"] = "ļ", ["m"] = "m",
        ["n"] = "n", ["ņ"] = "ņ", ["o"] = "o", ["ō"] = "o", ["p"] = "p",
        ["r"] = "r", ["ŗ"] = "ŗ", ["s"] = "s", ["š"] = "š", ["t"] = "t",
        ["u"] = "u", ["ū"] = "u", ["v"] = "v", ["z"] = "z", ["ž"] = "ž",
    },
    orders = {
        "a", "ā", "b", "c", "č", "d", "e", "ē", "f", "g",
        "ģ", "h", "i", "ī", "j", "k", "ķ", "l", "ļ", "m",
        "n", "ņ", "o", "ō", "p", "r", "ŗ", "s", "š", "t",
        "u", "ū", "v", "z", "ž",
    }
}

--- Hungarian

-- Helpful but disturbing:
-- http://en.wikipedia.org/wiki/Hungarian_alphabet#Alphabetical_ordering_.28collation.29
-- (In short: you'd have to analyse word-compounds to realize a correct order
-- for sequences like “nny”, “ssz”, and “zsz”. This is left as an exercise to
-- the reader…)

local cs,  CS  = utfchar(replacementoffset + 1), utfchar(replacementoffset + 11)
local dz,  DZ  = utfchar(replacementoffset + 2), utfchar(replacementoffset + 12)
local dzs, DZS = utfchar(replacementoffset + 3), utfchar(replacementoffset + 13)
local gy,  GY  = utfchar(replacementoffset + 4), utfchar(replacementoffset + 14)
local ly,  LY  = utfchar(replacementoffset + 5), utfchar(replacementoffset + 15)
local ny,  NY  = utfchar(replacementoffset + 6), utfchar(replacementoffset + 16)
local sz,  SZ  = utfchar(replacementoffset + 7), utfchar(replacementoffset + 17)
local ty,  TY  = utfchar(replacementoffset + 8), utfchar(replacementoffset + 18)
local zs,  ZS  = utfchar(replacementoffset + 9), utfchar(replacementoffset + 19)

definitions["hu"] = {
    replacements = {
        { "cs",  cs  }, { "CS",  CS  },
        { "dz",  dz  }, { "DZ",  DZ  },
        { "dzs", dzs }, { "DZS", DZS },
        { "gy",  gy  }, { "GY",  GY  },
        { "ly",  ly  }, { "LY",  LY  },
        { "ny",  ny  }, { "NY",  NY  },
        { "sz",  sz  }, { "SZ",  SZ  },
        { "ty",  ty  }, { "TY",  TY  },
        { "zs",  zs  }, { "ZS",  ZS  },
    },
    entries = {
        ["a"] = "a", ["á"] = "a",  ["b"] = "b",   ["c"] = "c",  [cs ] = "cs",
        ["d"] = "d", [dz ] = "dz", [dzs] = "dzs", ["e"] = "e",  ["é"] = "e",
        ["f"] = "f", ["g"] = "g",  [gy ] = "gy",  ["h"] = "h",  ["i"] = "i",
        ["í"] = "i", ["j"] = "j",  ["k"] = "k",   ["l"] = "l",  [ly ] = "ly",
        ["m"] = "m", ["n"] = "n",  [ny ] = "ny",  ["o"] = "o",  ["ó"] = "o",
        ["ö"] = "ö", ["ő"] = "ö",  ["p"] = "p",   ["q"] = "q",  ["r"] = "r",
        ["s"] = "s", [sz ] = "sz", ["t"] = "t",   [ty ] = "ty", ["u"] = "u",
        ["ú"] = "u", ["ü"] = "ü",  ["ű"] = "ü",   ["v"] = "v",  ["w"] = "w",
        ["x"] = "x", ["y"] = "y",  ["z"] = "z",   [zs ] = "zs",
    },
    orders = {
        "a", "á", "b", "c", cs,  "d", dz,  dzs, "e", "é",
        "f", "g", gy,  "h", "i", "í", "j", "k", "l", ly,
        "m", "n", ny,  "o", "ó", "ö", "ő", "p", "q", "r",
        "s", sz,  "t", ty, "u", "ú", "ü", "ű", "v", "w",
        "x", "y", "z", zs,
    },
    lower = {
        CS = cs, DZ = dz, DZS = dzs, GY = gy, LY = ly, NY = ny, SZ = sz, TY = ty, ZS = zs,
    },
    upper = {
        cs = CS, dz = DZ, dzs = DZS, gy = GY, ly = LY, ny = NY, sz = SZ, ty = TY, zs = ZS,
    },
}

-- Estonian

definitions["et"] = {
    entries = { -- f š z ž are used in estonian words of foreign origin, c č q w x y are used for foreign words only
        ["a"] = "a", ["b"] = "b", ["c"] = "c", ["č"] = "č", ["d"] = "d",
        ["e"] = "e", ["f"] = "f", ["g"] = "g", ["h"] = "h", ["i"] = "i",
        ["j"] = "j", ["k"] = "k", ["l"] = "l", ["m"] = "m", ["n"] = "n",
        ["o"] = "o", ["p"] = "p", ["q"] = "q", ["r"] = "r", ["s"] = "s",
        ["š"] = "š", ["z"] = "z", ["ž"] = "ž", ["t"] = "t", ["u"] = "u",
        ["v"] = "v", ["w"] = "w", ["õ"] = "õ", ["ä"] = "ä", ["ö"] = "ö",
        ["ü"] = "ü", ["x"] = "x", ["y"] = "y",
    },
    orders = {
        "a", "b", "c", "č", "d", "e", "f", "g", "h", "i",
        "j", "k", "l", "m", "n", "o", "p", "q", "r", "s",
        "š", "z", "ž", "t", "u", "v", "w", "õ", "ä", "ö",
        "ü", "x", "y",
    },
}

--- Korean

local fschars = characters.fschars

local function firstofsplit(first)
    local fs = fschars[first] or first -- leadconsonant
    return fs, fs -- entry, tag
end

definitions["kr"] = {
    firstofsplit = firstofsplit,
    orders       = {
        "ㄱ", "ㄴ", "ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ",
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
        "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
    }
}

-- Japanese

definitions["jp"] = {
    replacements = {
        { "ぁ", "あ" }, { "ぃ", "い" },
        { "ぅ", "う" }, { "ぇ", "え" },
        { "ぉ", "お" }, { "っ", "つ" },
        { "ゃ", "や" }, { "ゅ", "ゆ" },
        { "ょ", "よ" },
    },
    entries = {
        ["あ"] = "あ", ["い"] = "い", ["う"] = "う", ["え"] = "え", ["お"] = "お",
        ["か"] = "か", ["き"] = "き", ["く"] = "く", ["け"] = "け", ["こ"] = "こ",
        ["さ"] = "さ", ["し"] = "し", ["す"] = "す", ["せ"] = "せ", ["そ"] = "そ",
        ["た"] = "た", ["ち"] = "ち", ["つ"] = "つ", ["て"] = "て", ["と"] = "と",
        ["な"] = "な", ["に"] = "に", ["ぬ"] = "ぬ", ["ね"] = "ね", ["の"] = "の",
        ["は"] = "は", ["ひ"] = "ひ", ["ふ"] = "ふ", ["へ"] = "へ", ["ほ"] = "ほ",
        ["ま"] = "ま", ["み"] = "み", ["む"] = "む", ["め"] = "め", ["も"] = "も",
        ["や"] = "や", ["ゆ"] = "ゆ", ["よ"] = "よ",
        ["ら"] = "ら", ["り"] = "り", ["る"] = "る", ["れ"] = "れ", ["ろ"] = "ろ",
        ["わ"] = "わ", ["ゐ"] = "ゐ", ["ゑ"] = "ゑ", ["を"] = "を", ["ん"] = "ん",
    },
    orders = {
        "あ", "い", "う", "え", "お", "か", "き", "く", "け", "こ",
        "さ", "し", "す", "せ", "そ", "た", "ち", "つ", "て", "と",
        "な", "に", "ぬ", "ね", "の", "は", "ひ", "ふ", "へ", "ほ",
        "ま", "み", "む", "め", "も", "や", "ゆ", "よ",
        "ら", "り", "る", "れ", "ろ", "わ", "ゐ", "ゑ", "を", "ん",
    }
}
